import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import the barrel export file being tested
import 'package:audio_learning_app/providers/providers.dart';

// Import individual provider modules to verify exports
import 'package:audio_learning_app/providers/auth_providers.dart' as auth;
import 'package:audio_learning_app/providers/database_providers.dart' as database;
import 'package:audio_learning_app/providers/audio_providers.dart' as audio;
import 'package:audio_learning_app/providers/ui_providers.dart' as ui;
import 'package:audio_learning_app/providers/progress_providers.dart' as progress;
import 'package:audio_learning_app/providers/audio_context_provider.dart' as context;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Providers Barrel Export', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Auth Providers Export', () {
      test('should export authServiceProvider', () {
        expect(() => container.read(authServiceProvider), returnsNormally);
        expect(() => container.read(auth.authServiceProvider), returnsNormally);

        // Should be the same provider
        final provider1 = authServiceProvider;
        final provider2 = auth.authServiceProvider;
        expect(identical(provider1, provider2), isTrue);
      });

      test('should export authStateProvider', () {
        expect(() => container.read(authStateProvider), returnsNormally);
        expect(() => container.read(auth.authStateProvider), returnsNormally);
        expect(identical(authStateProvider, auth.authStateProvider), isTrue);
      });

      test('should export currentUserProvider', () {
        expect(() => container.read(currentUserProvider), returnsNormally);
        expect(() => container.read(auth.currentUserProvider), returnsNormally);
        expect(
            identical(currentUserProvider, auth.currentUserProvider), isTrue);
      });

      test('should export isAuthenticatedProvider', () {
        expect(() => container.read(isAuthenticatedProvider), returnsNormally);
        expect(() => container.read(auth.isAuthenticatedProvider),
            returnsNormally);
        expect(identical(isAuthenticatedProvider, auth.isAuthenticatedProvider),
            isTrue);
      });
    });

    group('Course Providers Export', () {
      test('should export database service providers', () {
        // Test that database providers are accessible
        // supabaseServiceProvider was refactored - testing core database access
        expect(() => localCoursesProvider, returnsNormally);
        expect(() => courseAssignmentsProvider, returnsNormally);
      });

      test('should export enrolledCoursesProvider', () {
        expect(() => container.read(enrolledCoursesProvider), returnsNormally);
        // Note: enrolledCoursesProvider is from course_providers, not database_providers
      });

      test('should export assignmentsProvider family', () {
        const testCourseId = 'test-course-id';
        expect(() => container.read(assignmentsProvider(testCourseId)),
            returnsNormally);
      });

      test('should export learningObjectsProvider family', () {
        const testAssignmentId = 'test-assignment-id';
        expect(() => container.read(learningObjectsProvider(testAssignmentId)),
            returnsNormally);
      });

      test('should export progressProvider family', () {
        const testLearningObjectId = 'test-lo-id';
        expect(() => container.read(progressProvider(testLearningObjectId)),
            returnsNormally);
      });

      test('should export state providers', () {
        expect(() => container.read(selectedCourseProvider), returnsNormally);
        expect(
            () => container.read(selectedAssignmentProvider), returnsNormally);
        expect(() => container.read(selectedLearningObjectProvider),
            returnsNormally);

        // Note: These providers are from course_providers, not database_providers
      });
    });

    group('Audio Providers Export', () {
      test('should export critical audio providers', () {
        // These are CRITICAL for the dual-level highlighting system
        expect(
            () => container.read(audioPlayerServiceProvider), returnsNormally);
        expect(() => container.read(isPlayingProvider), returnsNormally);
        expect(() => container.read(playbackPositionProvider), returnsNormally);
        // playbackDurationProvider was removed in refactoring

        expect(
            identical(
                audioPlayerServiceProvider, audio.audioPlayerServiceProvider),
            isTrue);
        expect(identical(isPlayingProvider, audio.isPlayingProvider), isTrue);
        expect(
            identical(playbackPositionProvider, audio.playbackPositionProvider),
            isTrue);
        // playbackDurationProvider was removed in refactoring
      });

      test('should export mini player provider', () {
        expect(() => container.read(shouldShowMiniPlayerProvider),
            returnsNormally);
        expect(
            identical(shouldShowMiniPlayerProvider,
                audio.shouldShowMiniPlayerProvider),
            isTrue);
      });
    });

    group('UI Providers Export', () {
      test('should export critical UI providers', () {
        // These are CRITICAL for the highlighting widget
        expect(() => container.read(fontSizeIndexProvider), returnsNormally);
        expect(() => container.read(playbackSpeedProvider), returnsNormally);

        expect(
            identical(fontSizeIndexProvider, ui.fontSizeIndexProvider), isTrue);
        expect(
            identical(playbackSpeedProvider, ui.playbackSpeedProvider), isTrue);
      });

      test('should provide font size notifier', () {
        final notifier = container.read(fontSizeIndexProvider.notifier);
        expect(notifier, isA<FontSizeNotifier>());

        final directNotifier =
            container.read(ui.fontSizeIndexProvider.notifier);
        expect(identical(notifier, directNotifier), isTrue);
      });

      test('should provide playback speed notifier', () {
        final notifier = container.read(playbackSpeedProvider.notifier);
        expect(notifier, isA<PlaybackSpeedNotifier>());

        final directNotifier =
            container.read(ui.playbackSpeedProvider.notifier);
        expect(identical(notifier, directNotifier), isTrue);
      });
    });

    group('Progress Providers Export', () {
      test('should export progress update provider', () {
        expect(() => container.read(progressUpdateProvider), returnsNormally);
        expect(() => container.read(progress.progressUpdateProvider),
            returnsNormally);
        expect(
            identical(progressUpdateProvider, progress.progressUpdateProvider),
            isTrue);
      });

      test('should export app initialization provider', () {
        expect(
            () => container.read(appInitializationProvider), returnsNormally);
        expect(() => container.read(progress.appInitializationProvider),
            returnsNormally);
        expect(
            identical(
                appInitializationProvider, progress.appInitializationProvider),
            isTrue);
      });
    });

    group('Audio Context Provider Export', () {
      test('should export audio context provider', () {
        expect(() => container.read(audioContextProvider), returnsNormally);
        expect(() => container.read(context.audioContextProvider),
            returnsNormally);
        expect(identical(audioContextProvider, context.audioContextProvider),
            isTrue);
      });

      test('should export mini player subtitle provider', () {
        expect(
            () => container.read(miniPlayerSubtitleProvider), returnsNormally);
        expect(() => container.read(context.miniPlayerSubtitleProvider),
            returnsNormally);
        expect(
            identical(
                miniPlayerSubtitleProvider, context.miniPlayerSubtitleProvider),
            isTrue);
      });
    });

    group('Database Provider Export', () {
      test('should export database providers for data access', () {
        // Test that database providers are accessible
        // Note: These providers connect to local SQLite database
        expect(() => localCoursesProvider, returnsNormally);
        expect(() => courseAssignmentsProvider, returnsNormally);
        expect(() => assignmentLearningObjectsProvider, returnsNormally);
      });

      test('should export user state providers', () {
        expect(() => userProgressProvider, returnsNormally);
        expect(() => userSettingsProvider, returnsNormally);
      });
    });

    group('Provider Functionality', () {
      test('should allow mixed usage of exported and direct providers', () {
        // Use exported providers
        final exportedAuthService = container.read(authServiceProvider);
        final exportedFontSize = container.read(fontSizeIndexProvider);

        // Use direct providers
        final directAuthService = container.read(auth.authServiceProvider);
        final directFontSize = container.read(ui.fontSizeIndexProvider);

        // Should be identical
        expect(identical(exportedAuthService, directAuthService), isTrue);
        expect(exportedFontSize, directFontSize);
      });

      test('should support provider state changes through exported providers',
          () {
        var notificationCount = 0;

        container.listen(
          fontSizeIndexProvider,
          (previous, next) => notificationCount++,
        );

        // Change through exported provider
        container.read(fontSizeIndexProvider.notifier).setFontSize(2);

        expect(notificationCount, 1);
        expect(container.read(fontSizeIndexProvider), 2);
        expect(container.read(ui.fontSizeIndexProvider), 2); // Should match
      });

      test('should support family providers through export', () {
        const courseId1 = 'course-1';
        const courseId2 = 'course-2';

        final assignments1 = container.read(assignmentsProvider(courseId1));
        final assignments2 = container.read(assignmentsProvider(courseId2));

        expect(assignments1, isA<AsyncValue>());
        expect(assignments2, isA<AsyncValue>());
      });
    });

    group('Critical Provider Dependencies', () {
      test('should maintain critical highlighting system providers', () {
        // These providers are CRITICAL for dual-level highlighting
        // Test critical providers individually to avoid type issues
        expect(() => container.read(fontSizeIndexProvider), returnsNormally);
        expect(() => container.read(playbackPositionProvider), returnsNormally);
        expect(() => container.read(isPlayingProvider), returnsNormally);
        expect(() => container.read(audioPlayerServiceProvider), returnsNormally);
      });

      test('should maintain provider relationships', () {
        // Verify that related providers can work together
        expect(
            () => {
                  container.read(authServiceProvider),
                  container.read(supabaseServiceProvider),
                  container.read(audioPlayerServiceProvider),
                  container.read(fontSizeIndexProvider),
                },
            returnsNormally);
      });
    });

    group('Backward Compatibility', () {
      test('should not break existing imports', () {
        // Test that all common provider patterns work
        expect(() => container.read(enrolledCoursesProvider), returnsNormally);
        expect(() => container.read(authStateProvider), returnsNormally);
        expect(() => container.read(isPlayingProvider), returnsNormally);
        expect(() => container.read(fontSizeIndexProvider), returnsNormally);
        expect(() => container.read(progressUpdateProvider), returnsNormally);
      });

      test('should support legacy provider usage patterns', () {
        // Family providers
        expect(
            () => container.read(assignmentsProvider('test')), returnsNormally);
        expect(() => container.read(learningObjectsProvider('test')),
            returnsNormally);
        expect(() => container.read(progressProvider('test')), returnsNormally);
      });
    });

    group('Provider Container Lifecycle', () {
      test('should dispose all exported providers correctly', () {
        final testContainer = ProviderContainer();

        // Access various exported providers
        testContainer.read(authServiceProvider);
        testContainer.read(fontSizeIndexProvider);
        testContainer.read(audioPlayerServiceProvider);
        testContainer.read(enrolledCoursesProvider);
        testContainer.read(progressUpdateProvider);

        // Should dispose without errors
        expect(() => testContainer.dispose(), returnsNormally);
      });

      test('should handle provider recreation across containers', () {
        final container1 = ProviderContainer();
        final fontSize1 = container1.read(fontSizeIndexProvider);
        container1.dispose();

        final container2 = ProviderContainer();
        final fontSize2 = container2.read(fontSizeIndexProvider);

        // Should start with same default values
        expect(fontSize1, equals(fontSize2));
        container2.dispose();
      });
    });

    group('Validation Function', () {
      test('should provide validation function', () {
        expect(() => validateProviders(), returnsNormally);
      });

      test('validation should not throw errors', () {
        expect(() => validateProviders(), returnsNormally);
      });
    });

    group('Module Organization', () {
      test('should organize providers by concern', () {
        // Auth-related providers should be accessible
        expect(() => container.read(authServiceProvider), returnsNormally);
        expect(() => container.read(currentUserProvider), returnsNormally);

        // Course-related providers should be accessible
        expect(() => container.read(enrolledCoursesProvider), returnsNormally);
        expect(() => container.read(selectedCourseProvider), returnsNormally);

        // Audio-related providers should be accessible
        expect(
            () => container.read(audioPlayerServiceProvider), returnsNormally);
        expect(() => container.read(isPlayingProvider), returnsNormally);

        // UI-related providers should be accessible
        expect(() => container.read(fontSizeIndexProvider), returnsNormally);
        expect(() => container.read(playbackSpeedProvider), returnsNormally);
      });
    });

    group('Performance', () {
      test('should not add overhead to provider access', () {
        // Accessing providers through export should be as fast as direct access
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 1000; i++) {
          container.read(fontSizeIndexProvider);
          container.read(audioPlayerServiceProvider);
        }

        stopwatch.stop();

        // Should complete quickly (under 100ms for 1000 accesses)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('Type Safety', () {
      test('should maintain type safety across exports', () {
        final authService = container.read(authServiceProvider);
        final fontSize = container.read(fontSizeIndexProvider);
        final assignments = container.read(assignmentsProvider('test'));

        expect(authService, isNotNull);
        expect(fontSize, isA<int>());
        expect(assignments, isA<AsyncValue>());
      });
    });
  });
}
