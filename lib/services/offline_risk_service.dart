// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class OfflineRiskService {
  static final OfflineRiskService _instance = OfflineRiskService._internal();
  factory OfflineRiskService() => _instance;
  OfflineRiskService._internal();

  List<Map<String, dynamic>> _riskGrid = [];
  bool _isLoaded = false;

  Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/mumbai_risk_grid.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      _riskGrid = List<Map<String, dynamic>>.from(jsonList);
      _isLoaded = true;
      debugPrint('✅ Loaded ${_riskGrid.length} risk regions offline');
    } catch (e) {
      debugPrint('❌ Failed to load risk data: $e');
      _riskGrid = [];
    }
  }

  Map<String, dynamic> getRiskForLocation(double latitude, double longitude) {
    if (!_isLoaded || _riskGrid.isEmpty) {
      return {
        'risk_score': 0.5,
        'risk_level': 'moderate',
        'confidence': 0.5,
        'source': 'offline_default',
        'area_name': 'Unknown',
      };
    }

    double minDistance = double.infinity;
    Map<String, dynamic>? nearestRegion;

    for (var region in _riskGrid) {
      final double lat = (region['Latitude'] ?? 0).toDouble();
      final double lng = (region['Longitude'] ?? 0).toDouble();

      // Quick squared distance check before expensive Haversine
      final double dLat = lat - latitude;
      final double dLng = lng - longitude;
      if ((dLat * dLat + dLng * dLng) > 0.01)
        continue; // Skip points > ~10km away

      final double distance = _haversineDistance(latitude, longitude, lat, lng);

      if (distance < minDistance && distance < 3.0) {
        minDistance = distance;
        nearestRegion = region;
      }
    }

    if (nearestRegion != null) {
      final double riskScore = (nearestRegion['risk'] ?? 0.5).toDouble();
      return {
        'risk_score': riskScore,
        'risk_level': _getRiskLevel(riskScore),
        'confidence': 0.85,
        'source': 'offline_grid',
        'area_name': nearestRegion['area_name'] ?? 'Unknown',
      };
    }

    // ✅ IMPROVED: Better fallback estimation for ALL Mumbai areas
    final double estimatedRisk = _estimateRiskFromCoordinates(
      latitude,
      longitude,
    );
    return {
      'risk_score': estimatedRisk,
      'risk_level': _getRiskLevel(estimatedRisk),
      'confidence': 0.5,
      'source': 'offline_estimate',
      'area_name': _getAreaNameFromCoordinates(latitude, longitude),
    };
  }

  List<Map<String, dynamic>> generateHeatmapData({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int resolution = 50,
  }) {
    if (!_isLoaded) return [];

    final List<Map<String, dynamic>> results = [];
    final double latStep = (maxLat - minLat) / resolution;
    final double lngStep = (maxLng - minLng) / resolution;

    for (int i = 0; i <= resolution; i++) {
      for (int j = 0; j <= resolution; j++) {
        final double lat = minLat + (i * latStep);
        final double lng = minLng + (j * lngStep);

        // ✅ EXPANDED: More permissive boundary check
        if (!_isInMumbaiBoundary(lat, lng)) {
          results.add({
            'lat': lat,
            'lng': lng,
            'risk_score': 0.0,
            'risk_level': 'safe',
          });
          continue;
        }

        double minDistance = double.infinity;
        double riskScore = 0.5;

        for (var region in _riskGrid) {
          final double regionLat = (region['Latitude'] ?? 0).toDouble();
          final double regionLng = (region['Longitude'] ?? 0).toDouble();
          final double distance = _haversineDistance(
            lat,
            lng,
            regionLat,
            regionLng,
          );

          if (distance < minDistance && distance < 3.0) {
            minDistance = distance;
            riskScore = (region['risk'] ?? 0.5).toDouble();
          }
        }

        // ✅ IMPROVED: Better fallback for areas without data
        if (riskScore == 0.5 && minDistance == double.infinity) {
          riskScore = _estimateRiskFromCoordinates(lat, lng);
        }

        results.add({
          'lat': lat,
          'lng': lng,
          'risk_score': riskScore,
          'risk_level': _getRiskLevel(riskScore),
        });
      }
    }
    debugPrint('🔥 Generated ${results.length} heatmap points offline');
    return results;
  }

  String _getRiskLevel(double score) {
    if (score >= 0.7) return 'critical';
    if (score >= 0.5) return 'high';
    if (score >= 0.3) return 'moderate';
    return 'low';
  }

  // ✅ IMPROVED: Better risk estimation for ALL Mumbai areas including South Mumbai
  double _estimateRiskFromCoordinates(double lat, double lng) {
    // South Mumbai (Colaba, Fort, Kalbadevi, Cotton Green, Marine Lines, etc.)
    if (lat < 19.00) {
      if (lng < 72.83) return 0.68; // Colaba, Nariman Point
      if (lng < 72.85)
        return 0.72; // Fort, Kalbadevi, Cotton Green, Marine Lines
      if (lng < 72.87) return 0.65; // Dadar, Worli fringe
      return 0.60; // Southern suburbs fringe
    }

    // Central Mumbai (Dadar, Parel, Lower Parel, Prabhadevi)
    if (lat < 19.05) {
      if (lng < 72.84) return 0.62; // Worli, Lower Parel
      if (lng < 72.86) return 0.64; // Parel, Prabhadevi
      return 0.58; // Central fringe
    }

    // Western Suburbs (Bandra to Borivali)
    if (lat < 19.20) {
      if (lat < 19.10) return 0.55; // Bandra, Khar, Santacruz
      if (lat < 19.15) return 0.52; // Andheri, Jogeshwari
      return 0.48; // Goregaon, Malad, Kandivali
    }

    // Far Suburbs (Borivali, Dahisar, Mira Road)
    if (lat < 19.30) {
      if (lng < 72.86) return 0.45; // Borivali West
      if (lng < 72.90) return 0.50; // Dahisar, Mira Road
      return 0.42; // Eastern suburbs fringe
    }

    // Thane & Beyond
    if (lat < 19.45) {
      if (lng > 72.95) return 0.58; // Thane West/East
      return 0.46; // Mira-Bhayandar fringe
    }

    // Default fallback
    return 0.45;
  }

  // ✅ NEW: Get approximate area name from coordinates (for alerts)
  String _getAreaNameFromCoordinates(double lat, double lng) {
    if (lat < 18.92) {
      if (lng < 72.82) return 'Colaba';
      return 'Fort/Kalbadevi';
    }
    if (lat < 18.96) {
      if (lng < 72.84) return 'Marine Lines/Cotton Green';
      if (lng < 72.86) return 'Grant Road/Mumbai Central';
      return 'Byculla/Mazgaon';
    }
    if (lat < 19.00) {
      if (lng < 72.83) return 'Worli';
      if (lng < 72.85) return 'Lower Parel/Prabhadevi';
      return 'Dadar';
    }
    if (lat < 19.05) return 'Mahim/Bandra';
    if (lat < 19.10) return 'Khar/Santacruz';
    if (lat < 19.15) return 'Andheri/Jogeshwari';
    if (lat < 19.20) return 'Goregaon/Malad';
    if (lat < 19.25) return 'Kandivali/Borivali';
    if (lat < 19.30) return 'Dahisar/Mira Road';
    if (lng > 72.95) return 'Thane';
    return 'Mumbai Suburbs';
  }

  // ✅ EXPANDED: More permissive boundary to include ALL of Greater Mumbai
 // ✅ EXPANDED: Includes ALL of South Mumbai + Harbor areas
  bool _isInMumbaiBoundary(double lat, double lng) {
    // South: Include ALL of South Mumbai + Colaba + Navy Nagar
    if (lat < 18.88 && lng < 72.75) return false; // Open sea SW
    if (lat < 18.90 && lng > 72.95) return false; // Open sea SE

    // West: Arabian Sea boundary (permissive)
    if (lng < 72.68) return false;

    // East: Include Thane creek fringe + Airoli/Ghansoli
    if (lng > 73.12) return false;

    // North: Include Vasai-Virar
    if (lat > 19.55) return false;

    // North-East: Include Thane city + Kalyan fringe
    if (lat > 19.30 && lng > 73.05) return false;

    // South-East: Include all harbor areas (Sewri, Wadala, Mazgaon)
    if (lat < 19.00 && lng > 73.00) return false;

    // ✅ Inside Greater Mumbai boundary (ALL areas included)
    return true;
  }

  double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    final double lat1Rad = _toRadians(lat1);
    final double lat2Rad = _toRadians(lat2);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);
}
