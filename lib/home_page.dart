import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:noor_new/screens/mapbox_safe_route.dart';
import 'package:noor_new/screens/fake_call_setup.dart';
import 'package:noor_new/widgets/animated_bottom_nav.dart';
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
import 'package:noor_new/theme/app_colors.dart';

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

  // ✅ Panic Animation State
  bool _isPanicActive = false;
  int _countdown = 3;

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
    debugPrint('LOW BATTERY DETECTED! Triggering Auto-SOS...');
    _lowBatterySossent = true;

    try {
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
        title: 'Low Battery SOS Sent',
        body: 'Your location has been sent to emergency contacts.',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      _lowBatterySossent = false;
      debugPrint('Failed to send Low Battery SOS: $e');
      if (e.toString().contains('contact') || e.toString().contains('empty')) {
        debugPrint(
          'SOS Failed: No trusted contacts found. Please add contacts in Profile.',
        );
      }
    }
  }

  // ✅ NEW: Trigger Panic Animation
  void _triggerPanicAnimation() {
    setState(() {
      _isPanicActive = true;
      _countdown = 3;
    });

    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(seconds: 1), () {
      if (!_isPanicActive) return;
      setState(() => _countdown = 2);
      HapticFeedback.heavyImpact();

      Future.delayed(const Duration(seconds: 1), () {
        if (!_isPanicActive) return;
        setState(() => _countdown = 1);
        HapticFeedback.heavyImpact();

        Future.delayed(const Duration(seconds: 1), () {
          if (!_isPanicActive) return;
          setState(() => _isPanicActive = false);
          _callSOS(context);
        });
      });
    });
  }

  // ✅ NEW: Cancel Panic
  void _cancelPanic() {
    setState(() {
      _isPanicActive = false;
      _countdown = 3;
    });
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('SOS Cancelled'),
        backgroundColor: Colors.grey,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              debugPrint('DANGER ZONE ENTERED: ${result['level']}');
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
        title: '${data['level']} RISK DETECTED!',
        body: data['message'],
        notificationDetails: notificationDetails,
      );
    } catch (e) {
      debugPrint('Notification Error: $e');
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
      debugPrint('Location error: $e');
    }
    return "Mumbai, India";
  }

  Future<void> _callSOS(BuildContext context) async {
    try {
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
        debugPrint('Location not available for SOS: $e');
      }

      await SOSService.sendSOSSMS(locationLink);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('SOS alert sent to trusted contacts!'),
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
      String errorMessage = 'SOS failed: ${e.toString()}';
      Color errorColor = Colors.red;
      IconData errorIcon = Icons.error_outline;

      if (e.toString().toLowerCase().contains('contact') ||
          e.toString().toLowerCase().contains('empty') ||
          e.toString().toLowerCase().contains('null')) {
        errorMessage =
            'No trusted contacts found! Please add contacts in your Profile first.';
        errorColor = AppColors.riskOrange;
        errorIcon = Icons.person_add_disabled;

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
                label: 'Go to Circle',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CirclePage()),
                  );
                },
              ),
            ),
          );
        }
      } else {
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

  List<Map<String, dynamic>> get _emergencyNumbers {
    return [
      {
        'title': 'Police',
        'number': '100',
        'icon': Icons.security,
        'color': AppColors.primaryBurgundyLight,
      },
      {
        'title': 'Women Helpline',
        'number': '1091',
        'icon': Icons.female,
        'color': AppColors.riskRed,
      },
      {
        'title': 'Fire',
        'number': '101',
        'icon': Icons.local_fire_department,
        'color': AppColors.riskOrange,
      },
      {
        'title': 'Ambulance',
        'number': '102',
        'icon': Icons.medical_services,
        'color': AppColors.riskGreen,
      },
      {
        'title': 'Disaster Mgmt',
        'number': '1077',
        'icon': Icons.warning_amber_rounded,
        'color': AppColors.riskYellow,
      },
      {
        'title': 'Childline',
        'number': '1098',
        'icon': Icons.child_care,
        'color': AppColors.secondaryRoseGold,
      },
    ];
  }

  Future<void> _dialNumber(String number, String name) async {
    final Uri launchUri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not dial $name'),
              backgroundColor: AppColors.riskRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Dialing error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dynamic Colors
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppColors.bgDarkStart, AppColors.bgDarkEnd]
          : [AppColors.bgLightStart, AppColors.bgLightEnd],
    );
    final glassColor = isDark ? AppColors.glassDark : AppColors.glassLight;
    final textColorMain = isDark
        ? AppColors.textDarkMain
        : AppColors.textLightMain;
    final textColorSub = isDark
        ? AppColors.textDarkSub
        : AppColors.textLightSub;
    final borderColor = Colors.white.withOpacity(0.2);
    final sosButtonColor = isDark
        ? AppColors.primaryBurgundyDark
        : AppColors.primaryBurgundyLight;

    return Stack(
      children: [
        // 1. Gradient Background
        Container(decoration: BoxDecoration(gradient: bgGradient)),

        // 2. Main Content
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Help',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: textColorMain,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
        Padding(
  padding: const EdgeInsets.only(top: 8),
  child: Row(
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primaryBurgundyLight,
        child: const Icon(Icons.person, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, User!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColorMain,
            ),
          ),
          Text(
            'Stay safe today',
            style: TextStyle(
              fontSize: 12,
              color: textColorSub,
            ),
          ),
        ],
      ),
    ],
  ),
),

