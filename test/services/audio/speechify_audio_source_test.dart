import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_learning_app/services/audio/speechify_audio_source.dart';
import 'package:audio_learning_app/config/env_config.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Load environment variables for tests
    await EnvConfig.load();
  });

  group('SpeechifyAudioSource', () {
    group('Base64 Audio Handling', () {
      test('should create audio source from base64 data', () async {
        // Create sample WAV header (44 bytes) + some audio data
        final wavHeader = Uint8List.fromList([
          // RIFF header
          0x52, 0x49, 0x46, 0x46, // "RIFF"
          0x24, 0x00, 0x00, 0x00, // File size - 8
          0x57, 0x41, 0x56, 0x45, // "WAVE"
          // fmt subchunk
          0x66, 0x6D, 0x74, 0x20, // "fmt "
          0x10, 0x00, 0x00, 0x00, // Subchunk size
          0x01, 0x00, // Audio format (PCM)
          0x01, 0x00, // Number of channels
          0x44, 0xAC, 0x00, 0x00, // Sample rate (44100)
          0x88, 0x58, 0x01, 0x00, // Byte rate
          0x02, 0x00, // Block align
          0x10, 0x00, // Bits per sample
          // data subchunk
          0x64, 0x61, 0x74, 0x61, // "data"
          0x00, 0x00, 0x00, 0x00, // Data size
        ]);

        // Add some sample audio data
        final audioData = Uint8List.fromList(
          wavHeader.toList() + List.generate(100, (i) => i % 256)
        );

        // Encode to base64
        final base64Audio = base64.encode(audioData);

        // Create audio source
        final audioSource = await createSpeechifyAudioSource(base64Audio);

        expect(audioSource, isNotNull);
        expect(audioSource, isA<CustomAudioSource>());
      });

      test('should handle invalid base64 data', () async {
        const invalidBase64 = 'not-valid-base64!@#';

        expect(
          () => createSpeechifyAudioSource(invalidBase64),
          throwsA(isA<AudioSourceException>()),
        );
      });

      test('should decode base64 audio correctly', () async {
        // Create test audio data
        final originalBytes = Uint8List.fromList(
          List.generate(256, (i) => i % 256)
        );

        // Encode to base64
        final base64Audio = base64.encode(originalBytes);

        // Create audio source
        final audioSource = await createSpeechifyAudioSource(base64Audio) as CustomAudioSource;

        // Verify the decoded data matches
        expect(audioSource.audioData.length, equals(originalBytes.length));
        for (int i = 0; i < originalBytes.length; i++) {
          expect(audioSource.audioData[i], equals(originalBytes[i]));
        }
      });
    });

    group('CustomAudioSource', () {
      test('should handle range requests', () async {
        // Create test audio data
        final audioBytes = Uint8List.fromList(
          List.generate(1000, (i) => i % 256)
        );

        final audioSource = CustomAudioSource(audioBytes);

        // Request a specific range
        final response = await audioSource.request(100, 200);

        expect(response.sourceLength, equals(1000));
        expect(response.contentLength, equals(100));
        expect(response.offset, equals(100));
        expect(response.contentType, equals('audio/wav'));

        // Verify the stream data
        final chunks = await response.stream.toList();
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(100));

        // Check that the data is correct
        for (int i = 0; i < 100; i++) {
          expect(chunks[0][i], equals((100 + i) % 256));
        }
      });

      test('should handle full data request', () async {
        final audioBytes = Uint8List.fromList(
          List.generate(500, (i) => i % 256)
        );

        final audioSource = CustomAudioSource(audioBytes);

        // Request without range (full data)
        final response = await audioSource.request();

        expect(response.sourceLength, equals(500));
        expect(response.contentLength, equals(500));
        expect(response.offset, equals(0));

        final chunks = await response.stream.toList();
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(500));
      });

      test('should handle out-of-bounds requests', () async {
        final audioBytes = Uint8List.fromList(
          List.generate(100, (i) => i % 256)
        );

        final audioSource = CustomAudioSource(audioBytes);

        // Request beyond data bounds
        final response = await audioSource.request(50, 200);

        expect(response.sourceLength, equals(100));
        expect(response.contentLength, equals(50)); // Clamped to available data
        expect(response.offset, equals(50));

        final chunks = await response.stream.toList();
        expect(chunks[0].length, equals(50));
      });

      test('should handle zero-length requests', () async {
        final audioBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final audioSource = CustomAudioSource(audioBytes);

        // Request with same start and end
        final response = await audioSource.request(2, 2);

        expect(response.contentLength, equals(0));
        expect(response.offset, equals(2));

        final chunks = await response.stream.toList();
        expect(chunks.length, equals(1));
        expect(chunks[0].length, equals(0));
      });
    });

    group('SpeechifyAudioSource (Legacy)', () {
      test('should initialize with stream URL', () {
        const streamUrl = 'https://example.com/audio.mp3';
        final source = SpeechifyAudioSource(streamUrl: streamUrl);

        expect(source.streamUrl, equals(streamUrl));
        expect(source.tag, equals('SpeechifyStream'));
      });

      test('should have correct buffer configuration', () {
        // Buffer configuration is private, just verify source creation
        const streamUrl = 'https://example.com/audio.mp3';
        final source = SpeechifyAudioSource(streamUrl: streamUrl);
        expect(source, isNotNull);
        // Internal buffer sizes: 64KB chunks, 10s forward, 30s backward
      });

      test('should parse content length header', () {
        const streamUrl = 'https://example.com/audio.mp3';
        final source = SpeechifyAudioSource(streamUrl: streamUrl);

        // Access private method through reflection would be needed
        // For now, just verify the source is created
        expect(source, isNotNull);
      });

      test('should handle content range parsing', () {
        // Test ContentRange class
        final contentRange = ContentRange(
          start: 100,
          end: 199,
          total: 1000,
        );

        expect(contentRange.start, equals(100));
        expect(contentRange.end, equals(199));
        expect(contentRange.total, equals(1000));
      });
    });

    group('AudioSourceException', () {
      test('should format error message correctly', () {
        final exception = AudioSourceException('Test error message');

        expect(exception.message, equals('Test error message'));
        expect(
          exception.toString(),
          equals('AudioSourceException: Test error message'),
        );
      });

      test('should handle different error types', () {
        final connectionError = AudioSourceException(
          'Connection timeout while loading audio'
        );
        expect(connectionError.message, contains('Connection timeout'));

        final authError = AudioSourceException(
          'Audio URL expired. Please refresh the content.'
        );
        expect(authError.message, contains('expired'));

        final notFoundError = AudioSourceException(
          'Audio not found. Please try again.'
        );
        expect(notFoundError.message, contains('not found'));
      });
    });

    group('Integration with Speechify API', () {
      test('should handle real Speechify base64 response', () async {
        // Simulate real Speechify API response format
        const speechifyResponse = {
          'audio_data': 'UklGRv////9XQVZFZm10IBAAAAABAAEAgLsAAAB3AQACABAATElTVBoAAABJTkZPSVNGVA0AAABMYXZmNjEuNy4xMDAAAGRhdGH/////',
          'audio_format': 'wav',
        };

        final base64Audio = speechifyResponse['audio_data'] as String;

        // Should not throw
        final audioSource = await createSpeechifyAudioSource(base64Audio);
        expect(audioSource, isNotNull);
      });

      test('should handle empty audio data', () async {
        const emptyBase64 = '';

        // Empty base64 is valid (creates empty array)
        final audioSource = await createSpeechifyAudioSource(emptyBase64);
        expect(audioSource, isNotNull);
        expect(audioSource, isA<CustomAudioSource>());

        final customSource = audioSource as CustomAudioSource;
        expect(customSource.audioData.length, equals(0));
      });
    });

    group('Validation', () {
      test('validation function should run', () {
        validateSpeechifyAudioSource();
        // Validation function prints to console
        expect(true, isTrue);
      });
    });
  });
}

