import 'dart:async';

import 'package:flutter/material.dart';
import 'main.dart';
import 'inbox.dart';
import 'saved.dart';
import 'widgets/main_nav_bar.dart';
import 'widgets/skeletons.dart';
import 'core/api_client.dart';
import 'core/avatar_resolver.dart';
import 'core/message_realtime_service.dart';
import 'core/unread_service.dart';
import 'models/models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with RouteAware {
  List<_ConversationGroup> _groups = [];
  Map<int, String?> _counterpartAvatars = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    conversationUpdateNotifier.addListener(_onConversationUpdate);
    conversationReadStateNotifier.addListener(_onRealtimeStateChanged);
    messageRealtimeService.unreadConversationIdsNotifier.addListener(
      _onRealtimeStateChanged,
    );
    messageRealtimeService.latestMessagesNotifier.addListener(
      _onRealtimeStateChanged,
    );
  }

  void _onConversationUpdate() {
    if (mounted) _loadConversations();
  }

  void _onRealtimeStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    conversationUpdateNotifier.removeListener(_onConversationUpdate);
    conversationReadStateNotifier.removeListener(_onRealtimeStateChanged);
    messageRealtimeService.unreadConversationIdsNotifier.removeListener(
      _onRealtimeStateChanged,
    );
    messageRealtimeService.latestMessagesNotifier.removeListener(
      _onRealtimeStateChanged,
    );
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final resp = await apiClient.dio.get(
        '/conversations',
        queryParameters: {'page': 0, 'size': 50},
      );
      final items = (resp.data['items'] as List)
          .map((e) => ConversationListItem.fromJson(e as Map<String, dynamic>))
          .toList();
      // Seed first-time-seen conversations as "read" at their current lastMessageAt.
      // Subsequent new messages (arriving via STOMP) will post-date this timestamp
      // and cause the unread dot to appear without backend unreadCount support.
      for (final item in items) {
        conversationVisitedAt.putIfAbsent(
          item.id,
          () => item.lastMessageAt ?? DateTime.now(),
        );
      }
      final avatarMap = await avatarResolver.resolveAvatarUrls(
        items.map((item) => item.counterpartUserId),
      );
      if (mounted) {
        setState(() {
          _groups = _groupConversations(items);
          _counterpartAvatars = avatarMap;
        });
        final fallback = items.fold(0, (sum, c) => sum + c.unreadCount);
        messageRealtimeService.setServerUnreadCount(fallback);
        unawaited(
          unreadService
              .refreshUnreadCount(fallbackCount: fallback)
              .then((count) {
            if (mounted) {
              messageRealtimeService.setServerUnreadCount(count);
            }
          }).catchError((_) {}),
        );
        unawaited(messageRealtimeService.refreshSubscriptions());
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<_ConversationGroup> _groupConversations(
    List<ConversationListItem> items,
  ) {
    DateTime? effectiveLastMessageAt(ConversationListItem item) {
      final live = messageRealtimeService.latestMessagesNotifier.value[item.id];
      return live?.createdAt ?? item.lastMessageAt;
    }

    String? effectiveLastMessageBody(ConversationListItem item) {
      final live = messageRealtimeService.latestMessagesNotifier.value[item.id];
      return live?.body ?? item.lastMessageBody;
    }

    final map = <int, List<ConversationListItem>>{};
    for (final c in items) {
      map.putIfAbsent(c.counterpartUserId, () => []).add(c);
    }
    final groups =
        map.entries.map((e) {
          final convs = List<ConversationListItem>.from(e.value)
            ..sort((a, b) {
              final aTime = effectiveLastMessageAt(a);
              final bTime = effectiveLastMessageAt(b);
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });
          return _ConversationGroup(
            counterpartUserId: e.key,
            counterpartFullName: convs.first.counterpartFullName,
            counterpartPhoneNumber: convs.first.counterpartPhoneNumber,
            counterpartActiveNow: convs.any((c) => c.counterpartActiveNow),
            totalUnread: convs.fold(0, (sum, c) => sum + c.unreadCount),
            mostRecent: convs.first,
            effectiveLastMessageAt: effectiveLastMessageAt(convs.first),
            effectiveLastMessageBody: effectiveLastMessageBody(convs.first),
            conversations: convs,
          );
        }).toList()..sort((a, b) {
          if (a.effectiveLastMessageAt == null) return 1;
          if (b.effectiveLastMessageAt == null) return -1;
          return b.effectiveLastMessageAt!.compareTo(a.effectiveLastMessageAt!);
        });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).lightGray,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/logo.jpg', width: 40, height: 40),
          ),
        ),
        title: Text(
          'Tukwatagane',
          style: TextStyle(
            color: AppColors.of(context).darkGray,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bookmark_border,
              color: AppColors.of(context).mediumGray,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Text(
              'Messages',
              style: TextStyle(
                color: AppColors.of(context).darkGray,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Conversation List
          Expanded(
            child: _isLoading
                ? SkeletonShimmer(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 5,
                      itemBuilder: (_, __) => const ChatTileSkeleton(),
                    ),
                  )
                : _groups.isEmpty
                ? Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(
                        color: AppColors.of(context).mediumGray,
                        fontSize: 16,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadConversations,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final group = _groups[index];
                        return _GroupedChatTile(
                          group: group,
                          avatarUrl:
                              _counterpartAvatars[group.counterpartUserId],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 3),
    );
  }
}

class _ConversationGroup {
  final int counterpartUserId;
  final String counterpartFullName;
  final String? counterpartPhoneNumber;
  final bool counterpartActiveNow;
  final int totalUnread;
  final ConversationListItem mostRecent;
  final DateTime? effectiveLastMessageAt;
  final String? effectiveLastMessageBody;
  final List<ConversationListItem> conversations;

  const _ConversationGroup({
    required this.counterpartUserId,
    required this.counterpartFullName,
    this.counterpartPhoneNumber,
    required this.counterpartActiveNow,
    required this.totalUnread,
    required this.mostRecent,
    this.effectiveLastMessageAt,
    this.effectiveLastMessageBody,
    required this.conversations,
  });
}

class _GroupedChatTile extends StatelessWidget {
  final _ConversationGroup group;
  final String? avatarUrl;

  const _GroupedChatTile({
    required this.group,
    this.avatarUrl,
  });

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openConversation(BuildContext context, ConversationListItem conv) {
    final initials = group.counterpartFullName.isNotEmpty
        ? group.counterpartFullName[0].toUpperCase()
        : '?';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InboxScreen(
          conversationId: conv.id,
          userName: group.counterpartFullName,
          avatarUrl: avatarUrl,
          isOnline: group.counterpartActiveNow,
          phoneNumber: group.counterpartPhoneNumber,
          initials: initials,
          counterpartUserId: group.counterpartUserId,
          productTitle: conv.listingTitle,
          productListingId: conv.listingId,
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    if (group.conversations.length == 1) {
      _openConversation(context, group.conversations.first);
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _ThreadPickerSheet(
          group: group,
          onSelect: (conv) {
            Navigator.pop(context);
            _openConversation(context, conv);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = group.counterpartFullName.isNotEmpty
        ? group.counterpartFullName[0].toUpperCase()
        : '?';
    final resolvedAvatarUrl = (avatarUrl?.trim().isNotEmpty == true)
        ? avatarUrl
        : null;
    final hasUnread =
      messageRealtimeService.unreadConversationIdsNotifier.value.any(
        (id) => group.conversations.any((c) => c.id == id),
      ) ||
      group.conversations.any((conv) {
      final visitedAt = conversationVisitedAt[conv.id];
      final live = messageRealtimeService.latestMessagesNotifier.value[conv.id];
      final messageAt = live?.createdAt ?? conv.lastMessageAt;
      return messageAt != null &&
        (visitedAt == null || messageAt.isAfter(visitedAt));
    });
    final subtitle = group.conversations.length > 1
        ? '${group.conversations.length} active threads'
        : group.mostRecent.listingTitle;

    return InkWell(
      onTap: () => _onTap(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.of(context).white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            resolvedAvatarUrl != null
                ? CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(resolvedAvatarUrl),
                  )
                : CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.of(context).lightGray,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: AppColors.of(context).darkGray,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.counterpartFullName,
                    style: TextStyle(
                      color: AppColors.of(context).darkGray,
                      fontWeight: hasUnread ? FontWeight.w900 : FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.of(context).mediumGray,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (group.effectiveLastMessageBody != null) ...[
                    SizedBox(height: 2),
                    Text(
                      group.effectiveLastMessageBody!,
                      style: TextStyle(
                        color: hasUnread
                            ? AppColors.of(context).darkGray
                            : AppColors.of(context).mediumGray,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _timeAgo(group.effectiveLastMessageAt),
                  style: TextStyle(
                    color: AppColors.of(context).mediumGray,
                    fontSize: 12,
                  ),
                ),
                if (hasUnread) ...[
                  SizedBox(height: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).darkGray,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadPickerSheet extends StatelessWidget {
  final _ConversationGroup group;
  final void Function(ConversationListItem) onSelect;

  const _ThreadPickerSheet({required this.group, required this.onSelect});

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.of(context).mediumGray,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Conversations with ${group.counterpartFullName}',
            style: TextStyle(
              color: AppColors.of(context).darkGray,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        SizedBox(height: 8),
        ...group.conversations.map(
          (conv) => ListTile(
            leading: Icon(
              Icons.chat_bubble_outline,
              color: conv.unreadCount > 0
                  ? AppColors.of(context).primary
                  : AppColors.of(context).mediumGray,
            ),
            title: Text(
              conv.listingTitle,
              style: TextStyle(
                color: AppColors.of(context).darkGray,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: conv.lastMessageBody != null
                ? Text(
                    conv.lastMessageBody!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.of(context).mediumGray),
                  )
                : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(conv.lastMessageAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.of(context).mediumGray,
                  ),
                ),
                if (conv.unreadCount > 0) ...[
                  SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Text(
                      conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            onTap: () => onSelect(conv),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
