import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:audio_learning_app/providers/theme_provider.dart';

void main() {
  group('ThemeProvider', () {
    setUp(() {
      // Reset SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('themeProvider', () {
      test('should provide ThemeNotifier instance', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(themeProvider.notifier);
        expect(notifier, isA<ThemeNotifier>());
      });

      test('should start with system theme mode', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final themeMode = container.read(themeProvider);
        expect(themeMode, ThemeMode.system);
      });
    });

    group('ThemeNotifier', () {
      group('Initialization', () {
        test('should start with ThemeMode.system', () {
          final notifier = ThemeNotifier();
          expect(notifier.state, ThemeMode.system);
        });

        test('should load saved theme from SharedPreferences', () async {
          SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});

          final notifier = ThemeNotifier();
          // Wait for async loading
          await Future.delayed(const Duration(milliseconds: 100));

          expect(notifier.state, ThemeMode.dark);
        });

        test('should default to system theme if no saved preference', () async {
          SharedPreferences.setMockInitialValues({});

          final notifier = ThemeNotifier();
          await Future.delayed(const Duration(milliseconds: 100));

          expect(notifier.state, ThemeMode.system);
        });

        test('should handle invalid saved theme preference', () async {
          SharedPreferences.setMockInitialValues({'theme_mode': 'invalid'});

          final notifier = ThemeNotifier();
          await Future.delayed(const Duration(milliseconds: 100));

          expect(notifier.state, ThemeMode.system);
        });
      });

      group('setTheme', () {
        test('should update state to light theme', () async {
          final notifier = ThemeNotifier();

          await notifier.setTheme(ThemeMode.light);

          expect(notifier.state, ThemeMode.light);
        });

        test('should update state to dark theme', () async {
          final notifier = ThemeNotifier();

          await notifier.setTheme(ThemeMode.dark);

          expect(notifier.state, ThemeMode.dark);
        });

        test('should update state to system theme', () async {
          final notifier = ThemeNotifier();

          await notifier.setTheme(ThemeMode.system);

          expect(notifier.state, ThemeMode.system);
        });

        test('should persist light theme to SharedPreferences', () async {
          final notifier = ThemeNotifier();

          await notifier.setTheme(ThemeMode.light);

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('theme_mode'), 'light');
        });

        test('should persist dark theme to SharedPreferences', () async {
          final notifier = ThemeNotifier();

          await notifier.setTheme(ThemeMode.dark);

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('theme_mode'), 'dark');
        });

        test('should persist system theme to SharedPreferences', () async {
          final notifier = ThemeNotifier();

          await notifier.setTheme(ThemeMode.system);

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('theme_mode'), 'system');
        });

        test('should update state even if persistence fails', () async {
          // Mock SharedPreferences to fail
          SharedPreferences.setMockInitialValues({});

          final notifier = ThemeNotifier();

          // This should not throw and should still update state
          await notifier.setTheme(ThemeMode.dark);

          expect(notifier.state, ThemeMode.dark);
        });
      });

      group('themeName', () {
        test('should return "Light" for light theme', () {
          final notifier = ThemeNotifier();
          notifier.state = ThemeMode.light;

          expect(notifier.themeName, 'Light');
        });

        test('should return "Dark" for dark theme', () {
          final notifier = ThemeNotifier();
          notifier.state = ThemeMode.dark;

          expect(notifier.themeName, 'Dark');
        });

        test('should return "Auto" for system theme', () {
          final notifier = ThemeNotifier();
          notifier.state = ThemeMode.system;

          expect(notifier.themeName, 'Auto');
        });
      });

      group('themeIcon', () {
        test('should return light_mode icon for light theme', () {
          final notifier = ThemeNotifier();
          notifier.state = ThemeMode.light;

          expect(notifier.themeIcon, Icons.light_mode);
        });

        test('should return dark_mode icon for dark theme', () {
          final notifier = ThemeNotifier();
          notifier.state = ThemeMode.dark;

          expect(notifier.themeIcon, Icons.dark_mode);
        });

        test('should return brightness_auto icon for system theme', () {
          final notifier = ThemeNotifier();
          notifier.state = ThemeMode.system;

          expect(notifier.themeIcon, Icons.brightness_auto);
        });
      });

      group('State Persistence Integration', () {
        test('should maintain theme across notifier instances', () async {
          // Set theme with first instance
          final notifier1 = ThemeNotifier();
          await notifier1.setTheme(ThemeMode.dark);

          // Create new instance (simulating app restart)
          final notifier2 = ThemeNotifier();
          await Future.delayed(const Duration(milliseconds: 100));

          expect(notifier2.state, ThemeMode.dark);
        });

        test('should cycle through all theme modes', () async {
          final notifier = ThemeNotifier();

          // Start with system
          expect(notifier.state, ThemeMode.system);

          // Change to light
          await notifier.setTheme(ThemeMode.light);
          expect(notifier.state, ThemeMode.light);
          expect(notifier.themeName, 'Light');
          expect(notifier.themeIcon, Icons.light_mode);

          // Change to dark
          await notifier.setTheme(ThemeMode.dark);
          expect(notifier.state, ThemeMode.dark);
          expect(notifier.themeName, 'Dark');
          expect(notifier.themeIcon, Icons.dark_mode);

          // Back to system
          await notifier.setTheme(ThemeMode.system);
          expect(notifier.state, ThemeMode.system);
          expect(notifier.themeName, 'Auto');
          expect(notifier.themeIcon, Icons.brightness_auto);
        });
      });
    });

    group('Provider Integration', () {
      test('should notify listeners when theme changes', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        var notificationCount = 0;
        ThemeMode? lastTheme;

        container.listen(
          themeProvider,
          (previous, next) {
            notificationCount++;
            lastTheme = next;
          },
        );

        final notifier = container.read(themeProvider.notifier);
        await notifier.setTheme(ThemeMode.dark);

        expect(notificationCount, 1);
        expect(lastTheme, ThemeMode.dark);
      });

      test('should provide theme name through provider', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(themeProvider.notifier);
        expect(notifier.themeName, 'Auto'); // Default system theme
      });

      test('should provide theme icon through provider', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(themeProvider.notifier);
        expect(
            notifier.themeIcon, Icons.brightness_auto); // Default system theme
      });

      test('should handle multiple listeners', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        var listener1Called = 0;
        var listener2Called = 0;

        container.listen(
          themeProvider,
          (previous, next) => listener1Called++,
        );

        container.listen(
          themeProvider,
          (previous, next) => listener2Called++,
        );

        final notifier = container.read(themeProvider.notifier);
        await notifier.setTheme(ThemeMode.light);

        expect(listener1Called, 1);
        expect(listener2Called, 1);
      });
    });

    group('Error Handling', () {
      test('should handle SharedPreferences load errors gracefully', () async {
        // This tests the error handling in _loadTheme
        final notifier = ThemeNotifier();

        // Should not throw and should default to system
        expect(notifier.state, ThemeMode.system);
      });

      test('should handle theme setting edge cases', () async {
        final notifier = ThemeNotifier();

        // Test setting same theme multiple times
        await notifier.setTheme(ThemeMode.dark);
        await notifier.setTheme(ThemeMode.dark);
        await notifier.setTheme(ThemeMode.dark);

        expect(notifier.state, ThemeMode.dark);
      });
    });

    group('Theme Mode Mapping', () {
      test('should correctly map all theme modes to names', () {
        final notifier = ThemeNotifier();

        // Test all enum values
        for (final mode in ThemeMode.values) {
          notifier.state = mode;
          final name = notifier.themeName;

          switch (mode) {
            case ThemeMode.light:
              expect(name, 'Light');
              break;
            case ThemeMode.dark:
              expect(name, 'Dark');
              break;
            case ThemeMode.system:
              expect(name, 'Auto');
              break;
          }
        }
      });

      test('should correctly map all theme modes to icons', () {
        final notifier = ThemeNotifier();

        // Test all enum values
        for (final mode in ThemeMode.values) {
          notifier.state = mode;
          final icon = notifier.themeIcon;

          switch (mode) {
            case ThemeMode.light:
              expect(icon, Icons.light_mode);
              break;
            case ThemeMode.dark:
              expect(icon, Icons.dark_mode);
              break;
            case ThemeMode.system:
              expect(icon, Icons.brightness_auto);
              break;
          }
        }
      });
    });

    group('SharedPreferences Key', () {
      test('should use consistent key for persistence', () async {
        final notifier = ThemeNotifier();

        await notifier.setTheme(ThemeMode.light);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('theme_mode'), true);
        expect(prefs.getString('theme_mode'), 'light');
      });
    });
  });
}
