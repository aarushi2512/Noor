import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DangerZoneAlert extends StatelessWidget {
  final String level;
  final String message;
  final String tip;
  final VoidCallback onSafe;
  final VoidCallback onSOS;

  const DangerZoneAlert({
    super.key,
    required this.level,
    required this.message,
    required this.tip,
    required this.onSafe,
    required this.onSOS,
  });

  @override
  Widget build(BuildContext context) {
    // Vibrate heavily when alert appears
    HapticFeedback.heavyImpact();
    HapticFeedback.vibrate();

    bool isCritical = level == 'CRITICAL';
    Color mainColor = isCritical ? Colors.red : Colors.orange;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button closing
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.95),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing Warning Icon
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween<double>(begin: 0.8, end: 1.2),
                    builder: (context, double scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Icon(
                          Icons.warning_rounded,
                          color: mainColor,
                          size: 100,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),

                  // Title
                  Text(
                    '$level ZONE DETECTED!',
                    style: TextStyle(
                      color: mainColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Tip Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: mainColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb, color: Colors.yellowAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: onSOS,
                      icon: const Icon(Icons.sos, size: 24),
                      label: const Text(
                        'ACTIVATE SOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: OutlinedButton(
                      onPressed: onSafe,
                      child: const Text(
                        'I AM SAFE / FALSE ALARM',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
