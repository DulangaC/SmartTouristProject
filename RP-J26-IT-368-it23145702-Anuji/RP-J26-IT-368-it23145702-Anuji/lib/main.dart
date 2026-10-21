import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const SriLankanTravelApp());
}

class SriLankanTravelApp extends StatelessWidget {
  const SriLankanTravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ceylon Travel',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF550000), // Burgundy
          primary: const Color(0xFF550000),
          secondary: const Color(0xFF5D4037), // Earthy Brown
          surface: const Color(0xFFFFF8E1), // Light Creamy Surface
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF5D4037),
            fontFamily: 'Serif',
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
