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
        expect(find.text('Audio Learning Platform'), findsOneWidget);
        expect(find.byIcon(Icons.headphones), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    testWidgets('Splash screen navigates to main screen', (WidgetTester tester) async {
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
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('Bottom navigation shows correct screens', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      // Verify Home screen is shown by default
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('My Courses'), findsOneWidget);

      // Tap on Settings tab
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      // Verify Settings screen is shown
      expect(find.byType(SettingsScreen), findsOneWidget);
      // The Settings text appears in AppBar and also in BottomNavigationBar
      expect(find.text('Settings'), findsWidgets);

      // Tap back on Home tab
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      // Verify Home screen is shown again
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Bottom navigation bar has correct items', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MainNavigationScreen(),
          ),
        ),
      );

      // Verify navigation items
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}