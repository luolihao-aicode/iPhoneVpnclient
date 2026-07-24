import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'models/node.dart';
import 'node_grouping.dart';

class SubscriptionError implements Exception {
  final String message;
  const SubscriptionError(this.message);
  @override
  String toString() => message;
}

String _decodeBase64(String input) {
  final clean = input.replaceAll('-', '+').replaceAll('_', '/').trim();
  if (clean.isEmpty || clean.length % 4 == 1) return '';
  try {
    final decoded = utf8.decode(base64.decode(clean.padRight((clean.length / 4).ceil() * 4, '=')));
    if (decoded.contains(':') || decoded.contains('{') || decoded.contains('}')) return decoded;
    return '';
  } catch (_) {
    return '';
  }
}

String _cryptoId(String value) {
  int hash = 2166136261;
  for (final char in value.codeUnits) {
    hash ^= char;
    hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
  }
  return 'node-${(hash & 0xFFFFFFFF).toRadixString(16)}';
}

VpnNode? _normalizeJsonNode(Map<String, dynamic> node, [int index = 0]) {
  final type = (node['type'] ?? node['protocol'] ?? '').toString().toLowerCase();
  final name = (node['name'] ?? node['remarks'] ?? node['ps'] ?? '$type-${index + 1}').toString();

  if (type == 'ss' || type == 'shadowsocks') {
    final server = (node['server'] ?? node['address'] ?? '').toString();
    final port = int.tryParse(node['server_port']?.toString() ?? node['port']?.toString() ?? '0') ?? 0;
    return VpnNode(
      id: node['nodeId']?.toString() ?? _cryptoId('shadowsocks:$name:$server:$port'),
      type: NodeType.shadowsocks,
      name: name,
      server: server,
      port: port,
      method: node['method']?.toString() ?? node['cipher']?.toString(),
      password: node['password']?.toString(),
    );
  }

  if (type == 'vmess') {
    final server = (node['add'] ?? node['address'] ?? node['server'] ?? '').toString();
    final port = int.tryParse(node['port']?.toString() ?? '0') ?? 0;
    final uuid = (node['id'] ?? node['uuid'] ?? '').toString();
    final transport = (node['net'] ?? node['network'] ?? node['transport'] ?? 'tcp').toString();
    return VpnNode(
      id: node['nodeId']?.toString() ?? _cryptoId('vmess:$name:$server:$port:$uuid:$transport'),
      type: NodeType.vmess,
      name: name,
      server: server,
      port: port,
      uuid: uuid,
      security: node['security']?.toString() ?? 'auto',
      alterId: int.tryParse(node['aid']?.toString() ?? node['alterId']?.toString() ?? '0') ?? 0,
      transport: transport,
      host: node['host']?.toString() ?? node['requestHost']?.toString(),
      path: node['path']?.toString(),
      tls: node['tls'] == 'tls' || node['tls'] == true || node['streamSecurity'] == 'tls',
      serverName: node['sni']?.toString() ?? node['serverName']?.toString() ?? node['host']?.toString(),
      insecure: node['allowInsecure'] == true || node['allowInsecure'] == 'true' || node['allowInsecure'] == 'True',
    );
  }

  if (type == 'vless' || type == 'trojan') {
    final server = (node['server'] ?? node['address'] ?? '').toString();
    final port = int.tryParse(node['port']?.toString() ?? '0') ?? 0;
    final uuid = node['uuid']?.toString() ?? node['id']?.toString() ?? '';
    final password = node['password']?.toString();
    return VpnNode(
      id: node['nodeId']?.toString() ??
          _cryptoId('$type:$name:$server:$port:${uuid.isNotEmpty ? uuid : (password ?? '')}'),
      type: type == 'vless' ? NodeType.vless : NodeType.trojan,
      name: name,
      server: server,
      port: port,
      uuid: uuid.isNotEmpty ? uuid : null,
      password: password,
      tls: node['tls'] != false,
      serverName: node['serverName']?.toString() ?? node['sni']?.toString(),
      flow: node['flow']?.toString(),
    );
  }

  if (type == 'anytls' || type == 'any-tls') {
    final server = (node['server'] ?? node['address'] ?? '').toString();
    final port = int.tryParse(
          node['server_port']?.toString() ?? node['port']?.toString() ?? '0',
        ) ??
        0;
    final tls = node['tls'] is Map
        ? Map<String, dynamic>.from(node['tls'] as Map)
        : const <String, dynamic>{};
    return VpnNode(
      id: node['nodeId']?.toString() ?? _cryptoId('anytls:$name:$server:$port'),
      type: NodeType.anytls,
      name: name,
      server: server,
      port: port,
      password: node['password']?.toString(),
      tls: node['tls'] != false,
      serverName: node['serverName']?.toString() ??
          node['sni']?.toString() ??
          node['servername']?.toString() ??
          tls['server_name']?.toString() ??
          server,
      insecure: node['insecure'] == true ||
          node['skip-cert-verify'] == true ||
          tls['insecure'] == true,
      idleSessionCheckInterval:
          node['idle_session_check_interval']?.toString(),
      idleSessionTimeout: node['idle_session_timeout']?.toString(),
      minIdleSession:
          int.tryParse(node['min_idle_session']?.toString() ?? '0') ?? 0,
    );
  }

  if (type == 'wireguard') {
    final server = (node['server'] ?? node['address'] ?? '').toString();
    final port = int.tryParse(node['port']?.toString() ?? '51820') ?? 51820;
    return VpnNode(
      id: node['nodeId']?.toString() ??
          _cryptoId('wireguard:$name:$server:$port:${node['peerPublicKey'] ?? node['public_key'] ?? ''}'),
      type: NodeType.wireguard,
      name: name,
      server: server,
      port: port,
      privateKey: node['privateKey']?.toString() ?? node['private_key']?.toString(),
      peerPublicKey: node['peerPublicKey']?.toString() ?? node['public_key']?.toString(),
      preSharedKey: node['preSharedKey']?.toString() ?? node['pre_shared_key']?.toString(),
      localAddress: node['localAddress']?.toString() ?? node['local_address']?.toString(),
      reserved: (node['reserved'] as List?)?.cast<int>(),
    );
  }

  return null;
}

