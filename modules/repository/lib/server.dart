import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:repository/database/database_isolate.dart';
import 'package:repository/database/database_request.dart';
import 'package:repository/debug.dart';
import 'package:repository/memory.dart';
import 'package:shared_kernel/payment_processor_enum.dart';
import 'package:shared_kernel/payment_processor_status.dart';
import 'package:shared_kernel/repository_event.dart';
import 'package:shared_kernel/repository_response.dart';
import 'package:shared_kernel/sql_execute.dart';
import 'package:shared_kernel/sql_get.dart';
import 'package:shared_kernel/sql_response.dart';
import 'package:shared_kernel/status_updater_leader.dart';

part 'handlers.dart';

Future<void> startServer() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('WebSocket server listening on ws://localhost:8080');

  await for (HttpRequest request in server) {
    debug("Received request: ${request.method} ${request.uri}");
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocket socket;
      try {
        socket = await WebSocketTransformer.upgrade(request);
      } catch (e) {
        print('Error upgrading to WebSocket: $e');
        Future(() async {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('Internal Server Error');
          await request.response.flush();
          await request.response.close();
          print(
            "${request.method} ${request.uri} ${request.response.statusCode} ${request.response.reasonPhrase}",
          );
        }).whenComplete(() {});
        continue;
      }
      try {
        debug("WebSocket connection established: ${request.uri}");
        handleWebSocket(socket);
      } catch (e, st) {
        print('Error in WebSocket handler: $e');
        Future(() => Error.throwWithStackTrace(e, st)).whenComplete(() {});
        continue;
      }
    } else {
      print(
        'This is not a WebSocket request: ${request.method} ${request.uri}',
      );
      Future(() async {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('This is not a WebSocket request');
        await request.response.flush();
        await request.response.close();
        print(
          "${request.method} ${request.uri} ${request.response.statusCode} ${request.response.reasonPhrase}",
        );
      }).whenComplete(() {});
    }
  }
}

Future<void> handleWebSocket(WebSocket webSocket) async {
  StreamSubscription? sub;

  Future<void> sendResponse(
    RepositoryEvent event,
    Future<RepositoryResponse> Function(RepositoryEvent event) action,
  ) async {
    try {
      final response = await action(event);
      webSocket.add(jsonEncode(response));
    } catch (e) {
      print('Action error: $e');
      if (e is Error) {
        webSocket.add(
          jsonEncode(
            RepositoryResponse.error(
              sequence: event.sequence,
              error: e.toString(),
            ),
          ),
        );
        return;
      }
    }
  }

  try {
    final completer = Completer<void>();

    sub = webSocket.listen(
      (message) {
        final castedMessage = castMessage(message);
        final event = RepositoryEvent.fromJson(jsonDecode(castedMessage));
        switch (event.eventType) {
          case RepositoryEventType.setStatusUpdaterLeader:
            sendResponse(event, _setStatusUpdaterLeader);
            break;
          case RepositoryEventType.updateStatusUpdaterLeaderExpiration:
            sendResponse(event, _updateStatusUpdaterLeaderExpiration);
            break;
          case RepositoryEventType.sqlExecute:
            final request = SqlExecute.fromJson(event.data);
            sendResponse(
              event,
              (event) => _sqlExecute(event.sequence, request),
            );
            break;
          case RepositoryEventType.sqlGet:
            final request = SqlGet.fromJson(event.data);
            sendResponse(event, (event) => _sqlGet(event.sequence, request));
            break;
          case RepositoryEventType.setStatus:
            sendResponse(event, _setStatus);
            break;
          case RepositoryEventType.getStatus:
            sendResponse(event, _getStatus);
            break;
        }
      },
      onDone: () {
        print('Connection closed by remote.');
        webSocket.close();
        completer.complete(null);
      },
      onError: (error) {
        print('WebSocket error: $error');
        webSocket.close();
        completer.complete(null);
      },
    );

    await completer.future;
  } finally {
    Future(() => sub?.cancel()).whenComplete(() {});
  }
}

String castMessage(dynamic message) {
  if (message is String) {
    return message;
  } else {
    throw ArgumentError('Unsupported message type: ${message.runtimeType}');
  }
}
