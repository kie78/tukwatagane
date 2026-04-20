import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
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
final ValueNotifier<int?> pendingProductDeepLinkNotifier = ValueNotifier<int?>(
  null,
);
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.light,
);

/// Per-conversation last-visit timestamp. Seeded on first chat-list load.
/// Updated whenever the user opens an inbox screen.
final Map<int, DateTime> conversationVisitedAt = {};

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

const _themeStorageKey = 'theme_mode';

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  const storage = FlutterSecureStorage();
  await storage.write(
    key: _themeStorageKey,
    value: mode == ThemeMode.dark ? 'dark' : 'light',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  const storage = FlutterSecureStorage();
  final savedTheme = await storage.read(key: _themeStorageKey);
  if (savedTheme == 'dark') themeModeNotifier.value = ThemeMode.dark;
  final loggedIn = await authService.isLoggedIn();
  runApp(MainApp(startLoggedIn: loggedIn));
}

// App Theme Colors
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.primary,
    required this.accent,
    required this.darkGray,
    required this.mediumGray,
    required this.lightGray,
    required this.white,
  });

  final Color primary;
  final Color accent;
  final Color darkGray;
  final Color mediumGray;
  final Color lightGray;
  final Color white;

  static const light = AppThemeColors(
    primary: Color(0xFF000000),
    accent: Color(0xFF000000),
    darkGray: Color(0xFF2D3748),
    mediumGray: Color(0xFF718096),
    lightGray: Color(0xFFE2E8F0),
    white: Color(0xFFFFFFFF),
  );

  static const dark = AppThemeColors(
    primary: Color(0xFFFFFFFF),
    accent: Color(0xFFFFFFFF),
    darkGray: Color(0xFFE2E8F0),
    mediumGray: Color(0xFF718096),
    lightGray: Color(0xFF1A202C),
    white: Color(0xFF3D4D61),
  );

  static AppThemeColors of(BuildContext context) =>
      Theme.of(context).extension<AppThemeColors>()!;

  @override
  AppThemeColors copyWith({
    Color? primary,
    Color? accent,
    Color? darkGray,
    Color? mediumGray,
    Color? lightGray,
    Color? white,
  }) {
    return AppThemeColors(
      primary: primary ?? this.primary,
      accent: accent ?? this.accent,
      darkGray: darkGray ?? this.darkGray,
      mediumGray: mediumGray ?? this.mediumGray,
      lightGray: lightGray ?? this.lightGray,
      white: white ?? this.white,
    );
  }

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      darkGray: Color.lerp(darkGray, other.darkGray, t)!,
      mediumGray: Color.lerp(mediumGray, other.mediumGray, t)!,
      lightGray: Color.lerp(lightGray, other.lightGray, t)!,
      white: Color.lerp(white, other.white, t)!,
    );
  }
}

class AppColors {
  static AppThemeColors of(BuildContext context) => AppThemeColors.of(context);
}

