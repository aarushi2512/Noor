import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:noor_new/screens/mapbox_safe_route.dart';
import 'package:noor_new/screens/fake_call_setup.dart';
import 'package:noor_new/widgets/animated_bottom_nav.dart';
import 'package:noor_new/widgets/emergency_card.dart';
import 'package:noor_new/widgets/danger_zone_alert.dart';
import 'package:noor_new/news_page.dart';
import 'package:noor_new/circle_page.dart';
import 'package:noor_new/profile_page.dart';
import 'package:noor_new/services/offline_risk_service.dart';
import 'package:noor_new/services/sos_service.dart';
import 'package:noor_new/services/forecast_service.dart';
import 'package:noor_new/models/risk_forecast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:battery_plus/battery_plus.dart';
import 'dart:async';
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePageContent(),
    const NewsPage(),
    const CirclePage(),
    const ProfilePage(),
  ];

  final List<NavItem> _navItems = [
    NavItem(
      icon: CupertinoIcons.house,
      activeIcon: CupertinoIcons.house_fill,
      label: 'Home',
    ),
    NavItem(
      icon: CupertinoIcons.compass,
      activeIcon: CupertinoIcons.compass_fill,
      label: 'Explore',
    ),
    NavItem(
      icon: CupertinoIcons.person_2,
      activeIcon: CupertinoIcons.person_2_fill,
      label: 'Circle',
    ),
    NavItem(
      icon: CupertinoIcons.person,
      activeIcon: CupertinoIcons.person_fill,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          const SizedBox(height: 100),
          AnimatedBottomNav(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: _navItems,
            glassColor: Colors.white,
            blurSigma: 15.0,
            activeColor: const Color(0xFFFF6B6B),
            inactiveColor: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final OfflineRiskService _riskService = OfflineRiskService();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final Battery _battery = Battery();

  bool _showDangerAlert = false;
  Map<String, dynamic>? _currentDangerData;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<BatteryState>? _batterySubscription;
  bool _isMonitoring = false;
  DateTime? _alertCooldownUntil;
  bool _lowBatterySossent = false;

  @override
  void initState() {
    super.initState();
    _riskService.initialize();
    _requestNotificationPermission();
    _startDangerZoneMonitoring();
    _startBatteryMonitoring();
  }

  Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _batterySubscription?.cancel();
    super.dispose();
  }

  void _startBatteryMonitoring() {
    _batterySubscription = _battery.onBatteryStateChanged.listen((
      BatteryState state,
    ) async {
      final int level = await _battery.batteryLevel;
      if (level <= 15 && !_lowBatterySossent) {
        _triggerLowBatterySOS();
      }
    });
  }

  Future<void> _triggerLowBatterySOS() async {
    debugPrint('⚠️ LOW BATTERY DETECTED! Triggering Auto-SOS...');
    _lowBatterySossent = true;

    try {
      // ✅ Check if SOS Service has contacts before proceeding
      // Assuming SOSService has a way to check contacts.
      // If your SOSService doesn't have this, we rely on the exception catch below.

      const LocationSettings settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      String locationLink =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';

      await SOSService.sendSOSSMS(locationLink);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'danger_zone_channel',
            'Danger Zone Alerts',
            importance: Importance.max,
            priority: Priority.high,
          );
      await _notificationsPlugin.show(
        id: 99,
        title: '🔋 Low Battery SOS Sent',
        body: 'Your location has been sent to emergency contacts.',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      _lowBatterySossent = false; // Reset so it can try again later if needed
      debugPrint('❌ Failed to send Low Battery SOS: $e');

      // ✅ Specific handling for "No Contacts" scenario if the exception message contains it
      if (e.toString().contains('contact') || e.toString().contains('empty')) {
        // Cannot show SnackBar here easily as this runs in background/listener
        // But we log it. In a real app, you might store a "failed SOS" flag to show on next open.
        debugPrint(
          '⚠️ SOS Failed: No trusted contacts found. Please add contacts in Profile.',
        );
      }
    }
  }

  void _startDangerZoneMonitoring() async {
    if (_isMonitoring) return;
    _isMonitoring = true;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (_showDangerAlert) return;
            if (_alertCooldownUntil != null &&
                DateTime.now().isBefore(_alertCooldownUntil!))
              return;

            final result = _riskService.checkDangerZone(
              position.latitude,
              position.longitude,
            );

            if (result['isDanger'] == true) {
              debugPrint('🚨 DANGER ZONE ENTERED: ${result['level']}');
              setState(() {
                _currentDangerData = result;
                _showDangerAlert = true;
              });
              _showDangerNotification(result);
            }
          },
        );
  }

  Future<void> _showDangerNotification(Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'danger_zone_channel',
          'Danger Zone Alerts',
          channelDescription: 'Critical safety warnings',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'Safety Alert',
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: 0,
        title: '⚠️ ${data['level']} RISK DETECTED!',
        body: data['message'],
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('❌ Notification Error: $e');
    }
  }

  Future<String> _getCurrentLocationName() async {
    try {
      const LocationSettings settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      );
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String area = place.subLocality ?? place.locality ?? "Unknown Area";
        String city = place.administrativeArea ?? "Mumbai";
        final Map<String, String> hindiToEnglish = {
          'कांदिवली': 'Kandivali',
          'अंधेरी': 'Andheri',
          'बोरीवली': 'Borivali',
          'दादर': 'Dadar',
          'बांद्रा': 'Bandra',
          'घाटकोपर': 'Ghatkopar',
          'ठाणे': 'Thane',
          'कुर्ला': 'Kurla',
          'जोगेश्वरी': 'Jogeshwari',
          'गोरेगांव': 'Goregaon',
          'मालाड': 'Malad',
          'विरार': 'Virar',
        };
        for (var key in hindiToEnglish.keys) {
          if (area.contains(key)) {
            area = hindiToEnglish[key]!;
            break;
          }
          if (city.contains(key)) {
            city = hindiToEnglish[key]!;
            break;
          }
        }
        return "$area, $city";
      }
    } catch (e) {
      debugPrint('❌ Location error: $e');
    }
    return "Mumbai, India";
  }

  // ✅ IMPROVED SOS LOGIC
  Future<void> _callSOS(BuildContext context) async {
    try {
      // ✅ Step 1: Try to send SOS
      String? locationLink;
      try {
        const LocationSettings settings = LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        );
        final position = await Geolocator.getCurrentPosition(
          locationSettings: settings,
        );
        locationLink =
            'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      } catch (e) {
        debugPrint('⚠️ Location not available for SOS: $e');
      }

      await SOSService.sendSOSSMS(locationLink);

      // ✅ Success Message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('🚨 SOS alert sent to trusted contacts!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      // ✅ Enhanced Error Handling
      String errorMessage = 'SOS failed: ${e.toString()}';
      Color errorColor = Colors.red;
      IconData errorIcon = Icons.error_outline;

      // ✅ Check for specific "No Contacts" error
      if (e.toString().toLowerCase().contains('contact') ||
          e.toString().toLowerCase().contains('empty') ||
          e.toString().toLowerCase().contains('null')) {
        errorMessage =
            'No trusted contacts found! Please add contacts in your Profile first.';
        errorColor = Colors.orange;
        errorIcon = Icons.person_add_disabled;

        // ✅ Show Action Button to go to Profile
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(errorIcon, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: errorColor,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              action: SnackBarAction(
                label: 'Go to Profile',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to Profile Page (Index 3 in your nav)
                  // You might need to expose a method in HomePage to change index
                  // For now, we just show the message.
                  // Ideally: Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                },
              ),
            ),
          );
        }
      } else {
        // ✅ Generic Error
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(errorIcon, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: errorColor,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  Future<List<Widget>> _loadEmergencyCards(BuildContext context) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/emergency_card.json',
      );
      final List<dynamic> jsonData = jsonDecode(jsonString);

      if (jsonData.isEmpty) {
        return [];
      }

      return jsonData.map((cardData) {
        return EmergencyCard(
          context: context,
          title: cardData['title'],
          subtitle: cardData['subtitle'],
          phoneNumber: cardData['phoneNumber'],
          icon: cardData['icon'],
          lightColors: (cardData['lightColors'] as List)
              .map((c) => Color(int.parse(c.substring(1), radix: 16)))
              .toList(),
          darkColors: (cardData['darkColors'] as List)
              .map((c) => Color(int.parse(c.substring(1), radix: 16)))
              .toList(),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error loading emergency cards: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color sosButtonColor = isDark
        ? const Color(0xFFC24A4A)
        : const Color(0xFFD05A5A);

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Help',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  clipBehavior: Clip.none,
                  height: 178,
                  child: FutureBuilder<List<Widget>>(
                    future: _loadEmergencyCards(context),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const Center(child: CircularProgressIndicator());

                      if (snapshot.hasError)
                        return Center(
                          child: Text(
                            'Error loading contacts',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        );

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        // ✅ IMPROVED EMPTY STATE
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.contact_phone_outlined,
                                size: 48,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No emergency contacts',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  // Navigate to Profile to add contacts
                                  // Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Go to Profile tab to add trusted contacts',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Contacts'),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView(
                        scrollDirection: Axis.horizontal,
                        children: snapshot.data!,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 48),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _callSOS(context);
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('SOS Help'),
                              content: const Text(
                                'Tap to send your live location to your trusted contacts immediately. Make sure you have added contacts in your Profile first.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Got it'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sosButtonColor,
                            boxShadow: [
                              BoxShadow(
                                color: sosButtonColor.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.exclamationmark_triangle_fill,
                                color: Colors.white,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'SOS',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap for emergency alert',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FakeCallSetup(),
                            ),
                          );
                        },
                        child: Container(
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? const Color(0xFF2D5A2D)
                                : const Color(0xFF4A7C4A),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isDark
                                            ? const Color(0xFF2D5A2D)
                                            : const Color(0xFF4A7C4A))
                                        .withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_callback_rounded,
                                color: Colors.white,
                                size: 48,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Fake Call',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Schedule fake call',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  '🌦️ Safety & Weather Dashboard',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<String>(
                  future: _getCurrentLocationName(),
                  builder: (context, locSnapshot) {
                    if (locSnapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    final locationName = locSnapshot.data ?? "Mumbai, India";
                    return FutureBuilder(
                      future: Future.delayed(
                        const Duration(milliseconds: 500),
                        () => ForecastService.getForecastForLocation(
                          locationName,
                          0.45,
                        ),
                      ),
                      builder: (context, forecastSnapshot) {
                        if (forecastSnapshot.connectionState ==
                            ConnectionState.waiting)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        if (!forecastSnapshot.hasData ||
                            (forecastSnapshot.data as List).isEmpty)
                          return const SizedBox.shrink();
                        final forecasts =
                            forecastSnapshot.data as List<RiskForecast>;
                        final current = forecasts.first;
                        final next = forecasts.length > 1 ? forecasts[1] : null;
                        final color = Color(int.parse(current.colorHex));
                        return _buildUnifiedForecastCard(
                          context: context,
                          current: current,
                          next: next,
                          primaryColor: color,
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        if (_showDangerAlert && _currentDangerData != null)
          DangerZoneAlert(
            level: _currentDangerData!['level'],
            message: _currentDangerData!['message'],
            tip: _currentDangerData!['tip'],
            onSafe: () {
              setState(() {
                _alertCooldownUntil = DateTime.now().add(
                  const Duration(seconds: 60),
                );
                _showDangerAlert = false;
                _currentDangerData = null;
              });
            },
            onSOS: () {
              _callSOS(context);
              setState(() {
                _alertCooldownUntil = DateTime.now().add(
                  const Duration(seconds: 180),
                );
                _showDangerAlert = false;
              });
            },
          ),
      ],
    );
  }

  Widget _buildUnifiedForecastCard({
    required BuildContext context,
    required RiskForecast current,
    RiskForecast? next,
    required Color primaryColor,
  }) {
    String weatherImpactTitle = "Weather Impact";
    String weatherImpactMessage = "";
    IconData weatherImpactIcon = Icons.cloud_sync;
    Color impactColor = Colors.blue;

    if (current.weatherCondition.contains("Rain")) {
      weatherImpactMessage =
          "Heavy rain reduces visibility and makes roads slippery. Risk level increased due to fewer pedestrians and slower traffic response.";
      weatherImpactIcon = Icons.thunderstorm;
      impactColor = Colors.indigo;
    } else if (current.weatherCondition.contains("Humid")) {
      weatherImpactMessage =
          "High humidity can cause fatigue and dehydration, reducing alertness. Stick to well-ventilated areas and carry water.";
      weatherImpactIcon = Icons.water_drop;
      impactColor = Colors.cyan;
    } else if (current.weatherCondition.contains("Cloudy") ||
        current.weatherCondition.contains("Overcast")) {
      weatherImpactMessage =
          "Overcast skies may reduce natural lighting earlier in the evening. Ensure your path is well-lit.";
      weatherImpactIcon = Icons.cloud;
      impactColor = Colors.grey;
    } else if (current.temperature > 35) {
      weatherImpactMessage =
          "Extreme heat can cause exhaustion. Avoid prolonged exposure and stay near shaded, populated areas.";
      weatherImpactIcon = Icons.wb_sunny;
      impactColor = Colors.orange;
    } else {
      weatherImpactMessage =
          "Clear conditions offer good visibility. Standard safety precautions apply.";
      weatherImpactIcon = Icons.check_circle_outline;
      impactColor = Colors.green;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.3),
                Colors.white.withValues(alpha: 0.1),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Current Conditions",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current.locationName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            "Now",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              current.weatherIcon == 'clear'
                                  ? Icons.wb_sunny
                                  : current.weatherIcon == 'cloudy'
                                  ? Icons.cloud
                                  : current.weatherIcon == 'humidity'
                                  ? Icons.water_drop
                                  : Icons.thunderstorm,
                              color: Colors.orangeAccent,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${current.temperature.toInt()}°C",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              current.weatherCondition,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              current.riskLevel == 'Low'
                                  ? Icons.shield
                                  : current.riskLevel == 'Moderate'
                                  ? Icons.warning
                                  : Icons.error,
                              color: primaryColor,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${(current.riskScore * 100).toInt()}%",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              "${current.riskLevel} Risk",
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: impactColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: impactColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(weatherImpactIcon, color: impactColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weatherImpactTitle,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: impactColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              weatherImpactMessage,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (next != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryColor, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Now",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                "${(current.riskScore * 100).toInt()}%",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('h a').format(next.dateTime),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${(next.riskScore * 100).toInt()}%",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MapboxSafeRoute(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: primaryColor.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.navigation, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          next != null
                              ? "Plan Safe Route"
                              : "Plan Safe Route Now",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
