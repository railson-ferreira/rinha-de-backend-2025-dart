import 'dart:async';
import 'dart:isolate';

import 'package:shared_kernel/sql_execute.dart';
import 'package:shared_kernel/sql_get.dart';
import 'package:shared_kernel/sql_response.dart';

import 'database.dart';
import 'database_request.dart';

final sqlIsolateSendPort = Completer<SendPort>();

Future<void> startSqlIsolate() async {
  final sqlIsolateReceivePort = ReceivePort();
  await Isolate.spawn((port) async {
    final mainIsolate = ReceivePort();
    sqliteIsolateEntry(mainIsolate.sendPort);
    final sqlSendPort = await mainIsolate.first as SendPort;
    port.send(sqlSendPort);
  }, sqlIsolateReceivePort.sendPort);
  final sqlSendPort = await sqlIsolateReceivePort.first as SendPort;
  sqlIsolateSendPort.complete(sqlSendPort);
  print('SQL isolate started');
}

void sqliteIsolateEntry(SendPort mainSendPort) {
  final ReceivePort isolateReceivePort = ReceivePort();
  mainSendPort.send(isolateReceivePort.sendPort);

  isolateReceivePort.listen((event) {
    switch (event) {
      case DatabaseEvent databaseEvent:
        switch (databaseEvent.request) {
          case SqlGet sqlGet:
            _sqlGet(sqlGet, databaseEvent.responsePort);
            break;
          case SqlExecute sqlExecute:
            _executeSql(sqlExecute, databaseEvent.responsePort);
            break;
          default:
            print(
              "SQL Isolate received unknown request in database event: $event",
            );
            break;
        }
      default:
        print("SQL Isolate received unknown event: $event");
        break;
    }
  });
  clearDatabase();
  getDatabase().then((db) {
    print("Enabling WAL mode for SQLite");
    db.execute('PRAGMA journal_mode = WAL');
    print("Setting SQLite synchronous mode to NORMAL");
    db.execute('PRAGMA synchronous = NORMAL'); // Or OFF (unsafe on crash)
  });
}

void _executeSql(SqlExecute sqlExecute, SendPort responsePort) async {
  try {
    final db = await getDatabase();
    final stmt = db.prepare(sqlExecute.sql);

    stmt.execute(sqlExecute.parameters);

    stmt.dispose();
    responsePort.send(SqlResponse.success(rows: []));
  } catch (e) {
    responsePort.send(SqlResponse.error(error: e.toString()));
    return;
  }
}

void _sqlGet(SqlGet sqlGet, SendPort responsePort) async {
  try {
    final db = await getDatabase();
    final stmt = db.prepare(sqlGet.sql);

    final result = stmt.select(sqlGet.parameters);

    stmt.dispose();
    responsePort.send(SqlResponse.success(rows: result.rows));
  } catch (e) {
    responsePort.send(SqlResponse.error(error: e.toString()));
    return;
  }
}

class SqlIsolateMessage {
  final SendPort sendPort;

  SqlIsolateMessage(this.sendPort);
}
