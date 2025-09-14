import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:audio_learning_app/config/env_config.dart';
import 'package:audio_learning_app/services/speechify_service.dart';
import 'package:audio_learning_app/models/word_timing.dart';

void main() {
  group('Speechify API Integration Tests', () {
    late SpeechifyService service;

    setUpAll(() async {
      // Load environment variables
      await EnvConfig.load();

      // Verify API key is configured
      expect(EnvConfig.isSpeechifyConfigured, isTrue,
          reason: 'Speechify API key must be configured in .env file');
    });

    setUp(() {
      service = SpeechifyService();
    });

    test('API key is loaded correctly', () {
      final apiKey = EnvConfig.speechifyApiKey;
      expect(apiKey, isNotEmpty);
      expect(apiKey.length, equals(44)); // Including the = at the end
      expect(apiKey, startsWith('yC5SufqmMc'));
      expect(apiKey, endsWith('Jkw='));
    });

    test('Base URL is configured correctly', () {
      final baseUrl = EnvConfig.speechifyBaseUrl;
      expect(baseUrl, equals('https://api.sws.speechify.com'));
    });

    test('Generate audio with default voice', () async {
      const testContent = 'Hello, this is a test of the Speechify API.';

      final result = await service.generateAudioStream(
        content: testContent,
        voice: 'henry',
      );

      // Verify audio data
      expect(result.audioData, isNotEmpty);
      expect(result.audioFormat, equals('wav'));

      // Verify we can decode the audio
      final audioBytes = result.getAudioBytes();
      expect(audioBytes, isNotEmpty);
      expect(audioBytes.length, greaterThan(100000)); // Should be substantial audio data

      // Verify WAV header
      final wavHeader = String.fromCharCodes(audioBytes.take(4));
      expect(wavHeader, equals('RIFF'));
    });

    test('Generate audio with word timings', () async {
      const testContent = 'This is a test sentence with multiple words.';

      final result = await service.generateAudioWithTimings(
        content: testContent,
      );

      // Verify audio data
      expect(result.audioData, isNotEmpty);

      // Verify word timings
      expect(result.wordTimings, isNotEmpty);
      expect(result.wordTimings.length, greaterThanOrEqualTo(7)); // At least 7 words

      // Check first word timing
      final firstWord = result.wordTimings.first;
      expect(firstWord.word, isNotEmpty);
      expect(firstWord.startMs, equals(0));
      expect(firstWord.endMs, greaterThan(0));

      // Check timing sequence
      for (int i = 1; i < result.wordTimings.length; i++) {
        final prevWord = result.wordTimings[i - 1];
        final currWord = result.wordTimings[i];

        // Current word should start at or after previous word ends
        expect(currWord.startMs, greaterThanOrEqualTo(prevWord.endMs));

        // Word should have duration
        expect(currWord.endMs, greaterThan(currWord.startMs));
      }
    });

    test('Generate audio with different speeds', () async {
      const testContent = 'Testing different playback speeds.';

      // Test slow speed
      final slowResult = await service.generateAudioStream(
        content: testContent,
        speed: 0.8,
      );
      expect(slowResult.audioData, isNotEmpty);

      // Test normal speed
      final normalResult = await service.generateAudioStream(
        content: testContent,
        speed: 1.0,
      );
      expect(normalResult.audioData, isNotEmpty);

      // Test fast speed
      final fastResult = await service.generateAudioStream(
        content: testContent,
        speed: 1.5,
      );
      expect(fastResult.audioData, isNotEmpty);
    });

    test('Parse speech marks correctly', () async {
      const testContent = 'Hello world, how are you today?';

      final result = await service.generateAudioWithTimings(
        content: testContent,
      );

      // Verify word timings parsed correctly
      expect(result.wordTimings, isNotEmpty);

      // Check words match content
      final words = result.wordTimings.map((t) => t.word).toList();
      final joinedWords = words.join(' ');

      // Should contain the main words (punctuation may vary)
      expect(joinedWords.toLowerCase(), contains('hello'));
      expect(joinedWords.toLowerCase(), contains('world'));
      expect(joinedWords.toLowerCase(), contains('how'));
      expect(joinedWords.toLowerCase(), contains('are'));
      expect(joinedWords.toLowerCase(), contains('you'));
      expect(joinedWords.toLowerCase(), contains('today'));
    });

    test('Handle SSML content', () async {
      const plainText = 'This is a test. Another sentence here.';
      final ssmlContent = service.processSSMLContent(plainText);

      // Verify SSML formatting
      expect(ssmlContent, contains('<speak>'));
      expect(ssmlContent, contains('</speak>'));
      expect(ssmlContent, contains('<s>'));
      expect(ssmlContent, contains('</s>'));
      expect(ssmlContent, contains('<break time="200ms"/>'));

      // Test generation with SSML
      final result = await service.generateAudioStream(
        content: ssmlContent,
        isSSML: true,
      );

      expect(result.audioData, isNotEmpty);
    });

    test('Handle API errors gracefully', () async {
      // Test with invalid voice
      expect(
        () => service.generateAudioStream(
          content: 'Test',
          voice: 'invalid_voice_id',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Verify word timing synchronization', () async {
      const testContent = 'One two three four five.';

      final result = await service.generateAudioWithTimings(
        content: testContent,
      );

      // Each word should have reasonable duration
      for (final timing in result.wordTimings) {
        final duration = timing.endMs - timing.startMs;

        // Each word should take at least 50ms to say
        expect(duration, greaterThanOrEqualTo(50));

        // But not more than 2 seconds
        expect(duration, lessThanOrEqualTo(2000));
      }

      // Total duration should be reasonable
      if (result.wordTimings.isNotEmpty) {
        final totalDuration = result.wordTimings.last.endMs;

        // 5 words should take between 1-5 seconds
        expect(totalDuration, greaterThanOrEqualTo(1000));
        expect(totalDuration, lessThanOrEqualTo(5000));
      }
    });

    test('Generate long content', () async {
      const longContent = '''
        This is a longer piece of content to test the Speechify API.
        It contains multiple sentences and should generate a larger audio file.
        We want to ensure that the API can handle longer texts without issues.
        The word timings should still be accurate for all words in the content.
      ''';

      final result = await service.generateAudioWithTimings(
        content: longContent,
      );

      expect(result.audioData, isNotEmpty);
      expect(result.wordTimings, isNotEmpty);

      // Should have many word timings
      expect(result.wordTimings.length, greaterThan(20));

      // Audio should be larger for longer content
      final audioBytes = result.getAudioBytes();
      expect(audioBytes.length, greaterThan(500000)); // > 500KB for long content
    });

    test('Verify configuration validation', () {
      expect(service.isConfigured(), isTrue);
    });
  });
}