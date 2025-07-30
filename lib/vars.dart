import 'dart:io';
import 'dart:math';

final paymentProcessorDefaultUrl = Uri.parse(
  Platform.environment['PAYMENT_PROCESSOR_DEFAULT_URL']!,
);
final paymentProcessorFallbackUrl = Uri.parse(
  Platform.environment['PAYMENT_PROCESSOR_FALLBACK_URL']!,
);

final debugLogsEnabled = Platform.environment['DEBUG_LOGS_ENABLED'] == 'true';

final concurrentLimit = 4;
final numberOfIsolates = min(concurrentLimit, Platform.numberOfProcessors);
