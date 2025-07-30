import 'package:rinha_de_backend_2025_dart/payment_processor_enum.dart';

var paymentProcessorsStatuses = <PaymentProcessor, PaymentProcessorStatus>{};

class PaymentProcessorStatus {
  final PaymentProcessor processor;
  final bool failing;
  final int minResponseTimeInMs;

  PaymentProcessorStatus({
    required this.processor,
    required this.failing,
    required this.minResponseTimeInMs,
  });

  Map<String, Object?> toJson() {
    return {
      'processor': processor.name,
      'failing': failing,
      'minResponseTime': minResponseTimeInMs,
    };
  }

  @override
  String toString() {
    return 'PaymentProcessorStatus(processor: $processor, failing: $failing, minResponseTimeInMs: $minResponseTimeInMs)';
  }
}
