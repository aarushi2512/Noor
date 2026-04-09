import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'home_page.dart';
import 'theme/theme_provider.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'providers/auth_provider.dart';
import 'services/fake_call_service.dart';

// MUST be top-level for background execution
@pragma('vm:entry-point')
Future<void> backgroundCallback(int id) async {
  debugPrint('🔔 Background alarm triggered! ID: $id');

  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Firebase for background tasks (optional but safe)
  await Firebase.initializeApp();

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
  // ✅ 1. Initialize Flutter bindings FIRST
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ 2. Initialize Firebase BEFORE anything else
  await Firebase.initializeApp();
  
  // ✅ 3. Initialize other services
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

  await notificationsPlugin.initialize(settings: initializationSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'danger_zone_channel',
    'Danger Zone Alerts',
    description: 'Critical safety warnings',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await dotenv.load(fileName: ".env");
  await AndroidAlarmManager.initialize();
  await FakeCallService().initialize();

  // ✅ 4. NOW run the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
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
          title: 'Noor - Women Safety',
          
          // ✅ Use your ThemeProvider's logic for themes
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B1A5D),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF8B1A5D),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: themeProvider.isDarkMode 
              ? ThemeMode.dark 
              : ThemeMode.light,
          
          debugShowCheckedModeBanner: false,
          home: const HomePage(),
        );
      },
    );
  }
}