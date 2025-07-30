import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:rinha_de_backend_2025_dart/debug.dart';
import 'package:rinha_de_backend_2025_dart/payment_processor_enum.dart';
import 'package:rinha_de_backend_2025_dart/payment_processors_statuses.dart';
import 'package:rinha_de_backend_2025_dart/vars.dart';

Future<void> startStatusFetchLoopIsolated(List<SendPort> ports) async {
  await Isolate.spawn((ports) async {
    runZonedGuarded(
      () {
        try {
          updateStatus(PaymentProcessor.default_, ports);
          updateStatus(PaymentProcessor.fallback_, ports);
        } finally {
          Timer.periodic(Duration(seconds: 5, milliseconds: 10), (timer) async {
            updateStatus(PaymentProcessor.default_, ports);
            updateStatus(PaymentProcessor.fallback_, ports);
          });
        }
      },
      (error, stack) {
        print("StatusFetchLoop: $error");
        print(stack);
      },
    );
  }, ports);
  print('Status Fetch Loop started');
}

void updateStatus(PaymentProcessor processor, List<SendPort> ports) async {
  final httpClient = HttpClient();
  try {
    debug(
      'Fetching status for $processor at ${DateTime.now().toIso8601String()}',
    );
    final HttpClientRequest request;
    switch (processor) {
      case PaymentProcessor.default_:
        request = await httpClient.getUrl(
          paymentProcessorDefaultUrl.replace(path: "/payments/service-health"),
        );
      case PaymentProcessor.fallback_:
        request = await httpClient.getUrl(
          paymentProcessorFallbackUrl.replace(path: "/payments/service-health"),
        );
    }
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode > 299) {
      print('Error fetching status for $processor: ${response.statusCode}');
      return;
    }
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, Object?>;
    final status = PaymentProcessorStatus(
      processor: processor,
      failing: json['failing'] as bool,
      minResponseTimeInMs: (json['minResponseTime'] as num).toInt(),
    );
    debug('✅ status for $processor: $status');
    for (var port in ports) {
      port.send(status);
    }
  } finally {
    httpClient.close(force: true);
  }
}
