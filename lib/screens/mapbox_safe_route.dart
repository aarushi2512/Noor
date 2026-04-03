// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:noor_new/services/route_risk_service.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noor_new/services/offline_risk_service.dart';
import 'package:geolocator/geolocator.dart'
    as geo
    show Geolocator, Position, LocationAccuracy, LocationSettings;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:noor_new/services/sos_service.dart';

class MapboxSafeRoute extends StatefulWidget {
  const MapboxSafeRoute({super.key});

  @override
  State<MapboxSafeRoute> createState() => _MapboxSafeRouteState();
}

class _MapboxSafeRouteState extends State<MapboxSafeRoute> {
  final OfflineRiskService _riskService = OfflineRiskService();
  MapboxMap? mapboxMap;
  String? accessToken;

  Point? origin;
  Point? destination;
  bool isLoading = false;
  String? _routeDistance;
  String? _routeDuration;
  
  // ✅ Route risk scoring variables
  List<Map<String, dynamic>> _routeOptions = [];
  int _selectedRouteIndex = 0;
  final RouteRiskService _routeRiskService = RouteRiskService();
  
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

  // ✅ Risk heatmap variables
  bool _showRiskHeatmap = false;
  List<Map<String, dynamic>> _heatmapData = [];

  @override
  void initState() {
    super.initState();

    // ✅ Initialize offline risk service (loads JSON from assets)
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
        origin = Point(coordinates: Position(72.8561, 19.2435));
        _sourceController.text = 'SFIT, Borivali';
      });
      _moveCamera();
      _addOriginMarker();
    }
  }

  void _onMapCreated(MapboxMap map) {
    mapboxMap = map;
    _moveCamera();

    // ✅ Just add 3D buildings - NO camera listener
    _add3DBuildings();
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

      debugPrint('✅ 3D buildings layer added');
    } catch (e) {
      debugPrint('❌ Failed to add 3D buildings: $e');
    }
  }

  void _moveCamera() {
    if (mapboxMap != null && origin != null) {
      mapboxMap!.flyTo(
        CameraOptions(center: origin, zoom: 16.0, pitch: 45.0),
        MapAnimationOptions(duration: 1000),
      );
    }
  }

  void _debouncedSearch(String query, bool isSource) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      _onSearchChanged(query, isSource);
    });
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
    if (origin != null && destination != null) {
      _drawRoute(origin!, destination!);
    }
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
        circleColor: Colors.blue.toARGB32(),
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
        circleColor: Colors.red.toARGB32(),
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );
  }

  // ✅ FULL UPDATED _drawRoute() with route alternatives + risk scoring
  Future<void> _drawRoute(Point start, Point end) async {
    if (mapboxMap == null || accessToken == null) return;
    setState(() => isLoading = true);

    try {
      // ✅ Calculate direct distance between start/end (for detour penalty)
      final directDistance = _calculateDistance(
        Position(start.coordinates.lng, start.coordinates.lat),
        Position(end.coordinates.lng, end.coordinates.lat),
      );
      print(
        '📏 [DEBUG] Direct distance: ${directDistance.toStringAsFixed(2)} km',
      );

      // ✅ Fetch MULTIPLE routes (alternatives=true)
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/$_profile/'
        '${start.coordinates.lng},${start.coordinates.lat};'
        '${end.coordinates.lng},${end.coordinates.lat}?'
        'geometries=geojson&overview=full&access_token=$accessToken'
        '&alternatives=true'
        '&annotations=duration,distance',
      );

      print('🔍 [DEBUG] Fetching routes: $url');
      final res = await http.get(url);

      if (res.statusCode != 200) {
        print('❌ [DEBUG] Route API error: ${res.statusCode}');
        return;
      }

      final data = jsonDecode(res.body);

      if (data['routes'] == null || data['routes'].isEmpty) {
        print('❌ [DEBUG] No routes found');
        return;
      }

      final List routes = data['routes'];
      print('✅ [DEBUG] Found ${routes.length} route alternatives');

      // ✅ Calculate risk for EACH route (with direct distance for detour penalty)
      final List<Map<String, dynamic>> routeOptions = [];

      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        final geometry = route['geometry'];

        // Extract coordinates from route geometry
        final List<Map<String, double>> coordinates = _extractCoordinates(
          geometry,
        );

        // Calculate risk for this route (with detour penalty)
        final riskData = await _routeRiskService.calculateRouteRisk(
          routeCoordinates: coordinates,
          directDistanceKm: directDistance, // ✅ Pass direct distance
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

        print(
          '🔍 [DEBUG] Route $i: ${route['duration'] / 60}min, '
          'risk: ${riskData['risk_score'].toStringAsFixed(2)}, '
          'detour: ${riskData['detour_factor'].toStringAsFixed(1)}x',
        );
      }

      // ✅ IMPROVED: Label routes with proper logic
      // Find the fastest route by duration
      final fastestDuration = routeOptions
          .map((r) => r['duration'] as double)
          .reduce((a, b) => a < b ? a : b);

      // Find the safest route by risk score  
      final safestRisk = routeOptions
          .map((r) => r['risk_score'] as double)
          .reduce((a, b) => a < b ? a : b);

      // Label each route
      for (int i = 0; i < routeOptions.length; i++) {
        final option = routeOptions[i];
        final isFastest = option['duration'] == fastestDuration;
        final isSafest = option['risk_score'] == safestRisk;

        if (isFastest && isSafest) {
          option['label'] = '🟢⚡ Best Overall';
          option['label_color'] = Colors.teal;
        } else if (isSafest) {
          option['label'] = '🟢 Safest';
          option['label_color'] = Colors.green;
        } else if (isFastest) {
          option['label'] = '⚡ Fastest';
          option['label_color'] = Colors.orange;
        } else {
          option['label'] = '🟡 Balanced';
          option['label_color'] = Colors.amber[700];
        }
        print('🏷️ [DEBUG] Route ${option['route_index']}: ${option['label']}');
      }

      // ✅ Sort: Safest first, then fastest (for default selection)
      routeOptions.sort((a, b) {
        // Primary: Risk score (lower is safer)
        final riskCompare = a['risk_score'].compareTo(b['risk_score']);
        if (riskCompare != 0) return riskCompare;
        // Secondary: Duration (lower is faster)
        return a['duration'].compareTo(b['duration']);
      });

      if (!mounted) return;
      setState(() {
        _routeOptions = routeOptions;
        _selectedRouteIndex = 0; // Default to safest
        _routeDistance =
            '${(routeOptions[0]['distance'] / 1000).toStringAsFixed(2)} km';
        _routeDuration =
            '${(routeOptions[0]['duration'] / 60).toStringAsFixed(0)} min';
      });

      // ✅ Draw the safest route by default
      await _drawSelectedRoute();
      print('✅ [DEBUG] Drew default route (index 0)');

    } catch (e, stack) {
      debugPrint("❌ Route error: $e");
      debugPrint("❌ Stack: $stack");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✅ Helper: Extract coordinates from GeoJSON geometry
  List<Map<String, double>> _extractCoordinates(dynamic geometry) {
    final List<Map<String, double>> coordinates = [];
    
    if (geometry == null || geometry['coordinates'] == null) {
      return coordinates;
    }
    
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

  // ✅ Draw the currently selected route
  Future<void> _drawSelectedRoute() async {
    if (mapboxMap == null) return;
    if (_routeOptions.isEmpty || _selectedRouteIndex >= _routeOptions.length) {
      print('⚠️ [DEBUG] Cannot draw route: no options or invalid index');
      return;
    }
    
    final selectedRoute = _routeOptions[_selectedRouteIndex];
    final geometry = selectedRoute['geometry'];
    
    if (geometry == null) {
      print('❌ [DEBUG] No geometry for selected route');
      return;
    }
    
    final style = mapboxMap!.style;
    
    // Clean up existing route layer
    if (await style.styleLayerExists(_routeLayerId)) {
      await style.removeStyleLayer(_routeLayerId);
    }
    if (await style.styleSourceExists(_routeSourceId)) {
      await style.removeStyleSource(_routeSourceId);
    }

    // Add new source and layer
    await style.addSource(
      GeoJsonSource(
        id: _routeSourceId, 
        data: jsonEncode(geometry),
      ),
    );
    
    final routeColor = (selectedRoute['label_color'] as Color?) ?? Colors.teal;
    
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
    
    print('✅ [DEBUG] Drew route ${selectedRoute['route_index']}: ${selectedRoute['label']}');
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
      // ✅ Also reset route options
      _routeOptions = [];
      _selectedRouteIndex = 0;
    });
  }

  Future<void> _triggerSOS() async {
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
                Text('🚨 SOS alert sent to trusted contacts!'),
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

  // ✅ NEW: Toggle risk heatmap
  Future<void> _toggleHeatmap() async {
    setState(() {
      _showRiskHeatmap = !_showRiskHeatmap;
    });

    if (_showRiskHeatmap) {
      // Show helpful hint to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔍 Tip: Zoom in for detailed risk view'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Load heatmap data
      if (_heatmapData.isEmpty && origin != null) {
        await _loadHeatmapData();
      } else {
        await _addHeatmapLayer();
      }
    } else {
      // Hide heatmap when toggled off
      if (mapboxMap != null) {
        final style = mapboxMap!.style;
        if (await style.styleLayerExists('risk-heatmap')) {
          await style.removeStyleLayer('risk-heatmap');
        }
        if (await style.styleSourceExists('risk-source')) {
          await style.removeStyleSource('risk-source');
        }
      }
    }
  }

  // ✅ NEW: Load heatmap data
  Future<void> _loadHeatmapData() async {
    print('[DEBUG] Starting OFFLINE _loadHeatmapData()');

    if (mapboxMap == null) {
      print('❌ [DEBUG] mapboxMap is null');
      return;
    }

    try {
      // ✅ FIXED BOUNDING BOX: Covers ALL of Greater Mumbai
      const double minLat = 18.85; // Colaba (South Mumbai)
      const double maxLat = 19.55; // Vasai-Virar (North)
      const double minLng = 72.70; // Arabian Sea (West)
      const double maxLng = 73.10; // Thane Creek (East)

      print('🔥 [DEBUG] Generating offline heatmap for ENTIRE Mumbai...');

      final data = _riskService.generateHeatmapData(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        resolution: 60,
      );

      print('🔥 [DEBUG] Generated ${data.length} points offline');

      if (data.isNotEmpty && mounted) {
        setState(() {
          _heatmapData = data;
        });
        await _addHeatmapLayer();
        print('✅ [DEBUG] Heatmap layer added successfully');
      }
    } catch (e, stack) {
      print('❌ [DEBUG] Error: $e');
      print('❌ [DEBUG] Stack: $stack');
    }
  }

  // ✅ Center camera on Mumbai (unused but kept for reference)
  void _centerOnMumbai() {
    if (mapboxMap != null) {
      mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(72.85, 19.15),
          ), // Center of Mumbai
          zoom: 10.0, // ✅ Zoomed out to show all Mumbai
          pitch: 0.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }
  }
  Future<void> _addHeatmapLayer() async {
    print('🔥 [DEBUG] _addHeatmapLayer() with ${_heatmapData.length} points');

    if (mapboxMap == null || _heatmapData.isEmpty) {
      print('❌ [DEBUG] mapboxMap null or no data');
      return;
    }

    final style = mapboxMap!.style;

    try {
      // Clean up existing layers
      if (await style.styleLayerExists('risk-heatmap')) {
        await style.removeStyleLayer('risk-heatmap');
      }
      if (await style.styleSourceExists('risk-source')) {
        await style.removeStyleSource('risk-source');
      }

      // Build GeoJSON features
      final features = _heatmapData.map((point) {
        return {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [point['lng'], point['lat']],
          },
          'properties': {
            'risk': point['risk_score'] ?? 0.5,
            'level': point['risk_level'] ?? 'moderate',
          },
        };
      }).toList();

      final geojson = {'type': 'FeatureCollection', 'features': features};

      // Add source
      await style.addSource(
        GeoJsonSource(
          id: 'risk-source',
          data: jsonEncode(geojson),
        ),
      );
      print('✅ Source added');

      // ✅ BASE LAYER: Balanced starting point
      await style.addLayer(
        HeatmapLayer(
          id: 'risk-heatmap',
          sourceId: 'risk-source',
          heatmapRadius: 50.0,
          heatmapIntensity: 0.8,
        ),
      );
      print('✅ Base layer added');

      // ✅ TUNED FOR ZOOM 11-12 (15km = 1/4 screen):
      await style.setStyleLayerProperty(
        'risk-heatmap',
        'heatmap-radius',
        [
          'interpolate',
          ['linear'],
          ['zoom'],
          9, 25,   // ✅ Visible but not overwhelming (India view)
          10, 35,  // ✅ Light coverage (West India)
          11, 50,  // ✅ ✅ PERFECT for 15km = 1/4 screen!
          12, 65,  // ✅ ✅ Great for city view
          13, 75,  // ✅ Balanced
          14, 85,  // ✅ Good for area view
          15, 95,  // ✅ Detailed neighborhood
          16, 105, // ✅ Clear street-level detail
          17, 115, // ✅ Red spots concentrated
          18, 125, // ✅ Maximum detail
        ],
      );
      print('✅ Dynamic radius applied (tuned for zoom 11-12)');

      // ✅ TUNED INTENSITY: Colors visible at zoom 11-12
      await style.setStyleLayerProperty(
        'risk-heatmap',
        'heatmap-intensity',
        [
          'interpolate',
          ['linear'],
          ['zoom'],
          9, 0.25,  // ✅ Light but visible (India view)
          10, 0.35, // ✅ Visible gradient (West India)
          11, 0.55, // ✅ ✅ PERFECT for 15km = 1/4 screen!
          12, 0.75, // ✅ ✅ Great contrast for city view
          13, 0.90, // ✅ Balanced
          14, 1.05, // ✅ Strong colors
          15, 1.20, // ✅ Clear neighborhood detail
          16, 1.35, // ✅ Vibrant street-level
          17, 1.50, // ✅ Red spots pop
          18, 1.65, // ✅ Maximum visibility
        ],
      );
      print('✅ Dynamic intensity applied (tuned for zoom 11-12)');

      // Set weight (risk-based coloring)
      await style.setStyleLayerProperty(
        'risk-heatmap',
        'heatmap-weight',
        ['get', 'risk'],
      );

      // ✅ VIBRANT color gradient (visible at all zooms)
      await style.setStyleLayerProperty(
        'risk-heatmap',
        'heatmap-color',
        [
          'interpolate',
          ['linear'],
          ['heatmap-density'],
          0, 'rgba(34, 197, 94, 0.4)',     // ✅ Green visible
          0.25, 'rgba(234, 179, 8, 0.7)',   // ✅ Yellow clear
          0.5, 'rgba(249, 115, 22, 0.85)',  // ✅ Orange strong
          0.75, 'rgba(239, 68, 68, 0.92)',  // ✅ Red very visible
          1, 'rgba(127, 29, 29, 0.97)',     // ✅ Dark red clear
        ],
      );
      print('✅ Color gradient applied (vibrant)');

      print('✅ Heatmap configured - visible at 15km = 1/4 screen!');

    } catch (e, stack) {
      print('❌ Error: $e');
      print('❌ Stack: $stack');
    }
  }

  // ✅ Hide heatmap layer
  Future<void> _hideHeatmapLayer() async {
    if (mapboxMap == null) return;

    final style = mapboxMap!.style;

    if (await style.styleLayerExists('risk-heatmap')) {
      await style.removeStyleLayer('risk-heatmap');
      print('✅ Heatmap layer hidden');
    }
    if (await style.styleSourceExists('risk-source')) {
      await style.removeStyleSource('risk-source');
      print('✅ Heatmap source hidden');
    }
  }

  // ✅ Check if user entered high-risk zone
  Future<void> _checkRiskZone(geo.Position position) async {
    if (!_showRiskHeatmap || !_isJourneyActive) return;

    final riskData = _riskService.getRiskForLocation(
      position.latitude,
      position.longitude,
    );

    // ✅ Show alert for critical/high risk
    if (riskData['risk_level'] == 'critical') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🚨 CRITICAL RISK: ${riskData['area_name'] ?? 'This area'}\n'
                  'Stay alert & avoid if possible',
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
                  '⚠️ High risk: ${riskData['area_name'] ?? 'This area'}\n'
                  'Stay aware of surroundings',
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

  void _startJourney() {
    if (!mounted || origin == null || destination == null) return;
    setState(() {
      _isJourneyActive = true;
      _journeyHistory = [];
      _journeyProgress = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🚶 Journey started! Tracking location...'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'Share',
          textColor: Colors.white,
          onPressed: _shareCurrentLocation,
        ),
      ),
    );

    _startLocationTracking();
    _startPeriodicSharing();
  }

  // ✅ UPDATED: Added _checkRiskZone call
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
          _checkRiskZone(position); // ✅ NEW: Check risk zone
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

    if (_calculateDistance(current, end) < 0.05) _endJourney(); // 50 meters
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Journey completed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  double _calculateDistance(Position a, Position b) {
    const double earthRadius = 6371; // km
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

  // ✅ FIXED: Removed duplicate @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Safe Sprout Navigation",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        actions: [
          // ✅ Heatmap toggle button
          IconButton(
            icon: Icon(
              _showRiskHeatmap ? Icons.thermostat : Icons.thermostat_outlined,
              color: _showRiskHeatmap ? Colors.red : Colors.white,
            ),
            onPressed: _toggleHeatmap,
            tooltip: 'Toggle Risk Heatmap',
          ),
          IconButton(
            icon: const Icon(Icons.sos, color: Colors.red, size: 30),
            onPressed: _triggerSOS,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapWidget(
            styleUri: MapboxStyles.MAPBOX_STREETS,
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: (StyleLoadedEventData data) =>
                _add3DBuildings(),
          ),
          
          // ✅ Heatmap hint
          if (_showRiskHeatmap)
            Positioned(
              bottom: 150,
              right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '🔴 Zoom in for details',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          
          // ✅ Loading indicator
          if (isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.teal)),
          
          // ✅ Search boxes
          Positioned(
            top: 20,
            left: 15,
            right: 15,
            child: Column(
              children: [
                _buildSearchBox(
                  controller: _sourceController,
                  hint: "Starting point",
                  suggestions: _sourceSuggestions,
                  visible: _showSourceSuggestions,
                  onSelect: (p) => _selectSuggestion(p, true),
                  onClear: () => setState(() {
                    _showSourceSuggestions = false;
                    _sourceSuggestions = [];
                  }),
                ),
                const SizedBox(height: 12),
                _buildSearchBox(
                  controller: _destController,
                  hint: "Destination building/place",
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
                ),
              ],
            ),
          ),
          
          // ✅ NEW: Route options selector (show when multiple routes available)
          if (_routeOptions.length > 1 &&
              destination != null &&
              !_isJourneyActive)
            Positioned(
              bottom: 180,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🗺️ Choose Your Route',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._routeOptions.map((option) {
                      final isSelected =
                          _routeOptions.indexOf(option) == _selectedRouteIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRouteIndex = _routeOptions.indexOf(option);
                          });
                          _drawSelectedRoute();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.teal.withOpacity(0.1)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.teal
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected ? Colors.teal : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          option['label'] ?? 'Route',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: option['label_color'],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${(option['duration'] / 60).toStringAsFixed(0)} min',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(option['distance'] / 1000).toStringAsFixed(1)} km • '
                                      '${option['safe_percentage'].toStringAsFixed(0)}% safe zones',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    // ✅ Show detour warning if route is much longer
                                    if ((option['detour_factor'] as double? ?? 1.0) > 1.5)
                                      Text(
                                        '⚠️ ${(((option['detour_factor'] as double) - 1) * 100).toStringAsFixed(0)}% longer than direct',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          
          // ✅ Transport mode buttons
          Positioned(
            bottom: 110,
            left: 25,
            right: 25,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _modeButton(Icons.directions_walk, "walking"),
                  _modeButton(Icons.directions_bike, "cycling"),
                  _modeButton(Icons.directions_car, "driving"),
                ],
              ),
            ),
          ),
          
          // ✅ Start Journey button (only show when destination is set)
          if (destination != null)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isJourneyActive
                        ? Colors.grey
                        : const Color(0xFFE57171),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _isJourneyActive ? _endJourney : _startJourney,
                  child: Text(
                    _isJourneyActive
                        ? 'End Journey'
                        : 'Start Journey • ${_routeDistance ?? ""}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          
          // ✅ Journey progress card (only during active journey)
          if (_isJourneyActive)
            Positioned(
              top: 180,
              left: 20,
              right: 20,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _journeyProgress,
                        color: Colors.teal,
                      ),
                      if (_currentETA != null)
                        Text(
                          'ETA: $_currentETA',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeButton(IconData icon, String mode) {
    bool active = _profile == mode;
    return IconButton(
      icon: Icon(icon, color: active ? Colors.teal : Colors.black45, size: 28),
      onPressed: () {
        setState(() => _profile = mode);
        if (origin != null && destination != null)
          _drawRoute(origin!, destination!);
      },
    );
  }

  Widget _buildSearchBox({
    required TextEditingController controller,
    required String hint,
    required List<Map<String, dynamic>> suggestions,
    required bool visible,
    required Function(Map<String, dynamic>) onSelect,
    required VoidCallback onClear,
  }) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
        if (visible && suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(
                  suggestions[i]['display_name'],
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                ),
                subtitle: Text(
                  suggestions[i]['display_name']
                      .split(',')
                      .skip(1)
                      .take(2)
                      .join(','),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                onTap: () => onSelect(suggestions[i]),
              ),
            ),
          ),
      ],
    );
  }
}