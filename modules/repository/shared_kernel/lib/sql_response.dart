class SqlResponse {
  final String? error;
  final List<List<Object?>>? rows;

  SqlResponse.error({required String this.error}) : rows = null;
  SqlResponse.success({required List<List<Object?>> this.rows}) : error = null;

  Map<String, Object?> toJson() {
    return {'error': error, 'rows': rows};
  }

  @override
  String toString() {
    return 'SqlResponse(error: $error, rows: $rows)';
  }
}
