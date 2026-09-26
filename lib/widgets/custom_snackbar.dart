import 'dart:async';
import 'package:flutter/material.dart';

class CustomSnackbar {
  static OverlayEntry? _topEntry;
  static Timer? _topTimer;

  static void show({
    required BuildContext context,
    required String message,
    Color backgroundColor = Colors.black,
    Color textColor = Colors.white,
    IconData? icon,
    Color iconColor = Colors.white,
    Duration duration = const Duration(seconds: 3),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    double borderRadius = 12,
    EdgeInsetsGeometry margin = const EdgeInsets.all(16),
    bool showFromTop = false,
  }) {
    if (showFromTop) {
      // Use an overlay for top-positioned snackbars. Faking it with a huge
      // bottom margin causes "Floating SnackBar presented off screen"
      // assertions on scaffolds with bottom navigation bars.
      _showTopOverlay(
        context: context,
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        icon: icon,
        iconColor: iconColor,
        duration: duration,
        borderRadius: borderRadius,
      );
      return;
    }

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        behavior: behavior,
        margin: margin,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        content: _buildContent(message, textColor, icon, iconColor),
      ),
    );
  }

  static Widget _buildContent(
    String message,
    Color textColor,
    IconData? icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  static void _showTopOverlay({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required Color textColor,
    required IconData? icon,
    required Color iconColor,
    required Duration duration,
    required double borderRadius,
  }) {
    _removeTopOverlay();

    final overlay = Overlay.of(context, rootOverlay: true);
    final topPadding = MediaQuery.of(context).padding.top;

    final entry = OverlayEntry(
      builder: (_) => Positioned(
        top: topPadding + 30,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildContent(message, textColor, icon, iconColor),
          ),
        ),
      ),
    );

    _topEntry = entry;
    overlay.insert(entry);

    _topTimer = Timer(duration, _removeTopOverlay);
  }

  static void _removeTopOverlay() {
    _topTimer?.cancel();
    _topTimer = null;
    _topEntry?.remove();
    _topEntry = null;
  }

  static void success({
    required BuildContext context,
    required String message,
    bool showFromTop = false,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
      showFromTop: showFromTop,
    );
  }

  static void error({
    required BuildContext context,
    required String message,
    bool showFromTop = false,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.red,
      icon: Icons.error,
      showFromTop: showFromTop,
    );
  }

  static void warning({
    required BuildContext context,
    required String message,
    bool showFromTop = false,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.orange,
      icon: Icons.warning,
      showFromTop: showFromTop,
    );
  }

  static void info({
    required BuildContext context,
    required String message,
    bool showFromTop = false,
  }) {
    show(
      context: context,
      message: message,
      backgroundColor: Colors.blue,
      icon: Icons.info,
      showFromTop: showFromTop,
    );
  }
}
