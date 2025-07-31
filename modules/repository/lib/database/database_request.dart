import 'dart:isolate';

class DatabaseEvent {
  final Object request;
  final SendPort responsePort;

  DatabaseEvent(this.request, this.responsePort);

  @override
  String toString() {
    return 'DatabaseEvent(request: $request, responsePort: $responsePort)';
  }
}
