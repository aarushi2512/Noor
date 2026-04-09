import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SOSService {
  static Future<void> sendSOSSMS(String? locationLink) async {
    final prefs = await SharedPreferences.getInstance();
    final contactPhones = prefs.getStringList('emergency_contact_phones') ?? [];

    // DEBUG: See exactly what's stored
    print('SOS DEBUG: Sending to phones = $contactPhones');

    if (contactPhones.isEmpty) {
      throw Exception(
        'No trusted contacts configured. Please add contacts in Circle.',
      );
    }

    final recipientString = contactPhones.join(',');
    final message =
        '🚨 EMERGENCY ALERT 🚨\nI need help immediately!\nSafe Sprout user\n${locationLink ?? ''}';

    final uri = Uri.parse(
      'sms:$recipientString?body=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Could not open SMS app');
    }
  }
}