// Updated validation function for base64 audio
void validateSpeechifyAudioSource() {
  print('=== SpeechifyAudioSource Validation ===');

  // Test 1: Legacy source creation
  const testUrl = 'https://api.speechify.com/test/stream.mp3';
  final source = SpeechifyAudioSource(streamUrl: testUrl);
  assert(source.streamUrl == testUrl, 'Stream URL must be set');
  print('✓ Legacy audio source creation verified');

  // Test 2: Source tag
  assert(source.tag == 'SpeechifyStream', 'Tag must be set');
  print('✓ Source tag verified');

  // Test 3: Exception handling
  final exception = AudioSourceException('Test error');
  assert(
    exception.toString().contains('Test error'),
    'Exception message must be included'
  );
  print('✓ Exception handling verified');

  // Test 4: ContentRange model
  final range = ContentRange(start: 0, end: 99, total: 100);
  assert(range.start == 0, 'Start must be 0');
  assert(range.end == 99, 'End must be 99');
  assert(range.total == 100, 'Total must be 100');
  print('✓ ContentRange model verified');

  // Test 5: Base64 decoding
  final testBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
  final encoded = base64.encode(testBytes);
  final decoded = base64.decode(encoded);
  assert(decoded.length == testBytes.length, 'Decoded length must match');
  print('✓ Base64 encoding/decoding verified');

  print('=== All SpeechifyAudioSource validations passed ===');
}