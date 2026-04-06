import 'package:noor_new/models/risk_forecast.dart';

class ForecastService {
  static List<RiskForecast> getForecastForLocation(
    String locationName,
    double baseRiskScore,
  ) {
    final now = DateTime.now();
    List<RiskForecast> forecasts = [];

    // 1. CURRENT CONDITIONS (Right Now)
    forecasts.add(
      _generateForecast(
        locationName,
        baseRiskScore,
        now,
        isNight: _isNight(now),
        label: "Current",
        isCurrent: true,
      ),
    );

    // 2. NEXT WINDOW (Tonight or Tomorrow Morning)
    if (_isNight(now)) {
      forecasts.add(
        _generateForecast(
          locationName,
          baseRiskScore,
          DateTime(now.year, now.month, now.day + 1, 7, 0),
          isNight: false,
          label: "Tomorrow AM",
          isCurrent: false,
        ),
      );
    } else {
      forecasts.add(
        _generateForecast(
          locationName,
          baseRiskScore,
          DateTime(now.year, now.month, now.day, 20, 0),
          isNight: true,
          label: "Tonight",
          isCurrent: false,
        ),
      );
    }

    return forecasts;
  }

  static bool _isNight(DateTime dt) => dt.hour >= 19 || dt.hour < 6;

  static RiskForecast _generateForecast(
    String location,
    double baseScore,
    DateTime time, {
    required bool isNight,
    required String label,
    required bool isCurrent,
  }) {
    // ✅ Simulate Weather Data (In real app, fetch from OpenWeatherMap API)
    double temp = isNight ? 26.0 : 33.0;
    String condition = "Clear";
    String icon = "clear";
    String weatherImpact = "No significant weather impact.";

    // Simulate Mumbai-specific weather logic for demo
    if (location.toLowerCase().contains("mumbai")) {
      if (isNight) {
        condition = "Humid";
        icon = "humidity";
        temp = 28.0;
        weatherImpact = "High humidity may reduce visibility slightly.";
      } else {
        condition = "Partly Cloudy";
        icon = "cloudy";
        temp = 34.0;
        weatherImpact = "Heat may cause fatigue; stay hydrated.";
      }
    }

    // Simulate Rain Scenario (Uncomment to test rain logic)
    // condition = "Heavy Rain"; icon = "rain"; weatherImpact = "Rain reduces visibility & road traction. Risk increased.";

    // ✅ Calculate Risk Logic with Weather Integration
    double score = baseScore;
    String reason = "";
    String tip = "";

    // Base Time Logic
    if (isNight) {
      score += 0.25;
      reason = "Reduced visibility & lower foot traffic";
      tip = "Stick to well-lit main roads. Share live location.";
    } else {
      score -= 0.20;
      reason = "High commuter activity & police presence";
      tip = "Standard precautions. Stay aware.";
    }

    // ✅ Apply Weather Modifier
    if (condition.contains("Rain")) {
      score += 0.15; // Rain increases risk
      reason += ". Rain reduces visibility and road safety.";
      tip = "Avoid isolated shortcuts. Use main roads with drainage.";
    } else if (condition.contains("Fog")) {
      score += 0.10;
      reason += ". Fog severely limits visibility.";
      tip = "Use headlights. Walk slowly near traffic.";
    } else {
      // Clear weather impact
      reason += ". $weatherImpact";
    }

    score = score.clamp(0.0, 1.0);
    String level = score > 0.6 ? "High" : (score > 0.3 ? "Moderate" : "Low");

    return RiskForecast(
      locationName: location,
      dateTime: time,
      riskScore: score,
      riskLevel: level,
      reason: reason,
      tip: tip,
      temperature: temp,
      weatherCondition: condition,
      weatherIcon: icon,
    );
  }
}
