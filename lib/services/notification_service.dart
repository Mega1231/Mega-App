import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cached OAuth2 access token for FCM V1 API
  AccessCredentials? _credentials;

  // Callback when user taps a notification
  void Function(String type, String? callId, String? chatId)? onNotificationTap;

  /// Initialize local notifications and FCM foreground handling
  Future<void> initialize() async {
    // Android notification channels
    const androidChannel = AndroidNotificationChannel(
      'calls_channel',
      'Calls',
      description: 'Incoming call notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const messageChannel = AndroidNotificationChannel(
      'messages_channel',
      'Messages',
      description: 'Chat message notifications',
      importance: Importance.high,
      playSound: true,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);
    await androidPlugin?.createNotificationChannel(messageChannel);

    // Initialize local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Show system banners for FCM notifications while app is in foreground (iOS)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle FCM messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Check if app was opened from a terminated state notification
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  /// Handle foreground FCM message — show a local notification
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    if (notification == null) return;

    final type = data['type'] ?? 'message';
    final isCall = type == 'call';

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isCall ? 'calls_channel' : 'messages_channel',
          isCall ? 'Calls' : 'Messages',
          importance: isCall ? Importance.max : Importance.high,
          priority: isCall ? Priority.max : Priority.high,
          fullScreenIntent: isCall,
          category: isCall
              ? AndroidNotificationCategory.call
              : AndroidNotificationCategory.message,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    onNotificationTap?.call(
      data['type'] ?? 'message',
      data['callId'],
      data['chatId'],
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    onNotificationTap?.call(
      data['type'] ?? 'message',
      data['callId'],
      data['chatId'],
    );
  }

  /// Get OAuth2 access token for FCM V1 API using service account
  Future<String?> _getAccessToken() async {
    try {
      // Return cached token if still valid
      if (_credentials != null &&
          _credentials!.accessToken.expiry
              .isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        return _credentials!.accessToken.data;
      }

      final serviceAccountJson =
          await rootBundle.loadString('service-account.json');
      final serviceAccount =
          ServiceAccountCredentials.fromJson(serviceAccountJson);

      final client = http.Client();
      _credentials = await obtainAccessCredentialsViaServiceAccount(
        serviceAccount,
        ['https://www.googleapis.com/auth/firebase.messaging'],
        client,
      );
      client.close();

      return _credentials!.accessToken.data;
    } catch (_) {
      return null;
    }
  }

  /// Send a push notification using FCM V1 API
  Future<void> sendPushNotification({
    required String receiverId,
    required String title,
    required String body,
    required String type, // 'call' or 'message'
    String? callId,
    String? chatId,
  }) async {
    try {
      // Get the receiver's FCM token from Firestore
      final userDoc =
          await _firestore.collection('users').doc(receiverId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) return;

      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      // Get project ID from service account
      final serviceAccountJson =
          await rootBundle.loadString('service-account.json');
      final projectId =
          jsonDecode(serviceAccountJson)['project_id'] as String;

      await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'type': type,
              'callId': callId ?? '',
              'chatId': chatId ?? '',
            },
            'android': {
              'priority': 'HIGH',
              'notification': {
                'channel_id':
                    type == 'call' ? 'calls_channel' : 'messages_channel',
                'sound': 'default',
              },
            },
            'apns': {
              'payload': {
                'aps': {
                  'sound': 'default',
                  'badge': 1,
                },
              },
            },
          },
        }),
      );
    } catch (_) {
      // Silently fail — push notification is best-effort
    }
  }
}

/// Top-level function for FCM background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled automatically by the system tray.
}