List<VpnNode> _parseJsonSubscription(String text) {
  final value = json.decode(text);
  if (value is List) {
    return value.map((n) => _normalizeJsonNode(n as Map<String, dynamic>)).where((n) => n != null).cast<VpnNode>().toList();
  }
  if (value is! Map) throw const SubscriptionError('Invalid subscription format');

  final map = value as Map<String, dynamic>;
  final msg = map['msg'] ?? map['message'] ?? map['error'] ?? map['detail'];
  if (msg != null && msg.toString().isNotEmpty) {
    final hasNodes = [
      map['nodes'], map['proxies'], map['servers'],
      map['vmess'], map['shadowsocks'], map['anytls'], map['wireguard'],
    ].any((v) => v is List && v.isNotEmpty);
    if (!hasNodes) throw SubscriptionError(msg.toString());
  }

  for (final key in ['vmess', 'shadowsocks', 'anytls', 'wireguard']) {
    if (map[key] is List) {
      return (map[key] as List).map((n) {
        final node = Map<String, dynamic>.from(n as Map);
        node['type'] = key;
        return _normalizeJsonNode(node);
      }).where((n) => n != null).cast<VpnNode>().toList();
    }
  }

  final nodes = map['nodes'] ?? map['proxies'] ?? map['servers'];
  if (nodes is List) {
    return nodes.map((n) => _normalizeJsonNode(n as Map<String, dynamic>)).where((n) => n != null).cast<VpnNode>().toList();
  }

  throw const SubscriptionError('No nodes found in subscription');
}

dynamic _yamlToDart(dynamic value) {
  if (value is YamlMap) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _yamlToDart(entry.value),
    };
  }
  if (value is YamlList) {
    return value.map(_yamlToDart).toList();
  }
  return value;
}

List<VpnNode> _parseClashYaml(String text) {
  final document = loadYaml(text);
  final normalized = _yamlToDart(document);
  if (normalized is! Map) {
    throw const SubscriptionError('Invalid Clash subscription format');
  }

  final proxies = normalized['proxies'];
  if (proxies is! List) {
    throw const SubscriptionError('No nodes found in Clash subscription');
  }

  return proxies
      .whereType<Map>()
      .map((proxy) => _normalizeJsonNode(Map<String, dynamic>.from(proxy)))
      .where((node) => node != null)
      .cast<VpnNode>()
      .toList();
}

