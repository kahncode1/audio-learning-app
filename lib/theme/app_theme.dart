import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App Theme Configuration
///
/// Provides light and dark theme configurations following the design specifications.
/// Uses Literata serif font for improved readability.
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
  static Color lightWordHighlight = const Color(0xFF3B82F6).withOpacity(0.25);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF0F111A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkPrimary = Color(0xFF60A5FA);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkSentenceHighlight = Color(0xFF2D3A4F);
  static Color darkWordHighlight = const Color(0xFF60A5FA).withOpacity(0.30);

  /// Light theme configuration
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.literataTextTheme().apply(
      bodyColor: lightTextPrimary,
      displayColor: lightTextPrimary,
    );

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: lightPrimary,
      scaffoldBackgroundColor: lightBackground,

      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightPrimary,
        surface: lightSurface,
        background: lightBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        onBackground: lightTextPrimary,
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
        titleTextStyle: GoogleFonts.literata(
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

      useMaterial3: false,
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.literataTextTheme().apply(
      bodyColor: darkTextPrimary,
      displayColor: darkTextPrimary,
    );

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: darkPrimary,
      scaffoldBackgroundColor: darkBackground,

      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkPrimary,
        surface: darkSurface,
        background: darkBackground,
        onPrimary: darkBackground,
        onSecondary: darkBackground,
        onSurface: darkTextPrimary,
        onBackground: darkTextPrimary,
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
        titleTextStyle: GoogleFonts.literata(
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

      useMaterial3: false,
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