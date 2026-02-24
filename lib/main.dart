import 'package:flutter/material.dart';
import 'login.dart';

void main() {
  runApp(const MainApp());
}

// App Theme Colors
class AppColors {
  static const teal = Color(0xFF000000); // Black
  static const darkGray = Color(0xFF2D3748);
  static const mediumGray = Color(0xFF718096);
  static const lightGray = Color(0xFFE2E8F0);
  static const white = Color(0xFFFFFFFF);
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tukwatagane',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          primary: AppColors.teal,
        ),
        scaffoldBackgroundColor: AppColors.lightGray,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
