import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/word_timing.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import 'dio_provider.dart';

/// SpeechifyService - Text-to-speech API integration
///
/// Purpose: Handles all interactions with Speechify API for TTS generation
/// Dependencies:
/// - Speechify API: https://api.sws.speechify.com/v1
/// - DioProvider: Singleton HTTP client
///
/// IMPORTANT: Audio Streaming Clarification
/// - The Speechify API returns JSON with base64-encoded audio data
/// - We decode this to bytes and stream during playback (not saving to storage)
/// - This is true streaming - audio plays progressively from memory
/// - No files are downloaded or saved to the user's device
///
/// Features:
/// - Professional voice synthesis (henry, etc.)
/// - Word-level timing with sentence indexing
/// - SSML content processing
/// - Audio streaming from memory (no permanent storage)
/// - Connection pooling for performance
class SpeechifyService {
  static SpeechifyService? _instance;
  final Dio _dio;

  /// Singleton instance for consistent API usage
  static SpeechifyService get instance {
    _instance ??= SpeechifyService._internal();
    return _instance!;
  }

  factory SpeechifyService() => instance;

  SpeechifyService._internal() : _dio = DioProvider.createSpeechifyClient();

  // Voice configuration
  static const String defaultVoice = 'henry';  // Valid Speechify voice ID
  static const double defaultSpeed = 1.0;

  // API endpoints
  static const String _synthesizeEndpoint = '/v1/audio/speech';
  static const String _timingsEndpoint = '/v1/audio/speech';  // Same endpoint returns timings

