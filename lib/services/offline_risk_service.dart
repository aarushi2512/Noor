// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart'; // foundation.dart is included here

/// Helper class moved to top-level to fix 'class_in_class' error
class _RiskPoint {
  final double lat;
  final double lng;
  final double risk;
  final String? areaName;

  _RiskPoint({
    required this.lat,
    required this.lng,
    required this.risk,
    this.areaName,
  });
}

class OfflineRiskService {
  static final OfflineRiskService _instance = OfflineRiskService._internal();
  factory OfflineRiskService() => _instance;
  OfflineRiskService._internal();

  List<Map<String, dynamic>> _riskGrid = [];
  bool _isLoaded = false;

  // ✅ Now works because _RiskPoint is a top-level type
  List<_RiskPoint> _riskPoints = [];

  Future<void> initialize() async {
    if (_isLoaded) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/mumbai_risk_grid.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);

      _riskGrid = List<Map<String, dynamic>>.from(jsonList);

      // ✅ Map to the helper class
      _riskPoints = _riskGrid.map((region) {
        return _RiskPoint(
          lat: (region['Latitude'] ?? 0).toDouble(),
          lng: (region['Longitude'] ?? 0).toDouble(),
          risk: (region['risk'] ?? 0.5).toDouble(),
          areaName: region['area_name'],
        );
      }).toList();

      _isLoaded = true;
      debugPrint('✅ Loaded ${_riskGrid.length} risk regions offline');
    } catch (e) {
      debugPrint('❌ Failed to load risk data: $e');
      _riskGrid = [];
      _riskPoints = [];
    }
  }

  Map<String, dynamic> checkDangerZone(double lat, double lng) {
    if (!_isLoaded || _riskPoints.isEmpty) {
      return {'isDanger': false};
    }

    const double dangerRadiusKm = 0.15;
    const double highRiskThreshold = 0.7;

    for (var point in _riskPoints) {
      double dLat = (point.lat - lat) * 111.0;
      double dLng = (point.lng - lng) * 111.0 * math.cos(lat * math.pi / 180);
      double distSq = dLat * dLat + dLng * dLng;

      if (distSq > (dangerRadiusKm * dangerRadiusKm)) continue;

      double distance = _haversineDistance(lat, lng, point.lat, point.lng);

      if (distance <= dangerRadiusKm && point.risk >= highRiskThreshold) {
        bool isCritical = point.risk > 0.85;
        return {
          'isDanger': true,
          'level': isCritical ? 'CRITICAL' : 'HIGH',
          'areaName': point.areaName ?? _getAreaNameFromCoordinates(lat, lng),
          'message': isCritical
              ? '⚠️ CRITICAL DANGER ZONE DETECTED! Immediate caution advised.'
              : '⚠️ High Risk Area detected. Stay alert.',
          'tip': 'Move to a well-lit, populated area immediately.',
          'color': isCritical ? Colors.red : Colors.orange,
          'riskScore': point.risk,
        };
      }
    }

    return {'isDanger': false};
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

      final double dLat = lat - latitude;
      final double dLng = lng - longitude;

      // ✅ Added curly braces to satisfy lint rules
      if ((dLat * dLat + dLng * dLng) > 0.01) {
        continue;
      }

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

  // ... (generateHeatmapData and other private methods remain the same)

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
    return results;
  }

  String _getRiskLevel(double score) {
    if (score >= 0.7) return 'critical';
    if (score >= 0.5) return 'high';
    if (score >= 0.3) return 'moderate';
    return 'low';
  }

  double _estimateRiskFromCoordinates(double lat, double lng) {
    if (lat < 19.00) {
      if (lng < 72.83) return 0.68;
      if (lng < 72.85) return 0.72;
      if (lng < 72.87) return 0.65;
      return 0.60;
    }
    if (lat < 19.05) {
      if (lng < 72.84) return 0.62;
      if (lng < 72.86) return 0.64;
      return 0.58;
    }
    if (lat < 19.20) {
      if (lat < 19.10) return 0.55;
      if (lat < 19.15) return 0.52;
      return 0.48;
    }
    if (lat < 19.30) {
      if (lng < 72.86) return 0.45;
      if (lng < 72.90) return 0.50;
      return 0.42;
    }
    if (lat < 19.45) {
      if (lng > 72.95) return 0.58;
      return 0.46;
    }
    return 0.45;
  }

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

  bool _isInMumbaiBoundary(double lat, double lng) {
    if (lat < 18.88 && lng < 72.75) return false;
    if (lat < 18.90 && lng > 72.95) return false;
    if (lng < 72.68) return false;
    if (lng > 73.12) return false;
    if (lat > 19.55) return false;
    if (lat > 19.30 && lng > 73.05) return false;
    if (lat < 19.00 && lng > 73.00) return false;
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
