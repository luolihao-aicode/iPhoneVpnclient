import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Traffic data from sing-box API.
class TrafficData {
  final int up;
  final int down;

  const TrafficData({this.up = 0, this.down = 0});

  factory TrafficData.fromJson(Map<String, dynamic> json) {
    return TrafficData(
      up: _parseInt(json['up'] ?? json['upload']),
      down: _parseInt(json['down'] ?? json['download']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

/// Read sing-box traffic stats from the Clash API.
Future<TrafficData> readTrafficOnce({int apiPort = 9090}) async {
  try {
    final socket = await Socket.connect('127.0.0.1', apiPort,
        timeout: const Duration(milliseconds: 2000));

    socket.write(
        'GET /traffic HTTP/1.1\r\n'
        'Host: 127.0.0.1:$apiPort\r\n'
        'Connection: close\r\n\r\n');

    final completer = Completer<TrafficData>();
    String buffer = '';

    socket.listen(
      (data) {
        buffer += utf8.decode(data, allowMalformed: true);
        final lines = buffer.split(RegExp(r'\r?\n'));
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          if (line.startsWith('{') || line.startsWith('[')) {
            try {
              final traffic = TrafficData.fromJson(json.decode(line));
              socket.destroy();
              completer.complete(traffic);
              return;
            } catch (_) {
              break;
            }
          }
        }
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(const TrafficData());
      },
      onError: (e) {
        if (!completer.isCompleted) completer.complete(const TrafficData());
      },
    );

    return completer.future.timeout(const Duration(seconds: 2),
        onTimeout: () => const TrafficData());
  } catch (_) {
    return const TrafficData();
  }
}
