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
  List<ConversationListItem> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
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
        setState(() => _conversations = items);
        unreadNotifier.value = items.fold(0, (sum, c) => sum + c.unreadCount);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
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
                : _conversations.isEmpty
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
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            return ChatListTile(conv: _conversations[index]);
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

class ChatListTile extends StatelessWidget {
  final ConversationListItem conv;

  const ChatListTile({
    super.key,
    required this.conv,
  });

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final initials = conv.counterpartFullName.isNotEmpty
        ? conv.counterpartFullName[0].toUpperCase()
        : '?';
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InboxScreen(
              conversationId: conv.id,
              userName: conv.counterpartFullName,
              isOnline: conv.counterpartActiveNow,
              phoneNumber: conv.counterpartPhoneNumber,
              initials: initials,
              counterpartUserId: conv.counterpartUserId,
            ),
          ),
        );
      },
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
            // Avatar
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
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.counterpartFullName,
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontWeight: conv.unreadCount > 0
                          ? FontWeight.w900
                          : FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conv.listingTitle,
                    style: const TextStyle(color: AppColors.mediumGray, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conv.lastMessageBody != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      conv.lastMessageBody!,
                      style: TextStyle(
                        color: conv.unreadCount > 0
                            ? AppColors.darkGray
                            : AppColors.mediumGray,
                        fontWeight: conv.unreadCount > 0
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
            // Right column: timestamp + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(conv.lastMessageAt),
                  style: const TextStyle(color: AppColors.mediumGray, fontSize: 12),
                ),
                if (conv.unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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
