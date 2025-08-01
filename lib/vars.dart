import 'dart:io';

final repositoryUrl = Uri.parse(Platform.environment['REPOSITORY_URL']!);

final paymentProcessorDefaultUrl = Uri.parse(
  Platform.environment['PAYMENT_PROCESSOR_DEFAULT_URL']!,
);
final paymentProcessorFallbackUrl = Uri.parse(
  Platform.environment['PAYMENT_PROCESSOR_FALLBACK_URL']!,
);

final debugLogsEnabled = Platform.environment['DEBUG_LOGS_ENABLED'] == 'true';

final concurrentLimit = 7;
final numberOfIsolates = 1;
