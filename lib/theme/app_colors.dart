import 'package:flutter/material.dart';

// ✅ ONLY COLORS & ASSETS HERE - NO THEMES
class AppColors {
  // --- Background Gradients (Fallbacks) ---
  static const Color bgLightStart = Color(0xFFfefefe);
  static const Color bgLightEnd = Color(0xFFfdf2f8);

  static const Color bgDarkStart = Color(0xFF0a0a0a);
  static const Color bgDarkEnd = Color(0xFF1a050a);

  // --- ✅ NEW: Background Image Assets ---
  static const String bgLightImage = 'assets/images/bg_light.jpeg';
  static const String bgDarkImage = 'assets/images/bg_dark.jpeg';

  // --- Glass Effects ---
  static const Color glassLight = Color.fromRGBO(255, 255, 255, 0.75);
  static const Color glassDark = Color.fromRGBO(40, 15, 25, 0.70);

  // --- Accents ---
  static const Color primaryBurgundyLight = Color(0xFF7f1d1d);
  static const Color primaryBurgundyDark = Color(0xFF991b1b);

  static const Color secondaryTaupe = Color(0xFF78716c);
  static const Color secondaryRoseGold = Color(0xFFfca5a5);

  // --- Risk Gradient ---
  static const Color riskGreen = Color(0xFF65a30d);
  static const Color riskYellow = Color(0xFFca8a04);
  static const Color riskOrange = Color(0xFFea580c);
  static const Color riskRed = Color(0xFFdc2626);

  // --- Text ---
  static const Color textLightMain = Color(0xFF1c1917);
  static const Color textLightSub = Color(0xFF57534e);

  static const Color textDarkMain = Color(0xFFfefefe);
  static const Color textDarkSub = Color(0xFFfca5a5);
}
