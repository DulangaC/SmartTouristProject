import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'confirmation/confirmation_page.dart';

class RouteContent extends StatefulWidget {
  const RouteContent({super.key});

  @override
  State<RouteContent> createState() => _RouteContentState();
}

class _RouteContentState extends State<RouteContent> {
  double _budget = 2500;
  final List<String> _selectedClimates = ['Sunny', 'Cool'];
  final List<String> _mustVisitPlaces = [];
  List<String> _availablePlaces = [];
  bool _loadingPlaces = true;


  DateTime? _startDate;
  DateTime? _endDate;
  int _peopleCount = 1;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8001/api/destinations'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw Exception('API error');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final names = (data['destinations'] as List)
          .map((p) => (p as Map)['place_name'].toString()).toSet().toList()..sort();
      if (mounted) setState(() { _availablePlaces = names; _loadingPlaces = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingPlaces = true; });
    }
  }

  @override
  void dispose() {

    super.dispose();
  }

  int _calculateDays() {
    if (_startDate != null && _endDate != null) {
      // +1 to include both start and end days
      return _endDate!.difference(_startDate!).inDays + 1;
    }
    return 0;
  }

  void _selectDate(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF550000), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF5D4037), // body text color
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  bool get _isFormValid {
    return _selectedClimates.isNotEmpty && 
           !_loadingPlaces && 
           _startDate != null && 
           _endDate != null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(25, 60, 20, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF550000), Color(0xFF550000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(45),
                bottomRight: Radius.circular(45),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ceylon Path',
                        style: GoogleFonts.exo(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Find Your\nPerfect Route',
                        style: GoogleFonts.exo(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tailor your dream\ndestination in Sri Lanka in\nseconds.',
                        style: GoogleFonts.exo(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Image.network(
                    'https://thumbs.wbm.im/pw/small/28538d1855554060dd60202899f60265.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.map_rounded, size: 80, color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // --- 1. PREFERRED CLIMATES ---
          _buildSectionTitle('1. PREFERRED CLIMATES'),
          const SizedBox(height: 15),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildClimateCard('Sunny', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=300'), // Beach
                _buildClimateCard('Cool', 'https://tropicalessenceglobal.com/wp-content/uploads/2025/11/Inbound-scaled.jpg'), 
                _buildClimateCard('Historical', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR7qHVA2Kte3ttuw--FQizLZGQ-JByuv68Wb3nYvlEQAZFzOAODZzCuzhSU&s'), 
                _buildClimateCard('Wild', 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRGo0jIvb3vzLeksjMSRvc_00uCjvTxbGnIhHbpRLHJ4BMEH6UAKDjfn8m9&s'), 
                _buildClimateCard('Culture', 'https://www.lankatourexperts.com/wp-content/uploads/2023/07/Sri-Lanka-Culture.webp'), 
                _buildClimateCard('Tropical', 'https://img.freepik.com/free-photo/beautiful-tropical-beach-sea_74190-6612.jpg?semt=ais_hybrid&w=740&q=80'), 
              ],
            ),
          ),

          const SizedBox(height: 30),

          // --- 2. MUST-VISIT PLACES ---
          _buildSectionTitle('2. MUST-VISIT PLACES'),
          const SizedBox(height: 15),
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 25),
             child: _loadingPlaces
                 ? const Text('Could not load destinations. Start the backend, then reopen this page.')
                 : Autocomplete<String>(
                     optionsBuilder: (value) {
                       if (value.text.trim().isEmpty) return const Iterable<String>.empty();
                       return _availablePlaces.where((p) =>
                           p.toLowerCase().contains(value.text.trim().toLowerCase()) &&
                           !_mustVisitPlaces.contains(p)).take(8);
                     },
                     onSelected: (value) {
                       if (_mustVisitPlaces.length < 6 && !_mustVisitPlaces.contains(value)) {
                         setState(() => _mustVisitPlaces.add(value));
                       }
                     },
                     fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
                         TextField(controller: controller, focusNode: focusNode,
                           decoration: const InputDecoration(
                             labelText: 'Search and select dataset destinations',
                             border: OutlineInputBorder(),
                             prefixIcon: Icon(Icons.search)),
                         ),
                   ),
           ),
           const SizedBox(height: 8),
           const Padding(padding: EdgeInsets.symmetric(horizontal: 25),
             child: Text('Choose places from suggestions. Remove a chip to deselect. Maximum 6.',
               style: TextStyle(fontSize: 12))),
           const SizedBox(height: 8),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _mustVisitPlaces.map((place) => _buildPlaceChip(place)).toList(),
            ),
          ),

          const SizedBox(height: 35),

          // --- 3. TRIP DURATION ---
          _buildSectionTitle('3. TRIP DURATION'),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF550000), size: 22),
                            const SizedBox(width: 10),
                            Text(
                              _startDate != null && _endDate != null
                                  ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year} - ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                                  : 'Select Dates',
                              style: GoogleFonts.exo(
                                fontWeight: FontWeight.bold, 
                                fontSize: 15, 
                                color: const Color(0xFF5D4037)
                              ),
                            ),
                          ],
                        ),
                        if (_startDate != null && _endDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF550000).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_calculateDays()} Days',
                              style: GoogleFonts.exo(color: const Color(0xFF550000), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 35),

          // --- NEW: NUMBER OF TRAVELERS ---
          _buildSectionTitle('4. NUMBER OF TRAVELERS'),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.group_outlined, color: Color(0xFF550000), size: 22),
                      const SizedBox(width: 10),
                      Text('People', style: GoogleFonts.exo(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF5D4037))),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_peopleCount > 1) setState(() => _peopleCount--);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.remove, size: 20, color: Color(0xFF5D4037)),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text('$_peopleCount', style: GoogleFonts.exo(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF550000))),
                      const SizedBox(width: 15),
                      GestureDetector(
                        onTap: () => setState(() => _peopleCount++),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF550000).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, size: 20, color: Color(0xFF550000)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 35),

          // --- 5. MAXIMUM BUDGET ---
          _buildSectionTitle('5. MAXIMUM BUDGET (Total)'),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('USD \$${_budget.toInt()}', style: GoogleFonts.exo(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF5D4037))),
                      Text('Adjustable', style: GoogleFonts.exo(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF550000))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: const Color(0xFF550000),
                      inactiveTrackColor: Colors.grey.shade200,
                      thumbColor: Colors.white,
                      trackHeight: 4.0,
                    ),
                    child: Slider(
                      value: _budget,
                      min: 500,
                      max: 5000,
                      divisions: 90,
                      onChanged: (val) {
                        setState(() {
                          _budget = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 35),

          // --- NEXT BUTTON ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: GestureDetector(
              onTap: _isFormValid ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfirmationPage(
                      selectedClimates: _selectedClimates,
                      selectedCities: _mustVisitPlaces,
                      startDate: _startDate,
                      endDate: _endDate,
                      budget: _budget,
                      peopleCount: _peopleCount,
                    ),
                  ),
                );
              } : null, // Disable tap if form is invalid
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 55,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _isFormValid ? const Color(0xFF550000) : Colors.grey.shade400, // Change color based on validation
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isFormValid ? [
                    BoxShadow(color: const Color(0xFF550000).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                  ] : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isFormValid ? 'Next Step' : 'Please complete all fields', 
                      style: GoogleFonts.exo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    if (_isFormValid) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ]
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 35), // Removed 120 bottom padding since we now use native bottomNavigationBar
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Text(
        title,
        style: GoogleFonts.exo(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF5D4037), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildClimateCard(String title, String imageUrl) {
    bool isSelected = _selectedClimates.contains(title);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedClimates.remove(title);
          } else {
            _selectedClimates.add(title);
          }
        });
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? const Color(0xFF550000) : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(13), bottom: isSelected ? Radius.zero : const Radius.circular(13)),
                child: Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            Expanded(
              flex: 2,
              child: Center(
                child: Text(
                  title,
                  style: GoogleFonts.exo(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12,
                    color: isSelected ? const Color(0xFF550000) : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF550000).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.exo(color: const Color(0xFF550000), fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _mustVisitPlaces.remove(label);
              });
            },
            child: const Icon(Icons.cancel_outlined, color: Color(0xFF550000), size: 16),
          ),
        ],
      ),
    );
  }

  // Old mock calendar removed as it's replaced by real DateRangePicker
}
