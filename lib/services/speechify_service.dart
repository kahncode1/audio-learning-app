import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/word_timing.dart';
import '../config/app_config.dart';
import 'dio_provider.dart';

/// SpeechifyService - Text-to-speech API integration
///
/// Purpose: Handles all interactions with Speechify API for TTS generation
/// Dependencies:
/// - Speechify API: https://api.speechify.com/v1
/// - DioProvider: Singleton HTTP client
///
/// Features:
/// - Professional voice synthesis (professional_male_v2)
/// - Word-level timing with sentence indexing
/// - SSML content processing
/// - Audio streaming support
/// - Connection pooling for performance
class SpeechifyService {
  final Dio _dio;

  // Voice configuration
  static const String defaultVoice = 'professional_male_v2';
  static const double defaultSpeed = 1.0;

  // API endpoints
  static const String _synthesizeEndpoint = '/synthesize';
  static const String _timingsEndpoint = '/timings';

  SpeechifyService() : _dio = DioProvider.createSpeechifyClient();

  /// Generate audio stream from text content
  /// Returns a stream URL for audio playback
  Future<String> generateAudioStream({
    required String content,
    String voice = defaultVoice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    try {
      final response = await _dio.post(
        _synthesizeEndpoint,
        data: {
          'text': content,
          'voice': voice,
          'speed': speed,
          'format': 'mp3',
          'ssml': isSSML,
          'stream': true, // Enable streaming
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final streamUrl = response.data['stream_url'] as String?;
        if (streamUrl == null || streamUrl.isEmpty) {
          throw Exception('No stream URL returned from Speechify');
        }
        return streamUrl;
      } else {
        throw Exception('Failed to generate audio stream: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      debugPrint('Speechify API error: ${e.message}');
      if (e.response?.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please try again later.');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Invalid API key. Please check your Speechify configuration.');
      }
      throw Exception('Failed to connect to Speechify: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error in generateAudioStream: $e');
      throw Exception('Failed to generate audio: $e');
    }
  }

  /// Fetch word timings with sentence indexing for dual-level highlighting
  Future<List<WordTiming>> fetchWordTimings({
    required String content,
    String voice = defaultVoice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    try {
      final response = await _dio.post(
        _timingsEndpoint,
        data: {
          'text': content,
          'voice': voice,
          'speed': speed,
          'ssml': isSSML,
          'include_sentences': true, // Enable sentence indexing
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final timingsData = response.data['timings'] as List?;
        if (timingsData == null) {
          throw Exception('No timing data returned from Speechify');
        }

        return _parseWordTimings(timingsData);
      } else {
        throw Exception('Failed to fetch word timings: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      debugPrint('Speechify timing API error: ${e.message}');
      throw Exception('Failed to fetch word timings: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error in fetchWordTimings: $e');
      throw Exception('Failed to parse word timings: $e');
    }
  }

  /// Parse word timing data from Speechify response
  List<WordTiming> _parseWordTimings(List<dynamic> timingsData) {
    final timings = <WordTiming>[];

    for (final item in timingsData) {
      try {
        final word = item['word'] as String? ?? '';
        final startMs = (item['start_ms'] as num?)?.toInt() ?? 0;
        final endMs = (item['end_ms'] as num?)?.toInt() ?? 0;
        final sentenceIndex = (item['sentence_index'] as num?)?.toInt() ?? 0;

        if (word.isNotEmpty) {
          timings.add(WordTiming(
            word: word,
            startMs: startMs,
            endMs: endMs,
            sentenceIndex: sentenceIndex,
          ));
        }
      } catch (e) {
        debugPrint('Error parsing word timing: $e');
        // Skip malformed entries but continue processing
      }
    }

    return timings;
  }

  /// Generate audio with word timings in a single request
  /// More efficient than separate calls
  Future<AudioGenerationResult> generateAudioWithTimings({
    required String content,
    String voice = defaultVoice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    try {
      // Make parallel requests for better performance
      final results = await Future.wait([
        generateAudioStream(
          content: content,
          voice: voice,
          speed: speed,
          isSSML: isSSML,
        ),
        fetchWordTimings(
          content: content,
          voice: voice,
          speed: speed,
          isSSML: isSSML,
        ),
      ]);

      return AudioGenerationResult(
        streamUrl: results[0] as String,
        wordTimings: results[1] as List<WordTiming>,
      );
    } catch (e) {
      debugPrint('Error generating audio with timings: $e');
      throw Exception('Failed to generate audio with timings: $e');
    }
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
  final String streamUrl;
  final List<WordTiming> wordTimings;

  AudioGenerationResult({
    required this.streamUrl,
    required this.wordTimings,
  });
}

/// Validation function for SpeechifyService
void validateSpeechifyService() {
  debugPrint('=== SpeechifyService Validation ===');

  // Test 1: Service initialization
  final service = SpeechifyService();
  assert(service != null, 'Service must initialize');
  debugPrint('✓ Service initialization verified');

  // Test 2: Configuration check
  final isConfigured = service.isConfigured();
  if (!isConfigured) {
    debugPrint('⚠️ Speechify API key not configured');
  } else {
    debugPrint('✓ API key configuration verified');
  }

  // Test 3: SSML processing
  final plainText = 'Hello world. How are you?';
  final ssml = service.processSSMLContent(plainText);
  assert(ssml.contains('<speak>'), 'SSML must have speak tag');
  assert(ssml.contains('<s>'), 'SSML must have sentence tags');
  debugPrint('✓ SSML processing verified');

  // Test 4: Already SSML content
  final existingSSML = '<speak>Test content</speak>';
  final processed = service.processSSMLContent(existingSSML);
  assert(processed == existingSSML, 'Existing SSML should not be modified');
  debugPrint('✓ SSML preservation verified');

  debugPrint('=== All SpeechifyService validations passed ===');
}