import 'package:home_widget/home_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noor_new/services/sos_service.dart';

//  This annotation is CRITICAL. It keeps this function alive even if the app is closed.
@pragma('vm:entry-point')
Future<void> widgetCallback() async {
  print(' WIDGET TAPPED! Triggering SOS...');

  Position? position;
  try {
    position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 5),
    );
  } catch (e) {
    print(' Location error in widget: $e');
  }

  String locationLink = 'https://maps.google.com/?q=${position?.latitude ?? 0},${position?.longitude ?? 0}';

  try {
    await SOSService.sendSOSSMS(locationLink);
    print(' SOS Sent from Widget!');
  } catch (e) {
    print(' Failed to send SOS from widget: $e');
  }
} 