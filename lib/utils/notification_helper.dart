import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // Using 'settings' as the named parameter based on your previous error logs
    await _notifications.initialize(settings: initSettings);
  }

  static Future<void> showSafetyAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'safe_sprout_alerts',
          'Safety Alerts',
          channelDescription: 'Critical safety notifications',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
