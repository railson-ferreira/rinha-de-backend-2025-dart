class RepositoryEvent {
  final int sequence;
  final RepositoryEventType eventType;
  final Map<String, Object?> data;

  RepositoryEvent({
    required this.sequence,
    required this.eventType,
    required this.data,
  });

  factory RepositoryEvent.fromJson(Map<String, Object?> json) {
    assert(json['sequence'] is int);
    assert(json['eventType'] is String);
    assert(json['data'] is Map<String, Object?>);
    return RepositoryEvent(
      sequence: json['sequence'] as int,
      eventType: RepositoryEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () =>
            throw ArgumentError('Unknown event type: ${json['eventType']}'),
      ),
      data: Map<String, Object?>.from(json['data'] as Map),
    );
  }

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'eventType': eventType.name,
    'data': data,
  };

  @override
  String toString() {
    return 'RepositoryEvent(sequence: $sequence, eventType: $eventType, data: $data)';
  }
}

enum RepositoryEventType {
  setStatusUpdaterLeader,
  updateStatusUpdaterLeaderExpiration,
  setStatus,
  getStatus,
  sqlExecute,
  sqlGet,
}
