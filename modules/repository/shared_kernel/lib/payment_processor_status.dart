import 'package:shared_kernel/payment_processor_enum.dart';

class PaymentProcessorStatus {
  final PaymentProcessor processor;
  final bool failing;
  final int minResponseTime;

  PaymentProcessorStatus({
    required this.processor,
    required this.failing,
    required this.minResponseTime,
  });

  Map<String, Object?> toJson() {
    return {
      'processor': processor.name,
      'failing': failing,
      'minResponseTime': minResponseTime,
    };
  }

  @override
  String toString() {
    return 'PaymentProcessorStatus(processor: $processor, failing: $failing, minResponseTime: $minResponseTime)';
  }
}
