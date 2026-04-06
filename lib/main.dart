import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'home_page.dart';
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';
import 'services/fake_call_service.dart';

// MUST be top-level for background execution
@pragma('vm:entry-point')
Future<void> backgroundCallback(int id) async {
  debugPrint('🔔 Background alarm triggered! ID: $id');

  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final name = prefs.getString('fake_call_name_$id') ?? 'Unknown';
  final phone = prefs.getString('fake_call_phone_$id') ?? '';

  debugPrint('📞 Fake Call: $name ($phone)');

  final notifications = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();

  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  // ✅ FIX: Use 'settings' named parameter
  await notifications.initialize(settings: initSettings);

  await notifications.show(
    id: 0,
    title: '📞 $name is calling...',
    body: 'Tap to answer the fake call',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'fake_call_channel',
        'Fake Call Notifications',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // ✅ FIX 1: Use 'settings' named parameter here too
  await notificationsPlugin.initialize(settings: initializationSettings);

  // ✅ FIX 2: Create Channel properly for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'danger_zone_channel',
    'Danger Zone Alerts',
    description: 'Critical safety warnings',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  // Check if running on Android before creating channel
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await dotenv.load(fileName: ".env");
  await AndroidAlarmManager.initialize();
  await FakeCallService().initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Safe Sprout',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const HomePage(),
        );
      },
    );
  }
}
