import 'dart:convert';
import 'package:http/http.dart' as http;

class RiskApiService {
  // ✅ For Android Emulator: use 10.0.2.2
  // ✅ For iOS Simulator: use localhost
  // ✅ For Real Android Device: use your PC's IP
  // ✅ NEW (correct ngrok-free.dev domain + https):
  static const String baseUrl =
      'https://latticelike-wilford-presentive.ngrok-free.dev';

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      print('🔍 Health check: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Health check failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> predictRisk({
    required double latitude,
    required double longitude,
    int? hour,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/predict/risk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'hour': hour ?? DateTime.now().hour,
          'user_profile': 'general',
        }),
      );
      print('🔍 Predict risk: ${response.statusCode}');
      if (response.statusCode == 200) return jsonDecode(response.body);
    } catch (e) {
      print('❌ Predict risk failed: $e');
    }
    return null;
  }

  // ✅ SINGLE getHeatmapData method with logging
  Future<List<Map<String, dynamic>>?> getHeatmapData({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    int zoom = 12,
    int gridResolution = 15,
  }) async {
    try {
      final bbox = '$minLng,$minLat,$maxLng,$maxLat';
      print('🔍 [API] Fetching heatmap: bbox=$bbox');

      final uri = Uri.parse('$baseUrl/heatmap/data').replace(
        queryParameters: {
          'bbox': bbox,
          'zoom': zoom.toString(),
          'grid_resolution': gridResolution.toString(),
        },
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}), // Empty body for POST
      );

      print('🔍 [API] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(
          '🔍 [API] success=${data['success']}, count=${data['data']?.length ?? 0}',
        );

        if (data['success'] == true) {
          final result = List<Map<String, dynamic>>.from(data['data'] ?? []);
          print('✅ [API] Returning ${result.length} heatmap points');
          return result;
        }
      } else {
        print('❌ [API] HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e, stack) {
      print('❌ [API] Exception: $e');
      print('❌ [API] Stack: $stack');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getRiskAlerts({
    required double latitude,
    required double longitude,
    double radiusKm = 1.0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/risk/alerts?lat=$latitude&lng=$longitude&radius_km=$radiusKm',
        ),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }
}
