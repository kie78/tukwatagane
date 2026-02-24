import 'package:flutter/material.dart';
import 'main.dart';
import 'browse.dart';
import 'search.dart';
import 'sell.dart';
import 'inbox.dart';
import 'account.dart';
import 'userProfile.dart';
import 'saved.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _currentIndex = 3;

  final List<ChatTile> chats = [
    ChatTile(
      userName: 'Kato Mukasa',
      messagePreview: 'Is the jacket still available?',
      timestamp: '2m ago',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
      isUnread: true,
      isOnline: true,
    ),
    ChatTile(
      userName: 'Namukwaya Sarah',
      messagePreview: "Thank you! I'll pick it up tomorrow.",
      timestamp: '1h ago',
      avatarUrl: 'https://i.pravatar.cc/150?img=45',
      isUnread: false,
      isOnline: false,
    ),
    ChatTile(
      userName: 'Okello David',
      messagePreview: 'We have new electronics in stock',
      timestamp: 'Yesterday',
      avatarUrl: null,
      isUnread: true,
      isOnline: false,
      businessName: 'Kampala Electronics',
    ),
    ChatTile(
      userName: 'Kintu Michael',
      messagePreview: "What's the lowest price you can offer?",
      timestamp: '2d ago',
      avatarUrl: null,
      isUnread: false,
      isOnline: false,
      initials: 'KM',
    ),
  ];

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
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFD4C5B9),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                return ChatListTile(chat: chats[index]);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BrowseScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SearchScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SellScreen()),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AccountScreen()),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.mediumGray,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
        unselectedLabelStyle: const TextStyle(
          height: 1.0,
        ),
        iconSize: 24,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Browse',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.add_circle_outline,
              color: _currentIndex == 2
                  ? AppColors.teal
                  : AppColors.mediumGray,
            ),
            activeIcon: Icon(Icons.add_circle, color: AppColors.teal),
            label: 'Sell',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class ChatTile {
  final String userName;
  final String messagePreview;
  final String timestamp;
  final String? avatarUrl;
  final bool isUnread;
  final bool isOnline;
  final String? businessName;
  final String? initials;

  ChatTile({
    required this.userName,
    required this.messagePreview,
    required this.timestamp,
    this.avatarUrl,
    required this.isUnread,
    required this.isOnline,
    this.businessName,
    this.initials,
  });
}

class ChatListTile extends StatelessWidget {
  final ChatTile chat;

  const ChatListTile({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InboxScreen(
              userName: chat.userName,
              avatarUrl: chat.avatarUrl,
              isOnline: chat.isOnline,
              businessName: chat.businessName,
              initials: chat.initials,
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
          // User Avatar with optional online status
          Stack(
            children: [
              // Avatar
              if (chat.avatarUrl != null)
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(chat.avatarUrl!),
                )
              else if (chat.businessName != null)
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.darkGray,
                  child: Icon(
                    Icons.store,
                    color: AppColors.white,
                    size: 28,
                  ),
                )
              else
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.lightGray,
                  child: Text(
                    chat.initials ?? '',
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              // Online status indicator
              if (chat.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Text Stack
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.userName,
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chat.messagePreview,
                  style: TextStyle(
                    color: chat.isUnread ? Colors.black : AppColors.mediumGray,
                    fontWeight: chat.isUnread ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Metadata (Timestamp and Unread Indicator)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                chat.timestamp,
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              if (chat.isUnread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(height: 10),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
