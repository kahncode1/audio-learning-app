import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:audio_learning_app/providers/audio_providers.dart';
import 'package:audio_learning_app/services/audio_player_service_local.dart';
import 'package:audio_learning_app/models/learning_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Audio Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('audioPlayerServiceProvider', () {
      test('should provide AudioPlayerServiceLocal singleton', () {
        final service = container.read(audioPlayerServiceProvider);
        
        expect(service, isA<AudioPlayerServiceLocal>());
        expect(service, AudioPlayerServiceLocal.instance);
      });

      test('should provide same instance on multiple reads', () {
        final service1 = container.read(audioPlayerServiceProvider);
        final service2 = container.read(audioPlayerServiceProvider);
        
        expect(identical(service1, service2), isTrue);
      });
    });

    group('currentLearningObjectProvider', () {
      test('should start with null value', () {
        final currentObject = container.read(currentLearningObjectProvider);
        expect(currentObject, isNull);
      });

      test('should update current learning object', () {
        final learningObject = LearningObject(
          id: 'test-123',
          assignmentId: 'assign-456',
          title: 'Test Learning Object',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        container.read(currentLearningObjectProvider.notifier).state = learningObject;
        
        final currentObject = container.read(currentLearningObjectProvider);
        expect(currentObject, equals(learningObject));
        expect(currentObject!.id, 'test-123');
      });

      test('should allow clearing current learning object', () {
        final learningObject = LearningObject(
          id: 'test-123',
          assignmentId: 'assign-456',
          title: 'Test Learning Object',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        // Set then clear
        container.read(currentLearningObjectProvider.notifier).state = learningObject;
        container.read(currentLearningObjectProvider.notifier).state = null;
        
        final currentObject = container.read(currentLearningObjectProvider);
        expect(currentObject, isNull);
      });
    });

    group('Stream Providers', () {
      test('isAudioLoadedProvider should provide stream', () {
        final provider = container.read(isAudioLoadedProvider);
        expect(provider, isA<AsyncValue<bool>>());
      });

      test('audioPlayingStateProvider should provide stream', () {
        final provider = container.read(audioPlayingStateProvider);
        expect(provider, isA<AsyncValue<bool>>());
      });

      test('audioPositionProvider should provide stream', () {
        final provider = container.read(audioPositionProvider);
        expect(provider, isA<AsyncValue<Duration>>());
      });

      test('audioDurationProvider should provide stream', () {
        final provider = container.read(audioDurationProvider);
        expect(provider, isA<AsyncValue<Duration>>());
      });

      test('audioLoadingStateProvider should provide stream', () {
        final provider = container.read(audioLoadingStateProvider);
        expect(provider, isA<AsyncValue<ProcessingState>>());
      });
    });

    group('audioProgressProvider', () {
      test('should return 0.0 when no duration', () {
        // Mock empty streams
        final progress = container.read(audioProgressProvider);
        expect(progress, 0.0);
      });

      test('should calculate progress correctly', () {
        // This would require mocking the audio service streams
        // For now, test the provider exists and returns a double
        final progress = container.read(audioProgressProvider);
        expect(progress, isA<double>());
        expect(progress, greaterThanOrEqualTo(0.0));
        expect(progress, lessThanOrEqualTo(1.0));
      });
    });

    group('shouldShowMiniPlayerProvider', () {
      test('should return boolean value', () {
        final shouldShow = container.read(shouldShowMiniPlayerProvider);
        expect(shouldShow, isA<bool>());
      });

      test('should be false when no audio is loaded', () {
        // By default, no audio should be loaded
        final shouldShow = container.read(shouldShowMiniPlayerProvider);
        expect(shouldShow, false);
      });
    });

    group('Format Providers', () {
      test('formattedPositionProvider should return formatted string', () {
        final formatted = container.read(formattedPositionProvider);
        expect(formatted, isA<String>());
        expect(formatted, matches(r'^\d+:\d{2}$')); // Format like "0:00"
      });

      test('formattedDurationProvider should return formatted string', () {
        final formatted = container.read(formattedDurationProvider);
        expect(formatted, isA<String>());
        expect(formatted, matches(r'^\d+:\d{2}$')); // Format like "0:00"
      });

      test('should format zero duration as 0:00', () {
        // By default, duration should be zero
        final formatted = container.read(formattedDurationProvider);
        expect(formatted, '0:00');
      });

      test('should format zero position as 0:00', () {
        // By default, position should be zero
        final formatted = container.read(formattedPositionProvider);
        expect(formatted, '0:00');
      });
    });

    group('Provider Dependencies', () {
      test('audio providers should depend on audioPlayerServiceProvider', () {
        // Verify that providers can access the audio service
        final service = container.read(audioPlayerServiceProvider);
        expect(service, isNotNull);

        // Stream providers should be able to access service streams
        expect(() => container.read(audioPlayingStateProvider), returnsNormally);
        expect(() => container.read(audioPositionProvider), returnsNormally);
        expect(() => container.read(audioDurationProvider), returnsNormally);
      });

      test('computed providers should handle null stream values', () {
        // Progress provider should handle null values gracefully
        final progress = container.read(audioProgressProvider);
        expect(progress, isA<double>());

        // Format providers should handle null values gracefully
        final formattedPos = container.read(formattedPositionProvider);
        final formattedDur = container.read(formattedDurationProvider);
        expect(formattedPos, isA<String>());
        expect(formattedDur, isA<String>());
      });
    });

    group('Provider Lifecycle', () {
      test('providers should be disposable', () {
        // Create and dispose container
        final testContainer = ProviderContainer();
        testContainer.read(audioPlayerServiceProvider);
        testContainer.read(currentLearningObjectProvider);
        
        expect(() => testContainer.dispose(), returnsNormally);
      });

      test('providers should be re-readable after disposal', () {
        final testContainer = ProviderContainer();
        final service1 = testContainer.read(audioPlayerServiceProvider);
        testContainer.dispose();
        
        final newContainer = ProviderContainer();
        final service2 = newContainer.read(audioPlayerServiceProvider);
        
        // Should get same singleton instance
        expect(identical(service1, service2), isTrue);
        newContainer.dispose();
      });
    });

    group('State Updates', () {
      test('currentLearningObjectProvider should notify listeners on change', () {
        var notificationCount = 0;
        
        container.listen(
          currentLearningObjectProvider,
          (previous, next) => notificationCount++,
        );

        final learningObject = LearningObject(
          id: 'test-notify',
          assignmentId: 'assign-notify',
          title: 'Notification Test',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        container.read(currentLearningObjectProvider.notifier).state = learningObject;
        
        expect(notificationCount, 1);
        expect(container.read(currentLearningObjectProvider), equals(learningObject));
      });
    });

    group('Error Handling', () {
      test('stream providers should handle service errors gracefully', () {
        // Stream providers should not throw even if service has issues
        expect(() => container.read(audioPlayingStateProvider), returnsNormally);
        expect(() => container.read(audioPositionProvider), returnsNormally);
        expect(() => container.read(audioDurationProvider), returnsNormally);
      });

      test('computed providers should handle missing dependencies', () {
        // Progress provider should handle null/missing stream values
        expect(() => container.read(audioProgressProvider), returnsNormally);
        expect(() => container.read(shouldShowMiniPlayerProvider), returnsNormally);
      });
    });

    group('Integration', () {
      test('providers should work together', () {
        // Set a learning object
        final learningObject = LearningObject(
          id: 'integration-test',
          assignmentId: 'assign-integration',
          title: 'Integration Test',
          contentType: 'audio',
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 5000,
        );

        container.read(currentLearningObjectProvider.notifier).state = learningObject;

        // Verify other providers can access this
        final currentObject = container.read(currentLearningObjectProvider);
        expect(currentObject!.id, 'integration-test');

        // Other providers should work
        final service = container.read(audioPlayerServiceProvider);
        expect(service, isNotNull);

        final progress = container.read(audioProgressProvider);
        expect(progress, isA<double>());
      });
    });
  });
}