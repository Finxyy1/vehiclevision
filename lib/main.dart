import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const VehicleVisionApp());
}

class VehicleVisionApp extends StatelessWidget {
  const VehicleVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "VehicleVision",

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: "Roboto",

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff4facfe),
          brightness: Brightness.dark,
        ),
      ),

      home: const HomePage(),
    );
  }
}