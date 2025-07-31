import 'dart:async';
import 'dart:isolate';

import 'package:rinha_de_backend_2025_dart/handle_payments.dart';
import 'package:rinha_de_backend_2025_dart/payment_processors_statuses.dart';
import 'package:rinha_de_backend_2025_dart/vars.dart';
import 'package:shared_kernel/payment_processor_status.dart';

final isolatesCompleter = Completer<List<SendPort>>();
List<SendPort>? maybeIsolates = null;
FutureOr<List<SendPort>> get futureOrIsolates async {
  final lMaybeIsolates = maybeIsolates;
  if (lMaybeIsolates != null) {
    return lMaybeIsolates;
  }
  return maybeIsolates = await isolatesCompleter.future;
}

Future<List<SendPort>> startIsolatesPool() async {
  isolatesCompleter.complete(
    Future.wait([
      for (int i = 0; i < numberOfIsolates; i++) spawnIsolateWithSendPort(i),
    ]),
  );
  return isolatesCompleter.future;
}

Future<SendPort> spawnIsolateWithSendPort(int index) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(isolateEntry, (
    isolateIndex: index,
    sendPort: receivePort.sendPort,
  ));
  final sendPort = await receivePort.first as SendPort;
  return sendPort;
}

var currentIsolateIndex = 0;
void sendToIsolate(Object? request) async {
  final isolates = await futureOrIsolates;
  final index = currentIsolateIndex++ % isolates.length;
  final selected = isolates[index];
  selected.send(request);
}

void isolateEntry(({int isolateIndex, SendPort sendPort}) params) {
  final (:isolateIndex, :sendPort) = params;
  runZonedGuarded(
    () {
      final receivePort = ReceivePort();
      sendPort.send(receivePort.sendPort);
      print('Isolate $isolateIndex started');
      receivePort.listen((event) {
        switch (event) {
          case PaymentAction paymentAction:
            handlePaymentsIsolated(paymentAction);
            break;
          case PaymentProcessorStatus status:
            paymentProcessorsStatuses[status.processor] = status;
            break;
          default:
            print("Isolate $isolateIndex received unknown event: $event");
        }
      });
    },
    (error, stack) {
      print("Isolate $isolateIndex: $error");
      print(stack);
    },
  );
}
