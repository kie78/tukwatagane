import 'package:flutter/material.dart';
import 'main.dart';
import 'inbox.dart';
import 'saved.dart';
import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'models/models.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with RouteAware {
  List<_ConversationGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    conversationUpdateNotifier.addListener(_onConversationUpdate);
  }

  void _onConversationUpdate() {
    if (mounted) _loadConversations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    conversationUpdateNotifier.removeListener(_onConversationUpdate);
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
      final resp = await apiClient.dio.get('/conversations', queryParameters: {'page': 0, 'size': 50});
      final items = (resp.data['items'] as List)
          .map((e) => ConversationListItem.fromJson(e))
          .toList();
      if (mounted) {
        setState(() => _groups = _groupConversations(items));
        unreadNotifier.value = items.fold(0, (sum, c) => sum + c.unreadCount);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<_ConversationGroup> _groupConversations(List<ConversationListItem> items) {
    final map = <int, List<ConversationListItem>>{};
    for (final c in items) {
      map.putIfAbsent(c.counterpartUserId, () => []).add(c);
    }
    final groups = map.entries.map((e) {
      final convs = List<ConversationListItem>.from(e.value)
        ..sort((a, b) {
          if (a.lastMessageAt == null) return 1;
          if (b.lastMessageAt == null) return -1;
          return b.lastMessageAt!.compareTo(a.lastMessageAt!);
        });
      return _ConversationGroup(
        counterpartUserId: e.key,
        counterpartFullName: convs.first.counterpartFullName,
        counterpartPhoneNumber: convs.first.counterpartPhoneNumber,
        counterpartActiveNow: convs.any((c) => c.counterpartActiveNow),
        totalUnread: convs.fold(0, (sum, c) => sum + c.unreadCount),
        mostRecent: convs.first,
        conversations: convs,
      );
    }).toList()
      ..sort((a, b) {
        if (a.mostRecent.lastMessageAt == null) return 1;
        if (b.mostRecent.lastMessageAt == null) return -1;
        return b.mostRecent.lastMessageAt!.compareTo(a.mostRecent.lastMessageAt!);
      });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 40,
              height: 40,
            ),
          ),
        ),
        title: const Text(
          'Tukwatagane',
          style: TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: AppColors.mediumGray,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedScreen(),
                ),
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
                color: AppColors.darkGray,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // Conversation List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groups.isEmpty
                    ? const Center(
                        child: Text(
                          'No conversations yet',
                          style: TextStyle(color: AppColors.mediumGray, fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadConversations,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _groups.length,
                          itemBuilder: (context, index) {
                            return _GroupedChatTile(group: _groups[index]);
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
  final List<ConversationListItem> conversations;

  const _ConversationGroup({
    required this.counterpartUserId,
    required this.counterpartFullName,
    this.counterpartPhoneNumber,
    required this.counterpartActiveNow,
    required this.totalUnread,
    required this.mostRecent,
    required this.conversations,
  });
}

class _GroupedChatTile extends StatelessWidget {
  final _ConversationGroup group;

  const _GroupedChatTile({required this.group});

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
    final hasUnread = group.totalUnread > 0;
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.lightGray,
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.darkGray,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.counterpartFullName,
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontWeight: hasUnread ? FontWeight.w900 : FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.mediumGray, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (group.mostRecent.lastMessageBody != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      group.mostRecent.lastMessageBody!,
                      style: TextStyle(
                        color: hasUnread ? AppColors.darkGray : AppColors.mediumGray,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
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
                  _timeAgo(group.mostRecent.lastMessageAt),
                  style: const TextStyle(color: AppColors.mediumGray, fontSize: 12),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.darkGray,
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
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.mediumGray,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Conversations with ${group.counterpartFullName}',
            style: const TextStyle(
              color: AppColors.darkGray,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...group.conversations.map((conv) => ListTile(
              leading: Icon(
                Icons.chat_bubble_outline,
                color: conv.unreadCount > 0 ? AppColors.teal : AppColors.mediumGray,
              ),
              title: Text(
                conv.listingTitle,
                style: const TextStyle(
                    color: AppColors.darkGray, fontWeight: FontWeight.w600),
              ),
              subtitle: conv.lastMessageBody != null
                  ? Text(
                      conv.lastMessageBody!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.mediumGray),
                    )
                  : null,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _timeAgo(conv.lastMessageAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.mediumGray),
                  ),
                  if (conv.unreadCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius:
                            BorderRadius.all(Radius.circular(10)),
                      ),
                      child: Text(
                        conv.unreadCount > 99
                            ? '99+'
                            : '${conv.unreadCount}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () => onSelect(conv),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}
