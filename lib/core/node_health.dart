import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'models/node.dart';
import 'singbox_config.dart';

/// Result of a node health check.
class HealthCheckResult {
  final bool ok;
  final int? latency;
  final String healthStatus;
  final String target;
  final String? error;

  const HealthCheckResult({
    required this.ok,
    this.latency,
    this.healthStatus = 'unknown',
    this.target = 'YouTube',
    this.error,
  });
}

/// Perform a TCP ping to check if a host:port is reachable.
Future<int?> tcpPing(String host, int port, {int timeoutMs = 3000}) async {
  final stopwatch = Stopwatch()..start();
  try {
    // Android emulators often advertise IPv6 DNS answers without a working
    // IPv6 route. Prefer IPv4 so a healthy endpoint is not reported as down
    // before libbox gets a chance to establish the real protocol connection.
    final addresses = await InternetAddress.lookup(
      host,
      type: InternetAddressType.IPv4,
    );
    if (addresses.isEmpty) return null;
    final socket = await Socket.connect(
      addresses.first,
      port,
      timeout: Duration(milliseconds: timeoutMs),
    );
    await socket.close();
    stopwatch.stop();
    return max(1, stopwatch.elapsedMilliseconds);
  } catch (_) {
    return null;
  }
}

/// Check a node from a mobile build without starting a local sing-box process.
/// Android/iOS use the native libbox runtime, so there is no CLI executable for
/// the desktop-style health check path. A TCP probe still verifies that the
/// subscription endpoint is reachable and gives the user a useful latency.
Future<HealthCheckResult> checkNodeTcpAvailability({
  required VpnNode node,
  int timeoutMs = 3000,
}) async {
  final latency = await tcpPing(node.server, node.port, timeoutMs: timeoutMs);
  if (latency != null) {
    return HealthCheckResult(
      ok: true,
      latency: latency,
      healthStatus: 'available',
      target: 'Node',
    );
  }
  return HealthCheckResult(
    ok: false,
    healthStatus: 'unavailable',
    target: 'Node',
    error: 'TCP connection timed out',
  );
}

