import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:rinha_de_backend_2025_dart/debug.dart';
import 'package:rinha_de_backend_2025_dart/status_repository.dart';
import 'package:rinha_de_backend_2025_dart/vars.dart';
import 'package:shared_kernel/payment_processor_enum.dart';
import 'package:shared_kernel/payment_processor_status.dart';
import 'package:uuid/uuid.dart';

final String instanceId = Uuid().v4();
Future<void> startStatusFetchLoopIsolated(List<SendPort> ports) async {
  await Isolate.spawn((ports) async {
    runZonedGuarded(
      () async {
        var imTheLeader = false;
        try {
          imTheLeader = await StatusRepository.instance.setLeader(instanceId);
          if (imTheLeader) {
            await Future.wait([
              fetchStatusAndSave(PaymentProcessor.default_),
              fetchStatusAndSave(PaymentProcessor.fallback_),
            ]);
            updateStatus(PaymentProcessor.default_, ports);
            updateStatus(PaymentProcessor.fallback_, ports);
          }
        } finally {
          const Duration interval = Duration(seconds: 5, milliseconds: 10);
          Timer.periodic(interval, (timer) async {
            if (imTheLeader) {
              imTheLeader = await StatusRepository.instance.updateLeader(
                instanceId,
              );
            } else {
              imTheLeader = await StatusRepository.instance.setLeader(
                instanceId,
              );
            }
          });
          await Future.delayed(Duration(milliseconds: 100));
          Timer.periodic(interval, (timer) async {
            if (imTheLeader) {
              fetchStatusAndSave(PaymentProcessor.default_).whenComplete(() {
                updateStatus(PaymentProcessor.default_, ports);
              });
              fetchStatusAndSave(PaymentProcessor.fallback_).whenComplete(() {
                updateStatus(PaymentProcessor.fallback_, ports);
              });
            }
          });
          await Future.delayed(Duration(milliseconds: 100));
          Timer.periodic(interval ~/ 5, (timer) async {
            if (!imTheLeader) {
              updateStatus(PaymentProcessor.default_, ports);
              updateStatus(PaymentProcessor.fallback_, ports);
            }
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

Future<void> fetchStatusAndSave(PaymentProcessor processor) async {
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
      minResponseTime: (json['minResponseTime'] as num).toInt(),
    );
    await StatusRepository.instance.setStatus(status);
    debug('💾 status for $processor: $status');
  } finally {
    httpClient.close(force: true);
  }
}

void updateStatus(PaymentProcessor processor, List<SendPort> ports) async {
  final status = await StatusRepository.instance.getStatus(processor);
  for (var port in ports) {
    port.send(status);
  }
  debug('✅ status for $processor: $status');
}
