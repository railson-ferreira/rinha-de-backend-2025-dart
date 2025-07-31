part of 'server.dart';

Future<RepositoryResponse> _setStatusUpdaterLeader(
  RepositoryEvent event,
) async {
  if (currentStatusUpdaterLeader.expiration.isAfter(DateTime.now())) {
    debug("Status updater leader already set, denied: ${event.data}");
    return RepositoryResponse.error(
      sequence: event.sequence,
      error: "Status updater leader already set",
    );
  }
  debug("Setting status updater leader: ${event.data}");
  currentStatusUpdaterLeader = StatusUpdaterLeader.fromJson(event.data);
  return RepositoryResponse.data(sequence: event.sequence, data: {});
}

Future<RepositoryResponse> _updateStatusUpdaterLeaderExpiration(
  RepositoryEvent event,
) async {
  final statusUpdaterLeader = StatusUpdaterLeader.fromJson(event.data);
  if (currentStatusUpdaterLeader.leaderId != statusUpdaterLeader.leaderId) {
    debug("Status updater leader mismatch, denied: ${event.data}");
    return RepositoryResponse.error(
      sequence: event.sequence,
      error: "Status updater leader mismatch",
    );
  }

  if (statusUpdaterLeader.expiration.isBefore(DateTime.now())) {
    debug("New expiration is in the past, denied: ${event.data}");
    return RepositoryResponse.error(
      sequence: event.sequence,
      error: "New expiration is in the past",
    );
  }
  currentStatusUpdaterLeader = StatusUpdaterLeader(
    leaderId: statusUpdaterLeader.leaderId,
    expiration: statusUpdaterLeader.expiration,
  );
  debug("Updated status updater leader: $statusUpdaterLeader");
  return RepositoryResponse.data(sequence: event.sequence, data: {});
}

Future<RepositoryResponse> _sqlExecute(int sequence, SqlExecute request) async {
  final sendPort = await sqlIsolateSendPort.future;

  final responsePort = ReceivePort();
  sendPort.send(DatabaseEvent(request, responsePort.sendPort));
  final response = await responsePort.first as SqlResponse;

  if (response.error != null) {
    return RepositoryResponse.error(sequence: sequence, error: response.error!);
  }
  return RepositoryResponse.data(sequence: sequence, data: response.toJson());
}

Future<RepositoryResponse> _sqlGet(int sequence, SqlGet request) async {
  final sendPort = await sqlIsolateSendPort.future;

  final responsePort = ReceivePort();
  sendPort.send(DatabaseEvent(request, responsePort.sendPort));
  final response = await responsePort.first as SqlResponse;

  if (response.error != null) {
    return RepositoryResponse.error(sequence: sequence, error: response.error!);
  }

  return RepositoryResponse.data(sequence: sequence, data: response.toJson());
}

Future<RepositoryResponse> _setStatus(RepositoryEvent event) async {
  final statusJson = event.data;
  final processorName = statusJson['processor'] as String?;
  final status = PaymentProcessorStatus(
    processor: PaymentProcessor.values.firstWhere(
      (p) => p.name == processorName,
      orElse: () => throw Exception("Unknown processor: $processorName"),
    ),
    failing: statusJson['failing'] as bool? ?? false,
    minResponseTime: (statusJson['minResponseTime'] as num).toInt(),
  );
  debug("Setting status for processor: ${status.processor}");
  paymentProcessorsStatuses[status.processor] = status;
  return RepositoryResponse.data(sequence: event.sequence, data: {});
}

Future<RepositoryResponse> _getStatus(RepositoryEvent event) async {
  final processorName = event.data['processor'] as String?;
  if (processorName == null) {
    return RepositoryResponse.error(
      sequence: event.sequence,
      error: "Processor name is required",
    );
  }
  final processor = PaymentProcessor.values.firstWhere(
    (p) => p.name == processorName,
    orElse: () => throw Exception("Unknown processor: $processorName"),
  );
  debug("Getting status for processor: $processor");
  final status = paymentProcessorsStatuses[processor];
  if (status == null) {
    return RepositoryResponse.error(
      sequence: event.sequence,
      error: "Status for processor $processor not found",
    );
  }
  return RepositoryResponse.data(
    sequence: event.sequence,
    data: status.toJson(),
  );
}
