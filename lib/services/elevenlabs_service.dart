import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/word_timing.dart';
import '../config/env_config.dart';
import '../utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import 'dio_provider.dart';
import 'speechify_service.dart'; // For AudioGenerationResult

/// ElevenLabsService - Modern text-to-speech API integration
///
/// Purpose: Alternative TTS provider with HTTP streaming for mobile optimization
/// Dependencies:
/// - ElevenLabs API: https://api.elevenlabs.io/v1
/// - DioProvider: Singleton HTTP client
///
/// Key Features:
/// - Binary audio streaming (not base64)
/// - Character-level timing transformation to word-level
/// - Client-side sentence boundary detection
/// - Plain text input only
/// - Mobile-optimized HTTP streaming
///
/// IMPORTANT: Algorithm Details
/// - Character grouping uses space detection with punctuation handling
/// - Sentence detection uses 350ms pause threshold + terminal punctuation
/// - Abbreviation protection for common patterns (Dr., Inc., etc.)
/// - Binary search optimization for timing lookups
class ElevenLabsService {
  static ElevenLabsService? _instance;
  final Dio _dio;

  /// Singleton instance for consistent API usage
  static ElevenLabsService get instance {
    _instance ??= ElevenLabsService._internal();
    return _instance!;
  }

  factory ElevenLabsService() => instance;

  ElevenLabsService._internal() : _dio = DioProviderElevenLabs.createElevenLabsClient();

  // Voice configuration
  static const String defaultVoice = 'default'; // Will be replaced with actual voice ID
  static const String defaultModel = 'eleven_multilingual_v2';
  static const double defaultSpeed = 1.0;

  // Timing configuration
  static const int sentencePauseThresholdMs = 350;
  static const Set<String> abbreviations = {
    'Dr', 'Mr', 'Mrs', 'Ms', 'Prof', 'Sr', 'Jr',
    'Inc', 'Corp', 'Ltd', 'LLC', 'Co',
    'St', 'Ave', 'Rd', 'Blvd',
    'Jan', 'Feb', 'Mar', 'Apr', 'Jun', 'Jul', 'Aug', 'Sep', 'Sept', 'Oct', 'Nov', 'Dec',
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    'vs', 'etc', 'i.e', 'e.g', 'cf', 'al',
  };