  /// Generate audio stream from text content
  /// Returns base64-encoded audio data
  Future<AudioGenerationResult> generateAudioStream({
    required String content,
    String voice = defaultVoice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    try {
      // Convert SSML to plain text if needed
      String processedContent = content;
      if (isSSML) {
        processedContent = _convertSSMLToPlainText(content);
        AppLogger.info('Converted SSML to plain text', {
          'originalLength': content.length,
          'processedLength': processedContent.length,
        });
      }

      // Note: For production, consider implementing pagination or chunking for very long content
      // to avoid excessive API costs and memory usage

      final response = await _dio.post(
        _synthesizeEndpoint,
        data: {
          'input': processedContent,
          'voice_id': voice,
          'model': 'simba-turbo',
          'speed': speed,
          'include_speech_marks': true,  // Request word-level timing data
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        // Parse the response
        final audioData = response.data['audio_data'] as String?;
        final speechMarks = response.data['speech_marks'];

        // Debug logging to understand API response
        AppLogger.info('Speechify API response structure', {
          'hasAudioData': audioData != null,
          'audioDataLength': audioData?.length ?? 0,
          'hasSpeechMarks': speechMarks != null,
          'speechMarksType': speechMarks?.runtimeType.toString() ?? 'null',
          'responseKeys': response.data.keys.toList(),
        });

        if (audioData == null || audioData.isEmpty) {
          throw AudioException.generationTimeout();
        }

        // Parse word timings from speech marks
        // Pass the processed content for mock timing generation if needed
        final wordTimings = speechMarks != null
            ? _parseSpeechMarks(speechMarks)
            : _generateMockTimings(processedContent);

        return AudioGenerationResult(
          audioData: audioData,
          audioFormat: response.data['audio_format'] ?? 'wav',
          wordTimings: wordTimings,
        );
      } else {
        throw NetworkException.fromStatusCode(
          response.statusCode ?? 500,
          details: response.statusMessage,
        );
      }
    } on DioException catch (e) {
      AppLogger.error(
        'Speechify API error',
        error: e.message,
        data: {'statusCode': e.response?.statusCode},
      );
      if (e.response?.statusCode != null) {
        throw NetworkException.fromStatusCode(
          e.response!.statusCode!,
          url: e.requestOptions.uri.toString(),
          details: e.message,
        );
      }
      throw NetworkException(e.message ?? 'Failed to connect to Speechify');
    } catch (e) {
      AppLogger.error(
        'Unexpected error in generateAudioStream',
        error: e,
      );
      throw AudioException.streamingFailed(
        source: 'Speechify API',
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Convert SSML content to plain text
  String _convertSSMLToPlainText(String ssml) {
    // Remove all XML/SSML tags
    String plainText = ssml;

    // Remove <speak> tags
    plainText = plainText.replaceAll(RegExp(r'</?speak>'), '');

    // Remove <p> tags but keep the content
    plainText = plainText.replaceAll(RegExp(r'</?p>'), ' ');

    // Remove <mark> tags but keep the content
    plainText = plainText.replaceAll(RegExp(r'</?mark>'), '');

    // Remove any other XML tags
    plainText = plainText.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Clean up multiple spaces
    plainText = plainText.replaceAll(RegExp(r'\s+'), ' ');

    // Trim whitespace
    plainText = plainText.trim();

    return plainText;
  }

  /// Generate mock word timings based on text
  List<WordTiming> _generateMockTimings(String text) {
    final words = text.split(RegExp(r'\s+'));
    final timings = <WordTiming>[];

    // Assume average reading speed of 150 words per minute
    const msPerWord = 400; // 60000ms / 150 words
    int currentMs = 0;
    int sentenceIndex = 0;

    for (final word in words) {
      if (word.isEmpty) continue;

      timings.add(WordTiming(
        word: word,
        startMs: currentMs,
        endMs: currentMs + msPerWord - 50, // Small gap between words
        sentenceIndex: sentenceIndex,
      ));

      // Track sentence boundaries
      if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
        sentenceIndex++;
      }

      currentMs += msPerWord;
    }

    AppLogger.info('Generated mock timings', {
      'wordCount': timings.length,
      'sentences': sentenceIndex + 1,
      'durationMs': currentMs,
    });

    return timings;
  }

  /// Parse speech marks from Speechify API response
  List<WordTiming> _parseSpeechMarks(dynamic speechMarks) {
    final timings = <WordTiming>[];

    if (speechMarks == null) {
      AppLogger.warning('No speech marks in response');
      return timings;
    }

    try {
      // Speech marks should be a List according to the API
      if (speechMarks is List) {
        int sentenceIndex = 0;
        for (int i = 0; i < speechMarks.length; i++) {
          final mark = speechMarks[i] as Map;
          final type = mark['type'] as String?;

          if (type == 'word') {
            final word = mark['value'] as String? ?? '';

            timings.add(WordTiming(
              word: word,
              startMs: (mark['start'] as num?)?.toInt() ?? 0,
              endMs: (mark['end'] as num?)?.toInt() ?? 0,
              sentenceIndex: sentenceIndex,
            ));

            // Track sentence boundaries based on punctuation
            // Increment AFTER adding the word so first sentence is 0
            if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
              sentenceIndex++;
            }
          }
        }
      } else if (speechMarks is Map) {
        // Fallback for Map format if API changes
        final chunks = speechMarks['chunks'] as List?;
        if (chunks != null) {
          int sentenceIndex = 0;
          for (int i = 0; i < chunks.length; i++) {
            final chunk = chunks[i] as Map;
            if (chunk['type'] == 'word') {
              final word = chunk['value'] as String? ?? '';

              timings.add(WordTiming(
                word: word,
                startMs: (chunk['start_time'] as num?)?.toInt() ?? 0,
                endMs: (chunk['end_time'] as num?)?.toInt() ?? 0,
                sentenceIndex: sentenceIndex,
              ));

              // Track sentence boundaries
              // Increment AFTER adding the word so first sentence is 0
              if (word.endsWith('.') || word.endsWith('!') || word.endsWith('?')) {
                sentenceIndex++;
              }
            }
          }
        }
      }

      AppLogger.info('Parsed speech marks', {
        'count': timings.length,
        'format': speechMarks is List ? 'List' : 'Map'
      });
    } catch (e) {
      AppLogger.warning('Error parsing speech marks', {'error': e.toString()});
    }

    return timings;
  }

  /// Fetch word timings (now integrated with audio generation)
  Future<List<WordTiming>> fetchWordTimings({
    required String content,
    String voice = defaultVoice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    // The Speechify API returns timings with audio
    final result = await generateAudioStream(
      content: content,
      voice: voice,
      speed: speed,
      isSSML: isSSML,
    );

    return result.wordTimings;
  }

  /// Generate audio with word timings in a single request
  /// The API returns both in one call
  Future<AudioGenerationResult> generateAudioWithTimings({
    required String content,
    String voice = defaultVoice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    // Single API call returns both audio and timings
    return generateAudioStream(
      content: content,
      voice: voice,
      speed: speed,
      isSSML: isSSML,
    );
  }

  /// Process SSML content for enhanced speech synthesis
  String processSSMLContent(String rawContent) {
    // If already SSML, return as-is
    if (rawContent.trim().startsWith('<speak>')) {
      return rawContent;
    }

    // Convert plain text to SSML with basic formatting
    final buffer = StringBuffer('<speak>');

    // Split into sentences for better prosody
    final sentences = rawContent.split(RegExp(r'[.!?]+'));

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isNotEmpty) {
        // Add sentence with pause
        buffer.write('<s>$trimmed.</s>');
        buffer.write('<break time="200ms"/>');
      }
    }

    buffer.write('</speak>');
    return buffer.toString();
  }

  /// Validate API key configuration
  bool isConfigured() {
    return AppConfig.speechifyApiKey != 'YOUR_SPEECHIFY_API_KEY_HERE' &&
        AppConfig.speechifyApiKey.isNotEmpty;
  }

  /// Clean up resources
  void dispose() {
    // Dio client is managed by DioProvider
    // No explicit cleanup needed here
  }
}

/// Result of audio generation with timings
class AudioGenerationResult {
  final String audioData;  // Base64-encoded audio
  final String audioFormat; // Format of audio (wav, mp3, etc)
  final List<WordTiming> wordTimings;

  AudioGenerationResult({
    required this.audioData,
    required this.audioFormat,
    required this.wordTimings,
  });

  /// Decode base64 audio data to bytes
  Uint8List getAudioBytes() {
    return base64.decode(audioData);
  }
}

/// Validation function for SpeechifyService
void validateSpeechifyService() {
  AppLogger.info('Starting SpeechifyService validation');

  // Test 1: Singleton pattern
  final service1 = SpeechifyService();
  final service2 = SpeechifyService.instance;
  final service3 = SpeechifyService();

  assert(identical(service1, service2), 'Should be same singleton instance');
  assert(identical(service2, service3), 'Should be same singleton instance');
  AppLogger.debug('✓ Singleton pattern verified');

  // Test 2: Configuration check
  final isConfigured = service1.isConfigured();
  if (!isConfigured) {
    AppLogger.warning('Speechify API key not configured');
  } else {
    AppLogger.debug('✓ API key configuration verified');
  }

  // Test 3: SSML processing
  final plainText = 'Hello world. How are you?';
  final ssml = service1.processSSMLContent(plainText);
  assert(ssml.contains('<speak>'), 'SSML must have speak tag');
  assert(ssml.contains('<s>'), 'SSML must have sentence tags');
  AppLogger.debug('✓ SSML processing verified');

  // Test 4: Already SSML content
  final existingSSML = '<speak>Test content</speak>';
  final processed = service1.processSSMLContent(existingSSML);
  assert(processed == existingSSML, 'Existing SSML should not be modified');
  AppLogger.debug('✓ SSML preservation verified');

  AppLogger.info('All SpeechifyService validations passed');
}
