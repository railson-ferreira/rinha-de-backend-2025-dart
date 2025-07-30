import 'dart:convert';
import 'dart:io';

import 'package:rinha_de_backend_2025_dart/payments_repository.dart';

Future<void> handlePaymentsSummary(HttpRequest request) async {
  try {
    final fromStr = request.uri.queryParameters["from"];
    final toStr = request.uri.queryParameters["to"];
    final from = fromStr != null ? DateTime.parse(fromStr) : null;
    final to = toStr != null ? DateTime.parse(toStr) : null;
    final summary = await PaymentsRepository.instance.getPaymentsSummary(
      from: from,
      to: to,
    );
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(summary))
      ..close();
  } catch (e) {
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..close();
    rethrow;
  }
}
