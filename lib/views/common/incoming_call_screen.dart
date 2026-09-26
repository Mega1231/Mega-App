import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/agora_call_service.dart';
import '../../theme/app_theme.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatelessWidget {
  final CallInfo callInfo;
  final AppUser currentUser;

  const IncomingCallScreen({
    super.key,
    required this.callInfo,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = callInfo.type == CallType.video;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Caller info
            CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              child: Text(
                callInfo.callerName.isNotEmpty
                    ? callInfo.callerName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              callInfo.callerName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            // Pulsing indicator
            _PulsingDot(),
            const Spacer(flex: 3),
            // Accept / Decline buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 60, left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  _buildCallButton(
                    icon: Icons.call_end,
                    label: 'Decline',
                    color: AppTheme.errorColor,
                    onTap: () async {
                      await AgoraCallService()
                          .declineCall(callInfo.callId);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  // Accept
                  _buildCallButton(
                    icon: isVideo ? Icons.videocam : Icons.call,
                    label: 'Accept',
                    color: AppTheme.successColor,
                    onTap: () {
                      // Create an AppUser from call info for the caller
                      final callerUser = AppUser(
                        uid: callInfo.callerId,
                        username: '',
                        fullName: callInfo.callerName,
                        role: '',
                      );

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(
                            currentUser: currentUser,
                            otherUser: callerUser,
                            callType: callInfo.type,
                            incomingCall: callInfo,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.successColor,
        ),
      ),
    );
  }
}
