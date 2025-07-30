import 'dart:async';
import 'dart:isolate';

import 'package:rinha_de_backend_2025_dart/database_isolate.dart';
import 'package:rinha_de_backend_2025_dart/isolates_pool.dart';
import 'package:rinha_de_backend_2025_dart/server.dart';
import 'package:rinha_de_backend_2025_dart/status_fetch_loop.dart';

void main(List<String> arguments) {
  runZonedGuarded(
    () {
      startIsolatesPool().then((ports) {
        startStatusFetchLoopIsolated(ports);
        startSqlIsolate([...ports, mainIsolateEventsHandling()]);
      });
      startServer();
    },
    (error, stack) {
      print(error);
      print(stack);
    },
  );
}

SendPort mainIsolateEventsHandling() {
  final ReceivePort receivePort = ReceivePort();

  receivePort.listen((event) {
    switch (event) {
      case SqlIsolateMessage sqlIsolateMessage:
        sqlIsolateSendPort.complete(sqlIsolateMessage.sendPort);
        break;
      default:
        break;
    }
  });

  return receivePort.sendPort;
}
