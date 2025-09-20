import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode provider for managing app theme state
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

/// Theme state notifier with persistence
class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';

  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  /// Load saved theme preference from SharedPreferences
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_themeKey);

      if (themeName != null) {
        switch (themeName) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'system':
          default:
            state = ThemeMode.system;
            break;
        }
      }
    } catch (e) {
      // If error loading, default to system theme
      state = ThemeMode.system;
    }
  }

  /// Set and persist theme mode
  Future<void> setTheme(ThemeMode mode) async {
    state = mode;

    try {
      final prefs = await SharedPreferences.getInstance();
      String themeName;

      switch (mode) {
        case ThemeMode.light:
          themeName = 'light';
          break;
        case ThemeMode.dark:
          themeName = 'dark';
          break;
        case ThemeMode.system:
        default:
          themeName = 'system';
          break;
      }

      await prefs.setString(_themeKey, themeName);
    } catch (e) {
      // Silent fail - theme will still change for current session
    }
  }

  /// Get human-readable name for current theme mode
  String get themeName {
    switch (state) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Auto';
    }
  }

  /// Get icon for current theme mode
  IconData get themeIcon {
    switch (state) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }
}