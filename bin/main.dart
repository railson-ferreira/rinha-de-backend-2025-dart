import 'dart:async';

import 'package:rinha_de_backend_2025_dart/isolates_pool.dart';
import 'package:rinha_de_backend_2025_dart/server.dart';
import 'package:rinha_de_backend_2025_dart/status_fetch_loop.dart';

void main(List<String> arguments) {
  runZonedGuarded(
    () {
      startIsolatesPool().then((ports) {
        startStatusFetchLoopIsolated(ports);
      });
      startServer();
    },
    (error, stack) {
      print(error);
      print(stack);
    },
  );
}
