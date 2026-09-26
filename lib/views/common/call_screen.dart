import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/agora_call_service.dart';
import '../../theme/app_theme.dart';

class CallScreen extends StatefulWidget {
  final AppUser currentUser;
  final AppUser otherUser;
  final CallType callType;
  final CallInfo? incomingCall; // Non-null if answering an incoming call

  const CallScreen({
    super.key,
    required this.currentUser,
    required this.otherUser,
    required this.callType,
    this.incomingCall,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final AgoraCallService _callService = AgoraCallService();

  CallInfo? _callInfo;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  bool _isInitializing = true;
  String _statusText = 'Connecting...';
  String? _errorMessage;

  // Call timer
  Timer? _callTimer;
  int _callDurationSeconds = 0;

  @override
  void initState() {
    super.initState();
    _setupCall();
  }

  Future<void> _setupCall() async {
    try {
      // Setup callbacks
      _callService.onUserJoined = (remoteUid) {
        setState(() {
          _remoteUid = remoteUid;
          _isConnected = true;
          _statusText = 'Connected';
        });
        _startCallTimer();
      };

      _callService.onUserOffline = (remoteUid) {
        setState(() {
          _remoteUid = null;
          _isConnected = false;
          _statusText = 'Call ended';
        });
        _endCallAndPop();
      };

      _callService.onCallEnded = () {
        _endCallAndPop();
      };

      _callService.onError = (error) {
        setState(() => _errorMessage = error);
      };

      // Request permissions FIRST before doing anything
      final hasPermission =
          await _callService.requestPermissions(widget.callType);
      if (!hasPermission) {
        setState(() => _errorMessage =
            'Microphone${widget.callType == CallType.video ? ' and Camera' : ''} permission is required for calls.\n\nPlease enable it in Settings.');
        return;
      }

      if (widget.incomingCall != null) {
        // Answering an incoming call
        _callInfo = widget.incomingCall;
        await _callService.acceptCall(_callInfo!.callId);
        setState(() => _statusText = 'Connecting...');
      } else {
        // Starting an outgoing call
        setState(() => _statusText = 'Ringing...');
        _callInfo = await _callService.startCall(
          callerId: widget.currentUser.uid,
          callerName: widget.currentUser.fullName,
          receiverId: widget.otherUser.uid,
          receiverName: widget.otherUser.fullName,
          type: widget.callType,
        );
      }

      // Join the Agora channel
      await _callService.joinChannel(
        channelName: _callInfo!.channelName,
        type: widget.callType,
      );

      setState(() => _isInitializing = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isInitializing = false;
      });
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _callDurationSeconds++);
    });
  }

  String get _formattedDuration {
    final minutes =
        (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds =
        (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  bool _isEndingCall = false;

  Future<void> _endCallAndPop() async {
    if (_isEndingCall) return;
    _isEndingCall = true;

    _callTimer?.cancel();
    if (_callInfo != null) {
      try {
        await _callService.endCall(_callInfo!.callId);
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _callService.toggleMute(_isMuted);
  }

  Future<void> _toggleCamera() async {
    setState(() => _isCameraOff = !_isCameraOff);
    await _callService.toggleCamera(_isCameraOff);
  }

  Future<void> _switchCamera() async {
    await _callService.switchCamera();
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await _callService.toggleSpeaker(_isSpeakerOn);
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _callService.onUserJoined = null;
    _callService.onUserOffline = null;
    _callService.onCallEnded = null;
    _callService.onError = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Stack(
          children: [
            // Video views (only for video calls)
            if (widget.callType == CallType.video) _buildVideoViews(),

            // Local video preview (picture-in-picture)
            if (widget.callType == CallType.video && !_isCameraOff)
              _buildLocalVideoPreview(),

            // Audio call UI or video overlay
            if (widget.callType == CallType.audio || !_isConnected)
              _buildAudioCallUI(),

            // Bottom controls
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoViews() {
    return Column(
      children: [
        // Remote video (full screen)
        Expanded(
          child: _remoteUid != null && _callInfo != null
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _callService.engine,
                    canvas: VideoCanvas(uid: _remoteUid!),
                    connection:
                        RtcConnection(channelId: _callInfo!.channelName),
                  ),
                )
              : Center(
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 18,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLocalVideoPreview() {
    if (widget.callType != CallType.video || _isCameraOff) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 120,
          height: 160,
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _callService.engine,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioCallUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Avatar
          CircleAvatar(
            radius: 60,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            child: Text(
              widget.otherUser.fullName.isNotEmpty
                  ? widget.otherUser.fullName[0].toUpperCase()
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
            widget.otherUser.fullName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isConnected ? _formattedDuration : _statusText,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          if (_isInitializing) ...[
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white54),
          ],
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Duration (for video calls when connected)
          if (widget.callType == CallType.video && _isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _formattedDuration,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                _isMuted ? Icons.mic_off : Icons.mic,
                _isMuted ? 'Unmute' : 'Mute',
                _isMuted
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                _isMuted ? Colors.black : Colors.white,
                _toggleMute,
              ),
              if (widget.callType == CallType.video) ...[
                _buildControlButton(
                  _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  _isCameraOff ? 'Camera On' : 'Camera Off',
                  _isCameraOff
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2),
                  _isCameraOff ? Colors.black : Colors.white,
                  _toggleCamera,
                ),
                _buildControlButton(
                  Icons.cameraswitch,
                  'Flip',
                  Colors.white.withValues(alpha: 0.2),
                  Colors.white,
                  _switchCamera,
                ),
              ],
              _buildControlButton(
                _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                'Speaker',
                _isSpeakerOn
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                _isSpeakerOn ? Colors.black : Colors.white,
                _toggleSpeaker,
              ),
              _buildControlButton(
                Icons.call_end,
                'End',
                AppTheme.errorColor,
                Colors.white,
                _endCallAndPop,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 64),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