/// Check node availability by starting a sing-box instance and making a real request.
Future<HealthCheckResult> checkNodeAvailability({
  required String corePath,
  required String runtimeDir,
  required VpnNode node,
  int timeoutMs = 9000,
  String targetHost = 'www.youtube.com',
  int targetPort = 443,
  String targetLabel = 'YouTube',
}) async {
  Process? child;
  String? configPath;

  try {
    final dir = Directory(runtimeDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    // Find a free port
    final httpPort = await _freePort();

    configPath = '${runtimeDir}/health-${pid}-${DateTime.now().millisecondsSinceEpoch}-${Random().nextDouble().toStringAsFixed(10)}.json';

    final config = buildSingBoxConfig(
      node: node,
      mode: 'global',
      tunEnabled: false,
      httpPort: httpPort,
      includeSocks: false,
      includeApi: false,
      cacheFile: false,
      logLevel: 'warn',
    );

    final configFile = File(configPath);
    await configFile.writeAsString(singBoxConfigToJson(config));

    child = await Process.start(corePath, ['run', '-c', configPath],
        mode: ProcessStartMode.detachedWithStdio);
    child.stdout.drain();
    child.stderr.drain();

    await _waitForLocalPort(httpPort, min(2500, timeoutMs));
    final stopwatch = Stopwatch()..start();
    await _requestThroughHttpProxy(
      proxyPort: httpPort,
      targetHost: targetHost,
      targetPort: targetPort,
      timeoutMs: timeoutMs,
    );
    stopwatch.stop();

    return HealthCheckResult(
      ok: true,
      latency: max(1, stopwatch.elapsedMilliseconds),
      healthStatus: 'available',
      target: targetLabel,
    );
  } catch (error) {
    return HealthCheckResult(
      ok: false,
      healthStatus: 'unavailable',
      target: targetLabel,
      error: error.toString().length > 160 ? error.toString().substring(0, 160) : error.toString(),
    );
  } finally {
    child?.kill();
    if (configPath != null) {
      try {
        await File(configPath).delete();
      } catch (_) {}
    }
  }
}

Future<int> _freePort() async {
  final server = await ServerSocket.bind('127.0.0.1', 0);
  final port = server.port;
  await server.close();
  return port;
}

Future<void> _waitForLocalPort(int port, int timeoutMs) async {
  final deadline = DateTime.now().millisecondsSinceEpoch + timeoutMs;
  while (DateTime.now().millisecondsSinceEpoch < deadline) {
    try {
      final socket = await Socket.connect('127.0.0.1', port,
          timeout: const Duration(milliseconds: 250));
      await socket.close();
      return;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }
  throw Exception('health proxy did not start');
}

Future<void> _requestThroughHttpProxy({
  required int proxyPort,
  required String targetHost,
  required int targetPort,
  required int timeoutMs,
}) async {
  final completer = Completer<void>();
  Socket? socket;
  StreamSubscription? socketSub;
  SecureSocket? secureSocket;
  bool settled = false;

  void cleanup() {
    if (settled) return;
    settled = true;
    socketSub?.cancel();
    socket?.destroy();
    secureSocket?.destroy();
  }

  final timer = Timer(Duration(milliseconds: timeoutMs), () {
    cleanup();
    if (!completer.isCompleted) completer.completeError(Exception('health request timed out'));
  });

  try {
    socket = await Socket.connect('127.0.0.1', proxyPort,
        timeout: const Duration(milliseconds: 3000));

    socket.write(
        'CONNECT $targetHost:$targetPort HTTP/1.1\r\n'
        'Host: $targetHost:$targetPort\r\n'
        'Proxy-Connection: keep-alive\r\n\r\n');

    String proxyBuffer = '';
    socketSub = socket.listen(
      (data) {
        if (settled) return;
        proxyBuffer += utf8.decode(data, allowMalformed: true);
        if (!proxyBuffer.contains('\r\n\r\n')) return;

        final statusMatch = RegExp(r'^HTTP/\d(?:\.\d)?\s+(\d{3})',
            caseSensitive: false, multiLine: true).firstMatch(proxyBuffer);
        final status = int.tryParse(statusMatch?.group(1) ?? '') ?? 0;

        if (status != 200) {
          cleanup();
          if (!completer.isCompleted) {
            completer.completeError(Exception('proxy CONNECT failed: $status'));
          }
          return;
        }

        socketSub?.cancel();
        SecureSocket.secure(socket!, host: targetHost,
            onBadCertificate: (_) => true).then((ss) {
          secureSocket = ss;
          secureSocket!.write(
              'HEAD / HTTP/1.1\r\n'
              'Host: $targetHost\r\n'
              'User-Agent: ForgeDesktopVPN/0.1\r\n'
              'Connection: close\r\n\r\n');

          String responseBuffer = '';
          secureSocket!.listen(
            (respData) {
              if (settled) return;
              responseBuffer += utf8.decode(respData, allowMalformed: true);
              if (RegExp(r'^HTTP/\d(?:\.\d)?\s+\d{3}',
                  caseSensitive: false, multiLine: true).hasMatch(responseBuffer)) {
                cleanup();
                timer.cancel();
                if (!completer.isCompleted) completer.complete();
              }
            },
            onError: (e) {
              cleanup();
              timer.cancel();
              if (!completer.isCompleted) completer.completeError(e);
            },
            cancelOnError: true,
          );
        }).catchError((e) {
          cleanup();
          timer.cancel();
          if (!completer.isCompleted) completer.completeError(e);
        });
      },
      onError: (e) {
        cleanup();
        timer.cancel();
        if (!completer.isCompleted) completer.completeError(e);
      },
    );
  } catch (e) {
    cleanup();
    timer.cancel();
    if (!completer.isCompleted) completer.completeError(e);
  }

  return completer.future;
}
