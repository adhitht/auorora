import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'theme/liquid_glass_theme.dart';
import 'service_locator.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  setupServiceLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: LiquidGlassTheme.primary,
        scaffoldBackgroundColor: LiquidGlassTheme.background,
        colorScheme: ColorScheme.dark(
          primary: LiquidGlassTheme.primary,
          secondary: LiquidGlassTheme.accent,
          surface: LiquidGlassTheme.surface,
          error: LiquidGlassTheme.error,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
