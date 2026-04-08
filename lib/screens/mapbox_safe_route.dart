// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noor_new/services/offline_risk_service.dart';
import 'package:noor_new/services/route_risk_service.dart';
import 'package:noor_new/services/sos_service.dart';
import 'package:noor_new/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class MapboxSafeRoute extends StatefulWidget {
  const MapboxSafeRoute({super.key});

  @override
  State<MapboxSafeRoute> createState() => _MapboxSafeRouteState();
}

class _MapboxSafeRouteState extends State<MapboxSafeRoute> {
  final OfflineRiskService _riskService = OfflineRiskService();
  final RouteRiskService _routeRiskService = RouteRiskService();

  mapbox.MapboxMap? mapboxMap;
  String? accessToken;

  Point? origin;
  Point? destination;
  bool isLoading = false;
  String? _routeDistance;
  String? _routeDuration;

  List<Map<String, dynamic>> _routeOptions = [];
  int _selectedRouteIndex = 0;

  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  List<Map<String, dynamic>> _sourceSuggestions = [];
  List<Map<String, dynamic>> _destSuggestions = [];
  bool _showSourceSuggestions = false;
  bool _showDestSuggestions = false;

  bool _isSelectingSuggestion = false;
  String _profile = 'walking';

  final String _routeSourceId = 'route-source';
  final String _routeLayerId = 'route-layer';
  final String _originMarkerId = 'origin-marker';
  final String _destMarkerId = 'dest-marker';

  Timer? _searchTimer;
  StreamSubscription<geo.Position>? _locationSubscription;
  bool _isJourneyActive = false;
  double _journeyProgress = 0.0;
  String? _currentETA;
  List<geo.Position> _journeyHistory = [];

  bool _showRiskHeatmap = false;
  List<Map<String, dynamic>> _heatmapData = [];
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _riskService.initialize();
    accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (accessToken != null) {
      MapboxOptions.setAccessToken(accessToken!);
    }
    _init();

    _sourceController.addListener(() {
      if (!_isSelectingSuggestion &&
          _sourceController.text.length > 2 &&
          _sourceController.text != 'Current Location') {
        _debouncedSearch(_sourceController.text, true);
      }
    });

