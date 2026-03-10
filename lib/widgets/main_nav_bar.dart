import 'package:flutter/material.dart';
import '../main.dart';

class MainNavBar extends StatelessWidget {
  final int currentIndex;

  const MainNavBar({super.key, required this.currentIndex});

  static const List<String> _routes = [
    '/browse',
    '/search',
    '/sell',
    '/chat',
    '/account',
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        if (index == 4) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/account',
            (route) => false,
          );
          return;
        }
        if (index == currentIndex) return;
        Navigator.pushReplacementNamed(context, _routes[index]);
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
            color: currentIndex == 2 ? AppColors.teal : AppColors.mediumGray,
          ),
          activeIcon: const Icon(Icons.add_circle, color: AppColors.teal),
          label: 'Sell',
        ),
        BottomNavigationBarItem(
          icon: const _ChatIcon(active: false),
          activeIcon: const _ChatIcon(active: true),
          label: 'Chat',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.account_circle_outlined),
          activeIcon: Icon(Icons.account_circle),
          label: 'Account',
        ),
      ],
    );
  }
}

class _ChatIcon extends StatelessWidget {
  final bool active;
  const _ChatIcon({required this.active});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: unreadNotifier,
      builder: (context, count, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(active ? Icons.chat_bubble : Icons.chat_bubble_outline),
            if (count > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
