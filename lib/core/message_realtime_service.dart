import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../main.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'stomp_service.dart';

class IncomingConversationMessage {
  final int conversationId;
  final MessageResponse message;

  const IncomingConversationMessage({
    required this.conversationId,
    required this.message,
  });
}

class MessageRealtimeService {
  final ValueNotifier<Set<int>> unreadConversationIdsNotifier =
      ValueNotifier(<int>{});
  final ValueNotifier<Map<int, MessageResponse>> latestMessagesNotifier =
      ValueNotifier(<int, MessageResponse>{});
  final ValueNotifier<IncomingConversationMessage?> incomingMessageNotifier =
      ValueNotifier(null);

  final Map<int, VoidCallback> _subscriptions = {};
  bool _started = false;
  bool _refreshing = false;
  int? _myUserId;
  int _serverUnreadCount = 0;
  int _lastSubscribedConnectionGeneration = -1;

  Future<void> start() async {
    if (_started) {
      await refreshSubscriptions();
      return;
    }
    _started = true;
    conversationUpdateNotifier.addListener(_handleConversationUpdate);
    stompService.connectionGenerationNotifier.addListener(
      _handleStompConnectionGenerationChanged,
    );
    await refreshSubscriptions();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    conversationUpdateNotifier.removeListener(_handleConversationUpdate);
    stompService.connectionGenerationNotifier.removeListener(
      _handleStompConnectionGenerationChanged,
    );
    for (final unsub in _subscriptions.values) {
      unsub();
    }
    _subscriptions.clear();
    _serverUnreadCount = 0;
    _lastSubscribedConnectionGeneration = -1;
    unreadConversationIdsNotifier.value = <int>{};
    latestMessagesNotifier.value = <int, MessageResponse>{};
    incomingMessageNotifier.value = null;
  }

  void setServerUnreadCount(int count) {
    _serverUnreadCount = count;
    _syncUnreadBadge();
  }

  void setLatestMessage(int conversationId, MessageResponse message) {
    latestMessagesNotifier.value = {
      ...latestMessagesNotifier.value,
      conversationId: message,
    };
  }

  Future<void> refreshSubscriptions({bool forceResubscribe = false}) async {
    if (!_started || _refreshing) return;
    final isLoggedIn = await authService.isLoggedIn();
    if (!isLoggedIn) return;

    _refreshing = true;
    try {
      _myUserId ??= await authService.getUserId();
      final token = await apiClient.readToken();
      if (token == null) return;

      final resp = await apiClient.dio.get(
        '/conversations',
        queryParameters: {'page': 0, 'size': 50},
      );
      final items = (resp.data['items'] as List)
          .map((e) => ConversationListItem.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final item in items) {
        conversationVisitedAt.putIfAbsent(
          item.id,
          () => item.lastMessageAt ?? DateTime.now(),
        );
      }

      await stompService.connect(token: token);

      final currentGeneration = stompService.connectionGenerationNotifier.value;
      final shouldResubscribe =
          forceResubscribe ||
          currentGeneration != _lastSubscribedConnectionGeneration;

      if (shouldResubscribe) {
        for (final unsub in _subscriptions.values) {
          unsub();
        }
        _subscriptions.clear();
      }

      final desiredIds = items.map((item) => item.id).toSet();
      final existingIds = _subscriptions.keys.toSet();

      for (final id in existingIds.difference(desiredIds)) {
        _subscriptions.remove(id)?.call();
      }

      for (final id in desiredIds.difference(existingIds)) {
        final unsub = stompService.subscribeToConversation(
          conversationId: id,
          onMessage: (msg) => _handleIncomingMessage(id, msg),
        );
        if (unsub != null) {
          _subscriptions[id] = unsub;
        }
      }

      _lastSubscribedConnectionGeneration = currentGeneration;
    } catch (_) {
      // Keep app usable if realtime subscription refresh fails.
    } finally {
      _refreshing = false;
    }
  }

  void markConversationRead(int conversationId) {
    if (_removeUnreadConversation(conversationId)) {
      _syncUnreadBadge();
    }
  }

  void _handleConversationUpdate() {
    unawaited(refreshSubscriptions());
  }

  void _handleStompConnectionGenerationChanged() {
    unawaited(refreshSubscriptions(forceResubscribe: true));
  }

  void _handleIncomingMessage(int conversationId, MessageResponse msg) {
    if (msg.senderUserId == _myUserId) return;

    setLatestMessage(conversationId, msg);

    final isActiveConversation = openConversationNotifier.value == conversationId;
    if (!isActiveConversation) {
      final nextUnread = {...unreadConversationIdsNotifier.value, conversationId};
      unreadConversationIdsNotifier.value = nextUnread;
      _syncUnreadBadge();
      incomingMessageNotifier.value = IncomingConversationMessage(
        conversationId: conversationId,
        message: msg,
      );
    }

    conversationUpdateNotifier.value++;
  }

  bool _removeUnreadConversation(int conversationId) {
    if (!unreadConversationIdsNotifier.value.contains(conversationId)) {
      return false;
    }

    final nextUnread = {...unreadConversationIdsNotifier.value}
      ..remove(conversationId);
    unreadConversationIdsNotifier.value = nextUnread;
    return true;
  }

  void _syncUnreadBadge() {
    unreadNotifier.value = math.max(
      _serverUnreadCount,
      unreadConversationIdsNotifier.value.length,
    );
  }
}

final messageRealtimeService = MessageRealtimeService();