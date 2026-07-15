import 'dart:convert';
import 'models/node.dart';

const int defaultHttpPort = 2080;
const int defaultSocksPort = 2081;
const int defaultApiPort = 9090;

const List<String> cnDirectSuffixes = [
  'cn', '中国',
  'baidu.com', 'bdimg.com', 'bdstatic.com',
  'qq.com', 'tencent.com',
  'taobao.com', 'tmall.com', 'alicdn.com', 'alipay.com', 'aliyun.com',
  'jd.com', '360buyimg.com',
  'bilibili.com', 'bilivideo.com',
  'zhihu.com', 'zhimg.com',
  'weibo.com', 'weibocdn.com',
  '163.com', '126.com', 'netease.com',
  'sina.com.cn', 'sinaimg.cn',
  'sogou.com', 'sohu.com',
  '360.cn',
  'douyin.com', 'bytedance.com', 'toutiao.com',
  'ixigua.com',
  'xiaomi.com', 'huawei.com', 'mi.com',
  'meituan.com', 'dianping.com',
  'pinduoduo.com', 'pddpic.com',
  'kuaishou.com', 'ksapisrv.com',
  'amap.com', 'gaode.com', 'autonavi.com',
  'ctrip.com', 'qunar.com',
  'iqiyi.com', 'iqiyipic.com',
  'youku.com', 'ykimg.com',
  'douban.com',
  'csdn.net', 'gitee.com',
];

bool _isIpAddress(String value) {
  if (value.isEmpty) return false;
  return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(value) || value.contains(':');
}

Map<String, dynamic> _transport(VpnNode node) {
  if (node.transport == null || node.transport == 'tcp') return const {};
  if (node.transport == 'ws' || node.transport == 'websocket') {
    return {
      'type': 'ws',
      'path': node.path ?? '/',
      if (node.host != null) 'headers': {'Host': node.host},
    };
  }
  if (node.transport == 'grpc') {
    return {
      'type': 'grpc',
      'service_name': node.path ?? '',
    };
  }
  return {'type': node.transport};
}

Map<String, dynamic>? _tls(VpnNode node) {
  if (!node.tls) return null;
  return {
    'enabled': true,
    'server_name': node.serverName ?? node.host ?? node.server,
    'insecure': node.insecure,
  };
}

Map<String, dynamic> _nodeToOutbound(VpnNode node) {
  switch (node.type) {
    case NodeType.shadowsocks:
      return {
        'type': 'shadowsocks',
        'tag': 'proxy',
        'server': node.server,
        'server_port': node.port,
        'method': node.method,
        'password': node.password,
      };

    case NodeType.vmess:
      return {
        'type': 'vmess',
        'tag': 'proxy',
        'server': node.server,
        'server_port': node.port,
        'uuid': node.uuid,
        'security': node.security ?? 'auto',
        'alter_id': node.alterId,
        if (_transport(node).isNotEmpty) 'transport': _transport(node),
        if (_tls(node) != null) 'tls': _tls(node),
      };

    case NodeType.vless:
      return {
        'type': 'vless',
        'tag': 'proxy',
        'server': node.server,
        'server_port': node.port,
        'uuid': node.uuid,
        if (node.flow != null) 'flow': node.flow,
        if (_transport(node).isNotEmpty) 'transport': _transport(node),
        if (_tls(node) != null) 'tls': _tls(node),
      };

    case NodeType.trojan:
      return {
        'type': 'trojan',
        'tag': 'proxy',
        'server': node.server,
        'server_port': node.port,
        'password': node.password,
        'tls': {
          'enabled': true,
          'server_name': node.serverName ?? node.server,
        },
      };

    case NodeType.wireguard:
      return {
        'type': 'wireguard',
        'tag': 'proxy',
        'server': node.server,
        'server_port': node.port,
        'local_address': [node.localAddress],
        'private_key': node.privateKey,
        'peer_public_key': node.peerPublicKey,
        if (node.preSharedKey != null) 'pre_shared_key': node.preSharedKey,
        if (node.reserved != null) 'reserved': node.reserved,
      };
  }
}

List<Map<String, dynamic>> _dnsRulesForNode(VpnNode? node, String mode) {
  final rules = <Map<String, dynamic>>[];
  if (node != null && node.server.isNotEmpty && !_isIpAddress(node.server)) {
    rules.add({
      'domain': [node.server],
      'server': 'local',
    });
  }
  if (mode == 'rule') {
    rules.add({
      'domain_suffix': cnDirectSuffixes,
      'server': 'local',
    });
  }
  return rules;
}

/// Build a complete sing-box configuration JSON.
Map<String, dynamic> buildSingBoxConfig({
  required VpnNode node,
  String mode = 'global',
  bool tunEnabled = false,
  int httpPort = defaultHttpPort,
  int socksPort = defaultSocksPort,
  int apiPort = defaultApiPort,
  bool includeSocks = true,
  bool includeApi = true,
  bool cacheFile = true,
  String logLevel = 'info',
}) {
  final outbounds = [
    _nodeToOutbound(node),
    {'type': 'direct', 'tag': 'direct'},
    {'type': 'block', 'tag': 'block'},
  ];

  final inbounds = <Map<String, dynamic>>[
    {
      'type': 'http',
      'tag': 'http-in',
      'listen': '127.0.0.1',
      'listen_port': httpPort,
    },
  ];

  if (includeSocks) {
    inbounds.add({
      'type': 'socks',
      'tag': 'socks-in',
      'listen': '127.0.0.1',
      'listen_port': socksPort,
      'sniff': true,
      'sniff_override_destination': true,
    });
  }

  if (tunEnabled) {
    inbounds.add({
      'type': 'tun',
      'tag': 'tun-in',
      'interface_name': 'ForgeVPN',
      'address': ['172.19.0.1/30'],
      'auto_route': true,
      'strict_route': true,
      'stack': 'system',
      'sniff': true,
    });
  }

  final config = <String, dynamic>{
    'log': {
      'level': logLevel,
      'timestamp': true,
    },
    'dns': {
      'servers': [
        {'tag': 'local', 'address': '223.5.5.5', 'detour': 'direct'},
        {'tag': 'remote', 'address': 'tls://1.1.1.1', 'detour': 'proxy'},
      ],
      'rules': _dnsRulesForNode(node, mode),
      'final': 'remote',
      'strategy': 'prefer_ipv4',
    },
    'inbounds': inbounds,
    'outbounds': outbounds,
    'route': {
      'auto_detect_interface': true,
      'final': mode == 'direct' ? 'direct' : 'proxy',
      'rules': [
        {'ip_is_private': true, 'outbound': 'direct'},
        if (mode == 'rule')
          {
            'domain_suffix': cnDirectSuffixes,
            'outbound': 'direct',
          },
      ],
    },
  };

  final experimental = <String, dynamic>{};
  if (cacheFile) {
    experimental['cache_file'] = {'enabled': true};
  }
  if (includeApi) {
    experimental['clash_api'] = {
      'external_controller': '127.0.0.1:$apiPort',
      'secret': '',
    };
  }
  if (experimental.isNotEmpty) {
    config['experimental'] = experimental;
  }

  return config;
}

/// Serialize config to JSON string.
String singBoxConfigToJson(Map<String, dynamic> config) {
  return const JsonEncoder.withIndent('  ').convert(config);
}