VpnNode? _parseSsUri(String uri) {
  final withoutScheme = uri.substring('ss://'.length);
  final parts = withoutScheme.split('#');
  final main = parts[0];
  final decodedName = Uri.decodeComponent(parts.length > 1 ? parts[1] : 'Shadowsocks');
  final queryParts = main.split('?');
  final userinfoRaw = queryParts[0];
  final queryRaw = queryParts.length > 1 ? queryParts[1] : '';

  final decodedWhole = !userinfoRaw.contains('@') ? _decodeBase64(userinfoRaw) : '';
  final source = decodedWhole.isNotEmpty ? decodedWhole : userinfoRaw;
  final atParts = source.contains('@') ? source.split('@') : userinfoRaw.split('@');
  final encodedPart = atParts.length > 0 ? atParts[0] : '';
  final userinfo = encodedPart.contains(':') ? encodedPart : _decodeBase64(encodedPart);
  if (userinfo.isEmpty) return null;

  final colonIdx = userinfo.indexOf(':');
  if (colonIdx < 0) return null;
  final method = userinfo.substring(0, colonIdx);
  final password = userinfo.substring(colonIdx + 1);
  final target = atParts.length > 1 ? atParts[1] : '';
  final targetParts = target.split(':');
  if (targetParts.length < 2) return null;

  final port = int.tryParse(targetParts[1]) ?? 0;
  final params = Uri.splitQueryString(queryRaw);

  return VpnNode(
    id: _cryptoId(uri),
    type: NodeType.shadowsocks,
    name: decodedName,
    server: targetParts[0],
    port: port,
    method: method,
    password: password,
    plugin: params['plugin'],
  );
}

VpnNode? _parseVmessUri(String uri) {
  final decoded = _decodeBase64(uri.substring('vmess://'.length));
  if (decoded.isEmpty) return null;
  final node = json.decode(decoded) as Map<String, dynamic>;
  node['type'] = 'vmess';
  return _normalizeJsonNode(node);
}

VpnNode? _parseUrlNode(String uri, NodeType type) {
  final parsed = Uri.parse(uri);
  final params = parsed.queryParameters;
  final name = Uri.decodeComponent(parsed.fragment.isNotEmpty ? parsed.fragment : '${type.name}-${parsed.host}');

  if (type == NodeType.vless) {
    return VpnNode(
      id: _cryptoId(uri),
      type: type,
      name: name,
      server: parsed.host,
      port: parsed.port,
      uuid: parsed.userInfo,
      tls: params['security'] == 'tls' || params['security'] == 'reality',
      serverName: params['sni'] ?? params['peer'] ?? parsed.host,
      flow: params['flow'],
      transport: params['type'] ?? 'tcp',
      path: params['path'],
      host: params['host'],
    );
  }

  if (type == NodeType.anytls) {
    final params = parsed.queryParameters;
    return VpnNode(
      id: _cryptoId(uri),
      type: type,
      name: name,
      server: parsed.host,
      port: parsed.port,
      password: parsed.userInfo.isNotEmpty
          ? Uri.decodeComponent(parsed.userInfo)
          : params['password'],
      tls: true,
      serverName: params['sni'] ?? parsed.host,
      insecure: params['insecure'] == '1' || params['insecure'] == 'true',
      idleSessionCheckInterval: params['idle_session_check_interval'],
      idleSessionTimeout: params['idle_session_timeout'],
      minIdleSession: int.tryParse(params['min_idle_session'] ?? '0') ?? 0,
    );
  }

  return VpnNode(
    id: _cryptoId(uri),
    type: type,
    name: name,
    server: parsed.host,
    port: parsed.port,
    password: parsed.userInfo,
    tls: true,
    serverName: params['sni'] ?? parsed.host,
  );
}

