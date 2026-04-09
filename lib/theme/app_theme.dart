import 'package:flutter/material.dart';
import 'app_colors.dart'; 

//  LIGHT THEME
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.bgLightStart,

  colorScheme: ColorScheme.light(
    primary: AppColors.primaryBurgundyLight,
    onPrimary: Colors.white,
    surface: AppColors.glassLight,
    // Removed deprecated 'background' and 'onBackground'
    onSurface: AppColors.textLightMain,
    error: AppColors.riskRed,
  ),

  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.textLightMain,
      letterSpacing: -0.5,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.textLightMain,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.textLightSub),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.secondaryTaupe),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: AppColors.textLightMain,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: AppColors.textLightMain,
    ),
  ),

  // FIXED: Changed CardTheme to CardThemeData
  cardTheme: CardThemeData(
    color: AppColors.glassLight,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    elevation: 0,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryBurgundyLight,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
    ),
  ),

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.transparent,
    selectedItemColor: AppColors.primaryBurgundyLight,
    unselectedItemColor: AppColors.secondaryTaupe,
  ),
);

// DARK THEME
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bgDarkStart,

  colorScheme: ColorScheme.dark(
    primary: AppColors.primaryBurgundyDark,
    onPrimary: Colors.white,
    surface: AppColors.glassDark,
    // Removed deprecated 'background' and 'onBackground'
    onSurface: AppColors.textDarkMain,
    error: AppColors.riskRed,
  ),

  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.textDarkMain,
      letterSpacing: -0.5,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.textDarkMain,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.textDarkSub),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.secondaryRoseGold),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: AppColors.textDarkMain,
    titleTextStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: AppColors.textDarkMain,
    ),
  ),

  // FIXED: Changed CardTheme to CardThemeData
  cardTheme: CardThemeData(
    color: AppColors.glassDark,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    elevation: 0,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryBurgundyDark,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
    ),
  ),

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.transparent,
    selectedItemColor: AppColors.primaryBurgundyDark,
    unselectedItemColor: AppColors.secondaryRoseGold,
  ),
);
