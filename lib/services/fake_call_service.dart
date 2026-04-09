import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../models/fake_call.dart';
import '../screens/incoming_call_screen.dart';
import '../screens/active_call_screen.dart';
import '../main.dart' show backgroundCallback;

class FakeCallService {
  static final FakeCallService _instance = FakeCallService._internal();
  factory FakeCallService() => _instance;
  FakeCallService._internal();

  Timer? _scheduledTimer;
  bool _isRinging = false;
  int _alarmId = 0;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  //  Initialize background services
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        debugPrint(' Notification tapped: ${response.payload}');
      },
    );

    debugPrint(' FakeCallService initialized');
  }

  // 📞 Trigger immediate fake call
  Future<void> triggerImmediateCall(BuildContext context, FakeCall call) async {
    await _startRinging();
    _showIncomingCallScreen(context, call);
  }

  // ⏰ Schedule fake call (works when app is OPEN)
  Future<void> scheduleCall(FakeCall call, BuildContext context) async {
    final delay = call.scheduledTime!.difference(DateTime.now());

    if (delay.isNegative) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(' Please select a future time')),
      );
      return;
    }

    // Cancel any existing timer
    _scheduledTimer?.cancel();

    // Debug logging
    debugPrint(' Scheduling call in ${delay.inSeconds} seconds');
    debugPrint(' Will trigger at ${call.scheduledTime}');

    // Schedule with Timer
    _scheduledTimer = Timer(delay, () {
      debugPrint(' Timer fired! Triggering fake call...');

      // Ensure we're still mounted before showing UI
      if (context.mounted) {
        triggerImmediateCall(context, call);
      }
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⏰ Call scheduled for ${_formatTime(call.scheduledTime!)}\n'
          '⚠️ Keep app open for call to trigger',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }
  //  Start ringing
  Future<void> _startRinging() async {
    _isRinging = true;

    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
        pattern: [0, 1000, 500, 1000, 500, 1000, 500, 1000],
        intensities: [0, 255, 0, 255, 0, 255, 0, 255],
      );
    }

    try {
      await FlutterRingtonePlayer().playRingtone(
        volume: 1.0,
        looping: true,
        asAlarm: false,
      );
    } catch (e) {
      debugPrint('Ringtone error: $e');
    }
  }

  //  Stop ringing
  Future<void> stopRinging() async {
    _isRinging = false;
    await Vibration.cancel();
    await FlutterRingtonePlayer().stop();
  }

  //  Show incoming call screen
  void _showIncomingCallScreen(BuildContext context, FakeCall call) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          call: call,
          onAnswer: () => _onAnswer(context, call),
          onDecline: () => _onDecline(context),
        ),
      ),
    );
  }

  void _onAnswer(BuildContext context, FakeCall call) async {
    await stopRinging();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ActiveCallScreen(call: call)),
    );
  }

  void _onDecline(BuildContext context) async {
    await stopRinging();
    Navigator.pop(context);
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void dispose() {
    _scheduledTimer?.cancel();
    stopRinging();
  }
}
