import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rinha_de_backend_2025_dart/debug.dart';
import 'package:rinha_de_backend_2025_dart/isolates_pool.dart';
import 'package:rinha_de_backend_2025_dart/payment_processors_statuses.dart';
import 'package:rinha_de_backend_2025_dart/payments_repository.dart';
import 'package:rinha_de_backend_2025_dart/vars.dart';
import 'package:shared_kernel/payment_processor_enum.dart';

void handlePayments(HttpRequest request) async {
  String body = await utf8.decoder.bind(request).join();
  request.response
    ..statusCode = HttpStatus.noContent
    ..close();
  sendToIsolate(PaymentAction.fromJson(jsonDecode(body)));
}

final queue = <PaymentAction>[];
void handlePaymentsIsolated(PaymentAction paymentAction) async {
  queue.add(paymentAction);
  handleQueue();
}

var isQueueHandling = false;
var concurrentQueueHandling = 0;
void handleQueue() async {
  if (isQueueHandling) {
    return;
  }
  try {
    isQueueHandling = true;
    while (paymentProcessorsStatuses.length < 2) {
      print("waiting statuses...");
      await Future.delayed(Duration(milliseconds: 10));
    }
    // debug("Queue handler started");
    while (queue.isNotEmpty) {
      final maxPerIsolate = concurrentLimit ~/ numberOfIsolates;
      if (concurrentQueueHandling >= maxPerIsolate) {
        debug(
          "Too many concurrent queue handling in this isolate($concurrentQueueHandling >= $maxPerIsolate), waiting...",
        );
        await Future.delayed(Duration(milliseconds: 1));
        continue;
      }
      final (:index, :action) = queue.theOneWithHighestAmount();
      queue.removeAt(index);
      concurrentQueueHandling++;
      final now = DateTime.now();
      handleAction(action)
          .catchError((e) async {
            debug("Error handling action: $action. $e");
            await Future.delayed(Duration(milliseconds: 10));
            return false;
          })
          .then((succeeded) {
            if (!succeeded) {
              // re-add to queue
              queue.add(action);
            }
          })
          .whenComplete(() {
            concurrentQueueHandling--;
            final elapsed = DateTime.now().difference(now);
            debug(
              "Handled action in ${elapsed.inMilliseconds}ms (correlationId: ${action.correlationId}, amount: ${action.amount}). Queue size: ${queue.length}.",
            );
          });
    }
  } finally {
    isQueueHandling = false;
    // debug("Queue handler finished");
  }
}

Future<bool> handleAction(PaymentAction action) async {
  final httpClient = HttpClient();
  try {
    final statusDefault = paymentProcessorsStatuses[PaymentProcessor.default_]!;
    final statusFallback =
        paymentProcessorsStatuses[PaymentProcessor.fallback_]!;
    final HttpClientRequest request;
    final PaymentProcessor chosenProcessor;
    if (!statusDefault.failing) {
      request = await httpClient.postUrl(
        paymentProcessorDefaultUrl.replace(path: "/payments"),
      );
      chosenProcessor = PaymentProcessor.default_;
    } else if (!statusFallback.failing) {
      request = await httpClient.postUrl(
        paymentProcessorFallbackUrl.replace(path: "/payments"),
      );
      chosenProcessor = PaymentProcessor.fallback_;
    } else {
      await Future.delayed(Duration(milliseconds: 1));
      return false;
    }
    try {
      final requestedAt = (DateTime dateTime) {
        return dateTime.subtract(Duration(microseconds: dateTime.microsecond));
      }(DateTime.now().toUtc());

      final response =
          await (request
                ..headers.contentType = ContentType.json
                ..write(
                  jsonEncode({
                    "correlationId": action.correlationId,
                    "amount": action.amount,
                    "requestedAt": requestedAt.toIso8601String(),
                  }),
                ))
              .close();
      if (response.statusCode < 200 || response.statusCode > 299) {
        throw "Status: ${response.statusCode}. $action.";
      }
      Future.microtask(() async {
        (Object, StackTrace)? error;
        for (var i = 0; i < 10; i++) {
          try {
            await PaymentsRepository.instance.insertPayment(
              action,
              chosenProcessor,
              requestedAt,
            );
            break;
          } catch (e, st) {
            error = (e, st);
            await Future.delayed(Duration(milliseconds: 1));
          }
        }
        if (error != null) {
          debug("Error inserting payment: $action. ${error.$1}");
          throw error.$1;
        }
      });
    } catch (e) {
      if (e is! RepositoryException) {
        // If the request fails, we remove the payment from the repository
        await PaymentsRepository.instance.removePayment(action.correlationId);
      }
      rethrow;
    }
    if (chosenProcessor == PaymentProcessor.fallback_ && queue.isEmpty) {
      print(
        "Using fallback and there are no more actions in queue, waiting 5s before releasing.",
      );
      await Future.delayed(Duration(seconds: 5));
    }
    return true;
  } finally {
    httpClient.close(force: true);
  }
}

class PaymentAction {
  final String correlationId;
  final double amount;

  PaymentAction({required this.correlationId, required this.amount});

  factory PaymentAction.fromJson(Map<String, Object?> json) {
    assert(json['correlationId'] is String);
    assert(json['amount'] is num);
    return PaymentAction(
      correlationId: json['correlationId']! as String,
      amount: (json['amount']! as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'PaymentAction(correlationId: $correlationId, amount: ${Decimal(amount)})';
  }
}

class Decimal {
  final double value;

  Decimal(this.value);

  @override
  String toString() {
    return value.toStringAsFixed(2);
  }

  double toJson() {
    return double.parse(value.toStringAsFixed(2));
  }
}

extension _ on List<PaymentAction> {
  // void orderByAmountDesc() {
  //   sort((a, b) => b.amount.compareTo(a.amount));
  // }

  ({int index, PaymentAction action}) theOneWithHighestAmount() {
    if (isEmpty) {
      throw StateError("List is empty");
    }
    var maxIndex = 0;
    var maxAmount = first.amount;
    for (var i = 1; i < length; i++) {
      if (this[i].amount > maxAmount) {
        maxIndex = i;
        maxAmount = this[i].amount;
      }
    }
    return (index: maxIndex, action: this[maxIndex]);
  }
}
