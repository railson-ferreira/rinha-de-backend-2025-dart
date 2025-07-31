import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:rinha_de_backend_2025_dart/debug.dart';
import 'package:rinha_de_backend_2025_dart/vars.dart';
import 'package:rinha_de_backend_2025_dart/wrapping_counter.dart';
import 'package:shared_kernel/repository_event.dart';
import 'package:shared_kernel/repository_response.dart';
import 'package:shared_kernel/sql_execute.dart';

class RepositoryClient {
  static final RepositoryClient instance = RepositoryClient._(_Socket());
  final WrappingCounter _counter = WrappingCounter(0xffff);
  final _Socket _socket;

  RepositoryClient._(this._socket);

  Future<Map<String, Object?>> sendEvent(
    RepositoryEventType eventType,
    Map<String, Object?> data,
  ) async {
    final sequence = _counter.value;
    _counter.increment();
    final response = await _socket.handleRequest(
      RepositoryEvent(sequence: sequence, eventType: eventType, data: data),
    );

    if (response.error != null) {
      throw Exception('Error executing event: ${response.error}');
    }
    return response.data!;
  }

  Future<void> sqlExecute(SqlExecute sqlExecute) async {
    final sequence = _counter.value;
    _counter.increment();
    final response = await _socket.handleRequest(
      RepositoryEvent(
        sequence: sequence,
        eventType: RepositoryEventType.sqlExecute,
        data: sqlExecute.toJson(),
      ),
    );

    if (response.error != null) {
      throw Exception('Error executing SQL: ${response.error}');
    }
  }

  Future<List<List<Object?>>> sqlGet(SqlExecute sqlExecute) async {
    final sequence = _counter.value;
    _counter.increment();
    final response = await _socket.handleRequest(
      RepositoryEvent(
        sequence: sequence,
        eventType: RepositoryEventType.sqlGet,
        data: sqlExecute.toJson(),
      ),
    );

    if (response.error != null) {
      throw Exception('Error getting SQL: ${response.error}');
    }
    final rows = response.data!["rows"]! as List<Object?>;
    return rows.cast();
  }
}

class _Socket {
  WebSocket? _webSocket;
  final List<
    ({
      int sequence,
      RepositoryEvent request,
      void Function(RepositoryResponse) onResponse,
    })
  >
  requestQueue = [];
  final responseStreamController =
      StreamController<
        ({int sequence, RepositoryResponse response})
      >.broadcast();

  Stream<({int sequence, RepositoryResponse response})> get responseStream =>
      responseStreamController.stream;

  StreamSink<({int sequence, RepositoryResponse response})> get responseSink =>
      responseStreamController.sink;

  _Socket() {
    _initialize();
  }
  Future<void> _initialize() async {
    while (true) {
      try {
        await _start();
      } catch (e, st) {
        print('client connection failed: $e');
        print(st);
      } finally {
        print("Retrying in 1 second...");
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }

  Future<void> _start() async {
    StreamSubscription? sub;
    try {
      final completer = Completer<void>();
      print('Connecting to WebSocket at $repositoryUrl');
      final webSocket = _webSocket = await WebSocket.connect(
        repositoryUrl.toString(),
      );
      print('Connected to WebSocket at $repositoryUrl');

      sub = webSocket.listen(
        (message) {
          final castedMessage = castMessage(message);
          final response = RepositoryResponse.fromJson(
            jsonDecode(castedMessage),
          );
          responseSink.add((sequence: response.sequence, response: response));
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

  Future<RepositoryResponse> handleRequest(RepositoryEvent request) {
    final completer = Completer<RepositoryResponse>();

    requestQueue.add((
      sequence: request.sequence,
      request: request,
      onResponse: (response) {
        if (response.error != null) {
          completer.completeError(response.error!);
        } else {
          completer.complete(response);
        }
      },
    ));
    handleQueue();
    return completer.future;
  }

  void handleQueue() async {
    var varWebSocket = _webSocket;
    while (requestQueue.isNotEmpty) {
      final (:sequence, :request, :onResponse) = requestQueue.removeAt(0);

      while (varWebSocket == null ||
          varWebSocket.readyState != WebSocket.open) {
        varWebSocket = _webSocket;
        await Future.delayed(Duration(milliseconds: 1));
      }
      final webSocket = varWebSocket;
      Future(() async {
        try {
          webSocket.add(jsonEncode(request));

          final completer = Completer<RepositoryResponse>();

          final sub = responseStream.listen((event) {
            if (event.sequence == sequence) {
              completer.complete(event.response);
            }
          });

          final response = await completer.future;
          sub.cancel();

          if (response.error != null) {
            onResponse(
              RepositoryResponse.error(
                sequence: sequence,
                error: response.error,
              ),
            );
          } else {
            onResponse(
              RepositoryResponse.data(sequence: sequence, data: response.data),
            );
          }
        } catch (_) {
          debug('Error handling request: $request');
          onResponse(
            RepositoryResponse.error(
              sequence: sequence,
              error: 'Error handling request: $request',
            ),
          );
        }
      }).whenComplete(() {});
    }
  }
}

String castMessage(dynamic message) {
  if (message is String) {
    return message;
  } else {
    throw ArgumentError('Unsupported message type: ${message.runtimeType}');
  }
}
