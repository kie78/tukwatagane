import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/models.dart';
import 'app_config.dart';

class StompService {
  StompClient? _client;
  bool _connected = false;
  Completer<void>? _connectCompleter;

  Future<void> connect({required String token}) async {
    // Already connected — nothing to do.
    if (_connected) return;

    // Connection in progress — wait for the same handshake.
    if (_connectCompleter != null) {
      await _connectCompleter!.future;
      return;
    }

    _connectCompleter = Completer<void>();

    final baseUrl = AppConfig.baseUrl
        .replaceFirst('/api/v1', '')
        .replaceFirst('https://', 'http://');

    _client = StompClient(
      config: StompConfig.sockJS(
        url: '$baseUrl/ws',
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (_) {
          _connected = true;
          if (!(_connectCompleter?.isCompleted ?? true)) {
            _connectCompleter?.complete();
          }
        },
        onDisconnect: (_) {
          _connected = false;
          _connectCompleter = null;
        },
        onStompError: (_) {
          _connected = false;
          if (!(_connectCompleter?.isCompleted ?? true)) {
            _connectCompleter?.complete(); // unblock callers; subscribe will handle the error
          }
          _connectCompleter = null;
        },
        onWebSocketError: (_) {
          _connected = false;
          if (!(_connectCompleter?.isCompleted ?? true)) {
            _connectCompleter?.complete();
          }
          _connectCompleter = null;
        },
      ),
    );
    _client!.activate();

    // Wait until onConnect (or an error callback) fires.
    await _connectCompleter!.future;
  }

  StompUnsubscribe? subscribeToConversation({
    required int conversationId,
    required void Function(MessageResponse msg) onMessage,
  }) {
    if (!_connected || _client == null) return null;
    return _client!.subscribe(
      destination: '/topic/conversations.$conversationId',
      callback: (frame) {
        if (frame.body != null) {
          onMessage(MessageResponse.fromJson(jsonDecode(frame.body!)));
        }
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
    _connected = false;
    _connectCompleter = null;
  }

  bool get isConnected => _connected;
}

final stompService = StompService();
