import 'dart:async';

import 'package:sqlite3/sqlite3.dart';

Future<Database> _initDatabase() async {
  final db = sqlite3.open('rinha.db');
  // Create the table if it doesn't exist
  db.execute('''
    CREATE TABLE IF NOT EXISTS payments (
      correlationId TEXT PRIMARY KEY NOT NULL,
      amountInCents INTEGER NOT NULL,
      requestedAtMs INTEGER NOT NULL,
      processor TEXT NOT NULL
    );
  ''');
  print("Database initialized.");
  return db;
}

Completer<Database>? _databaseCompleter;
Future<Database> getDatabase() async {
  if (_databaseCompleter == null) {
    _databaseCompleter = Completer<Database>();
    _databaseCompleter!.complete(_initDatabase());
  }
  return _databaseCompleter!.future;
}

Future<void> clearDatabase() async {
  final db = await getDatabase();
  print("Clearing database...");
  db.execute('''
    DELETE FROM payments
  ''');
}
