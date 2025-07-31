class StatusUpdaterLeader {
  final String leaderId;
  final DateTime expiration;

  StatusUpdaterLeader({required this.leaderId, required this.expiration});

  factory StatusUpdaterLeader.fromJson(Map<String, Object?> json) {
    assert(json['leaderId'] is String);
    assert(json['expiration'] is String);
    return StatusUpdaterLeader(
      leaderId: json['leaderId'] as String,
      expiration: DateTime.parse(json['expiration'] as String),
    );
  }

  Map<String, Object?> toJson() => {
    'leaderId': leaderId,
    'expiration': expiration.toIso8601String(),
  };

  @override
  String toString() {
    return 'StatusUpdaterLeader(leaderId: $leaderId, expiration: $expiration)';
  }
}
