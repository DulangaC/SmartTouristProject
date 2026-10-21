import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'hazard_admin_page.dart';

class FinalPlanPage extends StatefulWidget {
  final Map<String, dynamic> result;
  final Map<String, dynamic> riskRequest;

  const FinalPlanPage({
    super.key,
    required this.result,
    required this.riskRequest,
  });

  @override
  State<FinalPlanPage> createState() => _FinalPlanPageState();
}

class _FinalPlanPageState extends State<FinalPlanPage> {
  Map<String, dynamic>? _selectedRoute;
  String _selectedRouteKey = '';
  bool _loadingHazardMap = false;
  static const _weatherCoordinates = <String, LatLng>{
    'Kandy': LatLng(7.2906,80.6337), 'Nuwara Eliya': LatLng(6.9497,80.7891),
    'Ella': LatLng(6.8667,81.0466), 'Sigiriya': LatLng(7.9570,80.7603),
    'Colombo': LatLng(6.9271,79.8612),
  };
  bool _screenAfterSelection = false;
  String? _hazardMapError;
  List<Map<String, dynamic>> _mapHazards = [];
  bool _mapLoaded = false;

  Future<void> _loadHazardMap() async {
    if (_loadingHazardMap) return;
    setState(() {
      _loadingHazardMap = true;
      _hazardMapError = null;
      _mapLoaded = false;
    });
    try {
      final url = Uri.parse(
        'http://127.0.0.1:8001/api/hazards/geojson?include_test=$_includeTestReports',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw Exception('Hazard map API ${response.statusCode}: ${response.body}');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['features'] is! List) {
        throw const FormatException('Unexpected GeoJSON response');
      }
      final hazards = <Map<String, dynamic>>[];
      for (final feature in data['features'] as List) {
        if (feature is! Map) continue;
        final geometry = feature['geometry'];
        final properties = feature['properties'];
        if (geometry is! Map || properties is! Map) continue;
        final coords = geometry['coordinates'];
        if (geometry['type'] != 'Point' || coords is! List || coords.length < 2) continue;
        final lon = coords[0];
        final lat = coords[1];
        if (lat is! num || lon is! num) continue;
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
        hazards.add({
          'lat': lat.toDouble(),
          'lon': lon.toDouble(),
          ...Map<String, dynamic>.from(properties),
        });
      }
      if (!mounted) return;
      setState(() {
        _mapHazards = hazards;
        _mapLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hazardMapError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingHazardMap = false);
    }
  }

  Widget _hazardMapSection() {
    final markers = _mapHazards.map((hazard) {
      final severity = (hazard['severity'] ?? '').toString().toLowerCase();
      final color = severity == 'high' ? Colors.red :
          severity == 'medium' ? Colors.orange : Colors.amber.shade800;
      return Marker(
        point: LatLng(hazard['lat'] as double, hazard['lon'] as double),
        width: 44,
        height: 44,
        child: Tooltip(
          message: '${hazard['hazard_type'] ?? 'Hazard'} (${hazard['severity'] ?? 'Unknown'})',
          child: GestureDetector(
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text('${hazard['hazard_type'] ?? 'Reported hazard'}'),
                  content: Text(
                    'Severity: ${hazard['severity'] ?? 'Unknown'}\n'
                    'Status: unverified\n'
                    'Description: ${hazard['description'] ?? '-'}\n'
                    'Coordinates: ${hazard['lat']}, ${hazard['lon']}',
                  ),
                  actions: [TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  )],
                ),
              );
            },
            child: Icon(Icons.location_on, size: 38, color: color),
          ),
        ),
      );
    }).toList();

    final selectedStops = (_selectedRoute?['destinations'] as List<dynamic>? ?? [])
        .whereType<Map>().map((p) => Map<String, dynamic>.from(p))
        .where((p) => p['lat'] is num && p['lon'] is num)
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble())).toList();
    final origin = LatLng((widget.riskRequest['start_lat'] as num?)?.toDouble() ?? 7.2906,
        (widget.riskRequest['start_lon'] as num?)?.toDouble() ?? 80.6337);
    final routePoints = selectedStops.isEmpty ? <LatLng>[] : [origin, ...selectedStops];
    final weatherPoint = _weatherCoordinates[_weatherLocation]!;
    final weatherMarkers = <Marker>[
      Marker(point:weatherPoint, width:46,height:46,
        child:Tooltip(message:'Weather station: $_weatherLocation',
          child:GestureDetector(onTap:_loadWeather,
            child:const Icon(Icons.cloud, size:36, color:Colors.teal))))
    ];
    final routeMarkers = <Marker>[
      for (var i = 0; i < selectedStops.length; i++)
        Marker(point: selectedStops[i], width: 26, height: 26,
          child: Tooltip(message: 'Stop ${i+1}: ${(_selectedRoute!['destinations'] as List)[i]['place_name']}',
            child: CircleAvatar(radius: 13, backgroundColor: Colors.blue.shade700,
              child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 12))))),
    ];
    final center = selectedStops.isNotEmpty ? selectedStops.first : _mapHazards.isNotEmpty
        ? LatLng(_mapHazards.first['lat'] as double, _mapHazards.first['lon'] as double)
        : const LatLng(7.2906, 80.6337);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reported hazard map',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Blue = selected itinerary straight-line legs, red/orange = unverified reports, teal cloud = supported weather station. Not real road navigation.'),
            if (_selectedRoute != null)
              Text('Selected: ${_routeTitle(_selectedRoute!)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Weather station: $_weatherLocation (tap the teal cloud to load its data).'),
            if (_liveWeather != null)
              Text('$_weatherLocation: ${_asMap(_liveWeather?['current'])?['temperature_c'] ?? '-'} °C; tomorrow precipitation: ${_asMap(_liveWeather?['tomorrow_forecast'])?['precipitation_sum_mm'] ?? '-'} mm'),
            if (_mlWeather != null)
              Text('Experimental rainfall screen: ${_mlWeather!['screening_result'] ?? '-'}'),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadingHazardMap ? null : _loadHazardMap,
              icon: _loadingHazardMap
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.map_outlined),
              label: Text(_loadingHazardMap ? 'Loading map reports...' : 'Load Hazard Map'),
            ),
            if (_hazardMapError != null)
              SelectableText('Map loading failed: $_hazardMapError',
                  style: const TextStyle(color: Colors.red)),
            if (_mapLoaded || _selectedRoute != null) ...[
              const SizedBox(height: 10),
              Text('Active reports shown: ${_mapHazards.length}'
                  '${_includeTestReports ? ' (TEST MODE)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SizedBox(
                height: 330,
                child: FlutterMap(
                  key: ValueKey(_selectedRouteKey),
                  options: MapOptions(initialCenter: center,
                      initialZoom: selectedStops.isNotEmpty ? 9 : _mapHazards.isNotEmpty ? 10 : 8),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.smart_tourist',
                    ),
                    if (routePoints.length > 1)
                      PolylineLayer(polylines: [Polyline(points: routePoints,
                        strokeWidth: 4, color: Colors.blue.shade700)]),
                    MarkerLayer(markers: [...markers, ...routeMarkers, ...weatherMarkers]),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(_mapHazards.isEmpty
                  ? 'No active reports match the selected test mode.'
                  : 'Tap a map marker to see the report details.'),
            ],
          ],
        ),
      ),
    );
  }

  bool _includeTestReports = false;
  String _weatherLocation = 'Kandy';
  bool _loadingWeather = false;
  String? _weatherError;
  Map<String, dynamic>? _liveWeather;
  Map<String, dynamic>? _mlWeather;

  Future<void> _loadWeather() async {
    if (_loadingWeather) return;
    setState(() {
      _loadingWeather = true;
      _weatherError = null;
      _liveWeather = null;
      _mlWeather = null;
    });
    try {
      final name = Uri.encodeQueryComponent(_weatherLocation);
      final responses = await Future.wait([
        http.get(Uri.parse('http://127.0.0.1:8001/api/weather/live?location=$name')),
        http.get(Uri.parse('http://127.0.0.1:8001/api/weather/forecast-assisted-ml?location=$name')),
      ]).timeout(const Duration(seconds: 45));
      for (final response in responses) {
        if (response.statusCode != 200) {
          throw Exception('Weather API ${response.statusCode}: ${response.body}');
        }
      }
      final live = jsonDecode(responses[0].body);
      final ml = jsonDecode(responses[1].body);
      if (live is! Map<String, dynamic> || ml is! Map<String, dynamic>) {
        throw const FormatException('Unexpected weather response');
      }
      if (!mounted) return;
      setState(() {
        _liveWeather = live;
        _mlWeather = ml;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _weatherError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingWeather = false);
    }
  }

  Widget _weatherSection() {
    final current = _asMap(_liveWeather?['current']);
    final tomorrow = _asMap(_liveWeather?['tomorrow_forecast']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live weather and rainfall screening',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Select one of the five supported weather stations. This is not a forecast for every itinerary stop.'),
            DropdownButton<String>(
              isExpanded: true,
              value: _weatherLocation,
              items: ['Kandy', 'Nuwara Eliya', 'Ella', 'Sigiriya', 'Colombo']
                  .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                  .toList(),
              onChanged: _loadingWeather ? null : (name) {
                if (name != null) setState(() {
                  _weatherLocation = name;
                  _liveWeather = null;
                  _mlWeather = null;
                  _weatherError = null;
                });
              },
            ),
            ElevatedButton.icon(
              onPressed: _loadingWeather ? null : _loadWeather,
              icon: _loadingWeather
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud),
              label: Text(_loadingWeather ? 'Loading weather...' : 'Check Weather and ML'),
            ),
            if (_weatherError != null) ...[
              const SizedBox(height: 8),
              SelectableText('Weather check failed: $_weatherError',
                  style: const TextStyle(color: Colors.red)),
            ],
            if (_liveWeather != null) ...[
              const Divider(),
              Text('Current conditions — ${_liveWeather!['location'] ?? _weatherLocation}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Time: ${current?['observed_at'] ?? '-'}'),
              Text('Temperature: ${current?['temperature_c'] ?? '-'} °C'),
              Text('Current rain: ${current?['rain_mm'] ?? '-'} mm'),
              Text('Wind speed: ${current?['wind_speed_kmh'] ?? '-'} km/h'),
              const SizedBox(height: 8),
              Text('Tomorrow (${tomorrow?['date'] ?? '-'}) — Open-Meteo forecast',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Expected precipitation: ${tomorrow?['precipitation_sum_mm'] ?? '-'} mm'),
              Text('Temperature: ${tomorrow?['temperature_min_c'] ?? '-'} to ${tomorrow?['temperature_max_c'] ?? '-'} °C'),
            ],
            if (_mlWeather != null) ...[
              const Divider(),
              const Text('Experimental Random Forest screening',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Target: ${_mlWeather!['prediction_target'] ?? '-'}'),
              Text('Date: ${_mlWeather!['predicted_date'] ?? '-'}'),
              Text('Result: ${_mlWeather!['screening_result'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Model score: ${_mlWeather!['random_forest_score'] ?? '-'}'),
              Text('Classification threshold: ${_mlWeather!['classification_threshold'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('${_mlWeather!['warning'] ?? ''}',
                  style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  bool _checking = false;
  String? _riskError;
  Map<String, dynamic>? _riskResult;

  Future<void> _checkHazards() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _riskError = null;
    });

    try {
      final request = Map<String, dynamic>.from(widget.riskRequest);
      request['include_test'] = _includeTestReports;
      if (_selectedRoute != null) request['selected_route'] = _selectedRoute;
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8001/api/itinerary/risk-screen'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request),
      ).timeout(const Duration(seconds: 150));

      if (response.statusCode != 200) {
        throw Exception('API ${response.statusCode}: ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['screened_options'] is! List) {
        throw const FormatException('Unexpected hazard screening response');
      }
      if (!mounted) return;
      setState(() => _riskResult = decoded);
      if (!_mapLoaded) _loadHazardMap();
    } catch (e) {
      if (!mounted) return;
      setState(() => _riskError = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _selectRoute(Map<String, dynamic> route) {
    setState(() {
      _selectedRoute = route;
      _selectedRouteKey = _routeKey(route);
      _riskResult = null;
      _riskError = null;
    });
    // Immediately check the exact selected itinerary, not an independently chosen route.
    _checkHazards();
    if (!_mapLoaded) _loadHazardMap();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _routeTitle(Map<String, dynamic> route) {
    switch (route['option']) {
      case 'best_preference_match': return 'Best Plan';
      case 'shortest_straight_line': return 'Shortest Route';
      case 'longest_straight_line': return 'Longest Route';
      default: return (route['option'] ?? 'Suggested itinerary').toString().replaceAll('_', ' ');
    }
  }

  String _routeKey(Map<String, dynamic> route) =>
      (route['destinations'] as List<dynamic>? ?? [])
          .map((p) => (p as Map)['place_id'].toString()).join(',');

  Widget _routeCard(Map<String, dynamic> route, {bool isSuggested = false}) {
    final hazards = route['nearby_hazards'] as List<dynamic>? ?? [];
    final destinations = route['destinations'] as List<dynamic>? ?? [];
    final hazardCount = route['nearby_hazard_count'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _routeTitle(route),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (isSuggested) ...[
              const SizedBox(height: 6),
              const Text('Suggested based on reported-hazard proximity',
                  style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 10),
            Text('Destination cost: USD ${route['destination_cost_usd'] ?? '-'}'),
            Text('Straight-line distance: ${route['straight_line_km'] ?? '-'} km'),
            Text('Estimated total time (proxy): ${route['estimated_total_hours_proxy'] ?? '-'} hours'),
            Text('Preference match: ${route['preference_match_percent'] ?? '-'}%'),
            if (hazardCount != null) ...[
              const SizedBox(height: 10),
              Text(
                hazardCount == 0
                    ? 'No nearby active reports found within the screening radius'
                    : '$hazardCount nearby active hazard report(s) — review before travel',
                style: TextStyle(
                  color: hazardCount == 0 ? Colors.green.shade800 : Colors.deepOrange.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _selectRoute(route),
              icon: Icon(_selectedRouteKey == _routeKey(route) ? Icons.check_circle : Icons.map),
              label: Text(_selectedRouteKey == _routeKey(route) ? 'Selected — screening reports' : 'Select & view on map'),
            ),
            const SizedBox(height: 10),
            for (final rawPlace in destinations)
              if (_asMap(rawPlace) case final place?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.deepOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${place['place_name'] ?? 'Destination'}')),
                    ],
                  ),
                ),
            if (hazards.isNotEmpty) ...[
              const Divider(),
              const Text('Nearby reports (unverified)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              for (final rawHazard in hazards)
                if (_asMap(rawHazard) case final hazard?) ...[
                  Text('• ${hazard['hazard_type'] ?? 'Hazard'} — severity: ${hazard['severity'] ?? 'unknown'}'),
                  for (final rawLeg in (hazard['near_straight_line_legs'] as List<dynamic>? ?? []))
                    if (_asMap(rawLeg) case final leg?)
                      Padding(padding:const EdgeInsets.only(left:12,top:2),
                        child:Text('Near straight-line leg ${leg['leg_number']} (${leg['distance_km']} km)')),
                  for (final rawNear in (hazard['near_destinations'] as List<dynamic>? ?? []))
                    if (_asMap(rawNear) case final near?)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 2, bottom: 4),
                        child: Text('Near ${near['place_name'] ?? 'destination'} (${near['distance_km'] ?? '?'} km)'),
                      ),
                ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final originalOptions = widget.result['options'] as List<dynamic>? ?? [];
    final riskOptions = _riskResult?['screened_options'] as List<dynamic>?;
    final shownOptions = riskOptions ?? originalOptions;
    final suggested = _asMap(_riskResult?['suggested_option']);
    final alternativeGenerated = _riskResult?['alternative_generated'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your optimized itineraries'),
        backgroundColor: const Color(0xFF550000),
        foregroundColor: Colors.white,
        actions: [IconButton(tooltip:'Hazard admin', icon:const Icon(Icons.admin_panel_settings),
          onPressed:() async {
            await Navigator.push(context,MaterialPageRoute(builder: (_) => const HazardAdminPage()));
            if (!mounted) return;
            _loadHazardMap();
            if (_selectedRoute != null) _checkHazards();
          })],
      ),
      backgroundColor: const Color(0xFFFFF3E0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${widget.result['algorithm'] ?? 'NSGA-II'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Pareto routes found: ${widget.result['pareto_routes_found'] ?? 'N/A'}'),
          const SizedBox(height: 16),
          const Text('Choose a route below, then view its stops on the map. Blue lines are straight-line connections, not driving roads.'),
          const SizedBox(height: 12),
          const Text('Select a route below to display its destinations on the map.'),
          const SizedBox(height: 12),
          _weatherSection(),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              title: const Text('Include test reports (testing only)'),
              subtitle: const Text('Off for normal use. Turn on temporarily to verify the fictional hazard report.'),
              value: _includeTestReports,
              onChanged: _checking ? null : (value) {
                setState(() {
                  _includeTestReports = value;
                  _riskResult = null;
                  _riskError = null;
                  _mapLoaded = false;
                  _mapHazards = [];
                  _hazardMapError = null;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          _hazardMapSection(),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _checking ? null : _checkHazards,
            icon: _checking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.warning_amber_rounded),
            label: Text(_checking ? 'Checking reported hazards...' : 'Check Reported Hazards'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF550000),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (_riskError != null) ...[
            const SizedBox(height: 12),
            SelectableText('Hazard check failed: $_riskError',
                style: const TextStyle(color: Colors.red)),
          ],
          if (_riskResult != null) ...[
            if (_includeTestReports)
              const Text('TEST MODE — fictional reports included',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Active reports considered: ${_riskResult!['active_reports_considered'] ?? 0}'),
            Text('Screening radius: ${_riskResult!['radius_km'] ?? 5} km from stops and straight-line legs'),
            const SizedBox(height: 8),
            Text('Result: ${(_riskResult!['recommendation_status'] ?? '').toString().replaceAll('_', ' ')}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${_riskResult!['warning'] ?? ''}',
                style: const TextStyle(color: Colors.deepOrange)),
            if (_asMap(_riskResult!['selected_route']) case final screenedSelected?) ...[
              Text(screenedSelected['nearby_hazard_count'] == 0
                  ? 'Selected itinerary: no nearby active reports found (NOT a safety guarantee).'
                  : 'Selected itinerary: ${screenedSelected['nearby_hazard_count']} report(s) near stops or straight-line legs. Consider an alternative.',
                style:const TextStyle(fontWeight:FontWeight.bold, color:Colors.deepOrange)),
            ],
            if (suggested != null) ...[
              const SizedBox(height: 16),
              const Text('Alternative to the selected itinerary',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _routeCard(suggested, isSuggested: true),
              if (alternativeGenerated)
                Text('${_riskResult!['alternative_note'] ?? ''}',
                    style: const TextStyle(color: Colors.black87)),
            ],
            if (!alternativeGenerated && _riskResult!['alternative_note'] != null)
              Text('${_riskResult!['alternative_note']}'),
            const SizedBox(height: 16),
            const Text('Screened original route options',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
          ] else ...[
            const SizedBox(height: 12),
            const Text('Original optimized route options',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
          ],
          for (final rawRoute in shownOptions)
            if (_asMap(rawRoute) case final route?) _routeCard(route),
          const SizedBox(height: 12),
          const Text(
            'Research prototype: distances are straight-line estimates, not road routes. '
            'Costs exclude transport, meals and accommodation. Hazard screening uses '
            'unverified active reports near stops and straight-line segments, not actual road segments. '
            'No nearby reports does not mean a route is safe. '
            'Weather ML uses forecast inputs and has not been validated for live safety decisions.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