const SizedBox(height: 23),

                // ✅ EMERGENCY GRID
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _emergencyNumbers.length,
                  itemBuilder: (context, index) {
                    final item = _emergencyNumbers[index];
                    return _buildGlassEmergencyCard(
                      title: item['title'],
                      number: item['number'],
                      icon: item['icon'],
                      color: item['color'],
                      glassColor: glassColor,
                      borderColor: borderColor,
                      textColor: textColorMain,
                      subColor: textColorSub,
                    );
                  },
                ),

                const SizedBox(height: 20),

                // // ✅ REDESIGNED SOS BUTTON
                // Center(
                //   child: Column(
                //     children: [
                //       GestureDetector(
                //         onTap: _triggerPanicAnimation,
                //         onLongPress: () {
                //           showDialog(
                //             context: context,
                //             builder: (_) => AlertDialog(
                //               backgroundColor: glassColor,
                //               title: const Text(
                //                 'SOS Help',
                //                 style: TextStyle(color: Colors.white),
                //               ),
                //               content: const Text(
                //                 'Tap to initiate emergency alert. You will have 3 seconds to cancel.',
                //                 style: TextStyle(color: Colors.white70),
                //               ),
                //               actions: [
                //                 TextButton(
                //                   onPressed: () => Navigator.pop(context),
                //                   child: const Text(
                //                     'Got it',
                //                     style: TextStyle(color: Colors.white),
                //                   ),
                //                 ),
                //               ],
                //             ),
                //           );
                //         },
                //         child: AnimatedContainer(
                //           duration: const Duration(milliseconds: 300),
                //           width: 180,
                //           height: 180,
                //           decoration: BoxDecoration(
                //             shape: BoxShape.circle,
                //             color: sosButtonColor,
                //             boxShadow: [
                //               BoxShadow(
                //                 color: sosButtonColor.withValues(alpha: 0.4),
                //                 blurRadius: 30,
                //                 spreadRadius: 5,
                //                 offset: const Offset(0, 0),
                //               ),
                //               BoxShadow(
                //                 color: Colors.red.withValues(alpha: 0.2),
                //                 blurRadius: 50,
                //                 spreadRadius: 10,
                //                 offset: const Offset(0, 0),
                //               ),
                //             ],
                //             border: Border.all(
                //               color: Colors.white.withValues(alpha: 0.3),
                //               width: 2,
                //             ),
                //           ),
                //           child: const Column(
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Icon(Icons.sos, color: Colors.white, size: 56),
                //               SizedBox(height: 8),
                //               Text(
                //                 'TAP FOR SOS',
                //                 style: TextStyle(
                //                   fontSize: 18,
                //                   fontWeight: FontWeight.bold,
                //                   color: Colors.white,
                //                   letterSpacing: 2,
                //                 ),
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //       const SizedBox(height: 12),
                //       Text(
                //         'Hold to learn more',
                //         style: theme.textTheme.bodySmall?.copyWith(
                //           color: textColorSub,
                //         ),
                //       ),
                //     ],
                //   ),
                // ),

                //                 const SizedBox(height: 32),


                // ✅ REDESIGNED SOS BUTTON
