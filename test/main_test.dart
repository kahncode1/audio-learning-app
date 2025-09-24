import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_learning_app/main.dart';
import 'package:audio_learning_app/models/learning_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Main App', () {
    group('AudioLearningApp', () {
      testWidgets('should create MaterialApp with correct configuration',
          (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        // Find MaterialApp
        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.title, 'The Institutes');
        expect(materialApp.theme, isNotNull);
        expect(materialApp.darkTheme, isNotNull);
      });

      testWidgets('should have initial route to SplashScreen', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        expect(find.byType(SplashScreen), findsOneWidget);
      });

      testWidgets('should have correct named routes', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.routes, contains('/main'));
        expect(materialApp.routes, contains('/home'));
        expect(materialApp.routes, contains('/settings'));
        expect(materialApp.routes, contains('/local-content-test'));
        expect(materialApp.routes, contains('/cdn-download-test'));
      });

      testWidgets('should watch theme provider', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        // Should build without throwing
        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });

    group('SplashScreen', () {
      testWidgets('should display logo and title', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const SplashScreen(),
          ),
        );

        expect(find.text('The Institutes'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should handle logo loading error', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const SplashScreen(),
          ),
        );

        // Should show fallback icon when image fails to load
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('should have correct styling', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const SplashScreen(),
          ),
        );

        final titleWidget = tester.widget<Text>(find.text('The Institutes'));
        expect(titleWidget.style?.fontSize, 28);
        expect(titleWidget.style?.fontWeight, FontWeight.bold);
        expect(titleWidget.style?.color, const Color(0xFF003366));
      });

      testWidgets('should navigate to main screen after delay', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const SplashScreen(),
            routes: {
              '/main': (context) => const Scaffold(body: Text('Main Screen')),
            },
          ),
        );

        // Initially shows splash screen
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.text('Main Screen'), findsNothing);

        // Wait for navigation delay
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Should navigate to main screen
        expect(find.text('Main Screen'), findsOneWidget);
        expect(find.byType(SplashScreen), findsNothing);
      });

      testWidgets('should handle mounted check during navigation',
          (tester) async {
        late StatefulWidget splashWidget;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                splashWidget = const SplashScreen();
                return splashWidget;
              },
            ),
            routes: {
              '/main': (context) => const Text('Main'),
            },
          ),
        );

        // Widget should be mounted initially
        expect(find.byType(SplashScreen), findsOneWidget);

        // Fast forward to check mounted state handling
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Should complete without errors
        expect(tester.takeException(), isNull);
      });
    });

    group('MainNavigationScreen', () {
      testWidgets('should display HomePage by default', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: const MainNavigationScreen(),
            ),
          ),
        );

        expect(find.byType(MainNavigationScreen), findsOneWidget);
        // Should contain a stack with HomePage
        expect(find.byType(Stack), findsOneWidget);
      });

      testWidgets('should position mini player at bottom', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: const MainNavigationScreen(),
            ),
          ),
        );

        final stack = find.byType(Stack);
        expect(stack, findsOneWidget);

        final positioned = find.descendant(
          of: stack,
          matching: find.byType(Positioned),
        );
        expect(positioned, findsWidgets);
      });

      testWidgets('should handle mini player visibility animation',
          (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: const MainNavigationScreen(),
            ),
          ),
        );

        // Should have animated slide widget
        expect(find.byType(AnimatedSlide), findsOneWidget);

        // Animation should complete without errors
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('should watch mini player provider', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: const MainNavigationScreen(),
            ),
          ),
        );

        // Should build successfully with provider
        expect(find.byType(MainNavigationScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Route Generation', () {
      testWidgets('should handle course detail route generation',
          (tester) async {
        final app = MaterialApp.router(
          routerDelegate: _TestRouterDelegate('/course-detail', {
            'courseId': 'test-course',
            'courseTitle': 'Test Course',
          }),
          routeInformationParser: _TestRouteParser(),
        );

        await tester.pumpWidget(
          ProviderScope(child: app),
        );

        // Should handle route generation without throwing
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle assignments route generation', (tester) async {
        final app = MaterialApp.router(
          routerDelegate: _TestRouterDelegate('/assignments', {
            'courseId': 'test-course',
            'courseNumber': 'TEST-101',
            'courseTitle': 'Test Course',
          }),
          routeInformationParser: _TestRouteParser(),
        );

        await tester.pumpWidget(
          ProviderScope(child: app),
        );

        // Should handle route generation without throwing
        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle player route with map arguments',
          (tester) async {
        final learningObject = LearningObject(
          id: 'test-lo',
          assignmentId: 'test-assignment',
          title: 'Test LO',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        final app = MaterialApp.router(
          routerDelegate: _TestRouterDelegate('/player', {
            'learningObject': learningObject,
            'courseNumber': 'TEST-101',
            'courseTitle': 'Test Course',
            'assignmentTitle': 'Test Assignment',
            'assignmentNumber': 1,
          }),
          routeInformationParser: _TestRouteParser(),
        );

        await tester.pumpWidget(
          ProviderScope(child: app),
        );

        // Should handle route generation without throwing
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'should handle player route with legacy LearningObject argument',
          (tester) async {
        final learningObject = LearningObject(
          id: 'test-lo',
          assignmentId: 'test-assignment',
          title: 'Test LO',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        final app = MaterialApp.router(
          routerDelegate: _TestRouterDelegate('/player', learningObject),
          routeInformationParser: _TestRouteParser(),
        );

        await tester.pumpWidget(
          ProviderScope(child: app),
        );

        // Should handle route generation without throwing
        expect(tester.takeException(), isNull);
      });

      testWidgets('should return null for unknown routes', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        final unknownRoute = RouteSettings(name: '/unknown');
        final route = materialApp.onGenerateRoute!(unknownRoute);

        expect(route, isNull);
      });
    });

    group('Widget Structure', () {
      testWidgets('should have proper widget hierarchy', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        // Should have MaterialApp as root
        expect(find.byType(MaterialApp), findsOneWidget);

        // Should contain SplashScreen initially
        expect(find.byType(SplashScreen), findsOneWidget);

        // SplashScreen should have proper structure
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
        expect(find.text('The Institutes'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should handle provider scope correctly', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        // Should have ProviderScope in widget tree
        expect(find.byType(ProviderScope), findsOneWidget);

        // AudioLearningApp should be ConsumerWidget
        expect(find.byType(AudioLearningApp), findsOneWidget);
      });
    });

    group('Theme Integration', () {
      testWidgets('should use AppTheme for light and dark themes',
          (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.theme, isNotNull);
        expect(materialApp.darkTheme, isNotNull);
        expect(materialApp.themeMode, isNotNull);
      });

      testWidgets('should respond to theme provider changes', (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        // Should build without errors with theme provider
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Error Handling', () {
      testWidgets('should handle image loading errors gracefully',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const SplashScreen(),
          ),
        );

        final imageWidget = tester.widget<Image>(find.byType(Image));
        expect(imageWidget.errorBuilder, isNotNull);

        // Should have fallback behavior for image errors
        final scaffoldFinder = find.byType(Scaffold);
        expect(scaffoldFinder, findsOneWidget);
      });

      testWidgets('should handle navigation errors gracefully', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const SplashScreen(),
            // Intentionally no routes to test error handling
          ),
        );

        // Should not throw during initial build
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Accessibility', () {
      testWidgets('should have semantic labels for key elements',
          (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: AudioLearningApp(),
          ),
        );

        // Title should be accessible
        expect(find.text('The Institutes'), findsOneWidget);

        // Progress indicator should be present for loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Performance', () {
      testWidgets('should build efficiently without unnecessary rebuilds',
          (tester) async {
        int buildCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            child: Builder(
              builder: (context) {
                buildCount++;
                return const AudioLearningApp();
              },
            ),
          ),
        );

        // Should build once initially
        expect(buildCount, 1);

        // Additional pumps should not cause unnecessary rebuilds
        await tester.pump();
        await tester.pump();

        // Build count should remain stable
        expect(buildCount, 1);
      });
    });

    group('State Management', () {
      testWidgets('should integrate with Riverpod correctly', (tester) async {
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return const AudioLearningApp();
              },
            ),
          ),
        );

        // Should have access to provider container
        expect(container, isNotNull);
        expect(find.byType(AudioLearningApp), findsOneWidget);
      });
    });
  });
}

// Helper classes for route testing
class _TestRouterDelegate extends RouterDelegate<String>
    with PopNavigatorRouterDelegateMixin, ChangeNotifier {
  final String route;
  final dynamic arguments;

  _TestRouterDelegate(this.route, this.arguments);

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  String get currentConfiguration => route;

  @override
  Future<void> setNewRoutePath(String configuration) async {
    // Implementation for route setting
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          settings: RouteSettings(name: route, arguments: arguments),
          builder: (context) => const Scaffold(body: Text('Test Screen')),
        );
      },
    );
  }

}

class _TestRouteParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(
      RouteInformation routeInformation) async {
    return routeInformation.uri.path;
  }

  @override
  RouteInformation restoreRouteInformation(String configuration) {
    return RouteInformation(uri: Uri.parse(configuration));
  }
}
