import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../loading/generating_route_page.dart';

class ConfirmationPage extends StatelessWidget {
  final List<String> selectedClimates;
  final List<String> selectedCities;
  final DateTime? startDate;
  final DateTime? endDate;
  final double budget;
  final int peopleCount;

  const ConfirmationPage({
    super.key,
    required this.selectedClimates,
    required this.selectedCities,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.peopleCount,
  });

  int _calculateDays() {
    if (startDate != null && endDate != null) {
      return endDate!.difference(startDate!).inDays + 1;
    }
    return 0;
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0), // Matching Creamy Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF5D4037)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Confirm Your Trip',
          style: GoogleFonts.exo(
            color: const Color(0xFF5D4037),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Go back to reset
            },
            child: Text(
              'Reset',
              style: GoogleFonts.exo(
                color: const Color(0xFF550000),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. CLIMATE PREFERENCE ---
            _buildSectionCard(
              title: 'CLIMATE PREFERENCE',
              child: SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: selectedClimates.isEmpty 
                    ? [const Text('No climates selected', style: TextStyle(color: Colors.grey))]
                    : selectedClimates.map((climate) {
                      String imageUrl = '';
                      if (climate == 'Sunny') imageUrl = 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=300';
                      if (climate == 'Cool') imageUrl = 'https://tropicalessenceglobal.com/wp-content/uploads/2025/11/Inbound-scaled.jpg';
                      if (climate == 'Historical') imageUrl = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR7qHVA2Kte3ttuw--FQizLZGQ-JByuv68Wb3nYvlEQAZFzOAODZzCuzhSU&s';
                      if (climate == 'Wild') imageUrl = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRGo0jIvb3vzLeksjMSRvc_00uCjvTxbGnIhHbpRLHJ4BMEH6UAKDjfn8m9&s';
                      if (climate == 'Culture') imageUrl = 'https://www.lankatourexperts.com/wp-content/uploads/2023/07/Sri-Lanka-Culture.webp';
                      if (climate == 'Tropical') imageUrl = 'https://img.freepik.com/free-photo/beautiful-tropical-beach-sea_74190-6612.jpg?semt=ais_hybrid&w=740&q=80';
                      return _buildClimateItem(climate, imageUrl);
                    }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // --- 2. SELECTED CITIES ---
            _buildSectionCard(
              title: 'SELECTED CITIES',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: selectedCities.isEmpty
                    ? [const Text('No cities selected', style: TextStyle(color: Colors.grey))]
                    : selectedCities.map((city) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF550000),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                city,
                                style: GoogleFonts.exo(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF5D4037),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
              ),
            ),
            const SizedBox(height: 15),

            // --- 3. DURATION ---
            _buildSectionCard(
              title: 'DURATION',
              child: Row(
                children: [
                  Text(
                    startDate != null && endDate != null
                        ? '${_formatDate(startDate!)} - ${_formatDate(endDate!)}'
                        : 'Dates not selected',
                    style: GoogleFonts.exo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D4037),
                    ),
                  ),
                  const SizedBox(width: 15),
                  if (startDate != null && endDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF550000).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_calculateDays()} Days',
                        style: GoogleFonts.exo(
                          color: const Color(0xFF550000),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // --- 4. BUDGET LIMIT ---
            _buildSectionCard(
              title: 'BUDGET LIMIT',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '\$${budget.toInt()}',
                    style: GoogleFonts.exo(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D4037),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'USD',
                    style: GoogleFonts.exo(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D4037),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'For $peopleCount People',
                    style: GoogleFonts.exo(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),

            // --- GENERATE ROUTE BUTTON ---
            GestureDetector(
              onTap: () {
                // Navigate to the beautiful loading screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GeneratingRoutePage(
                    budget: budget,
                    climate: selectedClimates.contains('Cool') ? 'Cool' : selectedClimates.contains('Tropical') ? 'Tropical' : 'Moderate',
                    vibe: selectedClimates.contains('Culture') ? 'Culture' : selectedClimates.contains('Historical') ? 'Historical' : selectedClimates.contains('Wild') ? 'Wildlife' : 'Nature',
                    availableHours: _calculateDays() * 8.0,
                    mustVisitPlaces: selectedCities,
                  ),
                  ),
                );
              },
              child: Container(
                height: 55,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF550000),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF550000).withValues(alpha: 0.3), 
                      blurRadius: 15, 
                      offset: const Offset(0, 8)
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'Generate Route Plan',
                    style: GoogleFonts.exo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50), // Spacing for safe area
          ],
        ),
      ),
    );
  }

  // Helper Widget for the white container boxes
  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.exo(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600, // Matched to the UI design color
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  // Helper Widget for the small Climate Cards inside the confirmation page
  Widget _buildClimateItem(String title, String imageUrl) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                title,
                style: GoogleFonts.exo(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: const Color(0xFF550000), // Orange text like the UI
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