Center(
  child: Column(
    children: [
      GestureDetector(
        onTap: _triggerPanicAnimation,
        onLongPress: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: glassColor,
              title: Text(
                'SOS Help',
                style: TextStyle(
                  color: isDark ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Tap to initiate emergency alert. You will have 3 seconds to cancel.',
                style: TextStyle(
                  color: isDark ? Colors.black54 : Colors.white70,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      color: isDark ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark 
                ? Colors.white  // Dark mode: white button
                : const Color(0xFFE53E57),  // Light mode: red button (matching your design)
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : const Color(0xFFE53E57).withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              BoxShadow(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.2),
                blurRadius: 50,
                spreadRadius: 10,
              ),
            ],
            border: Border.all(
              color: isDark
                  ? const Color(0xFFE53E57).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.3),
              width: 3,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sos, 
                color: isDark ? const Color(0xFFE53E57) : Colors.white,
                size: 50,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap for Help',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFE53E57) : Colors.white,
                  letterSpacing: 2,
                  fontFamily: 'Montserrat',
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        '',
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColorSub,
        ),
      ),
    ],
  ),
),

                // ✅ FLAT THIN GLASS RECTANGLE (Horizontal Layout)
                Center(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FakeCallSetup(),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: 240,  // Slightly wider to fit horizontal text
                          height: 70,  // Thin height
                          decoration: BoxDecoration(
                           color: glassColor,
        border: Border.all(
          color: isDark 
              ? AppColors.primaryBurgundyLight.withValues(alpha: 0.6) 
              : AppColors.primaryBurgundyLight.withValues(alpha: 0.4),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ✅ Icon on the Left
                              Icon(
                                Icons.phone_callback_rounded,
                                color: sosButtonColor,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              // ✅ Text on the Right
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fake Call',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColorMain,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Schedule safety call',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textColorSub,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                Text(
                  'Safety & Weather Dashboard',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textColorMain,
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
                          glassColor: glassColor,
                          borderColor: borderColor,
                          textColorMain: textColorMain,
                          textColorSub: textColorSub,
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

        // ✅ PANIC OVERLAY
        if (_isPanicActive)
          Positioned.fill(
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.red.withValues(alpha: 0.8),
                        Colors.red.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.warning_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'SENDING SOS...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 40),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                        child: Text(
                          '$_countdown',
                          key: ValueKey<int>(_countdown),
                          style: const TextStyle(
                            fontSize: 120,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: _cancelPanic,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
              _triggerPanicAnimation();
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

  Widget _buildGlassEmergencyCard({
    required String title,
    required String number,
    required IconData icon,
    required Color color,
    required Color glassColor,
    required Color borderColor,
    required Color textColor,
    required Color subColor,
  }) {
    return GestureDetector(
      onTap: () => _dialNumber(number, title),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  number,
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedForecastCard({
    required BuildContext context,
    required RiskForecast current,
    RiskForecast? next,
    required Color primaryColor,
    required Color glassColor,
    required Color borderColor,
    required Color textColorMain,
    required Color textColorSub,
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
                glassColor.withValues(alpha: 0.5),
                glassColor.withValues(alpha: 0.2),
              ],
            ),
            border: Border.all(color: borderColor, width: 1.5),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: textColorMain,
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
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColorMain,
                              ),
                            ),
                            Text(
                              current.weatherCondition,
                              style: TextStyle(
                                fontSize: 12,
                                color: textColorSub,
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
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: textColorMain,
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
                      Icon(Icons.arrow_forward, size: 16, color: textColorSub),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                DateFormat('h a').format(next.dateTime),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: textColorSub,
                                ),
                              ),
                              Text(
                                "${(next.riskScore * 100).toInt()}%",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColorSub,
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