    _destController.addListener(() {
      if (!_isSelectingSuggestion && _destController.text.length > 2) {
        _debouncedSearch(_destController.text, false);
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _sourceController.dispose();
    _destController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await Permission.locationWhenInUse.request();
    await _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      geo.Position pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        origin = Point(
          coordinates: Position(
            pos.longitude.toDouble(),
            pos.latitude.toDouble(),
          ),
        );
        _sourceController.text = 'Current Location';
      });
      _moveCamera();
      _addOriginMarker();
    } catch (e) {
      debugPrint("Location error: $e");
      if (!mounted) return;
      setState(() {
        origin = Point(coordinates: Position(72.8777, 19.0760));
        _sourceController.text = 'Mumbai, India';
      });
      _moveCamera();
      _addOriginMarker();
    }
  }

  void _onMapCreated(mapbox.MapboxMap map) {
    mapboxMap = map;
    _moveCamera();
    _add3DBuildings();
  }

  void _moveCamera() {
    if (mapboxMap == null) return;
    final target = origin ?? Point(coordinates: Position(72.8777, 19.0760));
    mapboxMap!.flyTo(
      CameraOptions(center: target, zoom: 15.0, pitch: 0.0),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _add3DBuildings() async {
    if (mapboxMap == null) return;
    final style = mapboxMap!.style;
    if (await style.styleLayerExists('3d-buildings')) return;
    try {
      await style.addLayer(
        FillExtrusionLayer(
          id: '3d-buildings',
          sourceId: 'composite',
          sourceLayer: 'building',
          minZoom: 15.0,
          fillExtrusionHeight: null,
          fillExtrusionBase: null,
          fillExtrusionColor: Colors.grey.toARGB32(),
          fillExtrusionOpacity: 0.5,
        ),
      );
      await style.setStyleLayerProperty(
        '3d-buildings',
        'fill-extrusion-height',
        ["get", "height"],
      );
      await style.setStyleLayerProperty('3d-buildings', 'fill-extrusion-base', [
        "get",
        "min_height",
      ]);
    } catch (e) {
      debugPrint('❌ Failed to add 3D buildings: $e');
    }
  }

  void _debouncedSearch(String query, bool isSource) {
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 300),
      () => _onSearchChanged(query, isSource),
    );
  }

  void _onSearchChanged(String query, bool isSource) async {
    if (accessToken == null) return;
    try {
      final String proximity = origin != null
          ? "&proximity=${origin!.coordinates.lng},${origin!.coordinates.lat}"
          : "";
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
        '?access_token=$accessToken&limit=6&country=in$proximity&types=poi,address,neighborhood,place',
      );
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final List features = data['features'];
        final suggestions = features
            .map(
              (f) => {
                'display_name': f['place_name'],
                'lat': f['geometry']['coordinates'][1].toString(),
                'lon': f['geometry']['coordinates'][0].toString(),
              },
            )
            .toList();

        if (!mounted) return;
        setState(() {
          if (isSource) {
            _sourceSuggestions = suggestions.cast<Map<String, dynamic>>();
            _showSourceSuggestions = true;
          } else {
            _destSuggestions = suggestions.cast<Map<String, dynamic>>();
            _showDestSuggestions = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> place, bool isSource) {
    final lat = double.parse(place['lat']);
    final lng = double.parse(place['lon']);
    FocusScope.of(context).unfocus();
    _isSelectingSuggestion = true;

    if (!mounted) return;
    setState(() {
      if (isSource) {
        origin = Point(coordinates: Position(lng, lat));
        _sourceController.text = place['display_name'].split(',').first;
        _showSourceSuggestions = false;
        _sourceSuggestions = [];
        _addOriginMarker();
      } else {
        destination = Point(coordinates: Position(lng, lat));
        _destController.text = place['display_name'].split(',').first;
        _showDestSuggestions = false;
        _destSuggestions = [];
        _addDestMarker();
      }
    });

    _isSelectingSuggestion = false;
    _moveCamera();
    if (origin != null && destination != null)
      _drawRoute(origin!, destination!);
  }

  Future<void> _addOriginMarker() async {
    if (mapboxMap == null || origin == null) return;
    final style = mapboxMap!.style;
    if (await style.styleLayerExists(_originMarkerId))
      await style.removeStyleLayer(_originMarkerId);
    if (await style.styleSourceExists(_originMarkerId))
      await style.removeStyleSource(_originMarkerId);

    await style.addSource(
      GeoJsonSource(
        id: _originMarkerId,
        data: jsonEncode({
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [origin!.coordinates.lng, origin!.coordinates.lat],
          },
        }),
      ),
    );
    await style.addLayer(
      CircleLayer(
        id: _originMarkerId,
        sourceId: _originMarkerId,
        circleRadius: 10.0,
        circleColor: AppColors.primaryBurgundyLight.toARGB32(),
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
  }

  Future<void> _addDestMarker() async {
    if (mapboxMap == null || destination == null) return;
    final style = mapboxMap!.style;
    if (await style.styleLayerExists(_destMarkerId))
      await style.removeStyleLayer(_destMarkerId);
    if (await style.styleSourceExists(_destMarkerId))
      await style.removeStyleSource(_destMarkerId);

    await style.addSource(
      GeoJsonSource(
        id: _destMarkerId,
        data: jsonEncode({
          "type": "Feature",
          "geometry": {
            "type": "Point",
            "coordinates": [
              destination!.coordinates.lng,
              destination!.coordinates.lat,
            ],
          },
        }),
      ),
    );
    await style.addLayer(
      CircleLayer(
        id: _destMarkerId,
        sourceId: _destMarkerId,
        circleRadius: 10.0,
        circleColor: AppColors.riskRed.toARGB32(),
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
  }

  Future<void> _drawRoute(Point start, Point end) async {
    if (mapboxMap == null || accessToken == null) return;
    setState(() => isLoading = true);
    try {
      final directDistance = _calculateDistance(
        Position(start.coordinates.lng, start.coordinates.lat),
        Position(end.coordinates.lng, end.coordinates.lat),
      );
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/$_profile/${start.coordinates.lng},${start.coordinates.lat};${end.coordinates.lng},${end.coordinates.lat}?'
        'geometries=geojson&overview=full&access_token=$accessToken&alternatives=true&annotations=duration,distance',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (data['routes'] == null || data['routes'].isEmpty) return;

      final List routes = data['routes'];
      final List<Map<String, dynamic>> routeOptions = [];
      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final geometry = route['geometry'];
        final List<Map<String, double>> coordinates = _extractCoordinates(
          geometry,
        );
        final riskData = await _routeRiskService.calculateRouteRisk(
          routeCoordinates: coordinates,
          directDistanceKm: directDistance,
        );
        routeOptions.add({
          'route_index': i,
          'route': route,
          'geometry': geometry,
          'duration': route['duration'] as double,
          'distance': route['distance'] as double,
          'risk_score': riskData['risk_score'] as double,
          'risk_level': riskData['risk_level'] as String,
          'safe_percentage': riskData['safe_percentage'] as double,
          'high_risk_segments': riskData['high_risk_segments'] as int,
          'detour_factor': riskData['detour_factor'] as double,
        });
      }

      final fastestDuration = routeOptions
          .map((r) => r['duration'] as double)
          .reduce((a, b) => a < b ? a : b);
      final safestRisk = routeOptions
          .map((r) => r['risk_score'] as double)
          .reduce((a, b) => a < b ? a : b);

      for (int i = 0; i < routeOptions.length; i++) {
        final option = routeOptions[i];
        final isFastest = option['duration'] == fastestDuration;
        final isSafest = option['risk_score'] == safestRisk;
        if (isFastest && isSafest) {
          option['label'] = '🟢 Best Overall';
          option['label_color'] = AppColors.riskGreen;
        } else if (isSafest) {
          option['label'] = '🟢 Safest';
          option['label_color'] = AppColors.riskGreen;
        } else if (isFastest) {
          option['label'] = '⚡ Fastest';
          option['label_color'] = AppColors.riskOrange;
        } else {
          option['label'] = '🟡 Balanced';
          option['label_color'] = AppColors.riskYellow;
        }
      }
      routeOptions.sort((a, b) {
        final riskCompare = a['risk_score'].compareTo(b['risk_score']);
        if (riskCompare != 0) return riskCompare;
        return a['duration'].compareTo(b['duration']);
      });

      if (!mounted) return;
      setState(() {
        _routeOptions = routeOptions;
        _selectedRouteIndex = 0;
        _routeDistance =
            '${(routeOptions[0]['distance'] / 1000).toStringAsFixed(2)} km';
        _routeDuration =
            '${(routeOptions[0]['duration'] / 60).toStringAsFixed(0)} min';
      });
      await _drawSelectedRoute();
    } catch (e, stack) {
      debugPrint("❌ Route error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<Map<String, double>> _extractCoordinates(dynamic geometry) {
    final List<Map<String, double>> coordinates = [];
    if (geometry == null || geometry['coordinates'] == null) return coordinates;
    final coords = geometry['coordinates'] as List;
    for (var coord in coords) {
      if (coord is List && coord.length >= 2) {
        coordinates.add({
          'lng': (coord[0] as num).toDouble(),
          'lat': (coord[1] as num).toDouble(),
        });
      }
    }
    return coordinates;
  }

  Future<void> _drawSelectedRoute() async {
    if (mapboxMap == null ||
        _routeOptions.isEmpty ||
        _selectedRouteIndex >= _routeOptions.length)
      return;
    final selectedRoute = _routeOptions[_selectedRouteIndex];
    final geometry = selectedRoute['geometry'];
    if (geometry == null) return;
    final style = mapboxMap!.style;
    if (await style.styleLayerExists(_routeLayerId))
      await style.removeStyleLayer(_routeLayerId);
    if (await style.styleSourceExists(_routeSourceId))
      await style.removeStyleSource(_routeSourceId);
    await style.addSource(
      GeoJsonSource(id: _routeSourceId, data: jsonEncode(geometry)),
    );
    final routeColor =
        (selectedRoute['label_color'] as Color?) ??
        AppColors.primaryBurgundyLight;
    await style.addLayer(
      LineLayer(
        id: _routeLayerId,
        sourceId: _routeSourceId,
        lineColor: routeColor.toARGB32(),
        lineWidth: 6.0,
        lineJoin: LineJoin.ROUND,
        lineCap: LineCap.ROUND,
      ),
    );
  }

  Future<void> _clearRoute() async {
    if (mapboxMap == null) return;
    final style = mapboxMap!.style;
    if (await style.styleLayerExists(_routeLayerId))
      await style.removeStyleLayer(_routeLayerId);
    if (!mounted) return;
    setState(() {
      destination = null;
      _destController.clear();
      _routeDistance = null;
      _routeDuration = null;
      _showDestSuggestions = false;
      _destSuggestions = [];
      _routeOptions = [];
      _selectedRouteIndex = 0;
    });
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    try {
      String? locationLink;
      try {
        final position = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
          ),
        );
        locationLink =
            'http://maps.google.com/maps?q=${position.latitude},${position.longitude}';
      } catch (e) {
        debugPrint('⚠️ Location not available for SOS: $e');
      }
      await SOSService.sendSOSSMS(locationLink);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('🚨 SOS alert sent!'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ SOS failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleHeatmap() async {
    setState(() => _showRiskHeatmap = !_showRiskHeatmap);
    if (_showRiskHeatmap) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔍 Tip: Zoom in for detailed risk view'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 3),
          ),
        );
      if (_heatmapData.isEmpty && origin != null)
        await _loadHeatmapData();
      else
        await _addHeatmapLayer();
    } else {
      if (mapboxMap != null) {
        final style = mapboxMap!.style;
        if (await style.styleLayerExists('risk-heatmap'))
          await style.removeStyleLayer('risk-heatmap');
        if (await style.styleSourceExists('risk-source'))
          await style.removeStyleSource('risk-source');
      }
    }
  }

  Future<void> _loadHeatmapData() async {
    if (mapboxMap == null) return;
    try {
      const double minLat = 18.85,
          maxLat = 19.55,
          minLng = 72.70,
          maxLng = 73.10;
      final data = _riskService.generateHeatmapData(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        resolution: 60,
      );
      if (data.isNotEmpty && mounted) {
        setState(() => _heatmapData = data);
        await _addHeatmapLayer();
      }
    } catch (e, stack) {
      print('❌ Error: $e');
    }
  }

  Future<void> _addHeatmapLayer() async {
    if (mapboxMap == null || _heatmapData.isEmpty) return;
    final style = mapboxMap!.style;
    try {
      if (await style.styleLayerExists('risk-heatmap'))
        await style.removeStyleLayer('risk-heatmap');
      if (await style.styleSourceExists('risk-source'))
        await style.removeStyleSource('risk-source');
      final features = _heatmapData
          .map(
            (point) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [point['lng'], point['lat']],
              },
              'properties': {
                'risk': point['risk_score'] ?? 0.5,
                'level': point['risk_level'] ?? 'moderate',
              },
            },
          )
          .toList();
      await style.addSource(
        GeoJsonSource(
          id: 'risk-source',
          data: jsonEncode({'type': 'FeatureCollection', 'features': features}),
        ),
      );
      await style.addLayer(
        HeatmapLayer(
          id: 'risk-heatmap',
          sourceId: 'risk-source',
          heatmapRadius: 50.0,
          heatmapIntensity: 0.8,
        ),
      );
      await style.setStyleLayerProperty('risk-heatmap', 'heatmap-radius', [
        'interpolate',
        ['linear'],
        ['zoom'],
        9,
        25,
        10,
        35,
        11,
        50,
        12,
        65,
        13,
        75,
        14,
        85,
        15,
        95,
        16,
        105,
        17,
        115,
        18,
        125,
      ]);
      await style.setStyleLayerProperty('risk-heatmap', 'heatmap-intensity', [
        'interpolate',
        ['linear'],
        ['zoom'],
        9,
        0.25,
        10,
        0.35,
        11,
        0.55,
        12,
        0.75,
        13,
        0.90,
        14,
        1.05,
        15,
        1.20,
        16,
        1.35,
        17,
        1.50,
        18,
        1.65,
      ]);
      await style.setStyleLayerProperty('risk-heatmap', 'heatmap-weight', [
        'get',
        'risk',
      ]);
      await style.setStyleLayerProperty('risk-heatmap', 'heatmap-color', [
        'interpolate',
        ['linear'],
        ['heatmap-density'],
        0,
        'rgba(101, 163, 13, 0.4)',
        0.25,
        'rgba(202, 138, 4, 0.7)',
        0.5,
        'rgba(234, 88, 12, 0.85)',
        0.75,
        'rgba(220, 38, 38, 0.92)',
        1,
        'rgba(127, 29, 29, 0.97)',
      ]);
    } catch (e, stack) {
      print('❌ Error: $e');
    }
  }

  void _startJourney() {
    if (!mounted || origin == null || destination == null) return;
    setState(() {
      _isJourneyActive = true;
      _journeyHistory = [];
      _journeyProgress = 0.0;
    });
    _startLocationTracking();
    _startPeriodicSharing();
  }

  void _startLocationTracking() {
    final settings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: 10,
    );
    _locationSubscription =
        geo.Geolocator.getPositionStream(locationSettings: settings).listen((
          geo.Position position,
        ) {
          if (!mounted || !_isJourneyActive) return;
          setState(() {
            _journeyHistory.add(position);
            _updateJourneyProgress(position);
          });
          _followUserLocation(position);
          _checkRiskZone(position);
        });
  }

  void _updateJourneyProgress(geo.Position currentPos) {
    if (origin == null || destination == null) return;
    final start = origin!.coordinates;
    final end = destination!.coordinates;
    final current = Position(currentPos.longitude, currentPos.latitude);
    final totalDistance = _calculateDistance(start, end);
    final traveledDistance = _calculateDistance(start, current);
    setState(() {
      _journeyProgress = (traveledDistance / totalDistance).clamp(0.0, 1.0);
      _currentETA = _calculateETA(traveledDistance, totalDistance);
    });
    if (_calculateDistance(current, end) < 0.05) _endJourney();
  }

  Future<void> _shareCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
      final locationLink =
          'http://maps.google.com/maps?q=${position.latitude},${position.longitude}';
      await SOSService.sendSOSSMS(locationLink);
    } catch (e) {
      debugPrint('❌ Failed to share location: $e');
    }
  }

  void _startPeriodicSharing() {
    Future.delayed(const Duration(minutes: 3), () {
      if (mounted && _isJourneyActive) {
        _shareCurrentLocation();
        _startPeriodicSharing();
      }
    });
  }

  void _followUserLocation(geo.Position position) {
    mapboxMap?.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: 16.0,
        pitch: 45.0,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  void _endJourney() {
    if (!_isJourneyActive) return;
    setState(() {
      _isJourneyActive = false;
      _journeyProgress = 1.0;
    });
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  double _calculateDistance(Position a, Position b) {
    const double earthRadius = 6371;
    final dLat = _toRadians((b.lat - a.lat).toDouble());
    final dLon = _toRadians((b.lng - a.lng).toDouble());
    final lat1 = _toRadians(a.lat.toDouble());
    final lat2 = _toRadians(b.lat.toDouble());
    final haversine =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * (math.pi / 180);
  String _calculateETA(double traveled, double total) {
    if (traveled >= total) return 'Arrived';
    final remainingKm = total - traveled;
    final minutes = (remainingKm / 5.0 * 60).round();
    return '~$minutes min';
  }

  Future<void> _checkRiskZone(geo.Position position) async {
    if (!_showRiskHeatmap || !_isJourneyActive) return;
    final riskData = _riskService.getRiskForLocation(
      position.latitude,
      position.longitude,
    );
    if (riskData['risk_level'] == 'critical') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚨 CRITICAL RISK: ${riskData['area_name'] ?? 'This area'}\nStay alert!',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 5),
        ),
      );
    } else if (riskData['risk_level'] == 'high') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '⚠️ High risk: ${riskData['area_name'] ?? 'This area'}\nStay aware.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange[800],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _isDarkMode = isDark;

    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppColors.bgDarkStart, AppColors.bgDarkEnd]
          : [AppColors.bgLightStart, AppColors.bgLightEnd],
    );
    final glassColor = isDark ? AppColors.glassDark : AppColors.glassLight;
    final textColorMain = isDark
        ? AppColors.textDarkMain
        : AppColors.textLightMain;
    final textColorSub = isDark
        ? AppColors.textDarkSub
        : AppColors.textLightSub;
    final accentColor = isDark
        ? AppColors.primaryBurgundyDark
        : AppColors.primaryBurgundyLight;
    final iconColor = isDark
        ? AppColors.secondaryRoseGold
        : AppColors.secondaryTaupe;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(decoration: BoxDecoration(gradient: bgGradient)),

          // 2. Map Widget
          mapbox.MapWidget(
            styleUri: MapboxStyles.MAPBOX_STREETS,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: (StyleLoadedEventData data) =>
                _add3DBuildings(),
          ),

          // 3. Loading Indicator
          if (isLoading) const Center(child: CircularProgressIndicator()),

          // 4. Compact Top Search Bar (Side-by-Side)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: glassColor,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Source Field
                      Expanded(
                        child: _buildCompactSearchField(
                          controller: _sourceController,
                          hint: "From",
                          suggestions: _sourceSuggestions,
                          visible: _showSourceSuggestions,
                          onSelect: (p) => _selectSuggestion(p, true),
                          onClear: () => setState(() {
                            _showSourceSuggestions = false;
                            _sourceSuggestions = [];
                          }),
                          textColor: textColorMain,
                          subColor: textColorSub,
                          iconColor: iconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Destination Field
                      Expanded(
                        child: _buildCompactSearchField(
                          controller: _destController,
                          hint: "To",
                          suggestions: _destSuggestions,
                          visible: _showDestSuggestions,
                          onSelect: (p) => _selectSuggestion(p, false),
                          onClear: () {
                            setState(() {
                              _showDestSuggestions = false;
                              _destSuggestions = [];
                            });
                            _clearRoute();
                          },
                          textColor: textColorMain,
                          subColor: textColorSub,
                          iconColor: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Route Selection Card (Moved down slightly to avoid search bar)
          if (_routeOptions.length > 1 &&
              destination != null &&
              !_isJourneyActive)
            Positioned(
              top: 130,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: glassColor,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🗺️ Choose Route',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColorMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _routeOptions.length,
                            itemBuilder: (ctx, i) {
                              final option = _routeOptions[i];
                              final isSelected = i == _selectedRouteIndex;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedRouteIndex = i);
                                  _drawSelectedRoute();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accentColor.withOpacity(0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentColor
                                          : Colors.white.withOpacity(0.1),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: isSelected
                                            ? accentColor
                                            : iconColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  option['label'] ?? 'Route',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        option['label_color'],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${(option['duration'] / 60).toStringAsFixed(0)} min',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: textColorSub,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${(option['distance'] / 1000).toStringAsFixed(1)} km • ${option['safe_percentage'].toStringAsFixed(0)}% safe',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: textColorSub,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 6. Bottom Action Area (SOS + Risk Toggle + Start Button)
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Action Row: SOS & Risk Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Risk Toggle Button
                    GestureDetector(
                      onTap: _toggleHeatmap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(35),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: glassColor,
                              border: Border.all(
                                color: _showRiskHeatmap
                                    ? AppColors.riskRed
                                    : Colors.white.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(35),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.thermostat,
                                  color: _showRiskHeatmap
                                      ? AppColors.riskRed
                                      : iconColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _showRiskHeatmap ? "Risk On" : "Risk Off",
                                  style: TextStyle(
                                    color: _showRiskHeatmap
                                        ? AppColors.riskRed
                                        : iconColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // SOS Button
                    GestureDetector(
                      onTap: _triggerSOS,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sos,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Start Journey Card
                if (destination != null || _isJourneyActive)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: glassColor,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.4 : 0.1,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: _isJourneyActive
                            ? _buildTrackingCard(
                                textColorMain,
                                textColorSub,
                                accentColor,
                              )
                            : _buildStartButtonCard(
                                textColorMain,
                                textColorSub,
                                accentColor,
                                iconColor,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ New Compact Search Field Widget
  Widget _buildCompactSearchField({
    required TextEditingController controller,
    required String hint,
    required List<Map<String, dynamic>> suggestions,
    required bool visible,
    required Function(Map<String, dynamic>) onSelect,
    required VoidCallback onClear,
    required Color textColor,
    required Color subColor,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: subColor, fontSize: 12),
              prefixIcon: Icon(Icons.location_on, color: iconColor, size: 16),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 14, color: iconColor),
                      onPressed: onClear,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
          ),
        ),
        if (visible && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (ctx, i) => ListTile(
                dense: true,
                leading: Icon(Icons.location_on, size: 16, color: iconColor),
                title: Text(
                  suggestions[i]['display_name'],
                  style: TextStyle(fontSize: 11, color: textColor),
                ),
                onTap: () => onSelect(suggestions[i]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color glassColor,
    required Color iconColor,
    String? label,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: glassColor,
              border: Border.all(
                color: isActive
                    ? AppColors.riskRed
                    : Colors.white.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive ? AppColors.riskRed : iconColor,
                  size: 20,
                ),
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? AppColors.riskRed : iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStartButtonCard(
    Color textMain,
    Color textSub,
    Color accent,
    Color iconCol,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _profile == 'walking'
                        ? Icons.directions_walk
                        : _profile == 'cycling'
                        ? Icons.directions_bike
                        : Icons.directions_car,
                    color: accent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready?',
                      style: TextStyle(color: textSub, fontSize: 11),
                    ),
                    Text(
                      '${_routeDuration ?? '--'} • ${_routeDistance ?? '--'}',
                      style: TextStyle(
                        color: textMain,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.riskGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.riskGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield,
                    size: 12,
                    color: AppColors.riskGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_routeOptions.isNotEmpty ? _routeOptions[_selectedRouteIndex]['safe_percentage'].toStringAsFixed(0) : 0}%',
                    style: const TextStyle(
                      color: AppColors.riskGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildModeOption(Icons.directions_walk, 'walking', accent, iconCol),
            _buildModeOption(Icons.directions_bike, 'cycling', accent, iconCol),
            _buildModeOption(Icons.directions_car, 'driving', accent, iconCol),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _startJourney,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: accent.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.navigation, size: 18),
                SizedBox(width: 8),
                Text(
                  'Start Journey',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeOption(
    IconData icon,
    String mode,
    Color accent,
    Color iconCol,
  ) {
    bool isActive = _profile == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _profile = mode);
        if (origin != null && destination != null)
          _drawRoute(origin!, destination!);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? accent : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Icon(icon, color: isActive ? Colors.white : iconCol, size: 20),
      ),
    );
  }

  Widget _buildTrackingCard(Color textMain, Color textSub, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.radio_button_checked, color: accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'In Progress',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textMain,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Text(
              _currentETA ?? '--',
              style: TextStyle(
                color: textSub,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _journeyProgress,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareCurrentLocation,
                icon: const Icon(Icons.share_location, size: 16),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textMain,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _endJourney,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text(
                  'End',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
