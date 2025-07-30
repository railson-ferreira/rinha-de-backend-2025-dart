import 'dart:isolate';

import 'package:rinha_de_backend_2025_dart/database_isolate.dart';
import 'package:rinha_de_backend_2025_dart/handle_payments.dart';
import 'package:rinha_de_backend_2025_dart/payment_processor_enum.dart';
import 'package:rinha_de_backend_2025_dart/payment_summary_item.dart';

class PaymentsRepository {
  static final PaymentsRepository instance = PaymentsRepository();

  Future<SendPort> _sqlSendPort = sqlIsolateSendPort.future;
  Future<SendPort> get sqlSendPort async {
    try {
      return _sqlSendPort;
    } catch (e) {
      print("Error getting database: $e");
      return _sqlSendPort = sqlIsolateSendPort.future;
    }
  }

  Future<void> insertPayment(
    PaymentAction payment,
    PaymentProcessor processor,
    DateTime requestedAt,
  ) async {
    final sendPort = await sqlSendPort;
    final responsePort = ReceivePort();
    sendPort.send(
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
        responsePort: responsePort.sendPort,
      ),
    );
    final response = await responsePort.first as SqlExecuteResponse;
    if (response.error != null) {
      throw DatabaseException("Error inserting payment: ${response.error}");
    }
  }

  Future<void> removePayment(String correlationId) async {
    final sendPort = await sqlSendPort;
    final responsePort = ReceivePort();
    sendPort.send(
      SqlExecute(
        sql: '''
    DELETE FROM payments WHERE correlationId = ?;
  ''',
        parameters: [correlationId],
        responsePort: responsePort.sendPort,
      ),
    );
    final response = await responsePort.first as SqlExecuteResponse;
    if (response.error != null) {
      throw DatabaseException("Error removing payment: ${response.error}");
    }
  }

  Future<Map<String, PaymentSummaryItem>> getPaymentsSummary({
    required DateTime? from,
    required DateTime? to,
  }) async {
    final sendPort = await sqlSendPort;
    final responsePort = ReceivePort();
    sendPort.send(
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
        responsePort: responsePort.sendPort,
      ),
    );
    final response = await responsePort.first as SqlExecuteResponse;
    if (response.error != null) {
      throw DatabaseException(
        "Error getting payments summary: ${response.error}",
      );
    }
    final rows = response.rows!;
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

class DatabaseException implements Exception {
  final Exception _exception;
  DatabaseException([var message]) : _exception = Exception(message);

  @override
  String toString() {
    return "DatabaseException: ${_exception.toString()}";
  }
}
