// Dart & Flutter
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Third-party packages
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Configuration
import 'config/env_config.dart';

// Services
import 'services/error_tracking_service.dart';
import 'services/performance_monitor.dart';
import 'utils/app_logger.dart';

// Models
import 'models/learning_object_v2.dart';

// Providers
import 'providers/audio_providers.dart';
import 'providers/theme_provider.dart';

// Screens
import 'screens/assignments_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/enhanced_audio_player_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

// Debug-only screens
import 'screens/cdn_download_test_screen.dart' if (dart.library.io) 'screens/cdn_download_test_screen.dart';
import 'screens/local_content_test_screen.dart' if (dart.library.io) 'screens/local_content_test_screen.dart';

// Theme
import 'theme/app_theme.dart';

// Widgets
import 'widgets/mini_audio_player.dart';

void main() async {
  // Run the app in a guarded zone to catch all errors
  await runZonedGuarded(
    () async {
      // Ensure Flutter binding is initialized
      WidgetsFlutterBinding.ensureInitialized();

      // Load environment variables
      await EnvConfig.load();

      // Initialize error tracking (Sentry)
      // TODO: Replace with actual Sentry DSN from environment
      final sentryDsn = ''; // TODO: Add SENTRY_DSN to .env file
      if (sentryDsn.isNotEmpty) {
        await ErrorTrackingService.initialize(
          dsn: sentryDsn,
          tracesSampleRate: kDebugMode ? 1.0 : 0.3,
        );
      } else {
        AppLogger.warning(
            'Sentry DSN not configured - error tracking disabled');
      }

      // Set up Flutter error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        // Log to console in debug mode
        if (kDebugMode) {
          FlutterError.presentError(details);
        }

        // Report to error tracking service
        ErrorTrackingService.reportError(
          details.exception,
          details.stack,
          level: SentryLevel.error,
          message: 'Flutter framework error',
          context: {
            'library': details.library ?? 'unknown',
            'context': details.context?.toString() ?? 'unknown',
          },
        );

        // Log locally
        AppLogger.error(
          'Flutter Error',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      // Set up platform error handling
      PlatformDispatcher.instance.onError = (error, stack) {
        ErrorTrackingService.reportError(
          error,
          stack,
          level: SentryLevel.fatal,
          message: 'Platform error',
        );
        AppLogger.error('Platform Error', error: error, stackTrace: stack);
        return true;
      };

      // Initialize Supabase
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        anonKey: EnvConfig.supabaseAnonKey,
      );

      // Print configuration status for debugging
      EnvConfig.printConfigurationStatus();

      // Start performance monitoring
      PerformanceMonitor.startTracking();
      AppLogger.info('Performance monitoring started');

      // Add initialization breadcrumb
      ErrorTrackingService.addBreadcrumb(
        message: 'App initialized',
        category: 'lifecycle',
        data: {
          'supabase_url': EnvConfig.supabaseUrl,
          'environment': kDebugMode ? 'development' : 'production',
        },
      );

      runApp(
        const ProviderScope(
          child: AudioLearningApp(),
        ),
      );
    },
    (error, stack) {
      // Handle errors that occur outside of Flutter framework
      ErrorTrackingService.reportError(
        error,
        stack,
        level: SentryLevel.fatal,
        message: 'Uncaught error in guarded zone',
      );
      AppLogger.error('Uncaught Error', error: error, stackTrace: stack);
    },
  );
}

class AudioLearningApp extends ConsumerWidget {
  const AudioLearningApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'The Institutes',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainNavigationScreen(),
        '/home': (context) => const HomePage(),
        '/settings': (context) => const SettingsScreen(),
        // Debug-only routes
        if (kDebugMode)
          '/local-content-test': (context) => const LocalContentTestScreen(),
        if (kDebugMode)
          '/cdn-download-test': (context) => const CDNDownloadTestScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/course-detail') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => CourseDetailScreen(
              courseId: args['courseId']!,
              courseTitle: args['courseTitle']!,
            ),
          );
        }
        if (settings.name == '/assignments') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => AssignmentsScreen(
              courseId: args['courseId']!,
              courseNumber: args['courseNumber']!,
              courseTitle: args['courseTitle']!,
            ),
          );
        }
        if (settings.name == '/player') {
          // Handle both Map arguments (new) and direct LearningObject (legacy)
          if (settings.arguments is Map<String, dynamic>) {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => EnhancedAudioPlayerScreen(
                learningObject: args['learningObject'] as LearningObjectV2,
                courseNumber: args['courseNumber'] as String?,
                courseTitle: args['courseTitle'] as String?,
                assignmentTitle: args['assignmentTitle'] as String?,
                assignmentNumber: args['assignmentNumber'] as int?,
              ),
            );
          } else {
            // Legacy support for direct LearningObject
            final learningObject = settings.arguments as LearningObjectV2;
            return MaterialPageRoute(
              builder: (context) => EnhancedAudioPlayerScreen(
                learningObject: learningObject,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Simulate loading and navigate to main screen
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/the-institutes-logo.png',
              height: 80,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if logo doesn't load
                return Icon(
                  Icons.business,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'The Institutes',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366), // Professional dark blue
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShowMiniPlayer = ref.watch(shouldShowMiniPlayerProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Main content (HomePage)
          const HomePage(),

          // Mini audio player positioned at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              offset: shouldShowMiniPlayer ? Offset.zero : const Offset(0, 1),
              child: const AnimatedMiniAudioPlayer(),
            ),
          ),
        ],
      ),
    );
  }
}
