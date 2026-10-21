import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/destination_card.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header Section with Overlapping Search
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 1. Main Orange Gradient Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(15, 60, 0, 70), // Reduced left padding to 15
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Right Side Hero Image (Larger Dancer Image)
                    Positioned(
                      right: -25,
                      top: -35,
                      bottom: -65,
                      child: Image.asset(
                        'assets/dancer.png',
                        fit: BoxFit.fitHeight, // Use fitHeight to maximize size
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                    // Left Branding Content
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        // Small Ceylon Path Text
                        Text(
                          'Ceylon Path',
                          style: GoogleFonts.exo(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // Large Ayubowan Text
                        Text(
                          'Ayubowan...',
                          style: GoogleFonts.exo(
                            color: Colors.white,
                            fontSize: 44, // Slightly reduced size to ensure it fits on left
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 2. Overlapping Search Bar with Notification Icon
              Positioned(
                bottom: -30, // Overlaps the bottom of the orange section
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  height: 65,
                  width: MediaQuery.of(context).size.width * 0.88,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: Color(0xFF550000), size: 26),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search destinations...',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      // Added Menu Icon Button here
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100, // Light grey background
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_rounded, color: Color(0xFF5D4037), size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 60),

          // --- FIRST SECTION: Service Icons (Always Visible, No Scroll) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildServiceIcon(Icons.explore_rounded, 'Plan'),
                _buildServiceIcon(Icons.verified_user_rounded, 'Safety'),
                _buildServiceIcon(Icons.radar_rounded, 'Threats'),
                _buildServiceIcon(Icons.emergency_share_rounded, 'SOS'),
                _buildServiceIcon(Icons.wifi_off_rounded, 'Offline'),
              ],
            ),
          ),

          const SizedBox(height: 35),

          // --- SECOND SECTION: Trending Places (This Month) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              'Trending (August)',
              style: GoogleFonts.exo(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5D4037),
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 310,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 25),
              physics: const BouncingScrollPhysics(),
              children: [
                const DestinationCard(
                  name: 'Kandy Perahera',
                  location: 'Kandy City',
                  image: 'https://esalaperahera.com/wp-content/uploads/2025/11/03rd-Randoli-Perahera-5U.webp',
                ),
                const DestinationCard(
                  name: 'Sigiriya Rock',
                  location: 'Matale District',
                  image: 'https://www.bluelankatours.com/wp-content/uploads/2023/08/Sigiriya-Main.jpg',
                ),
                const DestinationCard(
                  name: 'Nine Arches',
                  location: 'Ella Highlands',
                  image: 'https://d1ynolcus8dvgv.cloudfront.net/2019/01/nine-arch-2-5.jpg',
                ),
                const DestinationCard(
                  name: 'Temple of Tooth',
                  location: 'Kandy',
                  image: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQi83dAmBFY56hz2s_uX2ZMGwM9Yb6ZtaSGiX9YlDMx7Ddm0FXhQgrL6m6-&s',
                ),
                // View More Button at the end
                Padding(
                  padding: const EdgeInsets.only(right: 25, bottom: 12),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF550000).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF550000), size: 30),
                        ),
                        const SizedBox(height: 10),
                        Text('View More', style: GoogleFonts.exo(fontWeight: FontWeight.bold, color: const Color(0xFF550000))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 35),

          // --- THIRD SECTION: Travelling Places Map ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Text(
              'Travelling Places',
              style: GoogleFonts.exo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5D4037),
              ),
            ),
          ),

          const SizedBox(height: 15),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              height: 480, // Even more height to let the map breathe and look big
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5FE), // Pure ocean blue background
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: InteractiveViewer( // Allows users to zoom and pan the big map
                  child: Image.network(
                    'https://traveylo.com/img/Web%20pic/map.png', 
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(Icons.map_rounded, size: 100, color: const Color(0xFF5D4037).withValues(alpha: 0.1)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 35), // Removed 120 bottom padding since we now use native bottomNavigationBar
        ],
      ),
    );
  }

  Widget _buildServiceIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12), // Reduced padding to fit 5 items
          decoration: BoxDecoration(
            color: const Color(0xFF550000),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF550000).withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22), // Slightly smaller icon
        ),
        const SizedBox(height: 8),
        Text(
          label, 
          textAlign: TextAlign.center,
          style: GoogleFonts.exo(
            fontSize: 10, 
            fontWeight: FontWeight.bold, 
            color: const Color(0xFF5D4037)
          ),
        ),
      ],
    );
  }
}
