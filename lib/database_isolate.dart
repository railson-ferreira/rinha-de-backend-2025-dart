import 'dart:async';
import 'dart:isolate';

import 'package:rinha_de_backend_2025_dart/database.dart';

final sqlIsolateSendPort = Completer<SendPort>();

Future<void> startSqlIsolate(List<SendPort> ports) async {
  await Isolate.spawn((ports) async {
    final mainIsolate = ReceivePort();
    sqliteIsolateEntry(mainIsolate.sendPort);
    final sqlSendPort = await mainIsolate.first as SendPort;
    for (var port in ports) {
      port.send(SqlIsolateMessage(sqlSendPort));
    }
  }, ports);
  print('SQL isolate started');
}

void sqliteIsolateEntry(SendPort mainSendPort) {
  final ReceivePort isolateReceivePort = ReceivePort();
  mainSendPort.send(isolateReceivePort.sendPort);

  isolateReceivePort.listen((event) {
    switch (event) {
      case SqlGet sqlGet:
        _sqlGet(sqlGet);
        break;
      case SqlExecute sqlExecute:
        _executeSql(sqlExecute);
        break;
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

void _executeSql(SqlExecute sqlExecute) async {
  try {
    final db = await getDatabase();
    final stmt = db.prepare(sqlExecute.sql);

    stmt.execute(sqlExecute.parameters);

    stmt.dispose();
    sqlExecute.responsePort.send(SqlExecuteResponse.success(rows: []));
  } catch (e) {
    sqlExecute.responsePort.send(SqlExecuteResponse.error(error: e.toString()));
    return;
  }
}

void _sqlGet(SqlGet sqlGet) async {
  try {
    final db = await getDatabase();
    final stmt = db.prepare(sqlGet.sql);

    final result = stmt.select(sqlGet.parameters);

    stmt.dispose();
    sqlGet.responsePort.send(SqlExecuteResponse.success(rows: result.rows));
  } catch (e) {
    sqlGet.responsePort.send(SqlExecuteResponse.error(error: e.toString()));
    return;
  }
}

class SqlIsolateMessage {
  final SendPort sendPort;

  SqlIsolateMessage(this.sendPort);
}

class SqlExecute {
  final String sql;
  final List<Object?> parameters;
  final SendPort responsePort;

  SqlExecute({
    required this.sql,
    this.parameters = const [],
    required this.responsePort,
  });
}

class SqlGet extends SqlExecute {
  SqlGet({required super.sql, super.parameters, required super.responsePort});
}

class SqlExecuteResponse {
  final String? error;
  final List<List<Object?>>? rows;

  SqlExecuteResponse.error({required String this.error}) : rows = null;
  SqlExecuteResponse.success({required List<List<Object?>> this.rows})
    : error = null;
}
