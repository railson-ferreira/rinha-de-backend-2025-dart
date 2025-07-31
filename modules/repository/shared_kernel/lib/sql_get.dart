import 'package:shared_kernel/sql_execute.dart';

class SqlGet extends SqlExecute {
  SqlGet({required super.sql, super.parameters});

  SqlGet.fromJson(super.json) : super.fromJson();

  @override
  Map<String, Object?> toJson() => super.toJson();
}
