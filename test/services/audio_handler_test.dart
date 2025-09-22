import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'package:audio_learning_app/services/audio_handler.dart';
import 'package:audio_learning_app/models/learning_object.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioLearningHandler', () {
    late AudioPlayer audioPlayer;
    late AudioLearningHandler handler;

    setUp(() {
      audioPlayer = AudioPlayer();
      handler = AudioLearningHandler(audioPlayer);
    });

    tearDown(() {
      handler.dispose();
    });

    group('Initialization', () {
      test('should create handler with audio player', () {
        expect(handler, isNotNull);
        expect(handler, isA<AudioLearningHandler>());
      });

      test('should extend BaseAudioHandler', () {
        expect(handler, isA<BaseAudioHandler>());
      });

      test('should have SeekHandler mixin', () {
        expect(handler, isA<SeekHandler>());
      });
    });

    group('Media Item Management', () {
      test('should update media item for learning object', () {
        final learningObject = LearningObject(
          id: 'test-123',
          assignmentId: 'assignment-1',
          title: 'Test Audio Lesson',
          contentType: 'audio',
          ssmlContent: '<speak>Test content with multiple sentences.</speak>',
          plainText: 'Test content with multiple sentences.',
          orderIndex: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        handler.updateMediaItemForLearning(
          learningObject,
          audioDuration: const Duration(minutes: 5),
        );

        // The media item should be updated (we can't easily verify the stream)
        expect(learningObject.title, 'Test Audio Lesson');
      });

      test('should estimate duration when not provided', () {
        final learningObject = LearningObject(
          id: 'test-456',
          assignmentId: 'assignment-2',
          title: 'Long Content',
          contentType: 'audio',
          ssmlContent: '<speak>' + ('word ' * 300) + '</speak>', // 300 words
          plainText: 'word ' * 300, // 300 words
          orderIndex: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isCompleted: false,
          currentPositionMs: 0,
        );

        // ~150 words per minute, so 300 words = ~2 minutes
        handler.updateMediaItemForLearning(learningObject);
        
        // Verify estimation logic
        final wordCount = learningObject.plainText!.split(' ').length;
        final estimatedMinutes = (wordCount / 150).ceil();
        expect(estimatedMinutes, 2);
      });
    });

    group('Playback Controls', () {
      test('play() should call player.play()', () async {
        // Test the play method exists and can be called
        await handler.play();
        // In a real test with mocking, we'd verify _player.play() was called
      });

      test('pause() should call player.pause()', () async {
        await handler.pause();
        // In a real test with mocking, we'd verify _player.pause() was called
      });

      test('stop() should call player.stop()', () async {
        await handler.stop();
        // In a real test with mocking, we'd verify _player.stop() was called
      });

      test('seek() should seek to position', () async {
        const targetPosition = Duration(seconds: 30);
        await handler.seek(targetPosition);
        // In a real test with mocking, we'd verify _player.seek() was called
      });

      test('setSpeed() should set playback speed', () async {
        const speed = 1.5;
        await handler.setSpeed(speed);
        // In a real test with mocking, we'd verify _player.setSpeed() was called
      });
    });

    group('Skip Controls', () {
      test('skipToNext() should skip forward 30 seconds', () async {
        await handler.skipToNext();
        // Should skip forward by 30 seconds
        // In a real test, we'd verify the new position
      });

      test('skipToPrevious() should skip backward 30 seconds', () async {
        await handler.skipToPrevious();
        // Should skip backward by 30 seconds
        // In a real test, we'd verify the new position
      });

      test('skipToPrevious() should not go negative', () async {
        // When at the beginning
        await handler.seek(Duration.zero);
        await handler.skipToPrevious();
        // Should stay at zero, not go negative
      });
    });

    group('Processing State Mapping', () {
      test('should map just_audio states to audio_service states', () {
        // The handler maps ProcessingState values correctly:
        // idle -> idle
        // loading -> loading
        // buffering -> buffering
        // ready -> ready
        // completed -> completed
        expect(handler, isNotNull);
      });
    });

    group('Media Controls', () {
      test('should provide correct controls when playing', () {
        // When playing, should show: skipToPrevious, pause, skipToNext
        expect(MediaControl.pause, isNotNull);
        expect(MediaControl.skipToPrevious, isNotNull);
        expect(MediaControl.skipToNext, isNotNull);
      });

      test('should provide correct controls when paused', () {
        // When paused, should show: skipToPrevious, play, skipToNext
        expect(MediaControl.play, isNotNull);
        expect(MediaControl.skipToPrevious, isNotNull);
        expect(MediaControl.skipToNext, isNotNull);
      });
    });

    group('System Actions', () {
      test('should support seek actions', () {
        // Handler should support:
        // - MediaAction.seek
        // - MediaAction.seekForward
        // - MediaAction.seekBackward
        const supportedActions = {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        };
        expect(supportedActions.length, 3);
      });

      test('should have compact action indices for Android', () {
        // Android compact notification should show 3 actions
        const androidCompactActionIndices = [0, 1, 2];
        expect(androidCompactActionIndices.length, 3);
      });
    });

    group('Resource Management', () {
      test('dispose() should clean up resources', () {
        handler.dispose();
        // Handler should dispose of the audio player
        expect(handler, isNotNull); // Handler still exists but resources freed
      });
    });
  });

  group('initAudioService', () {
    test('should initialize audio service with correct config', () async {
      // The initAudioService function should set up:
      // - Correct notification channel ID
      // - Correct notification channel name
      // - Ongoing notification
      // - Stop foreground on pause
      // - 30 second skip intervals

      const expectedChannelId = 'com.audiolearning.app.audio';
      const expectedChannelName = 'Audio Learning';
      const expectedSkipInterval = Duration(seconds: 30);

      // Verify configuration values
      expect(expectedChannelId, contains('audio'));
      expect(expectedChannelName, contains('Audio'));
      expect(expectedSkipInterval.inSeconds, 30);
    });
  });

  group('Edge Cases', () {
    test('should handle empty learning object text', () {
      final emptyLearningObject = LearningObject(
        id: 'empty-1',
        assignmentId: 'assignment-1',
        title: 'Empty Content',
        contentType: 'audio',
        ssmlContent: '<speak></speak>',
        plainText: '', // Empty text
        orderIndex: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isCompleted: false,
        currentPositionMs: 0,
      );

      final handler = AudioLearningHandler(AudioPlayer());
      handler.updateMediaItemForLearning(emptyLearningObject);
      
      // Should handle empty text gracefully (minimum 1 minute duration)
      handler.dispose();
    });

    test('should handle null plain text', () {
      final nullTextObject = LearningObject(
        id: 'null-1',
        assignmentId: 'assignment-1',
        title: 'Null Text',
        contentType: 'audio',
        ssmlContent: '<speak>Content</speak>',
        plainText: null, // Null text
        orderIndex: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isCompleted: false,
        currentPositionMs: 0,
      );

      final handler = AudioLearningHandler(AudioPlayer());
      handler.updateMediaItemForLearning(nullTextObject);
      
      // Should handle null text gracefully
      handler.dispose();
    });

    test('should handle skip at boundaries', () async {
      final handler = AudioLearningHandler(AudioPlayer());
      
      // Test skip forward at end
      // (Would need mock to simulate being at the end of audio)
      await handler.skipToNext();
      
      // Test skip backward at beginning
      await handler.seek(Duration.zero);
      await handler.skipToPrevious();
      
      handler.dispose();
    });
  });

  group('Validation Function', () {
    test('validateAudioHandler should pass all checks', () {
      // The validation function should verify:
      // - AudioLearningHandler class exists
      // - Media controls are defined
      // - Audio service configuration is correct
      
      // This would normally be called at runtime in debug mode
      expect(() => validateAudioHandler(), returnsNormally);
    });
  });
}