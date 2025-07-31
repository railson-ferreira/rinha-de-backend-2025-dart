import 'package:rinha_de_backend_2025_dart/repository_client.dart';
import 'package:shared_kernel/payment_processor_enum.dart';
import 'package:shared_kernel/payment_processor_status.dart';
import 'package:shared_kernel/repository_event.dart';

class StatusRepository {
  static final StatusRepository instance = StatusRepository._(
    RepositoryClient.instance,
  );
  final RepositoryClient _repositoryClient;

  StatusRepository._(this._repositoryClient);

  Future<bool> setLeader(String instanceId) async {
    try {
      await _repositoryClient
          .sendEvent(RepositoryEventType.setStatusUpdaterLeader, {
            "leaderId": instanceId,
            "expiration": DateTime.now()
                .add(Duration(seconds: 6))
                .toIso8601String(),
          });
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<bool> updateLeader(String instanceId) async {
    try {
      await _repositoryClient
          .sendEvent(RepositoryEventType.updateStatusUpdaterLeaderExpiration, {
            "leaderId": instanceId,
            "expiration": DateTime.now()
                .add(Duration(seconds: 6))
                .toIso8601String(),
          });
      return true;
    } catch (error) {
      return false;
    }
  }

  Future<void> setStatus(PaymentProcessorStatus status) async {
    try {
      await _repositoryClient.sendEvent(
        RepositoryEventType.setStatus,
        status.toJson(),
      );
    } catch (error, st) {
      Error.throwWithStackTrace(
        RepositoryException("Error setting status: $error"),
        st,
      );
    }
  }

  Future<PaymentProcessorStatus> getStatus(PaymentProcessor processor) async {
    try {
      final json = await _repositoryClient.sendEvent(
        RepositoryEventType.getStatus,
        {"processor": processor.name},
      );
      return PaymentProcessorStatus(
        processor: processor,
        failing: json['failing'] as bool,
        minResponseTime: (json['minResponseTime'] as num).toInt(),
      );
    } catch (error, st) {
      Error.throwWithStackTrace(
        RepositoryException("Error setting status: $error"),
        st,
      );
    }
  }
}

class RepositoryException implements Exception {
  final Exception _exception;
  RepositoryException([var message]) : _exception = Exception(message);

  @override
  String toString() {
    return "DatabaseException: ${_exception.toString()}";
  }
}
