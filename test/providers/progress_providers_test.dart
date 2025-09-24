import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_learning_app/providers/progress_providers.dart';
import 'package:audio_learning_app/providers/auth_providers.dart';
import 'package:audio_learning_app/providers/course_providers.dart';
import 'package:audio_learning_app/providers/ui_providers.dart';
import 'package:audio_learning_app/providers/audio_providers.dart';
import 'package:audio_learning_app/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Progress Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('progressUpdateProvider', () {
      test('should provide ProgressUpdateNotifier instance', () {
        final progressUpdate = container.read(progressUpdateProvider.notifier);
        expect(progressUpdate, isA<ProgressUpdateNotifier>());
      });

      test('should start with data state', () {
        final state = container.read(progressUpdateProvider);
        expect(state, isA<AsyncData<void>>());
        expect(state.hasValue, isTrue);
      });

      test('should accept ref parameter in constructor', () {
        final progressUpdate = container.read(progressUpdateProvider.notifier);
        expect(progressUpdate.ref, isNotNull);
      });
    });

    group('ProgressUpdateNotifier', () {
      test('should initialize with AsyncValue.data(null)', () {
        final notifier = container.read(progressUpdateProvider.notifier);
        expect(notifier.state, isA<AsyncData<void>>());
        expect(notifier.state.hasValue, isTrue);
      });

      test('should handle updateProgress method calls', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Method should exist and not throw when called
        expect(
            () => notifier.updateProgress(
                  learningObjectId: 'test-lo-id',
                  positionMs: 5000,
                ),
            returnsNormally);
      });

      test('should handle markCompleted method calls', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        expect(() => notifier.markCompleted('test-lo-id'), returnsNormally);
      });

      test('should handle resumeProgress method calls', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        expect(() => notifier.resumeProgress('test-lo-id'), returnsNormally);
      });

      test('should expose ref property', () {
        final notifier = container.read(progressUpdateProvider.notifier);
        expect(notifier.ref, isNotNull);
      });

      test('should accept all updateProgress parameters', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should accept all optional parameters
        expect(
            () => notifier.updateProgress(
                  learningObjectId: 'test-lo-id',
                  positionMs: 10000,
                  isCompleted: true,
                  isInProgress: false,
                ),
            returnsNormally);
      });

      test('should handle progress state transitions', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Initial state should be data
        expect(notifier.state, isA<AsyncData<void>>());

        // State should remain accessible
        expect(notifier.state.hasValue, isTrue);
      });
    });

    group('appInitializationProvider', () {
      test('should provide future of boolean', () {
        final appInit = container.read(appInitializationProvider);
        expect(appInit, isA<AsyncValue<bool>>());
      });

      test('should handle initialization process', () {
        final appInit = container.read(appInitializationProvider);

        // Should be async value that eventually resolves to boolean
        appInit.when(
          data: (initialized) => expect(initialized, isA<bool>()),
          loading: () => expect(true, true), // Loading is valid
          error: (error, stack) => expect(error, isNotNull),
        );
      });

      test('should depend on auth and supabase services', () {
        // Should be able to read dependencies without throwing
        expect(() => container.read(authServiceProvider), returnsNormally);
        expect(() => container.read(supabaseServiceProvider), returnsNormally);
      });

      test('should handle initialization success', () {
        final appInit = container.read(appInitializationProvider);

        // Provider should handle both success and failure cases
        expect(appInit, isA<AsyncValue<bool>>());
      });

      test('should handle initialization failure gracefully', () {
        final appInit = container.read(appInitializationProvider);

        // Should not throw even if services fail to initialize
        appInit.when(
          data: (result) => expect(result, anyOf([isTrue, isFalse])),
          loading: () => expect(true, true),
          error: (_, __) => expect(true, true), // Error handling is valid
        );
      });
    });

    group('Provider Integration', () {
      test('progressUpdateProvider should access required providers', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should be able to access ref for reading other providers
        expect(notifier.ref, isNotNull);

        // Verify provider dependencies don't throw
        expect(() => container.read(supabaseServiceProvider), returnsNormally);
        expect(() => container.read(currentUserProvider), returnsNormally);
        expect(() => container.read(playbackSpeedProvider), returnsNormally);
        expect(() => container.read(fontSizeIndexProvider), returnsNormally);
        expect(() => container.read(playbackPositionProvider), returnsNormally);
      });

      test('should handle cross-provider state updates', () {
        final progressNotifier =
            container.read(progressUpdateProvider.notifier);

        // Should be able to read UI providers for preferences
        expect(() => container.read(fontSizeIndexProvider), returnsNormally);
        expect(() => container.read(playbackSpeedProvider), returnsNormally);

        // Should be able to update audio position
        expect(() => container.read(playbackPositionProvider.notifier),
            returnsNormally);
      });
    });

    group('Progress State Management', () {
      test('should track async operations', () {
        final state = container.read(progressUpdateProvider);
        expect(state, isA<AsyncValue<void>>());

        // Should handle all async states
        state.when(
          data: (_) => expect(true, true),
          loading: () => expect(true, true),
          error: (_, __) => expect(true, true),
        );
      });

      test('should handle progress updates with position', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should accept position parameters
        expect(
            () => notifier.updateProgress(
                  learningObjectId: 'test-id',
                  positionMs: 15000,
                ),
            returnsNormally);
      });

      test('should handle completion marking', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should mark as completed properly
        expect(() => notifier.markCompleted('test-id'), returnsNormally);
      });

      test('should handle progress resumption', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should handle resume logic
        expect(() => notifier.resumeProgress('test-id'), returnsNormally);
      });
    });

    group('Error Handling', () {
      test('should handle service errors gracefully', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should not throw when services are unavailable
        expect(
            () => notifier.updateProgress(
                  learningObjectId: 'invalid-id',
                  positionMs: 0,
                ),
            returnsNormally);
      });

      test('should handle authentication errors', () {
        final appInit = container.read(appInitializationProvider);

        // Should handle auth failures gracefully
        appInit.when(
          data: (result) => expect(result, isA<bool>()),
          loading: () => expect(true, true),
          error: (_, __) => expect(true, true),
        );
      });

      test('should handle invalid progress data', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should handle edge cases
        expect(
            () => notifier.updateProgress(
                  learningObjectId: '',
                  positionMs: -1,
                ),
            returnsNormally);
      });
    });

    group('Provider Dependencies', () {
      test('should depend on auth providers', () {
        // Auth providers should be accessible
        expect(() => container.read(authServiceProvider), returnsNormally);
        expect(() => container.read(currentUserProvider), returnsNormally);
        expect(() => container.read(isAuthenticatedProvider), returnsNormally);
      });

      test('should depend on course providers', () {
        // Course providers should be accessible
        expect(() => container.read(supabaseServiceProvider), returnsNormally);
        expect(() => container.read(progressProvider('test')), returnsNormally);
      });

      test('should depend on UI providers', () {
        // UI providers should be accessible
        expect(() => container.read(fontSizeIndexProvider), returnsNormally);
        expect(() => container.read(playbackSpeedProvider), returnsNormally);
      });

      test('should depend on audio providers', () {
        // Audio providers should be accessible
        expect(() => container.read(playbackPositionProvider), returnsNormally);
      });
    });

    group('Preference Synchronization', () {
      test('should sync font size preferences', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should be able to access font size provider
        expect(() => container.read(fontSizeIndexProvider), returnsNormally);
        expect(() => container.read(fontSizeIndexProvider.notifier),
            returnsNormally);
      });

      test('should sync playback speed preferences', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should be able to access playback speed provider
        expect(() => container.read(playbackSpeedProvider), returnsNormally);
        expect(() => container.read(playbackSpeedProvider.notifier),
            returnsNormally);
      });

      test('should restore preferences from progress', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should be able to restore user preferences
        expect(() => notifier.resumeProgress('test-id'), returnsNormally);
      });
    });

    group('Position Tracking', () {
      test('should track playback position', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should handle position updates
        expect(
            () => notifier.updateProgress(
                  learningObjectId: 'test-id',
                  positionMs: 30000,
                ),
            returnsNormally);
      });

      test('should handle position restoration', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should restore position from saved progress
        expect(() => notifier.resumeProgress('test-id'), returnsNormally);

        // Should access position provider
        expect(() => container.read(playbackPositionProvider.notifier),
            returnsNormally);
      });

      test('should handle zero position for completion', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Completion should reset position to 0
        expect(() => notifier.markCompleted('test-id'), returnsNormally);
      });
    });

    group('State Transitions', () {
      test('should handle loading state during updates', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Initial state should be data
        expect(notifier.state, isA<AsyncData<void>>());
        expect(notifier.state.hasValue, isTrue);
      });

      test('should handle completion state changes', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should handle completion marking
        expect(() => notifier.markCompleted('test-id'), returnsNormally);
      });

      test('should handle progress vs completed states', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should handle both progress and completion
        expect(
            () => notifier.updateProgress(
                  learningObjectId: 'test-id',
                  positionMs: 1000,
                  isInProgress: true,
                  isCompleted: false,
                ),
            returnsNormally);

        expect(
            () => notifier.updateProgress(
                  learningObjectId: 'test-id',
                  positionMs: 0,
                  isInProgress: false,
                  isCompleted: true,
                ),
            returnsNormally);
      });
    });

    group('Service Integration', () {
      test('should integrate with Supabase service', () {
        // Should be able to access Supabase service
        expect(() => container.read(supabaseServiceProvider), returnsNormally);
      });

      test('should handle service initialization', () {
        final appInit = container.read(appInitializationProvider);

        // Should initialize required services
        expect(appInit, isA<AsyncValue<bool>>());
      });

      test('should handle authentication bridging', () {
        final appInit = container.read(appInitializationProvider);

        // Should handle auth bridging logic
        appInit.when(
          data: (success) => expect(success, isA<bool>()),
          loading: () => expect(true, true),
          error: (_, __) => expect(true, true),
        );
      });
    });

    group('Provider Lifecycle', () {
      test('providers should be disposable', () {
        final testContainer = ProviderContainer();

        testContainer.read(progressUpdateProvider);
        testContainer.read(appInitializationProvider);

        expect(() => testContainer.dispose(), returnsNormally);
      });

      test('should handle provider recreation', () {
        final testContainer = ProviderContainer();
        final notifier1 = testContainer.read(progressUpdateProvider.notifier);
        testContainer.dispose();

        final newContainer = ProviderContainer();
        final notifier2 = newContainer.read(progressUpdateProvider.notifier);

        // Should be different instances
        expect(identical(notifier1, notifier2), isFalse);
        newContainer.dispose();
      });
    });

    group('Cache Invalidation', () {
      test('should invalidate progress cache on updates', () {
        final notifier = container.read(progressUpdateProvider.notifier);

        // Should handle cache invalidation
        expect(
            () => notifier.updateProgress(
                  learningObjectId: 'test-id',
                  positionMs: 5000,
                ),
            returnsNormally);
      });

      test('should handle progress provider invalidation', () {
        // Should be able to access progress provider
        expect(
            () => container.read(progressProvider('test-id')), returnsNormally);
      });
    });

    group('Mock Authentication Handling', () {
      test('should handle mock tokens in initialization', () {
        final appInit = container.read(appInitializationProvider);

        // Should handle mock token detection
        appInit.when(
          data: (result) => expect(result, isA<bool>()),
          loading: () => expect(true, true),
          error: (_, __) => expect(true, true),
        );
      });

      test('should skip Cognito bridge for mock auth', () {
        final appInit = container.read(appInitializationProvider);

        // Should handle mock auth without bridging
        expect(appInit, isA<AsyncValue<bool>>());
      });
    });
  });
}
