class RiskForecast {
  final String locationName;
  final DateTime dateTime;
  final double riskScore;
  final String riskLevel;
  final String reason;
  final String tip;

  // ✅ New Weather Fields
  final double temperature; // in Celsius
  final String weatherCondition; // e.g., "Clear", "Rainy"
  final String weatherIcon; // e.g., "clear_day", "rain"

  RiskForecast({
    required this.locationName,
    required this.dateTime,
    required this.riskScore,
    required this.riskLevel,
    required this.reason,
    required this.tip,
    required this.temperature,
    required this.weatherCondition,
    required this.weatherIcon,
  });

  String get colorHex {
    if (riskScore < 0.3) return '0xFF00E676';
    if (riskScore < 0.6) return '0xFFFFEB3B';
    return '0xFFF44336';
  }

  // Helper to check if this forecast is for "Right Now"
  bool get isCurrent {
    final now = DateTime.now();
    final diff = dateTime.difference(now).inMinutes.abs();
    return diff < 60; // Within 1 hour
  }
}
