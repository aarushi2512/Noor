// lib/services/route_risk_service.dart
import 'dart:math' as math;
import 'package:noor_new/services/offline_risk_service.dart';

class RouteRiskService {
  static final RouteRiskService _instance = RouteRiskService._internal();
  factory RouteRiskService() => _instance;
  RouteRiskService._internal();

  final OfflineRiskService _riskService = OfflineRiskService();

  /// Calculate risk score for a route (list of lat/lng coordinates)
  /// Returns: 0.0 (safe) to 1.0 (critical)
  Future<Map<String, dynamic>> calculateRouteRisk({
    required List<Map<String, double>> routeCoordinates,
    required double directDistanceKm,
  }) async {
    // ✅ Safer check: just verify coordinates exist
    if (routeCoordinates.isEmpty) {
      return {
        'risk_score': 0.5,
        'risk_level': 'moderate',
        'high_risk_segments': 0,
        'total_segments': 0,
        'safe_percentage': 50.0,
      };
    }
    // Calculate actual route distance (rough estimate: 1 point ≈ 10m)
    final routeDistanceKm = (routeCoordinates.length * 10) / 1000;
    final detourFactor =
        routeDistanceKm / directDistanceKm.clamp(0.1, routeDistanceKm);

    // ✅ PENALIZE excessive detours: if route is >2x longer, add risk penalty
    final detourPenalty = detourFactor > 2.0
        ? (detourFactor - 2.0) * 0.15
        : 0.0;

    int highRiskSegments = 0;
    int criticalSegments = 0;
    double totalRiskScore = 0.0;

    // Sample every 5th point for performance (adjust based on route length)
    final step = routeCoordinates.length > 100 ? 5 : 1;

    for (int i = 0; i < routeCoordinates.length; i += step) {
      final point = routeCoordinates[i];
      final lat = point['lat']!;
      final lng = point['lng']!;

      final riskData = _riskService.getRiskForLocation(lat, lng);
      final riskScore = riskData['risk_score'] as double;
      final riskLevel = riskData['risk_level'] as String;

      totalRiskScore += riskScore;

      if (riskLevel == 'critical') {
        criticalSegments++;
        highRiskSegments++;
      } else if (riskLevel == 'high') {
        highRiskSegments++;
      }
    }

   final validSamples = (routeCoordinates.length ~/ step).clamp(
      1,
      routeCoordinates.length,
    );
    final baseRiskScore = totalRiskScore / validSamples;

    // ✅ Apply detour penalty to final score
    final adjustedRiskScore = (baseRiskScore + detourPenalty).clamp(0.0, 1.0);

    final safePercentage = ((1.0 - adjustedRiskScore) * 100).clamp(0.0, 100.0);

    return {
      'risk_score': adjustedRiskScore,
      'risk_level': _getRiskLevel(adjustedRiskScore),
      'high_risk_segments': highRiskSegments,
      'critical_segments': criticalSegments,
      'total_segments': validSamples,
      'safe_percentage': safePercentage,
      'detour_factor': detourFactor,
      'route_distance_km': routeDistanceKm,
      'estimated_safe_duration': _calculateSafeDuration(
        routeCoordinates.length,
        safePercentage,
      ),
    };
  }

  String _getRiskLevel(double score) {
    if (score >= 0.7) return 'critical';
    if (score >= 0.5) return 'high';
    if (score >= 0.3) return 'moderate';
    return 'low';
  }

  String _calculateSafeDuration(int pointCount, double safePercentage) {
    // Rough estimate: 1 point ≈ 10 meters, walking speed 5 km/h
    final distanceKm = (pointCount * 10) / 1000;
    final durationMinutes = (distanceKm / 5.0 * 60);
    final safeMinutes = durationMinutes * (safePercentage / 100);
    return '${safeMinutes.round()} min in safe zones';
  }
}
