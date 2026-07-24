import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_vpn_flutter/core/models/node.dart';
import 'package:forge_vpn_flutter/core/singbox_config.dart';
import 'package:forge_vpn_flutter/core/subscription.dart';

class _RetryingSubscriptionClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (requests.length == 1) {
      return http.StreamedResponse(
        Stream<List<int>>.value(utf8.encode('forbidden')),
        403,
        request: request,
      );
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('anytls://secret@example.com:443#AnyTLS')),
      200,
      request: request,
    );
  }
}

void main() {
  test('resolves a pasted Stash install link to its HTTPS subscription', () {
    final encoded = Uri.encodeComponent('https://example.com/temporary-config');
    expect(
      resolveSubscriptionInput('stash://install-config?url=$encoded&name=AnyTLS'),
      'https://example.com/temporary-config',
    );
  });

  test('parses an AnyTLS URI node', () {
    final node = parseSubscription(
      'anytls://secret@example.com:443?sni=cdn.example.com#AnyTLS',
    ).single;

    expect(node.type, NodeType.anytls);
    expect(node.password, 'secret');
    expect(node.serverName, 'cdn.example.com');
    expect(node.tls, isTrue);
  });

  test('parses AnyTLS JSON and generates its sing-box outbound', () {
    final node = parseSubscription(jsonEncode({
      'type': 'anytls',
      'name': 'AnyTLS JSON',
      'server': 'example.com',
      'server_port': 443,
      'password': 'secret',
      'tls': {'server_name': 'cdn.example.com', 'insecure': true},
      'idle_session_check_interval': '30s',
      'idle_session_timeout': '30s',
      'min_idle_session': 2,
    })).single;

    final config = buildSingBoxConfig(node: node, includeSocks: false);
    final outbound = (config['outbounds'] as List).first as Map;

    expect(outbound['type'], 'anytls');
    expect(outbound['password'], 'secret');
    expect(outbound['min_idle_session'], 2);
    expect((outbound['tls'] as Map)['server_name'], 'cdn.example.com');
  });

  test('retries a forbidden subscription request with the FlClash user agent', () async {
    final client = _RetryingSubscriptionClient();

    final nodes = await fetchSubscription(
      'https://example.com/temporary-config',
      client: client,
    );

    expect(nodes, hasLength(1));
    expect(client.requests, hasLength(2));
    expect(client.requests.first.headers['User-Agent'], 'ForgeDesktopVPN/0.1');
    expect(client.requests.last.headers['User-Agent'], 'flclash');
  });

  test('parses AnyTLS from a Clash YAML subscription', () {
    final nodes = parseSubscription('''
proxies:
  - name: AnyTLS YAML
    type: anytls
    server: example.com
    port: 443
    password: secret
    sni: cdn.example.com
    skip-cert-verify: true
''');

    expect(nodes, hasLength(1));
    expect(nodes.single.type, NodeType.anytls);
    expect(nodes.single.serverName, 'cdn.example.com');
    expect(nodes.single.insecure, isTrue);
  });

  test('filters traffic and expiry metadata from subscription nodes', () {
    final nodes = parseSubscription(jsonEncode({
      'proxies': [
        {
          'type': 'anytls',
          'name': '🇭🇰 Hong Kong | 01',
          'server': 'hk.example.com',
          'port': 443,
          'password': 'secret',
        },
        {
          'type': 'anytls',
          'name': 'Traffic Reset: 26 Days Left',
          'server': 'hk.example.com',
          'port': 443,
          'password': 'secret',
        },
        {
          'type': 'anytls',
          'name': 'Expire Date: 2026-10-18',
          'server': 'hk.example.com',
          'port': 443,
          'password': 'secret',
        },
        {
          'type': 'anytls',
          'name': '31.26 GB | 150 GB',
          'server': 'hk.example.com',
          'port': 443,
          'password': 'secret',
        },
      ],
    }));

    expect(nodes, hasLength(1));
    expect(nodes.single.name, '🇭🇰 Hong Kong | 01');
  });

  test('routes common emulator DNS addresses directly', () {
    final config = buildSingBoxConfig(
      node: const VpnNode(
        id: 'hkg-1',
        type: NodeType.anytls,
        name: '🇭🇰 Hong Kong | 01',
        server: 'hk.example.com',
        port: 443,
        password: 'secret',
      ),
      tunEnabled: true,
      includeSocks: false,
    );
    final rules = ((config['route'] as Map)['rules'] as List)
        .cast<Map<String, dynamic>>();

    expect(
      rules,
      contains(
        predicate<Map<String, dynamic>>((rule) {
          final cidrs = (rule['ip_cidr'] as List?)?.cast<String>() ?? const [];
          return rule['outbound'] == 'direct' &&
              cidrs.contains('114.114.114.114/32');
        }),
      ),
    );
  });

  test('uses the responsive local DNS as the default resolver', () {
    final config = buildSingBoxConfig(
      node: const VpnNode(
        id: 'hkg-1',
        type: NodeType.anytls,
        name: '🇭🇰 Hong Kong | 01',
        server: 'hk.example.com',
        port: 443,
        password: 'secret',
      ),
    );
    expect((config['dns'] as Map)['final'], 'local');
  });
}
