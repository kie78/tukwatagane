import 'package:flutter/material.dart';

import '../api_exception.dart';
import '../../main.dart';

enum AppToastType { success, error, warning, info }

class AppToast {
  static const Duration _duration = Duration(seconds: 3);

  static void success(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.success);
  }

  static void error(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.error);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.warning);
  }

  static void info(BuildContext context, String message) {
    _show(context, message: message, type: AppToastType.info);
  }

  static void fromApiException(
    BuildContext context,
    ApiException exception, {
    String? fallbackMessage,
  }) {
    final msg = exception.message.trim().isNotEmpty
        ? exception.message
        : (fallbackMessage ?? 'Something went wrong. Please try again.');
    error(context, msg);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required AppToastType type,
  }) {
    if (message.trim().isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final style = _styleFor(type, AppColors.of(context));

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: style.background,
        duration: _duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(style.icon, color: style.foreground, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: style.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _ToastStyle _styleFor(AppToastType type, AppThemeColors c) {
    switch (type) {
      case AppToastType.success:
        return _ToastStyle(
          background: c.primary,
          foreground: c.white,
          icon: Icons.check_circle_outline,
        );
      case AppToastType.error:
        return _ToastStyle(
          background: c.primary,
          foreground: c.white,
          icon: Icons.error_outline,
        );
      case AppToastType.warning:
        return _ToastStyle(
          background: c.mediumGray,
          foreground: c.white,
          icon: Icons.warning_amber_rounded,
        );
      case AppToastType.info:
        return _ToastStyle(
          background: c.primary,
          foreground: c.white,
          icon: Icons.info_outline,
        );
    }
  }
}

class _ToastStyle {
  final Color background;
  final Color foreground;
  final IconData icon;

  const _ToastStyle({
    required this.background,
    required this.foreground,
    required this.icon,
  });
}
