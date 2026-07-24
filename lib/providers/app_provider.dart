import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models/node.dart';
import '../core/node_health.dart' as health;
import '../core/node_latency.dart';
import '../core/node_storage.dart';
import '../core/subscription.dart';
import '../core/stats.dart';
import '../core/singbox_config.dart';
import '../services/singbox_service.dart';
import '../services/android_vpn_service.dart';
import '../services/ios_vpn_service.dart';

/// Application settings.
class AppSettings {
  final bool systemProxy;
  final bool tunEnabled;
  final String routeMode;
  final bool autoStart;
  final bool darkMode;

  const AppSettings({
    this.systemProxy = true,
    this.tunEnabled = false,
    this.routeMode = 'global',
    this.autoStart = false,
    this.darkMode = true,
  });

  AppSettings copyWith({
    bool? systemProxy,
    bool? tunEnabled,
    String? routeMode,
    bool? autoStart,
    bool? darkMode,
  }) {
    return AppSettings(
      systemProxy: systemProxy ?? this.systemProxy,
      tunEnabled: tunEnabled ?? this.tunEnabled,
      routeMode: routeMode ?? this.routeMode,
      autoStart: autoStart ?? this.autoStart,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}

/// Runtime state for the VPN connection.
class RuntimeState {
  final bool connected;
  final bool checkingNodes;
  final int? latency;
  final int upSpeed;
  final int downSpeed;
  final List<String> logs;
  final String proxyWarning;

  const RuntimeState({
    this.connected = false,
    this.checkingNodes = false,
    this.latency,
    this.upSpeed = 0,
    this.downSpeed = 0,
    this.logs = const [],
    this.proxyWarning = '',
  });

  RuntimeState copyWith({
    bool? connected,
    bool? checkingNodes,
    int? latency,
    int? upSpeed,
    int? downSpeed,
    List<String>? logs,
    String? proxyWarning,
  }) {
    return RuntimeState(
      connected: connected ?? this.connected,
      checkingNodes: checkingNodes ?? this.checkingNodes,
      latency: latency ?? this.latency,
      upSpeed: upSpeed ?? this.upSpeed,
      downSpeed: downSpeed ?? this.downSpeed,
      logs: logs ?? this.logs,
      proxyWarning: proxyWarning ?? this.proxyWarning,
    );
  }
}

/// Main application state provider.
class AppProvider extends ChangeNotifier {
  static const _subscriptionUrlKey = 'subscription_url';
  static const _nodesKey = 'subscription_nodes';
  static const _selectedNodeKey = 'selected_node_id';

  List<VpnNode> _nodes = [];
  String _selectedNodeId = '';
  AppSettings _settings = const AppSettings();
  RuntimeState _runtime = const RuntimeState();
  String _subscriptionUrl = '';

  SingBoxController? _controller;
  AndroidVpnService? _androidVpn;
  IosVpnService? _iosVpn;
  Timer? _statsTimer;
  int _latencyBatchId = 0;
  bool _isSwitching = false;

  /// Platform detection.
  static bool get _isAndroid =>
      !kIsWeb && Platform.operatingSystem == 'android';
  static bool get _isiOS => !kIsWeb && Platform.operatingSystem == 'ios';

  /// Auto-detect sing-box binary path for desktop platforms.
  static String _detectCorePath() {
    if (Platform.isWindows) {
      // Check common locations
      final candidates = [
        '../desktop-vpn-client/resources/bin/sing-box.exe',
        './sing-box.exe',
        'C:/tools/sing-box/sing-box.exe',
      ];
      for (final p in candidates) {
        final f = File(p);
        if (f.existsSync()) return f.absolute.path;
      }
    } else if (Platform.isLinux) {
      for (final p in ['/usr/local/bin/sing-box', '/usr/bin/sing-box']) {
        final f = File(p);
        if (f.existsSync()) return f.absolute.path;
      }
    } else if (Platform.isMacOS) {
      for (final p in [
        '/usr/local/bin/sing-box',
        '/opt/homebrew/bin/sing-box'
      ]) {
        final f = File(p);
        if (f.existsSync()) return f.absolute.path;
      }
    }
    return '';
  }

  // Getters
  List<VpnNode> get nodes => sortNodesByLatency(_nodes);
  String get selectedNodeId => _selectedNodeId;
  AppSettings get settings => _settings;
  RuntimeState get runtime => _runtime;
  String get subscriptionUrl => _subscriptionUrl;
  bool get isSwitching => _isSwitching;

  VpnNode? get selectedNode {
    if (nodes.isEmpty) return null;
    return nodes.firstWhere(
      (n) => n.id == _selectedNodeId,
      orElse: () => nodes.first,
    );
  }

  /// Initialize the controller (platform-appropriate).
  Future<void> initialize(String corePath) async {
    if (_isiOS) {
      await _initIOS();
    } else if (_isAndroid) {
      await _initAndroid();
    } else {
      _initDesktop(corePath);
    }

    // Restore saved subscription URL
    await _restoreSubscription();
  }

  Future<void> _restoreSubscription() async {
    var restored = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString(_subscriptionUrlKey) ?? '';
      if (savedUrl.isNotEmpty) {
        _subscriptionUrl = savedUrl;
        log('Restored subscription URL from cache');
        restored = true;
      }
      final savedNodes = prefs.getString(_nodesKey);
      if (savedNodes != null) {
        final nodes = decodeNodes(savedNodes);
        if (nodes.isNotEmpty) {
          _nodes = nodes;
          _selectedNodeId = prefs.getString(_selectedNodeKey) ?? '';
          if (!_nodes.any((node) => node.id == _selectedNodeId)) {
            _selectedNodeId = _nodes.first.id;
          }
          log('Restored ${_nodes.length} subscription nodes from cache');
          restored = true;
        }
      }
    } catch (_) {}
    if (restored) notifyListeners();
  }

  Future<void> _persistNodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nodesKey, encodeNodes(_nodes));
      await prefs.setString(_selectedNodeKey, _selectedNodeId);
    } catch (_) {}
  }

  Future<void> _initAndroid() async {
    _androidVpn = AndroidVpnService();

    _androidVpn!.onStatus = (status, message) {
      switch (status) {
        case 'connected':
          _runtime = _runtime.copyWith(connected: true, proxyWarning: '');
          notifyListeners();
          break;
        case 'disconnected':
          _runtime = _runtime.copyWith(connected: false, proxyWarning: message);
          _statsTimer?.cancel();
          notifyListeners();
          break;
        case 'error':
          log('VPN Error: $message');
          _runtime = _runtime.copyWith(connected: false);
          notifyListeners();
          break;
        case 'permission_granted':
          log('VPN permission granted');
          notifyListeners();
          break;
        case 'permission_denied':
          log('VPN permission denied');
          notifyListeners();
          break;
        case 'ready':
        case 'connecting':
        case 'disconnecting':
          log('VPN state: $status${message.isEmpty ? '' : ' ($message)'}');
          break;
      }
    };

    _androidVpn!.onLog = (line) {
      log(line);
    };
    await _androidVpn!.restoreState();
  }

  Future<void> _initIOS() async {
    _iosVpn = IosVpnService();

    _iosVpn!.onStatus = (status, message) {
      switch (status) {
        case 'connected':
          _runtime = _runtime.copyWith(connected: true, proxyWarning: '');
          notifyListeners();
          break;
        case 'disconnected':
          _runtime = _runtime.copyWith(connected: false, proxyWarning: message);
          _statsTimer?.cancel();
          notifyListeners();
          break;
        case 'error':
          log('VPN Error: $message');
          _runtime = _runtime.copyWith(connected: false);
          notifyListeners();
          break;
      }
    };

    _iosVpn!.onLog = (line) {
      log(line);
    };
    await _iosVpn!.restoreState();
  }

  Future<void> _initDesktop(String suppliedPath) async {
    final corePath = suppliedPath.isNotEmpty ? suppliedPath : _detectCorePath();
    if (corePath.isEmpty) {
      log('Warning: sing-box binary not found. Connection will fail.');
    } else {
      log('Core path: $corePath');
    }
    final appDir = await getApplicationSupportDirectory();
    final runtimeDir = appDir.path;

    _controller = SingBoxController(
      corePath: corePath,
      runtimeDir: runtimeDir,
      onState: ({bool? connected, int? pid, int? code}) {
        _runtime = _runtime.copyWith(connected: connected ?? false);
        if (connected != true) {
          _runtime =
              _runtime.copyWith(upSpeed: 0, downSpeed: 0, proxyWarning: '');
        }
        notifyListeners();
      },
      onLog: (line) {
        log(line);
      },
    );
  }

  /// Import nodes from a subscription URL.
  Future<void> importSubscription(String url) async {
    final resolvedUrl = resolveSubscriptionInput(url);
    if (resolvedUrl == null) {
      throw Exception('Unsupported subscription link. Paste an HTTPS or Stash install link.');
    }
    final fetchedNodes = await fetchSubscription(resolvedUrl);
    _latencyBatchId++;
    _nodes = sortNodesByLatency(fetchedNodes);
    _subscriptionUrl = resolvedUrl;

    // Persist subscription URL
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_subscriptionUrlKey, resolvedUrl);
    } catch (_) {}

    if (!_nodes.any((n) => n.id == _selectedNodeId)) {
      _selectedNodeId = _nodes.isNotEmpty ? _nodes.first.id : '';
    }
    await _persistNodes();
    notifyListeners();

    // Start health check
    checkAllNodes();
  }

  /// Import nodes from raw subscription text.
  Future<void> importSubscriptionText(String rawText) async {
    final parsedNodes = parseSubscription(rawText);
    _latencyBatchId++;
    _nodes = sortNodesByLatency(parsedNodes);

    if (!_nodes.any((n) => n.id == _selectedNodeId)) {
      _selectedNodeId = _nodes.isNotEmpty ? _nodes.first.id : '';
    }
    await _persistNodes();
    notifyListeners();
  }

  /// Select a node.
  void selectNode(String nodeId) {
    _selectedNodeId = nodeId;
    final node = selectedNode;
    _runtime = _runtime.copyWith(latency: node?.latencyMs);
    unawaited(_persistNodes());
    notifyListeners();
  }

  /// Ping a single node.
  Future<health.HealthCheckResult?> pingNode(String nodeId) async {
    final node = nodes.firstWhere((n) => n.id == nodeId);
    if (_controller == null && !_isAndroid && !_isiOS) return null;

    _latencyBatchId++;
    _nodes = _nodes
        .map((n) => n.id == nodeId
            ? n.copyWith(latencyMs: null, healthStatus: HealthStatus.checking)
            : n)
        .toList();
    notifyListeners();

    if (_isAndroid || _isiOS) {
      // Mobile builds use the native libbox runtime and do not ship a CLI
      // executable for the desktop-style local proxy health check.
      final result = await health.checkNodeTcpAvailability(node: node);
      _nodes = updateNodeLatency(_nodes, nodeId, result);
      _runtime = _runtime.copyWith(latency: selectedNode?.latencyMs);
      notifyListeners();
      return result;
    }

    final result = await health.checkNodeAvailability(
      corePath: _controller!.corePath,
      runtimeDir: '${_controller!.runtimeDir}/health',
      node: node,
    );

    _nodes = updateNodeLatency(_nodes, nodeId, result);
    _runtime = _runtime.copyWith(latency: selectedNode?.latencyMs);
    notifyListeners();
    return result;
  }

  /// Check all nodes' health.
  Future<void> checkAllNodes() async {
    if (nodes.isEmpty) return;

    final batchId = ++_latencyBatchId;
    _nodes = prepareNodesForLatencyTest(_nodes);
    _runtime = _runtime.copyWith(
        checkingNodes: true, latency: selectedNode?.latencyMs);
    notifyListeners();

    const concurrency = 3;
    int cursor = 0;

    final corePath = _controller?.corePath ?? '';
    final healthDir = '${_controller?.runtimeDir ?? '/'}/health';

    final workers = List.generate(min(concurrency, nodes.length), (_) async {
      while (cursor < nodes.length && batchId == _latencyBatchId) {
        final node = nodes[cursor];
        cursor++;

        try {
          final result = (_isAndroid || _isiOS)
              ? await health.checkNodeTcpAvailability(node: node)
              : await health.checkNodeAvailability(
                  corePath: corePath,
                  runtimeDir: healthDir,
                  node: node,
                );
          if (batchId != _latencyBatchId) return;
          _nodes = updateNodeLatency(_nodes, node.id, result);
          _runtime = _runtime.copyWith(latency: selectedNode?.latencyMs);
          notifyListeners();
        } catch (_) {}
      }
    });

    await Future.wait(workers);
    if (batchId == _latencyBatchId) {
      _runtime = _runtime.copyWith(checkingNodes: false);
      notifyListeners();
    }
  }

  /// Connect to the selected node.
  Future<void> connect({AppSettings? settingsPatch}) async {
    final node = selectedNode;
    if (node == null) throw Exception('Please import and select a node first.');

    final mergedSettings = settingsPatch != null
        ? _settings.copyWith(
            systemProxy: settingsPatch.systemProxy,
            tunEnabled: settingsPatch.tunEnabled,
            routeMode: settingsPatch.routeMode,
          )
        : _settings;

    _settings = mergedSettings;
    notifyListeners();

    if (_isiOS) {
      await _connectIOS(node, mergedSettings);
    } else if (_isAndroid) {
      await _connectAndroid(node, mergedSettings);
    } else {
      await _connectDesktop(node, mergedSettings);
    }
  }

  Future<void> _connectAndroid(VpnNode node, AppSettings settings) async {
    if (_androidVpn == null) {
      await _initAndroid();
    }

    // Build the sing-box config JSON
    final config = buildSingBoxConfig(
      node: node,
      mode: settings.routeMode,
      tunEnabled: true, // Android always uses TUN
    );
    final configJson = singBoxConfigToJson(config);

    // Request permission if needed
    if (!_androidVpn!.hasPermission) {
      _isSwitching = true;
      notifyListeners();

      log('Requesting VPN permission...');
      final granted = await _androidVpn!.requestPermission();
      if (!granted) {
        _isSwitching = false;
        notifyListeners();
        throw Exception('VPN permission was denied');
      }
      log('VPN permission granted');
    }

    _isSwitching = false;
    log('Starting VPN (Android TUN)...');
    final ok = await _androidVpn!.connect(configJson);
    if (!ok) {
      throw Exception('Failed to start VPN service');
    }

    // Connection status will be updated via callback
  }

  Future<void> _connectIOS(VpnNode node, AppSettings settings) async {
    if (_iosVpn == null) {
      await _initIOS();
    }

    // Build the sing-box config JSON (same format as Android)
    final config = buildSingBoxConfig(
      node: node,
      mode: settings.routeMode,
      tunEnabled: true, // iOS always uses TUN
    );
    final configJson = singBoxConfigToJson(config);

    log('Starting VPN (iOS TUN)...');
    log('Config: ${configJson.length} bytes');
    log('Node: ${node.name} (${node.type.label})');

    final ok = await _iosVpn!.connect(configJson);
    if (!ok) {
      // Error already logged via onLog callback
      throw Exception('Failed to start VPN service');
    }
  }

  Future<void> _connectDesktop(VpnNode node, AppSettings settings) async {
    if (_controller == null)
      throw Exception('sing-box controller not initialized.');

    // Stop any existing sing-box processes
    await _stopExistingSingBoxProcesses();

    log('Starting sing-box: route=${settings.routeMode}, tun=${settings.tunEnabled ? "on" : "off"}');

    _controller!.connect(
      node: node,
      mode: settings.routeMode,
      tunEnabled: settings.tunEnabled,
    );

    _runtime = _runtime.copyWith(connected: true, proxyWarning: '');
    _startStats();
    notifyListeners();
  }

  /// Disconnect from current node.
  Future<void> disconnect() async {
    _statsTimer?.cancel();

    if (_isiOS) {
      await _iosVpn?.disconnect();
    } else if (_isAndroid) {
      await _androidVpn?.disconnect();
    } else {
      _controller?.disconnect();
      await _stopExistingSingBoxProcesses();
    }

    _runtime = _runtime.copyWith(
        connected: false, upSpeed: 0, downSpeed: 0, proxyWarning: '');
    notifyListeners();
  }

  /// Save settings.
  void saveSettings(AppSettings newSettings) {
    _settings = newSettings;
    notifyListeners();
  }

  void log(String line) {
    final clean = line.trim();
    if (clean.isEmpty) return;
    final logs = [..._runtime.logs, clean];
    if (logs.length > 120) logs.removeRange(0, logs.length - 120);
    _runtime = _runtime.copyWith(logs: logs);
    notifyListeners();
  }

  void _startStats() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_runtime.connected) return;
      final traffic = await readTrafficOnce();
      _runtime = _runtime.copyWith(
        upSpeed: traffic.up,
        downSpeed: traffic.down,
      );
      notifyListeners();
    });
  }

  Future<void> _stopExistingSingBoxProcesses() async {
    if (!Platform.isWindows) return;
    try {
      final result = await Process.run('taskkill', [
        '/f',
        '/im',
        'sing-box.exe',
      ]);
      if (result.exitCode == 0) log('Cleaned up existing sing-box processes');
    } catch (_) {}
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _controller?.dispose();
    _androidVpn?.disconnect();
    _iosVpn?.disconnect();
    super.dispose();
  }
}
