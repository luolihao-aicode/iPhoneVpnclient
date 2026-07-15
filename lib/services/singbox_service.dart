import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/models/node.dart';
import '../core/singbox_config.dart';

/// Callback for sing-box process state changes.
typedef OnSingBoxState = void Function({bool connected, int? pid, int? code});
typedef OnSingBoxLog = void Function(String line);

/// Manages the sing-box core process.
class SingBoxController {
  final String corePath;
  final String runtimeDir;
  final OnSingBoxState? onState;
  final OnSingBoxLog? onLog;

  Process? _process;
  int _runId = 0;
  String? get configPath => _configPath;
  String? _configPath;

  SingBoxController({
    required this.corePath,
    required this.runtimeDir,
    this.onState,
    this.onLog,
  });

  bool get isRunning => _process != null && _process!.pid > 0;

  Future<void> ensureReady() async {
    if (!await File(corePath).exists()) {
      throw Exception('sing-box core not found: $corePath');
    }
    final dir = Directory('${runtimeDir}/runtime');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Connect to a node by starting sing-box.
  Future<Map<String, dynamic>> connect({
    required VpnNode node,
    String mode = 'global',
    bool tunEnabled = false,
  }) async {
    _runId++;
    final currentRunId = _runId;

    // Kill previous process
    await _process?.kill();
    _process = null;

    await ensureReady();

    final config = buildSingBoxConfig(
      node: node,
      mode: mode,
      tunEnabled: tunEnabled,
    );

    final runDir = Directory('${runtimeDir}/runtime');
    if (!await runDir.exists()) await runDir.create(recursive: true);

    _configPath = '${runDir.path}/sing-box.json';
    await File(_configPath!).writeAsString(singBoxConfigToJson(config));

    _process = await Process.start(
      corePath,
      ['run', '-c', _configPath!],
      mode: ProcessStartMode.detachedWithStdio,
      runInShell: Platform.isWindows,
    );

    final pid = _process!.pid;
    onState?.call(connected: true, pid: pid);

    _process!.stdout.transform(utf8.decoder).listen((line) {
      if (_runId != currentRunId) return;
      log(line);
    });

    _process!.stderr.transform(utf8.decoder).listen((line) {
      if (_runId != currentRunId) return;
      log(line);
    });

    _process!.exitCode.then((code) {
      if (_runId != currentRunId) return;
      onState?.call(connected: false, code: code);
      _process = null;
    });

    return {
      'mixedPort': defaultHttpPort,
      'httpPort': defaultHttpPort,
      'socksPort': defaultSocksPort,
      'apiPort': defaultApiPort,
      'configPath': _configPath,
    };
  }

  /// Disconnect the sing-box process.
  void disconnect() {
    if (_process != null) {
      _runId++;
      _process!.kill();
      _process = null;
    }
    onState?.call(connected: false);
  }

  void log(String line) {
    final clean = line.trim();
    if (clean.isNotEmpty) {
      onLog?.call(clean);
    }
  }

  void dispose() {
    disconnect();
  }
}
