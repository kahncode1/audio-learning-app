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
      final response = await _dio.post(
        _synthesizeEndpoint,
        data: {
          'input': content,
          'voice_id': voice,
          'model': 'simba-turbo',
          'speed': speed,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        // Parse the response
        final audioData = response.data['audio_data'] as String?;
        final speechMarks = response.data['speech_marks'];

        if (audioData == null || audioData.isEmpty) {
          throw AudioException.generationTimeout();
        }

        // Parse word timings from speech marks
        final wordTimings = _parseSpeechMarks(speechMarks);

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

  /// Parse speech marks from Speechify API response
  List<WordTiming> _parseSpeechMarks(dynamic speechMarks) {
    final timings = <WordTiming>[];

    if (speechMarks == null) return timings;

    try {
      // Speech marks can be a sentence with word chunks
      if (speechMarks is Map) {
        final chunks = speechMarks['chunks'] as List?;
        if (chunks != null) {
          for (int i = 0; i < chunks.length; i++) {
            final chunk = chunks[i] as Map;
            if (chunk['type'] == 'word') {
              timings.add(WordTiming(
                word: chunk['value'] as String? ?? '',
                startMs: (chunk['start_time'] as num?)?.toInt() ?? 0,
                endMs: (chunk['end_time'] as num?)?.toInt() ?? 0,
                sentenceIndex: 0,  // Single sentence
              ));
            }
          }
        }
      }
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
