import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';

enum CallType { audio, video }

enum CallStatus { ringing, accepted, declined, ended, missed }

class CallInfo {
  final String callId;
  final String channelName;
  final String callerId;
  final String callerName;
  final String receiverId;
  final String receiverName;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;

  CallInfo({
    required this.callId,
    required this.channelName,
    required this.callerId,
    required this.callerName,
    required this.receiverId,
    required this.receiverName,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'callId': callId,
        'channelName': channelName,
        'callerId': callerId,
        'callerName': callerName,
        'receiverId': receiverId,
        'receiverName': receiverName,
        'type': type == CallType.video ? 'video' : 'audio',
        'status': status.name,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory CallInfo.fromMap(Map<String, dynamic> map) => CallInfo(
        callId: map['callId'] ?? '',
        channelName: map['channelName'] ?? '',
        callerId: map['callerId'] ?? '',
        callerName: map['callerName'] ?? '',
        receiverId: map['receiverId'] ?? '',
        receiverName: map['receiverName'] ?? '',
        type: map['type'] == 'video' ? CallType.video : CallType.audio,
        status: CallStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => CallStatus.ended,
        ),
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

class AgoraCallService {
  static final AgoraCallService _instance = AgoraCallService._internal();
  factory AgoraCallService() => _instance;
  AgoraCallService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late RtcEngine _engine;
  RtcEngine get engine => _engine;
  bool _isEngineInitialized = false;

  String get appId => dotenv.env['AGORA_APP_ID'] ?? '';

  // Callbacks for UI updates
  void Function(int remoteUid)? onUserJoined;
  void Function(int remoteUid)? onUserOffline;
  void Function()? onCallEnded;
  void Function(String error)? onError;

  StreamSubscription<DocumentSnapshot>? _callListener;

  /// Initialize the Agora engine
  Future<void> initialize() async {
    if (_isEngineInitialized) return;

    if (appId.isEmpty) {
      throw Exception('AGORA_APP_ID is not set in .env file');
    }

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _registerEventHandlers();
    _isEngineInitialized = true;
  }

  void _registerEventHandlers() {
    _engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        // Successfully joined channel
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        onUserJoined?.call(remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid,
          UserOfflineReasonType reason) {
        onUserOffline?.call(remoteUid);
        if (reason == UserOfflineReasonType.userOfflineDropped ||
            reason == UserOfflineReasonType.userOfflineQuit) {
          onCallEnded?.call();
        }
      },
      onError: (ErrorCodeType err, String msg) {
        onError?.call('Agora error: $msg ($err)');
      },
    ));
  }

  /// Request microphone and camera permissions
  Future<bool> requestPermissions(CallType type) async {
    final permissions = <Permission>[Permission.microphone];
    if (type == CallType.video) {
      permissions.add(Permission.camera);
    }

    final statuses = await permissions.request();

    for (final entry in statuses.entries) {
      if (entry.value.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      if (!entry.value.isGranted) {
        return false;
      }
    }

    return true;
  }

  /// Generate a unique channel name for two users (max 64 chars for Agora)
  String _generateChannelName(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Use first 8 chars of each UID + timestamp to stay under 64 chars
    return '${sorted[0].substring(0, 8)}_${sorted[1].substring(0, 8)}_$timestamp';
  }

  /// Start an outgoing call
  Future<CallInfo> startCall({
    required String callerId,
    required String callerName,
    required String receiverId,
    required String receiverName,
    required CallType type,
  }) async {
    await initialize();

    final hasPermission = await requestPermissions(type);
    if (!hasPermission) {
      throw Exception('Required permissions not granted');
    }

    final channelName = _generateChannelName(callerId, receiverId);
    final callId = _firestore.collection('calls').doc().id;

    final callInfo = CallInfo(
      callId: callId,
      channelName: channelName,
      callerId: callerId,
      callerName: callerName,
      receiverId: receiverId,
      receiverName: receiverName,
      type: type,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    );

    // Save call document to Firestore (acts as signaling)
    await _firestore.collection('calls').doc(callId).set(callInfo.toMap());

    // Send push notification to receiver
    NotificationService().sendPushNotification(
      receiverId: receiverId,
      title: callerName,
      body: type == CallType.video
          ? 'Incoming Video Call'
          : 'Incoming Audio Call',
      type: 'call',
      callId: callId,
    );

    // Listen for call status changes (receiver accepting/declining)
    _listenToCallStatus(callId);

    return callInfo;
  }

  /// Join a channel (used by both caller and receiver after call is accepted)
  Future<void> joinChannel({
    required String channelName,
    required CallType type,
    String? token, // Token from your backend; null uses temp token (dev only)
  }) async {
    await initialize();

    if (type == CallType.video) {
      await _engine.enableVideo();
      await _engine.startPreview();
    } else {
      await _engine.disableVideo();
    }

    await _engine.joinChannel(
      token: token ?? '',  // Empty string = no token (testing only)
      channelId: channelName,
      uid: 0, // Let Agora assign UID
      options: ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: type == CallType.video,
        publishMicrophoneTrack: true,
        publishCameraTrack: type == CallType.video,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  /// Accept an incoming call
  Future<void> acceptCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': CallStatus.accepted.name,
    });
  }

  /// Decline an incoming call
  Future<void> declineCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': CallStatus.declined.name,
    });
  }

  bool _isLeavingCall = false;

  /// End an active call
  Future<void> endCall(String callId) async {
    if (_isLeavingCall) return;
    _isLeavingCall = true;

    _callListener?.cancel();
    _callListener = null;

    try {
      if (_isEngineInitialized) {
        await _engine.leaveChannel();
      }
    } catch (_) {}

    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': CallStatus.ended.name,
      });
    } catch (_) {}

    _isLeavingCall = false;
  }

  /// Listen for incoming calls for a specific user
  Stream<CallInfo?> listenForIncomingCalls(String userId) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return CallInfo.fromMap(snapshot.docs.first.data());
    });
  }

  /// Listen to call status changes (for the caller)
  void _listenToCallStatus(String callId) {
    _callListener?.cancel();
    _callListener = _firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final status = CallStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => CallStatus.ended,
      );

      if (status == CallStatus.declined || status == CallStatus.ended) {
        onCallEnded?.call();
      }
    });
  }

  // ---- In-call controls ----

  Future<void> toggleMute(bool muted) async {
    await _engine.muteLocalAudioStream(muted);
  }

  Future<void> toggleCamera(bool disabled) async {
    await _engine.muteLocalVideoStream(disabled);
  }

  Future<void> switchCamera() async {
    await _engine.switchCamera();
  }

  Future<void> toggleSpeaker(bool speakerOn) async {
    await _engine.setEnableSpeakerphone(speakerOn);
  }

  /// Dispose engine resources
  Future<void> dispose() async {
    _callListener?.cancel();
    if (_isEngineInitialized) {
      await _engine.leaveChannel();
      await _engine.release();
      _isEngineInitialized = false;
    }
  }
}
