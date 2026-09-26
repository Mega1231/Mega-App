import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/agora_call_service.dart';
import '../theme/app_theme.dart';
import '../views/common/call_screen.dart';
import '../views/common/incoming_call_screen.dart';

/// Wraps any screen to listen for incoming Agora calls.
/// Shows a WhatsApp-style notification banner at the top,
/// and the full incoming call screen on tap.
class IncomingCallListener extends StatefulWidget {
  final AppUser currentUser;
  final Widget child;

  const IncomingCallListener({
    super.key,
    required this.currentUser,
    required this.child,
  });

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener>
    with SingleTickerProviderStateMixin {
  final AgoraCallService _callService = AgoraCallService();
  StreamSubscription<CallInfo?>? _subscription;
  String? _lastHandledCallId;
  bool _isInCallScreen = false;

  // Banner state
  CallInfo? _currentCall;
  late AnimationController _bannerController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerController,
      curve: Curves.easeOutCubic,
    ));
    _startListening();
  }

  void _startListening() {
    _subscription = _callService
        .listenForIncomingCalls(widget.currentUser.uid)
        .listen((callInfo) {
      if (callInfo == null) {
        _dismissBanner();
        return;
      }
      if (callInfo.callId == _lastHandledCallId) return;
      if (_isInCallScreen) return;

      _lastHandledCallId = callInfo.callId;
      _showBanner(callInfo);
    });
  }

  void _showBanner(CallInfo callInfo) {
    setState(() => _currentCall = callInfo);
    _bannerController.forward();

    // Auto-dismiss after 30 seconds if not answered
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 30), () {
      _dismissBanner();
      // Mark as missed
      _callService.declineCall(callInfo.callId);
    });
  }

  void _dismissBanner() {
    _autoDismissTimer?.cancel();
    _bannerController.reverse().then((_) {
      if (mounted) setState(() => _currentCall = null);
    });
  }

  void _onAccept() {
    final call = _currentCall;
    if (call == null) return;

    _dismissBanner();
    _isInCallScreen = true;

    final callerUser = AppUser(
      uid: call.callerId,
      username: '',
      fullName: call.callerName,
      role: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          currentUser: widget.currentUser,
          otherUser: callerUser,
          callType: call.type,
          incomingCall: call,
        ),
      ),
    ).then((_) => _isInCallScreen = false);
  }

  void _onDecline() {
    final call = _currentCall;
    if (call == null) return;
    _callService.declineCall(call.callId);
    _dismissBanner();
  }

  void _onTapBanner() {
    final call = _currentCall;
    if (call == null) return;

    _dismissBanner();
    _isInCallScreen = true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          callInfo: call,
          currentUser: widget.currentUser,
        ),
      ),
    ).then((_) => _isInCallScreen = false);
  }

  @override
  void didUpdateWidget(IncomingCallListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.uid != widget.currentUser.uid) {
      _subscription?.cancel();
      _lastHandledCallId = null;
      _dismissBanner();
      _startListening();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _autoDismissTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // Incoming call banner overlay
        if (_currentCall != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              // Material ancestor prevents the yellow-underlined
              // "no material" text style in the overlay banner.
              child: Material(
                type: MaterialType.transparency,
                child: _IncomingCallBanner(
                  callInfo: _currentCall!,
                  onAccept: _onAccept,
                  onDecline: _onDecline,
                  onTap: _onTapBanner,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IncomingCallBanner extends StatelessWidget {
  final CallInfo callInfo;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTap;

  const _IncomingCallBanner({
    required this.callInfo,
    required this.onAccept,
    required this.onDecline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = callInfo.type == CallType.video;
    final topPadding = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(top: topPadding, left: 12, right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              child: Text(
                callInfo.callerName.isNotEmpty
                    ? callInfo.callerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name and type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    callInfo.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isVideo ? Icons.videocam : Icons.call,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isVideo
                            ? 'Incoming Video Call'
                            : 'Incoming Audio Call',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Decline button
            _CircleButton(
              icon: Icons.call_end,
              color: AppTheme.errorColor,
              onTap: onDecline,
            ),
            const SizedBox(width: 10),
            // Accept button
            _CircleButton(
              icon: isVideo ? Icons.videocam : Icons.call,
              color: AppTheme.successColor,
              onTap: onAccept,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
