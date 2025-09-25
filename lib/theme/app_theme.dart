import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Theme Configuration
///
/// Provides Material 3 (Material You) light and dark theme configurations.
/// Uses Montserrat sans-serif font for UI elements.
/// Implements dynamic color schemes with proper accessibility contrast.
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Typography settings
  static const double baseFontSize = 18.0;
  static const double lineHeight = 1.75;
  static const double letterSpacing = 0.3;

  // Light theme colors
  static const Color lightBackground = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF2196F3);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightSentenceHighlight = Color(0xFFE2E8F0);
  static Color lightWordHighlight = const Color(0xFF3B82F6).withValues(alpha: 0.25);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0F111A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkPrimary = Color(0xFF60A5FA);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkSentenceHighlight = Color(0xFF2D3A4F);
  static Color darkWordHighlight = const Color(0xFF60A5FA).withValues(alpha: 0.30);

  /// Light theme configuration with Material 3
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.montserratTextTheme().apply(
      bodyColor: lightTextPrimary,
      displayColor: lightTextPrimary,
    );

    return ThemeData(
      useMaterial3: true, // Enable Material 3
      brightness: Brightness.light,
      primaryColor: lightPrimary,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lightPrimary,
        brightness: Brightness.light,
        primary: lightPrimary,
        surface: lightSurface,
        background: lightBackground,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
        onBackground: lightTextPrimary,
        secondary: lightPrimary,
        onSecondary: Colors.white,
        surfaceVariant: lightSentenceHighlight,
        onSurfaceVariant: lightTextSecondary,
      ),
      textTheme: textTheme.copyWith(
        // Body text with specifications
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: baseFontSize,
          height: lineHeight,
          letterSpacing: letterSpacing,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: baseFontSize,
          height: lineHeight,
          letterSpacing: letterSpacing,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 14,
          letterSpacing: letterSpacing,
          color: lightTextSecondary,
        ),
        // Headings
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: letterSpacing,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: letterSpacing,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: letterSpacing,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: letterSpacing,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
        color: Color(0xFFE2E8F0),
      ),
      iconTheme: const IconThemeData(
        color: lightTextPrimary,
        size: 24,
      ),
      // Material 3 components
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightPrimary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: lightPrimary.withValues(alpha: 0.2),
        iconTheme: MaterialStateProperty.all(
          const IconThemeData(size: 24),
        ),
        labelTextStyle: MaterialStateProperty.all(
          textTheme.bodySmall,
        ),
      ),
    );
  }

  /// Dark theme configuration with Material 3
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.montserratTextTheme().apply(
      bodyColor: darkTextPrimary,
      displayColor: darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true, // Enable Material 3
      brightness: Brightness.dark,
      primaryColor: darkPrimary,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkPrimary,
        brightness: Brightness.dark,
        primary: darkPrimary,
        surface: darkSurface,
        background: darkBackground,
        onPrimary: darkBackground,
        onSurface: darkTextPrimary,
        onBackground: darkTextPrimary,
        secondary: darkPrimary,
        onSecondary: darkBackground,
        surfaceVariant: darkSentenceHighlight,
        onSurfaceVariant: darkTextSecondary,
      ),
      textTheme: textTheme.copyWith(
        // Body text with specifications
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: baseFontSize,
          height: lineHeight,
          letterSpacing: letterSpacing,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: baseFontSize,
          height: lineHeight,
          letterSpacing: letterSpacing,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 14,
          letterSpacing: letterSpacing,
          color: darkTextSecondary,
        ),
        // Headings
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: letterSpacing,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: letterSpacing,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: letterSpacing,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.montserrat(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          letterSpacing: letterSpacing,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 4,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkBackground,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
        color: Color(0xFF334155),
      ),
      iconTheme: const IconThemeData(
        color: darkTextPrimary,
        size: 24,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
      ),
      // Material 3 components
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkBackground,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: darkBackground,
        elevation: 4,
        shape: const CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: darkPrimary.withValues(alpha: 0.2),
        iconTheme: MaterialStateProperty.all(
          const IconThemeData(size: 24, color: darkTextPrimary),
        ),
        labelTextStyle: MaterialStateProperty.all(
          textTheme.bodySmall,
        ),
      ),
    );
  }
}

/// Extension to provide custom colors for highlighting
extension CustomColors on ThemeData {
  Color get sentenceHighlight {
    return brightness == Brightness.light
        ? AppTheme.lightSentenceHighlight
        : AppTheme.darkSentenceHighlight;
  }

  Color get wordHighlight {
    return brightness == Brightness.light
        ? AppTheme.lightWordHighlight
        : AppTheme.darkWordHighlight;
  }

  Color get textSecondary {
    return brightness == Brightness.light
        ? AppTheme.lightTextSecondary
        : AppTheme.darkTextSecondary;
  }
}
