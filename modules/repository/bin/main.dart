import 'dart:async';

import 'package:repository/database/database_isolate.dart';
import 'package:repository/server.dart';

void main(List<String> arguments) {
  runZonedGuarded(
    () {
      startSqlIsolate();
      startServer();
    },
    (error, stack) {
      print(error);
      print(stack);
    },
  );
}
