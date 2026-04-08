import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  late SharedPreferences _prefs;
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs.getBool('is_dark_mode');
    if (savedTheme != null) {
      _isDarkMode = savedTheme;
    } else {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _isDarkMode = brightness == Brightness.dark;
    }
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }
}
