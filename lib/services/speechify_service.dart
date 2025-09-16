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
  static const String defaultVoice = 'henry'; // Valid Speechify voice ID
  static const double defaultSpeed = 1.0;

  // API endpoints
  static const String _synthesizeEndpoint = '/v1/audio/speech';
  static const String _timingsEndpoint =
      '/v1/audio/speech'; // Same endpoint returns timings

  /// Generate audio stream from text content
  /// Returns base64-encoded audio data
  Future<AudioGenerationResult> generateAudioStream({
    required String content,
    String voice = defaultVoice,
    double speed = defaultSpeed,
    bool isSSML = false,
  }) async {
    try {
      // Log the endpoint we are about to hit
      if (kDebugMode) {
        AppLogger.debug('Preparing Speechify request', {
          'baseUrl': _dio.options.baseUrl,
          'endpoint': _synthesizeEndpoint,
          'fullUrl':
              Uri.parse(_dio.options.baseUrl + _synthesizeEndpoint).toString(),
        });
      }
      // Pass SSML directly to API - Speechify supports SSML tags
      String processedContent = content;
      if (isSSML) {
        // Don't convert SSML - send it directly to preserve chunk structure
        processedContent = content;
        AppLogger.info('Sending SSML content to API', {
          'length': content.length,
          'hasSpeak': content.contains('<speak>'),
          'hasEmphasis': content.contains('<emphasis'),
          'hasBreak': content.contains('<break'),
        });
      }

      // Note: For production, consider implementing pagination or chunking for very long content
      // to avoid excessive API costs and memory usage

      final payload = {
        'input': processedContent,
        'voice_id': voice,
        'model': 'simba-turbo',
        'speed': speed,
        'include_speech_marks': true, // Request word-level timing data
      };

      // Hint to API that input is SSML so it can honor <s>/<p> boundaries.
      if (isSSML) {
        payload['input_format'] = 'ssml';
        // Some backends respect this flag to return sentence-level segmentation.
        payload['include_sentence_marks'] = true;
      }

      final response = await _dio.post(
        _synthesizeEndpoint,
        data: payload,
      );

      if (response.statusCode == 200 && response.data != null) {
        // Parse the response
        final audioData = response.data['audio_data'] as String?;
        final speechMarks = response.data['speech_marks'];
        final billableChars = response.data['billable_characters_count'];

        if (kDebugMode) {
          final audioPreview = (audioData != null && audioData.isNotEmpty)
              ? audioData.substring(
                  0, audioData.length > 120 ? 120 : audioData.length)
              : null;
          final speechMarksSample =
              speechMarks is List && speechMarks.isNotEmpty
                  ? speechMarks.first
                  : speechMarks;

          AppLogger.debug('Speechify API raw payload', {
            'statusCode': response.statusCode,
            'audioFormat': response.data['audio_format'],
            'audioDataLength': audioData?.length ?? 0,
            'audioDataPreview': audioPreview,
            'speechMarksSample': speechMarksSample,
          });
        }

        // Debug logging to understand API response
        AppLogger.info('Speechify API response structure', {
          'hasAudioData': audioData != null,
          'audioDataLength': audioData?.length ?? 0,
          'hasSpeechMarks': speechMarks != null,
          'speechMarksType': speechMarks?.runtimeType.toString() ?? 'null',
          'responseKeys': response.data.keys.toList(),
          'billableCharactersCount': billableChars,
        });

        // Validate that speech_marks look like the documented structure
        if (speechMarks is Map) {
          final keys =
              (speechMarks as Map).keys.map((e) => e.toString()).toList();
          final hasChunks = (speechMarks as Map).containsKey('chunks');
          final hasType = (speechMarks as Map).containsKey('type');
          AppLogger.debug('speech_marks keys', {
            'keys': keys,
            'hasChunks': hasChunks,
            'hasType': hasType,
          });
        }

        // Summarize availability of character offsets for precise highlighting
        try {
          int withChars = 0;
          int total = 0;
          if (speechMarks is Map && speechMarks['chunks'] is List) {
            final List list = speechMarks['chunks'];
            for (final item in list) {
              if (item is Map) {
                if (item.containsKey('start') && item.containsKey('end'))
                  withChars++;
                total++;
              }
            }
          } else if (speechMarks is List) {
            for (final item in speechMarks) {
              if (item is Map) {
                if (item.containsKey('start') && item.containsKey('end'))
                  withChars++;
                total++;
              }
            }
          }
          if (total > 0) {
            AppLogger.info('Speechify marks char-offset coverage', {
              'withCharPositions': withChars,
              'totalMarks': total,
              'coveragePct': ((withChars / total) * 100).toStringAsFixed(1),
            });
          }
        } catch (_) {}

        if (audioData == null || audioData.isEmpty) {
          throw AudioException.invalidResponse('No audio data in API response');
        }

        // Parse word timings from speech marks
        // Pass the processed content for sentence boundary detection
        final wordTimings = speechMarks != null
            ? _parseSpeechMarks(speechMarks, processedContent)
            : _generateMockTimings(processedContent);

        final extractedText = _extractDisplayValue(speechMarks);
        final fallbackDisplayText =
            isSSML ? _convertSSMLToPlainText(content) : content;
        final resolvedDisplayText =
            (extractedText != null && extractedText.trim().isNotEmpty)
                ? _normalizeWhitespace(extractedText)
                : _normalizeWhitespace(fallbackDisplayText);

        AppLogger.info('Resolved display text from Speechify', {
          'length': resolvedDisplayText.length,
          'usedSpeechMarksValue':
              extractedText != null && extractedText.trim().isNotEmpty,
        });

        return AudioGenerationResult(
          audioData: audioData,
          audioFormat: response.data['audio_format'] ?? 'wav',
          wordTimings: wordTimings,
          displayText: resolvedDisplayText,
        );
      } else {
        throw NetworkException.fromStatusCode(
          response.statusCode ?? 500,
          details: response.statusMessage,
        );
      }
    } on DioException catch (e) {
      // Expanded diagnostics to make field-level and URL issues obvious
      final req = e.requestOptions;
      AppLogger.error(
        'Speechify API error',
        error: e.message,
        data: {
          'type': e.type.name,
          'statusCode': e.response?.statusCode,
          'method': req.method,
          'baseUrl': req.baseUrl,
          'path': req.path,
          'uri': req.uri.toString(),
        },
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

      // CRITICAL FIX: Separate punctuation from words for accurate matching
      // Store the clean word without punctuation for timing matching
      // Remove trailing punctuation only (not punctuation in the middle of words)
      final cleanWord = word.replaceAll(RegExp(r'''[.,;:!?'"()]+$'''), '');

      // Only add timing if we have a real word after cleaning
      if (cleanWord.isNotEmpty) {
        timings.add(WordTiming(
          word: cleanWord, // Use clean word without trailing punctuation
          startMs: currentMs,
          endMs: currentMs + msPerWord - 50, // Small gap between words
          sentenceIndex: sentenceIndex,
        ));
      }

      // Track sentence boundaries based on original word with punctuation
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
  ///
  /// Speechify API returns hierarchical NestedChunk structure:
  /// - Top level: NestedChunk(s) representing sentences/paragraphs
  /// - Each NestedChunk contains: chunks array with word-level timing
  /// Format: {value: "sentence", start_time, end_time, start, end, chunks: [words]}
  List<WordTiming> _parseSpeechMarks(dynamic speechMarks,
      [String? originalText]) {
    final timings = <WordTiming>[];

    if (speechMarks == null) {
      AppLogger.warning('No speech marks in response');
      return timings;
    }

    try {
      // Handle Map wrapper structure (actual API response)
      if (speechMarks is Map) {
        AppLogger.info('Speech marks is a Map', {
          'keys': (speechMarks as Map).keys.toList(),
        });

        // Check if this is a single NestedChunk (has both 'chunks' and 'value')
        if (speechMarks.containsKey('chunks') &&
            speechMarks.containsKey('value')) {
          final words = (speechMarks['chunks'] as List?)?.length ?? 0;
          AppLogger.info('Speechify marks format', {
            'mode': 'nested_chunks_single',
            'sentences': 1,
            'words': words,
          });
          return _parseNestedChunk(speechMarks, 0);
        }
        // Or it's a wrapper containing chunks
        else if (speechMarks.containsKey('chunks')) {
          final chunks = speechMarks['chunks'];

          if (chunks is List && chunks.isNotEmpty) {
            // Check if it's a list of NestedChunks or words
            final firstChunk = chunks[0];
            if (firstChunk is Map && firstChunk.containsKey('chunks')) {
              // List of NestedChunks (multiple sentences)
              // Count words across all sentence chunks
              int totalWords = 0;
              for (final ch in chunks) {
                if (ch is Map && ch['chunks'] is List) {
                  totalWords += (ch['chunks'] as List).length;
                }
              }
              AppLogger.info('Speechify marks format', {
                'mode': 'nested_chunks_list',
                'sentences': chunks.length,
                'words': totalWords,
              });
              return _parseMultipleSentences(chunks);
            } else {
              // Flat list of words (single sentence)
              AppLogger.info('Speechify marks format', {
                'mode': 'flat_words',
                'sentences': 1,
                'words': chunks.length,
              });
              return _parseFlatWordList(chunks, 0, originalText);
            }
          }
        } else {
          AppLogger.warning('Could not find chunks in Map structure');
        }
      } else if (speechMarks is List && speechMarks.isNotEmpty) {
        AppLogger.info('Speech marks is a List', {
          'count': speechMarks.length,
          'firstItem': speechMarks[0].runtimeType.toString(),
        });

        // Check if it's NestedChunks or flat words
        final firstItem = speechMarks[0];
        if (firstItem is Map && firstItem.containsKey('chunks')) {
          // List of NestedChunks (multiple sentences)
          int totalWords = 0;
          for (final ch in speechMarks) {
            if (ch is Map && ch['chunks'] is List) {
              totalWords += (ch['chunks'] as List).length;
            }
          }
          AppLogger.info('Speechify marks format', {
            'mode': 'nested_chunks_list',
            'sentences': speechMarks.length,
            'words': totalWords,
          });
          return _parseMultipleSentences(speechMarks);
        } else {
          // Flat word list (single sentence, fallback for old format)
          AppLogger.info('Speechify marks format', {
            'mode': 'flat_words',
            'sentences': 1,
            'words': speechMarks.length,
          });
          return _parseFlatWordList(speechMarks, 0, originalText);
        }
      } else {
        AppLogger.warning('Unexpected speech marks format', {
          'type': speechMarks.runtimeType.toString(),
        });
      }
    } catch (e, stackTrace) {
      AppLogger.warning('Error parsing speech marks', {
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      });
    }

    return timings;
  }

  String? _extractDisplayValue(dynamic node) {
    if (node == null) return null;

    if (node is Map) {
      final value = node['value'];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }

      final chunks = node['chunks'];
      if (chunks is List && chunks.isNotEmpty) {
        final buffer = StringBuffer();
        for (final chunk in chunks) {
          final chunkText = _extractDisplayValue(chunk);
          if (chunkText != null && chunkText.trim().isNotEmpty) {
            if (buffer.isNotEmpty) buffer.write(' ');
            buffer.write(chunkText.trim());
          }
        }
        final text = buffer.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    } else if (node is List && node.isNotEmpty) {
      final parts = <String>[];
      for (final item in node) {
        final part = _extractDisplayValue(item);
        if (part != null && part.trim().isNotEmpty) {
          parts.add(part.trim());
        }
      }
      if (parts.isNotEmpty) {
        return parts.join(' ');
      }
    } else if (node is String && node.trim().isNotEmpty) {
      return node;
    }

    return null;
  }

  String _normalizeWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Parse a single NestedChunk (sentence/paragraph)
  List<WordTiming> _parseNestedChunk(Map chunk, int sentenceIndex) {
    final timings = <WordTiming>[];
    final words = chunk['chunks'] as List?;

    AppLogger.info('Parsing NestedChunk', {
      'sentenceIndex': sentenceIndex,
      'sentenceText': chunk['value'],
      'wordCount': words?.length ?? 0,
    });

    if (words != null) {
      for (int i = 0; i < words.length; i++) {
        final wordChunk = words[i] as Map;

        // Extract word text
        final word = (wordChunk['value'] as String? ?? '').trim();
        if (word.isEmpty) continue;

        // Extract timing
        final startMs = (wordChunk['start_time'] as num?)?.toInt() ?? 0;
        final endMs = (wordChunk['end_time'] as num?)?.toInt() ?? 0;

        // Extract character positions
        final charStart = (wordChunk['start'] as num?)?.toInt();
        final charEnd = (wordChunk['end'] as num?)?.toInt();

        timings.add(WordTiming(
          word: word,
          startMs: startMs,
          endMs: endMs,
          sentenceIndex:
              sentenceIndex, // All words in this chunk have same sentence index
          charStart: charStart,
          charEnd: charEnd,
        ));
      }
    }

    return timings;
  }

  /// Parse multiple NestedChunks (sentences)
  List<WordTiming> _parseMultipleSentences(List sentences) {
    final timings = <WordTiming>[];

    AppLogger.info('Parsing multiple sentences', {'count': sentences.length});

    for (int i = 0; i < sentences.length; i++) {
      final sentenceChunk = sentences[i] as Map;
      timings.addAll(_parseNestedChunk(sentenceChunk, i));
    }

    AppLogger.info('Parsed all sentences', {
      'totalWords': timings.length,
      'totalSentences': sentences.length,
    });

    return timings;
  }

  /// Parse flat word list (fallback for old format or single sentence)
  List<WordTiming> _parseFlatWordList(List words, int baseSentenceIndex,
      [String? originalText]) {
    final timings = <WordTiming>[];
    int sentenceIndex = baseSentenceIndex;

    // If the API did not provide sentence indices, derive them from the
    // original text using character offsets. This handles the common case where
    // marks are a flat list of words without nested sentence chunks.
    final sentenceRanges = originalText != null
        ? _computeSentenceRanges(originalText)
        : <(int, int)>[];

    AppLogger.info('Parsing flat word list', {
      'wordCount': words.length,
      'baseSentenceIndex': baseSentenceIndex,
    });

    for (int i = 0; i < words.length; i++) {
      final mark = words[i] as Map;

      // Log the structure of the first few marks for debugging
      if (i < 3) {
        AppLogger.debug('Word mark structure at index $i', {
          'keys': mark.keys.toList(),
        });
      }

      // Check if this is a word entry (skip if type exists and is not "word")
      final type = mark['type'] as String?;
      if (type != null && type != 'word') {
        AppLogger.debug('Skipping non-word mark', {'type': type});
        continue;
      }

      // Extract word text with defensive fallbacks
      String word = '';
      if (mark.containsKey('value')) {
        word = (mark['value'] as String? ?? '').trim();
      } else if (mark.containsKey('word')) {
        word = (mark['word'] as String? ?? '').trim();
      }

      // Skip entries with empty words
      if (word.isEmpty) {
        AppLogger.debug('Skipping empty word at index $i');
        continue;
      }

      // Extract timing with multiple fallbacks
      int startMs = 0;
      int endMs = 0;

      // Try start_time/end_time (actual API format)
      if (mark.containsKey('start_time') && mark.containsKey('end_time')) {
        startMs = (mark['start_time'] as num?)?.toInt() ?? 0;
        endMs = (mark['end_time'] as num?)?.toInt() ?? 0;
      }
      // Try start_ms/end_ms (documented format)
      else if (mark.containsKey('start_ms') && mark.containsKey('end_ms')) {
        startMs = (mark['start_ms'] as num?)?.toInt() ?? 0;
        endMs = (mark['end_ms'] as num?)?.toInt() ?? 0;
      }

      // Extract character positions if available
      int? charStart;
      int? charEnd;
      if (mark.containsKey('start') && mark.containsKey('end')) {
        charStart = (mark['start'] as num?)?.toInt();
        charEnd = (mark['end'] as num?)?.toInt();
      }

      // Determine sentence index:
      // 1) Prefer API-provided index if present
      // 2) Otherwise, infer from character offsets against computed sentence ranges
      final apiSentenceIndex = (mark['sentence_index'] as num?)?.toInt();
      if (apiSentenceIndex != null) {
        sentenceIndex = apiSentenceIndex;
      } else if (charStart != null && sentenceRanges.isNotEmpty) {
        final inferred = _findSentenceIndexForOffset(sentenceRanges, charStart);
        if (inferred != null) {
          sentenceIndex = inferred;
        }
      }

      timings.add(WordTiming(
        word: word,
        startMs: startMs,
        endMs: endMs,
        sentenceIndex: sentenceIndex,
        charStart: charStart,
        charEnd: charEnd,
      ));
    }

    return timings;
  }

  /// Split text into sentence ranges using punctuation boundaries.
  /// Returns a list of (start, end) character index ranges.
  List<(int, int)> _computeSentenceRanges(String text) {
    final ranges = <(int, int)>[];
    int start = 0;

    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      final isTerminator = ch == '.' || ch == '!' || ch == '?';
      if (isTerminator) {
        // Extend through any trailing quotes or spaces
        int end = i + 1;
        while (end < text.length &&
            (text[end] == '"' ||
                text[end] == '\'' ||
                text[end] == ')' ||
                text[end] == ']' ||
                text[end] == ' ')) {
          end++;
        }
        ranges.add((start, end));
        start = end; // Next sentence starts here
      }
    }

    // Tail content without terminal punctuation
    if (start < text.length) {
      ranges.add((start, text.length));
    }
    return ranges;
  }

  /// Binary search for the sentence range that contains the given character offset.
  int? _findSentenceIndexForOffset(List<(int, int)> ranges, int offset) {
    int left = 0;
    int right = ranges.length - 1;
    while (left <= right) {
      final mid = (left + right) >> 1;
      final r = ranges[mid];
      if (offset < r.$1) {
        right = mid - 1;
      } else if (offset >= r.$2) {
        left = mid + 1;
      } else {
        return mid;
      }
    }
    return null;
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
  final String audioData; // Base64-encoded audio
  final String audioFormat; // Format of audio (wav, mp3, etc)
  final List<WordTiming> wordTimings;
  final String displayText; // Clean plain text supplied by Speechify

  AudioGenerationResult({
    required this.audioData,
    required this.audioFormat,
    required this.wordTimings,
    required this.displayText,
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
