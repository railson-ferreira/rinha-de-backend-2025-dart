import 'dart:io';

import 'package:rinha_de_backend_2025_dart/handle_payments_summary.dart';

import 'handle_payments.dart';

Future<void> startServer() async {
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    int.tryParse(Platform.environment["PORT"] ?? "") ?? 8080,
  );
  print('Server listening on port ${server.port}');

  server.listen(onRequest);
}

void onRequest(HttpRequest request) {
  if (request.method == 'POST' && request.uri.path == '/payments') {
    handlePayments(request);
  } else if (request.method == 'GET' &&
      request.uri.path == '/payments-summary') {
    handlePaymentsSummary(request);
  } else {
    request.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }
}
