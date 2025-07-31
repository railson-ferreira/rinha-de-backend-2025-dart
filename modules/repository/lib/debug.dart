import 'dart:io';

final debugLogsEnabled = Platform.environment['DEBUG_LOGS_ENABLED'] == 'true';
void debug(String message) {
  if (debugLogsEnabled) {
    print(message);
  }
}
