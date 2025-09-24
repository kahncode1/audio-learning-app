import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:audio_learning_app/services/local_content_service.dart';

/// Unit tests for LocalContentService
///
/// Purpose: Tests pre-processed content loading functionality
/// Coverage: Content availability, audio paths, timing data, and error handling
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalContentService', () {
    late LocalContentService service;
    const testId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';
    const invalidId = 'invalid-learning-object-id';

    setUpAll(() {
      // Set up the test asset bundle to load test content
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/assets'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'list') {
            return [];
          }
          return null;
        },
      );
    });

    setUp(() {
      service = LocalContentService();
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = LocalContentService();
        final instance2 = LocalContentService();
        final instance3 = LocalContentService.instance;

        expect(identical(instance1, instance2), isTrue);
        expect(identical(instance1, instance3), isTrue);
      });
    });

    group('Content Availability', () {
      test('should detect available test content', () async {
        final isAvailable = await service.isContentAvailable(testId);
        expect(isAvailable, isTrue);
      });

      test('should detect unavailable content', () async {
        final isAvailable = await service.isContentAvailable(invalidId);
        expect(isAvailable, isFalse);
      });
    });

    group('Audio Path', () {
      test('should return valid audio path for test content', () async {
        final path = await service.getAudioPath(testId);

        expect(path, isNotEmpty);
        expect(path, contains(testId));
        expect(path, contains('audio.mp3'));
        expect(path, startsWith('assets/test_content/'));
      });
    });

    group('Content Loading', () {
      test('should load content.json successfully', () async {
        final content = await service.getContent(testId);

        expect(content, isNotNull);
        expect(content['version'], equals('1.0'));
        expect(content['displayText'], isNotNull);
        expect(content['displayText'], isNotEmpty);
        expect(content['paragraphs'], isNotNull);
        expect(content['paragraphs'], isList);
      });

      test('should extract display text correctly', () async {
        final content = await service.getContent(testId);
        final displayText = LocalContentService.getDisplayText(content);

        expect(displayText, isNotEmpty);
        expect(displayText, contains('case reserve'));
      });

      test('should extract paragraphs correctly', () async {
        final content = await service.getContent(testId);
        final paragraphs = LocalContentService.getParagraphs(content);

        expect(paragraphs, isNotEmpty);
        expect(paragraphs, isList);
        expect(paragraphs.length, equals(4));
      });

      test('should have valid metadata', () async {
        final content = await service.getContent(testId);
        final metadata = content['metadata'] as Map<String, dynamic>?;

        expect(metadata, isNotNull);
        expect(metadata!['wordCount'], equals(63));
        expect(metadata['characterCount'], greaterThan(0));
        expect(metadata['estimatedReadingTime'], isNotNull);
      });
    });

    group('Timing Data', () {
      test('should load timing data successfully', () async {
        final timingData = await service.getTimingData(testId);

        expect(timingData, isNotNull);
        expect(timingData.words, isNotEmpty);
        expect(timingData.sentences, isNotEmpty);
        expect(timingData.totalDurationMs, greaterThan(0));
      });

      test('should have correct word count', () async {
        final timingData = await service.getTimingData(testId);
        expect(timingData.words.length, equals(63));
      });

      test('should have correct sentence count', () async {
        final timingData = await service.getTimingData(testId);
        expect(timingData.sentences.length, equals(4));
      });

      test('should have valid word timings', () async {
        final timingData = await service.getTimingData(testId);

        for (final word in timingData.words) {
          expect(word.word, isNotEmpty);
          expect(word.startMs, greaterThanOrEqualTo(0));
          expect(word.endMs, greaterThan(word.startMs));
          expect(word.sentenceIndex, greaterThanOrEqualTo(0));
          expect(word.charStart != null ? word.charStart! : 0,
              greaterThanOrEqualTo(0));
          expect(word.charEnd != null ? word.charEnd! : 0,
              greaterThanOrEqualTo(word.charStart ?? 0));
        }
      });

      test('should have valid sentence timings', () async {
        final timingData = await service.getTimingData(testId);

        for (final sentence in timingData.sentences) {
          expect(sentence.text, isNotEmpty);
          expect(sentence.startTime, greaterThanOrEqualTo(0));
          expect(sentence.endTime, greaterThan(sentence.startTime));
          expect(sentence.wordStartIndex, greaterThanOrEqualTo(0));
          expect(sentence.wordEndIndex,
              greaterThanOrEqualTo(sentence.wordStartIndex));
        }
      });

      test('words should be properly assigned to sentences', () async {
        final timingData = await service.getTimingData(testId);

        // Check that all words have valid sentence indices
        for (final word in timingData.words) {
          expect(word.sentenceIndex, lessThan(timingData.sentences.length));
        }

        // Check sentence word ranges
        for (final sentence in timingData.sentences) {
          final wordsInSentence =
              sentence.wordEndIndex - sentence.wordStartIndex + 1;
          expect(wordsInSentence, greaterThan(0));
        }
      });

      test('should find correct word at position', () async {
        final timingData = await service.getTimingData(testId);

        // Test at beginning
        expect(timingData.getCurrentWordIndex(0), equals(0));

        // Test at middle (5 seconds)
        final midIndex = timingData.getCurrentWordIndex(5000);
        expect(midIndex, greaterThanOrEqualTo(0));
        expect(midIndex, lessThan(timingData.words.length));

        // Test at end
        final endIndex =
            timingData.getCurrentWordIndex(timingData.totalDurationMs);
        expect(endIndex, equals(timingData.words.length - 1));

        // Test beyond end
        final beyondIndex =
            timingData.getCurrentWordIndex(timingData.totalDurationMs + 1000);
        expect(beyondIndex, equals(-1));
      });

      test('should find correct sentence at position', () async {
        final timingData = await service.getTimingData(testId);

        // Test at beginning
        expect(timingData.getCurrentSentenceIndex(0), equals(0));

        // Test at middle
        final midIndex = timingData.getCurrentSentenceIndex(10000);
        expect(midIndex, greaterThanOrEqualTo(0));
        expect(midIndex, lessThan(timingData.sentences.length));

        // Test at end
        final endIndex =
            timingData.getCurrentSentenceIndex(timingData.totalDurationMs);
        expect(endIndex, equals(timingData.sentences.length - 1));
      });
    });

    group('Error Handling', () {
      test('should throw when loading non-existent content', () async {
        expect(
          () => service.getContent(invalidId),
          throwsA(isA<Exception>()),
        );
      });

      test('should throw when loading non-existent timing data', () async {
        expect(
          () => service.getTimingData(invalidId),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
