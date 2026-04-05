import 'package:flutter/material.dart';
import 'main.dart';
import 'userProfile.dart';
import 'myListings.dart';
import 'saved.dart';
import 'login.dart';
import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'models/models.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String _userName = '';
  String _userEmail = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await authService.getUserName();
    final email = await authService.getUserEmail();
    if (mounted) {
      setState(() {
        _userName = name ?? 'User';
        _userEmail = email ?? '';
      });
    }

    try {
      final profileResp = await apiClient.dio.get('/users/profile');
      final profile = UserProfile.fromJson(profileResp.data);
      final avatar = profile.avatarUrl?.trim();
      if (mounted) {
        setState(() {
          _userName = profile.fullName;
          _userEmail = profile.email;
          _avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : null;
        });
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    try {
      await apiClient.dio.post('/auth/logout');
    } catch (_) {}
    await authService.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (_) => false,
      );
    }
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Heading
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text(
                'Account',
                style: TextStyle(
                  color: AppColors.of(context).darkGray,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (_userName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.of(context).darkGray,
                      backgroundImage: _avatarUrl != null
                          ? NetworkImage(_avatarUrl!)
                          : null,
                      child: _avatarUrl == null
                          ? Text(
                              _userName[0].toUpperCase(),
                              style: TextStyle(
                                color: AppColors.of(context).white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: TextStyle(
                            color: AppColors.of(context).darkGray,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_userEmail.isNotEmpty)
                          Text(
                            _userEmail,
                            style: TextStyle(
                              color: AppColors.of(context).mediumGray,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            // Navigation Menu Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Profile Card
                  _buildMenuCard(
                    icon: Icons.manage_accounts,
                    title: 'Profile',
                    subtitle: 'Manage credentials & security',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // My Listings Card
                  _buildMenuCard(
                    icon: Icons.store,
                    title: 'My Listings',
                    subtitle: 'Items currently for sale',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyListingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Bookmarks Card
                  _buildMenuCard(
                    icon: Icons.bookmark,
                    title: 'Bookmarks',
                    subtitle: 'Your saved items',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SavedScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Theme Card
                  _buildThemeCard(),
                  const SizedBox(height: 24),
                  // Logout Button
                  Center(
                    child: SizedBox(
                      width: 200,
                      child: ElevatedButton.icon(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.of(context).primary,
                          foregroundColor: AppColors.of(context).white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(Icons.logout, color: AppColors.of(context).white),
                        label: Text(
                          'Logout',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 4),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.of(context).white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Leading Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.of(context).primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.of(context).white, size: 24),
            ),
            const SizedBox(width: 16),
            // Text Stack
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.of(context).darkGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: AppColors.of(context).mediumGray, fontSize: 14),
                  ),
                ],
              ),
            ),
            // Trailing Arrow
            Icon(Icons.chevron_right, color: AppColors.of(context).mediumGray, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard() {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sun/moon pill toggle (leading)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              final tc = AppColors.of(context);
              return GestureDetector(
                onTap: () => setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                ),
                child: Container(
                  width: 72,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tc.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: tc.mediumGray.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        alignment: isDark
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: tc.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(
                            Icons.wb_sunny_rounded,
                            size: 17,
                            color: isDark
                                ? tc.mediumGray
                                : Colors.amber.shade700,
                          ),
                          Icon(
                            Icons.nightlight_round,
                            size: 17,
                            color: isDark
                                ? Colors.amber.shade700
                                : tc.mediumGray,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: TextStyle(
                    color: c.darkGray,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Light / Dark appearance',
                  style: TextStyle(color: c.mediumGray, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
