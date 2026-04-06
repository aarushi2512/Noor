import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:noor_new/screens/mapbox_safe_route.dart';
import 'package:noor_new/screens/fake_call_setup.dart';
import 'package:noor_new/widgets/animated_bottom_nav.dart';
import 'package:noor_new/widgets/emergency_card.dart';
import 'package:noor_new/news_page.dart';
import 'package:noor_new/circle_page.dart';
import 'package:noor_new/profile_page.dart';
import 'package:noor_new/services/sos_service.dart';
import 'package:noor_new/services/forecast_service.dart';
import 'package:noor_new/models/risk_forecast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
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
      backgroundColor: Theme.of(context).colorScheme.background,
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

class HomePageContent extends StatelessWidget {
  const HomePageContent({super.key});

  Future<String> _getCurrentLocationName() async {
    try {
      // 1. Get GPS Position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      // 2. Convert Coordinates to Address (Reverse Geocoding)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Construct a readable address: Area, City
        // Example: "Kandivali West, Mumbai"
        String area = place.subLocality ?? place.locality ?? "Unknown Area";
        String city = place.locality ?? "Mumbai";
        return "$area, $city";
      }
    } catch (e) {
      debugPrint('❌ Location error: $e');
    }
    // Fallback if permission denied or error
    return "Mumbai, India";
  }
  Future<void> _callSOS(BuildContext context) async {
    try {
      String? locationLink;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        locationLink =
            'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      } catch (e) {
        debugPrint('⚠️ Location not available for SOS: $e');
      }
      await SOSService.sendSOSSMS(locationLink);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS alert sent!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SOS failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Widget>> _loadEmergencyCards(BuildContext context) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/emergency_card.json',
      );
      final List<dynamic> jsonData = jsonDecode(jsonString);
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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Quick Help',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Emergency Cards
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
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    );
                  if (!snapshot.hasData || snapshot.data!.isEmpty)
                    return const Center(child: Text('No emergency contacts'));
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    children: snapshot.data!,
                  );
                },
              ),
            ),

            const SizedBox(height: 48),

            // SOS Button
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
                            'Tap to send location to trusted contacts.',
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
                            color: sosButtonColor.withOpacity(0.3),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Fake Call Button
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
                                    .withOpacity(0.3),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ✅ FINAL: Unified Dashboard with Detailed Weather Insights
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
                if (locSnapshot.connectionState == ConnectionState.waiting) {
                   return const Center(child: CircularProgressIndicator());
                }
                
                final locationName = locSnapshot.data ?? "Mumbai, India";

                return FutureBuilder(
                  future: Future.delayed(const Duration(milliseconds: 500), () => 
                    ForecastService.getForecastForLocation(locationName, 0.45) 
                  ),
                  builder: (context, forecastSnapshot) {
                    if (forecastSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!forecastSnapshot.hasData || (forecastSnapshot.data as List).isEmpty) return const SizedBox.shrink();
                    
                    final forecasts = forecastSnapshot.data as List<RiskForecast>;
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
              },),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✅ SINGLE MERGED WIDGET WITH DETAILED WEATHER LOGIC
  Widget _buildUnifiedForecastCard({
    required BuildContext context,
    required RiskForecast current,
    RiskForecast? next,
    required Color primaryColor,
  }) {
    // Determine detailed weather message based on condition
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
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              // 1. HEADER
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
                        Text(current.locationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
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

              // 2. MAIN ROW: Weather vs Risk
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Weather Side
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.05),
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
                    // Risk Side
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
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
                                color: primaryColor.withOpacity(0.8),
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

              // 3. DETAILED WEATHER IMPACT ANALYSIS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: impactColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: impactColor.withOpacity(0.2)),
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

              // 4. COMPARISON STRIP (Now vs Later)
              if (next != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      // Current (Active)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.15),
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
                      // Next (Inactive)
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

              // 5. ACTION BUTTON
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
                      shadowColor: primaryColor.withOpacity(0.4),
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
                              ? "Plan Safe Route (Now & ${DateFormat('h a').format(next.dateTime)})"
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
