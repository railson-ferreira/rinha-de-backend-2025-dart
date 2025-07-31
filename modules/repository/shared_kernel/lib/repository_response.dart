class RepositoryResponse {
  final int sequence;
  final String? error;
  final Map<String, Object?>? data;

  RepositoryResponse._raw({
    required this.sequence,
    required this.error,
    required this.data,
  });

  RepositoryResponse.data({required this.sequence, required this.data})
    : error = null;
  RepositoryResponse.error({required this.sequence, required this.error})
    : data = null;

  factory RepositoryResponse.fromJson(Map<String, Object?> json) {
    assert(json["sequence"] is int);
    assert(json["error"] is String?);
    assert(json["data"] is Map<String, Object?>?);
    return RepositoryResponse._raw(
      sequence: json['sequence']! as int,
      error: json['error'] as String?,
      data: json['data'] as Map<String, Object?>?,
    );
  }
  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'error': error,
    'data': data,
  };

  @override
  String toString() {
    return 'RepositoryResponse(sequence: $sequence, error: $error, data: $data)';
  }
}
