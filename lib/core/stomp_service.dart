import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../models/models.dart';
import 'app_config.dart';

class StompService {
  StompClient? _client;
  bool _connected = false;

  Future<void> connect({
    required String token,
    void Function()? onConnected,
  }) async {
    if (_connected) return;

    // Derive WebSocket URL from the HTTP base URL
    final baseUrl = AppConfig.baseUrl
        .replaceFirst('/api/v1', '')
        .replaceFirst('https://', 'http://'); // SockJS uses http(s)

    _client = StompClient(
      config: StompConfig.sockJS(
        url: '$baseUrl/ws',
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (_) {
          _connected = true;
          onConnected?.call();
        },
        onDisconnect: (_) => _connected = false,
        onStompError: (_) => _connected = false,
        onWebSocketError: (_) => _connected = false,
      ),
    );
    _client!.activate();
  }

  StompUnsubscribe subscribeToConversation({
    required int conversationId,
    required void Function(MessageResponse msg) onMessage,
  }) {
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
  }

  bool get isConnected => _connected;
}

final stompService = StompService();
