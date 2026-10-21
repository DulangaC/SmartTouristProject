import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../plan/final_plan_page.dart';

class GeneratingRoutePage extends StatefulWidget {
  final double budget;
  final String climate;
  final String vibe;
  final double availableHours;
  final List<String> mustVisitPlaces;

  const GeneratingRoutePage({
    super.key,
    required this.budget,
    required this.climate,
    required this.vibe,
    required this.availableHours,
    required this.mustVisitPlaces,
  });

  @override
  State<GeneratingRoutePage> createState() => _GeneratingRoutePageState();
}

class _GeneratingRoutePageState extends State<GeneratingRoutePage> {
  String? error;
  bool loading = true;

  // Chrome on this PC -> FastAPI on this PC, port 8001.
  // Android emulator would use http://10.0.2.2:8001 instead.
  static const String baseUrl = 'http://127.0.0.1:8001';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      error = null;
      loading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/itinerary/optimize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'budget': widget.budget,
          'climate': widget.climate,
          'vibe': widget.vibe,
          'available_hours': widget.availableHours,
          'start_lat': 7.2906,
          'start_lon': 80.6337,
          'must_visit_places': widget.mustVisitPlaces,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw Exception('API ${response.statusCode}: ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['result'] is! Map<String, dynamic>) {
        throw const FormatException('Unexpected itinerary response format');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FinalPlanPage(
            result: decoded['result'] as Map<String, dynamic>,
            riskRequest: {
              'budget': widget.budget,
              'climate': widget.climate,
              'vibe': widget.vibe,
              'available_hours': widget.availableHours,
              'start_lat': 7.2906,
              'start_lon': 80.6337,
              'hazard_radius_km': 5.0,
              'must_visit_places': widget.mustVisitPlaces,
              'include_test': false,
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generating itinerary')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: loading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Optimizing your itinerary using NSGA-II...'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 42),
                    const SizedBox(height: 16),
                    SelectableText(error ?? 'Unknown error', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
