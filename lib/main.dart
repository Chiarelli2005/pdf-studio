import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/permission_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PermissionService.requestAll();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0E1014),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF161A22),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PdfStudioApp());
}

class PdfStudioApp extends StatelessWidget {
  const PdfStudioApp({super.key});

  static const _bg = Color(0xFF0E1014);
  static const _bgElev = Color(0xFF161A22);
  static const _bgSoft = Color(0xFF1D2230);
  static const _border = Color(0xFF2A3142);
  static const _text = Color(0xFFE8ECF3);
  static const _textDim = Color(0xFF8B94A8);
  static const _accent = Color(0xFFFF5A3C);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        primaryColor: _accent,
        colorScheme: const ColorScheme.dark(
          primary: _accent,
          secondary: _accent,
          surface: _bgElev,
          surfaceContainerHighest: _bgSoft,
          onPrimary: Colors.white,
          onSurface: _text,
          outline: _border,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
          headlineSmall: GoogleFonts.jetBrainsMono(
            color: _text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
          titleLarge: GoogleFonts.jetBrainsMono(
            color: _text,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: GoogleFonts.jetBrainsMono(
            color: _textDim,
            letterSpacing: 1.8,
            fontSize: 10,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _bgElev,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.jetBrainsMono(
            color: _text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          iconTheme: const IconThemeData(color: _text),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _bgSoft,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          labelStyle: const TextStyle(color: _textDim),
        ),
        dividerColor: _border,
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: _bgElev,
          contentTextStyle: TextStyle(color: _text),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