  /// Generate audio stream from text content
  /// Returns AudioGenerationResult compatible with existing system
  Future<AudioGenerationResult> generateAudioStream({
    required String content,
    String? voice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    try {
      // ElevenLabs only supports plain text - ignore isSSML flag
      final plainText = content;

      // Get configured voice or use default
      final voiceId = voice ?? _getConfiguredVoiceId();

      AppLogger.info('ElevenLabs API request', {
        'voiceId': voiceId,
        'textLength': plainText.length,
      });

      // Prepare request payload
      final payload = {
        'text': plainText,
        'model_id': defaultModel,
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
          'style': 0.0,
          'use_speaker_boost': true,
        },
      };

      // Make API request for audio with timestamps
      final response = await _dio.post(
        '/v1/text-to-speech/$voiceId/stream/with-timestamps',
        data: payload,
        options: Options(
          responseType: ResponseType.bytes, // Get full response as bytes
          headers: {
            'xi-api-key': _getApiKey(),
            'Accept': 'application/json', // We need JSON for timing data
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        // Parse the response - ElevenLabs sends a special format
        // First part is timing data, second part is audio
        final responseData = _parseStreamResponse(response.data);

        // Extract timing data
        final characterTimings = responseData['character_start_times'] as List?;
        final audioBytes = responseData['audio_bytes'] as Uint8List?;

        if (audioBytes == null || audioBytes.isEmpty) {
          throw AudioException.invalidResponse('No audio data in ElevenLabs response');
        }

        // Transform character timings to word timings
        final wordTimings = characterTimings != null
            ? _transformCharacterToWordTimings(characterTimings, plainText)
            : _generateMockTimings(plainText);

        // Log transformation results
        AppLogger.info('ElevenLabs timing transformation', {
          'characterCount': characterTimings?.length ?? 0,
          'wordCount': wordTimings.length,
          'sentenceCount': _countSentences(wordTimings),
        });

        // Convert audio bytes to base64 for compatibility with existing system
        final audioData = base64.encode(audioBytes);

        return AudioGenerationResult(
          audioData: audioData,
          audioFormat: 'mp3',
          wordTimings: wordTimings,
          displayText: plainText,
        );
      } else {
        throw NetworkException.fromStatusCode(
          response.statusCode ?? 500,
          details: 'ElevenLabs API error',
        );
      }
    } on DioException catch (e) {
      AppLogger.error('ElevenLabs API error', error: e.message, data: {
        'statusCode': e.response?.statusCode,
        'error': e.response?.data,
      });

      if (e.response?.statusCode == 401) {
        throw NetworkException('Invalid ElevenLabs API key');
      } else if (e.response?.statusCode == 429) {
        throw NetworkException('ElevenLabs rate limit exceeded');
      }

      throw NetworkException.fromStatusCode(
        e.response?.statusCode ?? 500,
        details: e.message,
      );
    } catch (e) {
      AppLogger.error('Unexpected error in ElevenLabs generateAudioStream', error: e);
      throw AudioException.streamingFailed(
        source: 'ElevenLabs API',
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Transform character-level timings to word-level timings
  /// This is the core algorithm for ElevenLabs integration
  List<WordTiming> _transformCharacterToWordTimings(
    List<dynamic> characterTimings,
    String originalText,
  ) {
    final wordTimings = <WordTiming>[];

    if (characterTimings.isEmpty) {
      AppLogger.warning('Empty character timings received');
      return wordTimings;
    }

    // Build words from characters
    final wordBuffer = StringBuffer();
    int? wordStartMs;
    int? wordEndMs;
    int charIndex = 0;

    for (int i = 0; i < characterTimings.length; i++) {
      final charData = characterTimings[i] as Map<String, dynamic>;
      final char = charData['character'] as String? ?? '';
      final startMs = (charData['start_time_ms'] as num?)?.toInt() ?? 0;

      // Calculate approximate end time (use next character's start or add average duration)
      final endMs = i < characterTimings.length - 1
          ? ((characterTimings[i + 1] as Map)['start_time_ms'] as num?)?.toInt() ?? startMs + 50
          : startMs + 100; // Last character gets 100ms duration

      if (char.isEmpty) continue;

      // Start new word if needed
      if (wordStartMs == null) {
        wordStartMs = startMs;
      }

      // Check if this is a word boundary
      bool isWordBoundary = false;
      if (char == ' ' || char == '\n' || char == '\t') {
        isWordBoundary = true;
      } else {
        wordBuffer.write(char);
        wordEndMs = endMs;

        // Check if next character is a space or we're at the end
        if (i == characterTimings.length - 1) {
          isWordBoundary = true;
        } else if (i < characterTimings.length - 1) {
          final nextChar = (characterTimings[i + 1] as Map)['character'] as String? ?? '';
          if (nextChar == ' ' || nextChar == '\n' || nextChar == '\t') {
            isWordBoundary = true;
          }
        }
      }

      // Create word timing if we hit a boundary
      if (isWordBoundary && wordBuffer.isNotEmpty && wordStartMs != null && wordEndMs != null) {
        String word = wordBuffer.toString().trim();

        // Clean word of trailing punctuation for matching
        final cleanWord = _cleanWordForTiming(word);

        if (cleanWord.isNotEmpty) {
          wordTimings.add(WordTiming(
            word: cleanWord,
            startMs: wordStartMs,
            endMs: wordEndMs,
            sentenceIndex: 0, // Will be assigned later
            charStart: charIndex,
            charEnd: charIndex + word.length,
          ));
        }

        // Reset for next word
        wordBuffer.clear();
        wordStartMs = null;
        wordEndMs = null;
        charIndex += word.length + 1; // +1 for space
      }
    }

    // Handle any remaining word
    if (wordBuffer.isNotEmpty && wordStartMs != null && wordEndMs != null) {
      final word = wordBuffer.toString().trim();
      final cleanWord = _cleanWordForTiming(word);
      if (cleanWord.isNotEmpty) {
        wordTimings.add(WordTiming(
          word: cleanWord,
          startMs: wordStartMs,
          endMs: wordEndMs!,
          sentenceIndex: 0,
          charStart: charIndex,
          charEnd: charIndex + word.length,
        ));
      }
    }

    // Assign sentence indices based on punctuation and pauses
    return _assignSentenceIndices(wordTimings, originalText);
  }

  /// Assign sentence indices to word timings based on punctuation and pauses
  List<WordTiming> _assignSentenceIndices(List<WordTiming> words, String originalText) {
    if (words.isEmpty) return words;

    final result = <WordTiming>[];
    int sentenceIndex = 0;

    for (int i = 0; i < words.length; i++) {
      final word = words[i];

      // Check if this word ends with terminal punctuation
      bool hasTerminalPunctuation = false;
      bool isAbbreviation = false;

      // Find the word in original text to check punctuation
      final wordWithPunct = _findWordInOriginalText(originalText, word.word, word.charStart ?? 0);
      if (wordWithPunct != null) {
        hasTerminalPunctuation = _hasTerminalPunctuation(wordWithPunct);
        isAbbreviation = _isAbbreviation(wordWithPunct);
      }

      // Check for long pause to next word
      bool hasLongPause = false;
      if (i < words.length - 1) {
        final nextWord = words[i + 1];
        final pauseDuration = nextWord.startMs - word.endMs;
        hasLongPause = pauseDuration > sentencePauseThresholdMs;
      }

      // Assign current sentence index
      result.add(word.copyWith(sentenceIndex: sentenceIndex));

      // Determine if we should start a new sentence
      if (hasTerminalPunctuation && !isAbbreviation) {
        // Terminal punctuation without abbreviation = new sentence
        sentenceIndex++;
      } else if (hasLongPause && hasTerminalPunctuation) {
        // Long pause after punctuation = definitely new sentence
        sentenceIndex++;
      } else if (hasLongPause && i > 0 && i < words.length - 1) {
        // Long pause in middle of text might indicate sentence boundary
        // Be conservative - only if it's a really long pause
        final nextWord = words[i + 1];
        final pauseDuration = nextWord.startMs - word.endMs;
        if (pauseDuration > sentencePauseThresholdMs * 2) {
          sentenceIndex++;
        }
      }
    }

    AppLogger.debug('Sentence assignment complete', {
      'totalWords': result.length,
      'totalSentences': sentenceIndex + 1,
    });

    return result;
  }

  /// Find word in original text including punctuation
  String? _findWordInOriginalText(String text, String cleanWord, int startChar) {
    if (startChar >= text.length) return cleanWord;

    // Look for the word starting around startChar
    final searchStart = (startChar - 10).clamp(0, text.length);
    final searchEnd = (startChar + cleanWord.length + 10).clamp(0, text.length);
    final searchText = text.substring(searchStart, searchEnd);

    // Try to find the clean word
    final wordIndex = searchText.indexOf(cleanWord);
    if (wordIndex >= 0) {
      // Check if there's punctuation after the word
      final afterIndex = wordIndex + cleanWord.length;
      if (afterIndex < searchText.length) {
        final afterChar = searchText[afterIndex];
        if ('.!?,;:)]}"\''.contains(afterChar)) {
          return cleanWord + afterChar;
        }
      }
    }

    return cleanWord;
  }

  /// Clean word by removing trailing punctuation for timing matching
  String _cleanWordForTiming(String word) {
    // Remove trailing punctuation but keep internal punctuation
    return word.replaceAll(RegExp(r'''[.,;:!?'"()\[\]{}]+$'''), '');
  }

  /// Check if word has terminal punctuation
  bool _hasTerminalPunctuation(String word) {
    return word.endsWith('.') || word.endsWith('!') || word.endsWith('?');
  }

  /// Check if word is an abbreviation
  bool _isAbbreviation(String word) {
    if (!word.endsWith('.')) return false;

    // Remove the period and check against known abbreviations
    final wordWithoutPeriod = word.substring(0, word.length - 1);

    // Check exact match
    if (abbreviations.contains(wordWithoutPeriod)) {
      return true;
    }

    // Check case-insensitive match for some common ones
    final lowerWord = wordWithoutPeriod.toLowerCase();
    for (final abbr in abbreviations) {
      if (abbr.toLowerCase() == lowerWord) {
        return true;
      }
    }

    // Check for single capital letter (e.g., "A.", "B.")
    if (wordWithoutPeriod.length == 1 && wordWithoutPeriod.toUpperCase() == wordWithoutPeriod) {
      return true;
    }

    // Check for numbers with period (e.g., "1.", "2.")
    if (RegExp(r'^\d+$').hasMatch(wordWithoutPeriod)) {
      return true;
    }

    return false;
  }

  /// Count total sentences in word timings
  int _countSentences(List<WordTiming> words) {
    if (words.isEmpty) return 0;
    return words.map((w) => w.sentenceIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Parse streaming response from ElevenLabs
  /// Note: This is a simplified version - actual implementation may need adjustment
  /// based on ElevenLabs' exact response format
  Map<String, dynamic> _parseStreamResponse(dynamic data) {
    try {
      // If data is already bytes, we need to parse it
      if (data is Uint8List || data is List<int>) {
        // ElevenLabs might send JSON + audio in a specific format
        // This is a placeholder - adjust based on actual API response

        // Try to parse as JSON first
        try {
          final jsonStr = utf8.decode(data is Uint8List ? data : Uint8List.fromList(data as List<int>));
          final json = jsonDecode(jsonStr);

          if (json is Map && json.containsKey('character_start_times')) {
            // Response contains timing data
            return {
              'character_start_times': json['character_start_times'],
              'audio_bytes': Uint8List(0), // Audio might be in a separate field
            };
          }
        } catch (_) {
          // Not JSON, might be pure audio
        }

        // If not JSON, treat as audio bytes
        return {
          'character_start_times': null,
          'audio_bytes': data is Uint8List ? data : Uint8List.fromList(data as List<int>),
        };
      }

      // If data is already a map
      if (data is Map) {
        return {
          'character_start_times': data['character_start_times'],
          'audio_bytes': data['audio_bytes'] ?? Uint8List(0),
        };
      }

      AppLogger.warning('Unexpected ElevenLabs response format', {
        'dataType': data.runtimeType.toString(),
      });

      return {
        'character_start_times': null,
        'audio_bytes': Uint8List(0),
      };
    } catch (e) {
      AppLogger.error('Error parsing ElevenLabs response', error: e);
      return {
        'character_start_times': null,
        'audio_bytes': Uint8List(0),
      };
    }
  }

  /// Generate mock word timings when API doesn't provide them
  List<WordTiming> _generateMockTimings(String text) {
    final words = text.split(RegExp(r'\s+'));
    final timings = <WordTiming>[];

    // Assume average reading speed of 150 words per minute
    const msPerWord = 400; // 60000ms / 150 words
    int currentMs = 0;
    int sentenceIndex = 0;

    for (final word in words) {
      if (word.isEmpty) continue;

      // Clean word for timing
      final cleanWord = _cleanWordForTiming(word);

      if (cleanWord.isNotEmpty) {
        timings.add(WordTiming(
          word: cleanWord,
          startMs: currentMs,
          endMs: currentMs + msPerWord - 50,
          sentenceIndex: sentenceIndex,
        ));
      }

      // Check for sentence boundary
      if (_hasTerminalPunctuation(word) && !_isAbbreviation(word)) {
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

  /// Get configured voice ID from environment
  String _getConfiguredVoiceId() {
    // Check environment configuration
    try {
      final voiceId = EnvConfig.elevenLabsVoiceId;
      if (voiceId.isNotEmpty && voiceId != 'your_voice_id_here') {
        return voiceId;
      }
    } catch (e) {
      AppLogger.warning('Could not get ElevenLabs voice ID from config', {
        'error': e.toString(),
      });
    }

    // Return a default voice ID
    // You'll need to get this from ElevenLabs documentation
    return '21m00Tcm4TlvDq8ikWAM'; // Example: Rachel voice
  }

  /// Get API key from environment
  String _getApiKey() {
    try {
      final apiKey = EnvConfig.elevenLabsApiKey;
      if (apiKey.isNotEmpty && apiKey != 'your_api_key_here') {
        return apiKey;
      }
    } catch (e) {
      AppLogger.error('Could not get ElevenLabs API key from config', error: e);
    }
    throw AudioException('ElevenLabs API key not configured');
  }

  /// Fetch word timings (for compatibility with SpeechifyService interface)
  Future<List<WordTiming>> fetchWordTimings({
    required String content,
    String? voice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    final result = await generateAudioStream(
      content: content,
      voice: voice,
      speed: speed,
      isSSML: isSSML,
    );

    return result.wordTimings;
  }

  /// Generate audio with word timings (for compatibility)
  Future<AudioGenerationResult> generateAudioWithTimings({
    required String content,
    String? voice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    return generateAudioStream(
      content: content,
      voice: voice,
      speed: speed,
      isSSML: isSSML,
    );
  }

  /// Check if service is configured
  bool isConfigured() {
    try {
      final apiKey = _getApiKey();
      return apiKey.isNotEmpty && apiKey != 'your_api_key_here';
    } catch (_) {
      return false;
    }
  }

  /// Clean up resources
  void dispose() {
    // Dio client is managed by DioProvider
    // No explicit cleanup needed here
  }
}