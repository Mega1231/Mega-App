import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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

  /// Ask the backend to send a push for a chat message or incoming call.
  Future<void> sendPushNotification({
    required String receiverId,
    required String type, // 'call' or 'message'
    String? callId,
    String? chatId,
  }) async {
    try {
      final data = <String, String>{
        'receiverId': receiverId,
        'type': type,
      };
      if (callId != null) data['callId'] = callId;
      if (chatId != null) data['chatId'] = chatId;
      await FirebaseFunctions.instance
          .httpsCallable('sendPushNotification')
          .call(data);
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