class MainApp extends StatefulWidget {
  final bool startLoggedIn;
  const MainApp({super.key, required this.startLoggedIn});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 8);

  static final _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppThemeColors.light.primary,
      primary: AppThemeColors.light.primary,
    ),
    scaffoldBackgroundColor: AppThemeColors.light.lightGray,
    appBarTheme: AppBarTheme(
      backgroundColor: AppThemeColors.light.white,
      elevation: 0,
    ),
    textTheme: GoogleFonts.nunitoTextTheme(),
    extensions: const [AppThemeColors.light],
    useMaterial3: true,
  );

  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppThemeColors.dark.primary,
      primary: AppThemeColors.dark.primary,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: AppThemeColors.dark.lightGray,
    appBarTheme: AppBarTheme(
      backgroundColor: AppThemeColors.dark.white,
      elevation: 0,
    ),
    textTheme: GoogleFonts.nunitoTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    extensions: const [AppThemeColors.dark],
    useMaterial3: true,
  );
  static const Duration _popupDuration = Duration(seconds: 4);

  Timer? _unreadPollTimer;
  Timer? _popupDismissTimer;
  StreamSubscription<Uri>? _deepLinkSubscription;
  bool _pollingUnread = false;
  int? _lastUnreadCount;
  OverlayEntry? _messagePopupEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastUnreadCount = unreadNotifier.value;
    incomingMessageNotifierListener();
    _startDeepLinkHandling();
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
    _deepLinkSubscription?.cancel();
    _popupDismissTimer?.cancel();
    _removeMessagePopup();
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

  Future<void> _startDeepLinkHandling() async {
    final appLinks = AppLinks();

    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLinkUri(initialUri);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MainApp._startDeepLinkHandling] Initial link failed: $e');
      }
    }

    _deepLinkSubscription = appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleDeepLinkUri(uri)),
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('[MainApp._startDeepLinkHandling] Stream failed: $error');
        }
      },
    );
  }

  Future<void> _handleDeepLinkUri(Uri uri) async {
    final listingId = _extractProductListingId(uri);
    if (listingId == null) return;

    pendingProductDeepLinkNotifier.value = listingId;

    final loggedIn = await authService.isLoggedIn();
    if (!loggedIn || !mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BrowseScreen()),
        (route) => false,
      );
    });
  }

  int? _extractProductListingId(Uri uri) {
    if (uri.scheme.toLowerCase() != 'tukwatagane') return null;

    final pathSegments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (uri.host == 'product' && pathSegments.isNotEmpty) {
      return int.tryParse(pathSegments.first);
    }

    if (pathSegments.length >= 2 && pathSegments.first == 'product') {
      return int.tryParse(pathSegments[1]);
    }

    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(messageRealtimeService.start());
      unawaited(
        messageRealtimeService.refreshSubscriptions(forceResubscribe: true),
      );
      unawaited(_pollUnreadAndNotify());
    }
  }

  void _handleIncomingMessageNotification() {
    final incoming = messageRealtimeService.incomingMessageNotifier.value;
    if (incoming == null) return;
    if (openConversationNotifier.value == incoming.conversationId) return;

    _showTopMessagePopup(
      senderName: incoming.senderName,
      senderAvatarUrl: incoming.senderAvatarUrl,
      messageText: incoming.message.body,
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
        _showTopMessagePopup(
          senderName: 'Messages',
          senderAvatarUrl: null,
          messageText: text,
        );
      }
    } catch (_) {
      // Ignore intermittent polling failures.
    }
    _pollingUnread = false;
  }

  void _openChatFromNotification() {
    _removeMessagePopup();
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushNamed('/chat');
  }

  void _showTopMessagePopup({
    required String senderName,
    required String? senderAvatarUrl,
    required String messageText,
  }) {
    final navigator = appNavigatorKey.currentState;
    final overlay = navigator?.overlay;
    if (overlay == null) return;

    _popupDismissTimer?.cancel();
    _removeMessagePopup();

    _messagePopupEntry = OverlayEntry(
      builder: (context) {
        final c = AppColors.of(context);
        final topPadding = MediaQuery.of(context).padding.top;
        return Positioned(
          top: topPadding + 12,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openChatFromNotification,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    (senderAvatarUrl?.trim().isNotEmpty == true)
                        ? CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(senderAvatarUrl!),
                            backgroundColor: c.white,
                          )
                        : CircleAvatar(
                            radius: 18,
                            backgroundColor: c.white,
                            child: Text(
                              senderName.trim().isNotEmpty
                                  ? senderName.trim()[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: c.darkGray,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            messageText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_messagePopupEntry!);
    _popupDismissTimer = Timer(_popupDuration, _removeMessagePopup);
  }

  void _removeMessagePopup() {
    _messagePopupEntry?.remove();
    _messagePopupEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeModeNotifier,
      builder: (_, __) => MaterialApp(
        title: 'Tukwatagane',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        themeMode: themeModeNotifier.value,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        navigatorObservers: [routeObserver],
        home: widget.startLoggedIn ? const BrowseScreen() : const LoginScreen(),
        routes: {
          '/browse': (_) => const BrowseScreen(),
          '/search': (_) => const SearchScreen(),
          '/sell': (_) => const SellScreen(),
          '/chat': (_) => const ChatScreen(),
          '/account': (_) => const AccountScreen(),
        },
      ),
    );
  }
}