VpnNode? _parseLine(String line) {
  final text = line.trim();
  if (text.isEmpty) return null;
  if (text.startsWith('ss://')) return _parseSsUri(text);
  if (text.startsWith('vmess://')) return _parseVmessUri(text);
  if (text.startsWith('vless://')) return _parseUrlNode(text, NodeType.vless);
  if (text.startsWith('trojan://')) return _parseUrlNode(text, NodeType.trojan);
  if (text.startsWith('anytls://')) return _parseUrlNode(text, NodeType.anytls);
  return null;
}

/// Resolve a pasted subscription URL or an app-specific install wrapper.
String? resolveSubscriptionInput(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (uri.scheme == 'http' || uri.scheme == 'https') return text;
  if (uri.scheme.toLowerCase() == 'stash' &&
      (uri.host == 'install-config' || uri.path == '/install-config')) {
    final url = uri.queryParameters['url'];
    if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
      return url;
    }
  }
  return null;
}

List<VpnNode> _dedupeNodes(List<VpnNode> nodes) {
  final seen = <String>{};
  return nodes.where((n) {
    final key = n.id;
    if (seen.contains(key)) return false;
    seen.add(key);
    return true;
  }).toList();
}

List<VpnNode> _filterSubscriptionMetadata(List<VpnNode> nodes) {
  return nodes.where((node) => !isSubscriptionMetadataName(node.name)).toList();
}

/// Parse raw subscription text and return list of nodes.
List<VpnNode> parseSubscription(String rawText) {
  final source = rawText.trim();
  if (source.isEmpty) return [];

  final decodedCandidate = _decodeBase64(source);
  final decoded = decodedCandidate.isNotEmpty &&
          (decodedCandidate.contains('://') || decodedCandidate.startsWith('{') || decodedCandidate.startsWith('['))
      ? decodedCandidate
      : '';
  final candidates = [source, decoded].where((s) => s.isNotEmpty).toList();

  for (final candidate in candidates) {
    if (RegExp(r'^\s*proxies\s*:', multiLine: true).hasMatch(candidate)) {
      try {
        final yamlNodes = _parseClashYaml(candidate);
        if (yamlNodes.isNotEmpty) {
          return _dedupeNodes(_filterSubscriptionMetadata(yamlNodes));
        }
      } on SubscriptionError {
        // Continue with the other supported subscription formats.
      } catch (_) {
        // Continue with JSON and line-based parsing.
      }
    }
    try {
      return _filterSubscriptionMetadata(_parseJsonSubscription(candidate));
    } on SubscriptionError {
      rethrow;
    } catch (_) {
      // Continue with line-based parsing
    }
  }

  final lines = (decoded.isNotEmpty ? decoded : source).split(RegExp(r'\r?\n'));
  final nodes = lines.map(_parseLine).where((n) => n != null).cast<VpnNode>().where((n) => n.isUsable).toList();
  return _dedupeNodes(_filterSubscriptionMetadata(nodes));
}

/// Fetch subscription from a URL.
Future<List<VpnNode>> fetchSubscription(String url, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final uri = Uri.parse(url);
    final response = await c.get(uri, headers: {
      'User-Agent': 'ForgeDesktopVPN/0.1',
      'Accept': 'text/plain, application/json, */*',
    });

    // Some subscription endpoints only allow known proxy clients. FlClash
    // sends this identity and commonly receives Clash YAML in response.
    var effectiveResponse = response;
    if (effectiveResponse.statusCode == 403) {
      effectiveResponse = await c.get(uri, headers: {
        'User-Agent': 'flclash',
        'Accept': 'application/yaml, text/yaml, text/plain, */*',
        'Cache-Control': 'no-cache',
      });
    }
    if (effectiveResponse.statusCode == 403) {
      // Keep a browser fallback for endpoints that permit browsers instead.
      effectiveResponse = await c.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Cache-Control': 'no-cache',
      });
    }

    if (effectiveResponse.statusCode != 200) {
      if (effectiveResponse.statusCode == 403) {
        throw Exception(
          'Subscription request failed: HTTP 403 (link expired or server rejected the client)',
        );
      }
      throw Exception(
          'Subscription request failed: HTTP ${effectiveResponse.statusCode}');
    }
    return parseSubscription(effectiveResponse.body);
  } finally {
    if (client == null) c.close();
  }
}
