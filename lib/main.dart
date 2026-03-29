import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'login.dart';
import 'browse.dart';
import 'core/auth_service.dart';
import 'core/message_realtime_service.dart';
import 'core/unread_service.dart';
import 'search.dart';
import 'sell.dart';
import 'chat.dart';
import 'account.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

final ValueNotifier<int> unreadNotifier = ValueNotifier(0);
final ValueNotifier<int> conversationUpdateNotifier = ValueNotifier(0);
final ValueNotifier<int> bookmarkUpdateNotifier = ValueNotifier(0);
final ValueNotifier<int?> openConversationNotifier = ValueNotifier<int?>(null);
final ValueNotifier<int> conversationReadStateNotifier = ValueNotifier(0);

/// Per-conversation last-visit timestamp. Seeded on first chat-list load.
/// Updated whenever the user opens an inbox screen.
final Map<int, DateTime> conversationVisitedAt = {};

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final loggedIn = await authService.isLoggedIn();
  runApp(MainApp(startLoggedIn: loggedIn));
}

// App Theme Colors
class AppColors {
  static const teal = Color(0xFF000000); // Black
  static const darkGray = Color(0xFF2D3748);
  static const mediumGray = Color(0xFF718096);
  static const lightGray = Color(0xFFE2E8F0);
  static const white = Color(0xFFFFFFFF);
}

class MainApp extends StatefulWidget {
  final bool startLoggedIn;
  const MainApp({super.key, required this.startLoggedIn});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 8);

  Timer? _unreadPollTimer;
  bool _pollingUnread = false;
  int? _lastUnreadCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastUnreadCount = unreadNotifier.value;
    incomingMessageNotifierListener();
    _pollUnreadAndNotify();
    _unreadPollTimer = Timer.periodic(
      _pollInterval,
      (_) => _pollUnreadAndNotify(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    messageRealtimeService.incomingMessageNotifier.removeListener(
      _handleIncomingMessageNotification,
    );
    messageRealtimeService.stop();
    _unreadPollTimer?.cancel();
    super.dispose();
  }

  void incomingMessageNotifierListener() {
    messageRealtimeService.incomingMessageNotifier.addListener(
      _handleIncomingMessageNotification,
    );
    unawaited(messageRealtimeService.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(messageRealtimeService.start());
      unawaited(messageRealtimeService.refreshSubscriptions(forceResubscribe: true));
      unawaited(_pollUnreadAndNotify());
    }
  }

  void _handleIncomingMessageNotification() {
    final incoming = messageRealtimeService.incomingMessageNotifier.value;
    if (incoming == null) return;
    if (openConversationNotifier.value == incoming.conversationId) return;

    final messenger = appScaffoldMessengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.teal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        content: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            messenger.hideCurrentSnackBar();
            _openChatFromNotification();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.message_outlined,
                color: AppColors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  incoming.message.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Open',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pollUnreadAndNotify() async {
    if (_pollingUnread) return;
    _pollingUnread = true;
    try {
      final isLoggedIn = await authService.isLoggedIn();
      if (!isLoggedIn) {
        _pollingUnread = false;
        return;
      }

      unawaited(messageRealtimeService.start());

      final previous = _lastUnreadCount;
      final latest = await unreadService.refreshUnreadCount(
        fallbackCount: unreadNotifier.value,
        forceRefresh: true,
      );

      _lastUnreadCount = latest;
      messageRealtimeService.setServerUnreadCount(latest);

      final shouldNotify =
          previous != null &&
          latest > previous &&
          openConversationNotifier.value == null;

      if (shouldNotify) {
        final delta = latest - previous;
        final text = delta == 1
            ? 'You have a new message'
            : 'You have $delta new messages';
        final messenger = appScaffoldMessengerKey.currentState;
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.teal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            content: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                messenger.hideCurrentSnackBar();
                _openChatFromNotification();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.message_outlined,
                    color: AppColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Open',
                    style: TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (_) {
      // Ignore intermittent polling failures.
    }
    _pollingUnread = false;
  }

  void _openChatFromNotification() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushNamed('/chat');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tukwatagane',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          primary: AppColors.teal,
        ),
        scaffoldBackgroundColor: AppColors.lightGray,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      navigatorObservers: [routeObserver],
      home: widget.startLoggedIn ? const BrowseScreen() : const LoginScreen(),
      routes: {
        '/browse': (_) => const BrowseScreen(),
        '/search': (_) => const SearchScreen(),
        '/sell': (_) => const SellScreen(),
        '/chat': (_) => const ChatScreen(),
        '/account': (_) => const AccountScreen(),
      },
    );
  }
}
