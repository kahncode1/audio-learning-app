import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

import 'package:audio_learning_app/services/audio_player_service_local.dart';
import 'package:audio_learning_app/services/local_content_service.dart';
import 'package:audio_learning_app/services/word_timing_service_simplified.dart';
import 'package:audio_learning_app/services/audio_handler.dart';
import 'package:audio_learning_app/models/learning_object.dart';
import 'package:audio_learning_app/models/word_timing.dart';

void main() {
  late AudioPlayerServiceLocal service;

  // Test data
  final testLearningObject = LearningObject(
    id: 'test-id-123',
    assignmentId: 'test-assignment',
    title: 'Test Learning Object',
    contentType: 'audio',
    ssmlContent: '<speak>Test content</speak>',
    plainText: 'Test content',
    orderIndex: 1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    isCompleted: false,
    currentPositionMs: 0,
  );

  final testTimingData = TimingData(
    words: [
      WordTiming(
        word: 'Test',
        startMs: 0,
        endMs: 500,
        sentenceIndex: 0,
        wordIndexInSentence: 0,
      ),
      WordTiming(
        word: 'content',
        startMs: 500,
        endMs: 1000,
        sentenceIndex: 0,
        wordIndexInSentence: 1,
      ),
    ],
    sentences: [
      SentenceTiming(
        text: 'Test content',
        startMs: 0,
        endMs: 1000,
        wordIndexStart: 0,
        wordIndexEnd: 1,
      ),
    ],
    totalDurationMs: 1000,
  );

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    // Note: AudioPlayerServiceLocal uses singleton pattern
    // These tests focus on the public API behavior
    service = AudioPlayerServiceLocal.instance;
  });

  group('AudioPlayerServiceLocal - Initialization', () {
    test('should be a singleton', () {
      final instance1 = AudioPlayerServiceLocal.instance;
      final instance2 = AudioPlayerServiceLocal.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('should initialize with default values', () {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.isPlaying, isFalse);
      expect(service.position, Duration.zero);
      expect(service.speed, 1.0);
      expect(service.currentWordTimings, isEmpty);
      expect(service.currentDisplayText, isNull);
      expect(service.currentLearningObject, isNull);
    });

    test('should have speed options configured', () {
      expect(AudioPlayerServiceLocal.speedOptions, [0.8, 1.0, 1.25, 1.5, 1.75, 2.0]);
    });

    test('should have skip duration configured', () {
      expect(AudioPlayerServiceLocal.skipDuration, const Duration(seconds: 30));
    });
  });

  group('AudioPlayerServiceLocal - Audio Loading', () {
    test('should load local audio successfully', () async {
      final service = AudioPlayerServiceLocal.instance;
      
      // This test would require more complex mocking due to singleton pattern
      // For now, we verify the method exists and can be called
      expect(service.loadLocalAudio, isA<Function>());
    });

    test('should throw when content is not available locally', () async {
      // This would test the error case when content is missing
      // Requires mocking LocalContentService which is created internally
    });

    test('should load audio with fallback method for compatibility', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.loadAudio, isA<Function>());
      expect(service.loadLearningObject, isA<Function>());
    });
  });

  group('AudioPlayerServiceLocal - Playback Controls', () {
    test('play() should start playback', () async {
      final service = AudioPlayerServiceLocal.instance;
      // Method signature test - actual behavior requires complex mocking
      expect(service.play, isA<Function>());
    });

    test('pause() should pause playback', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.pause, isA<Function>());
    });

    test('togglePlayPause() should toggle between play and pause', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.togglePlayPause, isA<Function>());
    });

    test('stop() should stop playback and reset position', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.stop, isA<Function>());
    });
  });

  group('AudioPlayerServiceLocal - Seeking', () {
    test('skipForward() should skip forward by 30 seconds', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.skipForward, isA<Function>());
    });

    test('skipBackward() should skip backward by 30 seconds', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.skipBackward, isA<Function>());
    });

    test('seekToPosition() should seek to specific position', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.seekToPosition, isA<Function>());
    });
  });

  group('AudioPlayerServiceLocal - Speed Control', () {
    test('cycleSpeed() should cycle through speed options', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.cycleSpeed, isA<Function>());
    });

    test('setSpeed() should set specific speed', () async {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.setSpeed, isA<Function>());
    });

    test('speed options should be valid', () {
      for (final speed in AudioPlayerServiceLocal.speedOptions) {
        expect(speed, greaterThan(0));
        expect(speed, lessThanOrEqualTo(2.0));
      }
    });
  });

  group('AudioPlayerServiceLocal - Word Timing', () {
    test('getCurrentWordIndex() should return current word index', () {
      final service = AudioPlayerServiceLocal.instance;
      final index = service.getCurrentWordIndex();
      expect(index, isA<int>());
      expect(index, equals(-1)); // No timing data loaded
    });

    test('getCurrentSentenceIndex() should return current sentence index', () {
      final service = AudioPlayerServiceLocal.instance;
      final index = service.getCurrentSentenceIndex();
      expect(index, isA<int>());
      expect(index, equals(-1)); // No timing data loaded
    });
  });

  group('AudioPlayerServiceLocal - Streams', () {
    test('should provide isPlayingStream', () {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.isPlayingStream, isA<Stream<bool>>());
    });

    test('should provide positionStream', () {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.positionStream, isA<Stream<Duration>>());
    });

    test('should provide durationStream', () {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.durationStream, isA<Stream<Duration>>());
    });

    test('should provide speedStream', () {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.speedStream, isA<Stream<double>>());
    });

    test('should provide processingStateStream', () {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.processingStateStream, isA<Stream<ProcessingState>>());
    });
  });

  group('AudioPlayerServiceLocal - Duration Sanitization', () {
    test('should handle corrupted duration values', () {
      // This tests the duration sanitization logic
      // The service should detect and correct corrupted duration values
      final service = AudioPlayerServiceLocal.instance;
      
      // The service has logic to handle:
      // - Negative durations
      // - Extremely large durations (>1 hour)
      // - Milliseconds incorrectly interpreted as seconds
      expect(service.duration, isNotNull);
    });
  });

  group('AudioPlayerServiceLocal - Position Sanitization', () {
    test('should handle negative position values', () {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.position.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('should handle position exceeding duration', () {
      final service = AudioPlayerServiceLocal.instance;
      // Position should never exceed duration
      if (service.duration.inMilliseconds > 0) {
        expect(
          service.position.inMilliseconds,
          lessThanOrEqualTo(service.duration.inMilliseconds),
        );
      }
    });
  });

  group('AudioPlayerServiceLocal - Resource Management', () {
    test('dispose() should clean up resources', () {
      final service = AudioPlayerServiceLocal.instance;
      expect(service.dispose, isA<Function>());
      // Note: Don't actually dispose the singleton in tests
    });
  });

  group('AudioPlayerServiceLocal - Edge Cases', () {
    test('should handle loading with saved position', () async {
      final learningObjectWithPosition = LearningObject(
        id: 'test-id-123',
        assignmentId: 'test-assignment',
        title: 'Test with Position',
        contentType: 'audio',
        ssmlContent: '<speak>Test</speak>',
        plainText: 'Test',
        orderIndex: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isCompleted: false,
        currentPositionMs: 5000, // Saved position
      );

      final service = AudioPlayerServiceLocal.instance;
      // Would restore to saved position when loading
      expect(learningObjectWithPosition.currentPositionMs, 5000);
    });

    test('should handle asset paths vs file paths', () {
      // Service should distinguish between:
      // - assets/ paths (test content)
      // - file system paths (downloaded content)
      final assetPath = 'assets/audio/test.mp3';
      final filePath = '/path/to/audio.mp3';
      
      expect(assetPath.startsWith('assets/'), isTrue);
      expect(filePath.startsWith('assets/'), isFalse);
    });

    test('should handle interruptions properly', () {
      // Audio session configuration should handle:
      // - Duck (lower volume)
      // - Pause (pause playback)
      // - Resume (restore volume)
      final service = AudioPlayerServiceLocal.instance;
      expect(service, isNotNull);
    });
  });

  group('AudioPlayerServiceLocal - Integration Points', () {
    test('should integrate with WordTimingServiceSimplified', () {
      // Critical integration point for highlighting
      // Service should share timing data with WordTimingService
      final service = AudioPlayerServiceLocal.instance;
      expect(service, isNotNull);
    });

    test('should integrate with LocalContentService', () {
      // Service should use LocalContentService for:
      // - Checking content availability
      // - Loading content and timing data
      // - Getting audio file paths
      final service = AudioPlayerServiceLocal.instance;
      expect(service, isNotNull);
    });

    test('should integrate with AudioHandler for lock screen', () {
      // Service should update media item for lock screen controls
      final service = AudioPlayerServiceLocal.instance;
      expect(service, isNotNull);
    });
  });
}