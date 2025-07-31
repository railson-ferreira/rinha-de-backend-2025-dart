import 'package:rinha_de_backend_2025_dart/handle_payments.dart';
import 'package:rinha_de_backend_2025_dart/payment_summary_item.dart';
import 'package:rinha_de_backend_2025_dart/repository_client.dart';
import 'package:shared_kernel/payment_processor_enum.dart';
import 'package:shared_kernel/sql_execute.dart';
import 'package:shared_kernel/sql_get.dart';

class PaymentsRepository {
  static final PaymentsRepository instance = PaymentsRepository._(
    RepositoryClient.instance,
  );
  final RepositoryClient _repositoryClient;

  PaymentsRepository._(this._repositoryClient);

  Future<void> insertPayment(
    PaymentAction payment,
    PaymentProcessor processor,
    DateTime requestedAt,
  ) async {
    try {
      await _repositoryClient.sqlExecute(
        SqlExecute(
          sql: '''
    INSERT INTO payments (
      correlationId,
      amountInCents,
      requestedAtMs,
      processor
    ) VALUES (?, ?, ?, ?);
  ''',
          parameters: [
            payment.correlationId,
            (payment.amount * 100).round(),
            requestedAt.millisecondsSinceEpoch,
            switch (processor) {
              PaymentProcessor.default_ => "default",
              PaymentProcessor.fallback_ => "fallback",
            },
          ],
        ),
      );
    } catch (error) {
      throw RepositoryException("Error inserting payment: $error");
    }
  }

  Future<void> removePayment(String correlationId) async {
    try {
      await _repositoryClient.sqlExecute(
        SqlExecute(
          sql: '''
    DELETE FROM payments WHERE correlationId = ?;
  ''',
          parameters: [correlationId],
        ),
      );
    } catch (error) {
      throw RepositoryException("Error removing payment: $error");
    }
  }

  Future<Map<String, PaymentSummaryItem>> getPaymentsSummary({
    required DateTime? from,
    required DateTime? to,
  }) async {
    final List<List<Object?>> rows;
    try {
      rows = await _repositoryClient.sqlGet(
        SqlGet(
          sql:
              '''
    SELECT processor, COUNT(correlationId) AS totalRequests, SUM(amountInCents) AS totalAmount FROM payments
    ${from != null && to != null
                  ? 'WHERE requestedAtMs >= ? AND requestedAtMs <= ?'
                  : from != null
                  ? 'WHERE requestedAtMs >= ?'
                  : to != null
                  ? 'WHERE requestedAtMs <= ?'
                  : ''}
    GROUP BY processor
  ''',
          parameters: [
            if (from != null) from.millisecondsSinceEpoch,
            if (to != null) to.millisecondsSinceEpoch,
          ],
        ),
      );
    } catch (error, st) {
      Error.throwWithStackTrace(
        RepositoryException("Error getting payments summary: $error"),
        st,
      );
    }
    final summary = <String, PaymentSummaryItem>{};
    for (final row in rows) {
      final processor = row[0];
      final totalRequests = row[1];
      final totalAmount = row[2];
      if (totalRequests == 0) {
        continue;
      }
      assert(processor is String);
      assert(totalRequests is int);
      assert(totalAmount is int);
      summary[processor! as String] = PaymentSummaryItem(
        totalRequests: totalRequests! as int,
        totalAmount: (totalAmount! as int) / 100.0,
      );
    }

    for (var value in PaymentProcessor.values) {
      summary[switch (value) {
        PaymentProcessor.default_ => "default",
        PaymentProcessor.fallback_ => "fallback",
      }] ??= PaymentSummaryItem(
        totalRequests: 0,
        totalAmount: 0.0,
      );
    }
    return summary;
  }
}

class RepositoryException implements Exception {
  final Exception _exception;
  RepositoryException([var message]) : _exception = Exception(message);

  @override
  String toString() {
    return "RepositoryException: ${_exception.toString()}";
  }
}
