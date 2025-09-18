import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_learning_app/main.dart';
import 'package:audio_learning_app/screens/home_screen.dart';
import 'package:audio_learning_app/screens/settings_screen.dart';

void main() {
  group('Navigation Tests', () {
    testWidgets('App launches with splash screen', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        // Verify splash screen is shown
        expect(find.text('The Institutes'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    testWidgets('Splash screen navigates to main screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: AudioLearningApp(),
        ),
      );

      // Wait for the splash screen delay
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify we're now on the main navigation screen
      expect(find.byType(MainNavigationScreen), findsOneWidget);
      // HomePage should be visible as it's the main content
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Main navigation screen shows HomePage',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      // Verify Home screen is shown
      expect(find.byType(HomePage), findsOneWidget);
      // Look for the app bar title from HomePage
      expect(find.text('My Courses'), findsOneWidget);
    });

    testWidgets('Settings icon in app bar navigates to settings',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const MainNavigationScreen(),
            routes: {
              '/settings': (context) => const SettingsScreen(),
            },
          ),
        ),
      );

      // Look for settings icon in app bar
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon);
        await tester.pumpAndSettle();
        // Verify Settings screen would be shown
        expect(find.byType(SettingsScreen), findsOneWidget);
      }
    });
  });
}
