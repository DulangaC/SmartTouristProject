import 'package:flutter/material.dart';
import 'home/home_content.dart';
import 'route/route_content.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const RouteContent(), // The new Find Route Page
    const Center(child: Text('Emergency SOS', style: TextStyle(fontSize: 24, color: Colors.red ))),
    const Center(child: Text('Translator', style: TextStyle(fontSize: 24, color: Color(0xFF5D4037)))),
    const Center(child: Text('Profile', style: TextStyle(fontSize: 24, color: Color(0xFF5D4037)))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      resizeToAvoidBottomInset: true, // Crucial for keyboard interaction
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 65,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5D4037).withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home, "Home"),
            _buildNavItem(1, Icons.map_outlined, Icons.map, "Route"),
            _buildNavItem(2, Icons.crisis_alert, Icons.crisis_alert, "SOS"),
            _buildNavItem(3, Icons.translate_rounded, Icons.translate_rounded, "Translator"),
            _buildNavItem(4, Icons.person_outline, Icons.person, "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: isSelected ? 1.2 : 1.0,
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                color: isSelected 
                    ? const Color(0xFF550000) 
                    : Colors.grey.shade400,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                    ? const Color(0xFF550000) 
                    : Colors.grey.shade400,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
