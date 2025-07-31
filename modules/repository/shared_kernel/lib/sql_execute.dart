class SqlExecute {
  final String sql;
  final List<Object?> parameters;

  SqlExecute({required this.sql, this.parameters = const []});

  SqlExecute.fromJson(Map<String, Object?> json)
    : sql = json['sql'] as String,
      parameters =
          (json['parameters'] as List<dynamic>?)
              ?.map((e) => e as Object?)
              .toList() ??
          [];

  Map<String, dynamic> toJson() {
    return {'sql': sql, 'parameters': parameters};
  }
}
