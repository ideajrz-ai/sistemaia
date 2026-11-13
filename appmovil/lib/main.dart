import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/menus_screen.dart';
import 'screens/forms_screen.dart';
import 'screens/ocr_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/encuesta_screen.dart';
import 'screens/sesiones_screen.dart';
import 'screens/archivos_screen.dart';
import 'screens/citas_screen.dart';
import 'screens/qr_screen.dart';
import 'screens/geocercas_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/menus',
      builder: (context, state) => const MenusScreen(),
    ),
    GoRoute(
      path: '/encuesta',
      builder: (context, state) => const EncuestaScreen(),
    ),
    GoRoute(
      path: '/sesiones',
      builder: (context, state) => const SesionesScreen(),
    ),
    GoRoute(
      path: '/archivos',
      builder: (context, state) => const ArchivosScreen(),
    ),
    GoRoute(
      path: '/citas',
      builder: (context, state) => const CitasScreen(),
    ),
    GoRoute(
      path: '/qr',
      builder: (context, state) => const QRScreen(),
    ),
    GoRoute(
      path: '/geocercas',
      builder: (context, state) => const GeocercasScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/forms',
      builder: (context, state) => const FormsScreen(),
    ),
    GoRoute(
      path: '/ocr',
      builder: (context, state) => const OCRScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SistemaIA',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xfff97316),
          secondary: Color(0xfff97316),
          surface: Color(0xff17181a),
          background: Color(0xff0b0b0c),
          error: Color(0xfff87171),
        ),
        scaffoldBackgroundColor: const Color(0xff0b0b0c),
        cardColor: const Color(0xff17181a),
        dividerColor: const Color(0xff2e2f33),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xfff5f5f4)),
          bodyMedium: TextStyle(color: Color(0xfff5f5f4)),
          bodySmall: TextStyle(color: Color(0xff9b9b9b)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff17181a),
          foregroundColor: Color(0xfff5f5f4),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff101013),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xff2e2f33)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xff2e2f33)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xfff97316)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xfff97316),
            foregroundColor: const Color(0xff0b0b0c),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xfff97316),
            side: const BorderSide(color: Color(0xfff97316)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
