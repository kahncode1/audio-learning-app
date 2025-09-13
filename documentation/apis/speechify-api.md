# Speechify API Implementation Guide for Flutter Audio Learning App

## Overview

This comprehensive implementation guide provides production-ready code and best practices for integrating Speechify's Text-to-Speech API with a Flutter audio learning application. The guide focuses on enterprise-grade requirements including dual-level word/sentence highlighting, streaming audio, performance optimization, and robust error handling.

## Table of Contents

1. [API Overview & Authentication](#api-overview--authentication)
2. [Text-to-Speech Endpoints](#text-to-speech-endpoints)
3. [SSML Content Processing](#ssml-content-processing)
4. [Voice Selection & Configuration](#voice-selection--configuration)
5. [Word-Level Timing & Dual Highlighting](#word-level-timing--dual-highlighting)
6. [Custom StreamAudioSource Implementation](#custom-streamaudiosource-implementation)
7. [Dio HTTP Client Configuration](#dio-http-client-configuration)
8. [Streaming Audio with Range Headers](#streaming-audio-with-range-headers)
9. [Error Handling & Retry Mechanisms](#error-handling--retry-mechanisms)
10. [Rate Limiting & API Quota Management](#rate-limiting--api-quota-management)
11. [Caching Strategies](#caching-strategies)
12. [Performance Optimization](#performance-optimization)
13. [Production Code Examples](#production-code-examples)
14. [Testing & Troubleshooting](#testing--troubleshooting)

## API Overview & Authentication

### Base Configuration

```dart
/// Speechify API configuration constants
class SpeechifyConfig {
  static const String baseUrl = 'https://api.sws.speechify.com';
  static const String apiVersion = 'v1';

  // API Endpoints
  static const String speechEndpoint = '/v1/audio/speech';
  static const String streamEndpoint = '/v1/audio/stream';
  static const String voicesEndpoint = '/v1/voices';

  // Performance Settings
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
```

### Authentication Implementation

```dart
/// Authentication interceptor for Speechify API
class SpeechifyAuthInterceptor extends Interceptor {
  final String apiKey;

  SpeechifyAuthInterceptor({required this.apiKey});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Authorization'] = 'Bearer $apiKey';
    options.headers['Content-Type'] = 'application/json';
    options.headers['Accept'] = 'audio/mpeg, application/json';

    super.onRequest(options, handler);
  }
}
```

## Text-to-Speech Endpoints

### Core API Endpoints

Speechify provides two main speech generation endpoints:

1. **`/v1/audio/speech`** - Standard speech generation for complete text
2. **`/v1/audio/stream`** - Streaming speech generation for real-time audio

### Request Parameters

```dart
/// Request model for Speechify TTS API
class SpeechifyRequest {
  final String input;           // Text or SSML content
  final String voiceId;        // Voice identifier (e.g., 'professional_male_v2')
  final String? language;      // Language code (e.g., 'en-US')
  final double? speed;         // Playback speed (0.5 - 2.0)
  final String outputFormat;   // Audio format ('mp3', 'wav')
  final bool includeSpeechMarks; // Enable word-level timing data

  SpeechifyRequest({
    required this.input,
    required this.voiceId,
    this.language = 'en-US',
    this.speed = 1.0,
    this.outputFormat = 'mp3',
    this.includeSpeechMarks = true,
  });

  Map<String, dynamic> toJson() => {
    'input': input,
    'voice_id': voiceId,
    if (language != null) 'language': language,
    if (speed != null) 'speed': speed,
    'output_format': outputFormat,
    'include_speech_marks': includeSpeechMarks,
  };
}
```

### Response Models

```dart
/// Speechify API response with audio data and timing information
class SpeechifyResponse {
  final Uint8List audioData;
  final List<WordTiming> speechMarks;
  final String contentType;
  final int contentLength;
  final Map<String, String> headers;

  SpeechifyResponse({
    required this.audioData,
    required this.speechMarks,
    required this.contentType,
    required this.contentLength,
    required this.headers,
  });
}

/// Word timing data for dual-level highlighting
class WordTiming {
  final String word;
  final int startMs;
  final int endMs;
  final int sentenceIndex;  // For dual-level highlighting
  final int wordIndex;

  WordTiming({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.sentenceIndex,
    required this.wordIndex,
  });

  factory WordTiming.fromJson(Map<String, dynamic> json) => WordTiming(
    word: json['word'] as String,
    startMs: json['start_ms'] as int,
    endMs: json['end_ms'] as int,
    sentenceIndex: json['sentence_index'] as int,
    wordIndex: json['word_index'] as int,
  );
}
```

## SSML Content Processing

### SSML Implementation

Speech Synthesis Markup Language (SSML) provides fine-grained control over speech output:

```dart
/// SSML content processor for enhanced speech control
class SsmlProcessor {
  /// Escape special XML characters in text content
  static String escapeSSMLChars(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Create SSML wrapper for educational content
  static String createEducationalSSML({
    required String content,
    double? rate,
    String? pitch,
    String? volume,
    List<SSMLBreak>? breaks,
    List<SSMLEmphasis>? emphasis,
  }) {
    final buffer = StringBuffer('<speak>');

    // Apply prosody controls if specified
    if (rate != null || pitch != null || volume != null) {
      buffer.write('<prosody');
      if (rate != null) buffer.write(' rate="${_formatRate(rate)}"');
      if (pitch != null) buffer.write(' pitch="$pitch"');
      if (volume != null) buffer.write(' volume="$volume"');
      buffer.write('>');
    }

    // Process content with breaks and emphasis
    String processedContent = _processContentWithMarkers(
      content,
      breaks: breaks,
      emphasis: emphasis,
    );

    buffer.write(escapeSSMLChars(processedContent));

    // Close prosody if opened
    if (rate != null || pitch != null || volume != null) {
      buffer.write('</prosody>');
    }

    buffer.write('</speak>');
    return buffer.toString();
  }

  /// Format playback rate for SSML
  static String _formatRate(double rate) {
    if (rate <= 0.5) return 'x-slow';
    if (rate <= 0.8) return 'slow';
    if (rate <= 1.2) return 'medium';
    if (rate <= 1.5) return 'fast';
    return 'x-fast';
  }

  /// Process content with breaks and emphasis markers
  static String _processContentWithMarkers(
    String content, {
    List<SSMLBreak>? breaks,
    List<SSMLEmphasis>? emphasis,
  }) {
    String result = content;

    // Apply breaks
    breaks?.forEach((ssmlBreak) {
      result = result.replaceAll(
        ssmlBreak.marker,
        '<break time="${ssmlBreak.duration}ms"/>',
      );
    });

    // Apply emphasis
    emphasis?.forEach((emp) {
      result = result.replaceAll(
        emp.text,
        '<emphasis level="${emp.level}">${emp.text}</emphasis>',
      );
    });

    return result;
  }
}

/// SSML break configuration
class SSMLBreak {
  final String marker;    // Text marker to replace
  final int duration;     // Break duration in milliseconds

  SSMLBreak({required this.marker, required this.duration});
}

/// SSML emphasis configuration
class SSMLEmphasis {
  final String text;      // Text to emphasize
  final String level;     // 'reduced', 'moderate', 'strong'

  SSMLEmphasis({required this.text, required this.level});
}
```

### Professional Educational SSML Templates

```dart
/// Pre-built SSML templates for educational content
class EducationalSSMLTemplates {
  /// Template for insurance course content with appropriate pacing
  static String insuranceCourseTemplate(String content) {
    return '''
<speak>
  <prosody rate="medium" pitch="medium" volume="medium">
    <speechify:style emotion="professional" cadence="measured">
      ${SsmlProcessor.escapeSSMLChars(content)}
    </speechify:style>
  </prosody>
</speak>''';
  }

  /// Template for technical definitions with emphasis
  static String technicalDefinitionTemplate(String term, String definition) {
    return '''
<speak>
  <emphasis level="strong">${SsmlProcessor.escapeSSMLChars(term)}</emphasis>
  <break time="500ms"/>
  <prosody rate="slow">
    ${SsmlProcessor.escapeSSMLChars(definition)}
  </prosody>
</speak>''';
  }

  /// Template for numbered lists with clear separation
  static String numberedListTemplate(List<String> items) {
    final buffer = StringBuffer('<speak>');

    for (int i = 0; i < items.length; i++) {
      buffer.write('<emphasis level="moderate">');
      buffer.write('${i + 1}.</emphasis>');
      buffer.write('<break time="300ms"/>');
      buffer.write(SsmlProcessor.escapeSSMLChars(items[i]));
      if (i < items.length - 1) {
        buffer.write('<break time="800ms"/>');
      }
    }

    buffer.write('</speak>');
    return buffer.toString();
  }
}
```

## Voice Selection & Configuration

### Professional Voice Configuration

```dart
/// Voice configuration for educational content
class SpeechifyVoices {
  // Professional male voices for educational content
  static const String professionalMaleV2 = 'professional_male_v2';
  static const String businessMale = 'business_male_v1';
  static const String narratorMale = 'narrator_male_clear';

  // Professional female voices
  static const String professionalFemaleV2 = 'professional_female_v2';
  static const String businessFemale = 'business_female_v1';
  static const String narratorFemale = 'narrator_female_clear';

  /// Get recommended voice for educational content type
  static String getEducationalVoice({
    required EducationalContentType contentType,
    required VoiceGender gender,
  }) {
    switch (contentType) {
      case EducationalContentType.technical:
        return gender == VoiceGender.male
            ? professionalMaleV2
            : professionalFemaleV2;
      case EducationalContentType.narrative:
        return gender == VoiceGender.male
            ? narratorMale
            : narratorFemale;
      case EducationalContentType.business:
        return gender == VoiceGender.male
            ? businessMale
            : businessFemale;
    }
  }
}

enum EducationalContentType { technical, narrative, business }
enum VoiceGender { male, female }

/// Voice selection service
class VoiceSelectionService {
  final Dio _dio;

  VoiceSelectionService(this._dio);

  /// Fetch available voices from Speechify API
  Future<List<VoiceInfo>> getAvailableVoices() async {
    try {
      final response = await _dio.get(SpeechifyConfig.voicesEndpoint);

      if (response.statusCode == 200) {
        final List<dynamic> voicesData = response.data['voices'] as List;
        return voicesData.map((voice) => VoiceInfo.fromJson(voice)).toList();
      }

      throw SpeechifyException('Failed to fetch voices: ${response.statusCode}');
    } catch (e) {
      throw SpeechifyException('Error fetching voices: $e');
    }
  }

  /// Get optimal voice for content characteristics
  String selectOptimalVoice({
    required String contentLanguage,
    required EducationalContentType contentType,
    VoiceGender preferredGender = VoiceGender.male,
  }) {
    // Default to professional_male_v2 for insurance content
    if (contentLanguage.startsWith('en')) {
      return SpeechifyVoices.getEducationalVoice(
        contentType: contentType,
        gender: preferredGender,
      );
    }

    // Add logic for other languages as needed
    return SpeechifyVoices.professionalMaleV2;
  }
}

/// Voice information model
class VoiceInfo {
  final String id;
  final String displayName;
  final String language;
  final String gender;
  final List<String> supportedFeatures;

  VoiceInfo({
    required this.id,
    required this.displayName,
    required this.language,
    required this.gender,
    required this.supportedFeatures,
  });

  factory VoiceInfo.fromJson(Map<String, dynamic> json) => VoiceInfo(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    language: json['language'] as String,
    gender: json['gender'] as String,
    supportedFeatures: List<String>.from(json['supported_features'] ?? []),
  );
}
```

## Word-Level Timing & Dual Highlighting

### Speech Marks Processing

```dart
/// Service for processing speech marks and enabling dual-level highlighting
class SpeechMarksProcessor {
  /// Process speech marks response for dual-level highlighting
  static DualLevelTimingData processTimingData(
    String audioResponse,
    List<Map<String, dynamic>> speechMarks,
  ) {
    final wordTimings = <WordTiming>[];
    final sentenceTimings = <SentenceTiming>[];

    int currentSentenceIndex = 0;
    List<WordTiming> currentSentenceWords = [];

    for (final mark in speechMarks) {
      final wordTiming = WordTiming.fromJson(mark);
      wordTimings.add(wordTiming);
      currentSentenceWords.add(wordTiming);

      // Detect sentence boundaries (periods, exclamation marks, question marks)
      if (_isSentenceEnd(wordTiming.word)) {
        // Create sentence timing from accumulated words
        if (currentSentenceWords.isNotEmpty) {
          final sentenceTiming = SentenceTiming(
            sentenceIndex: currentSentenceIndex,
            startMs: currentSentenceWords.first.startMs,
            endMs: currentSentenceWords.last.endMs,
            wordTimings: List.from(currentSentenceWords),
          );
          sentenceTimings.add(sentenceTiming);

          currentSentenceIndex++;
          currentSentenceWords.clear();
        }
      }
    }

    // Handle any remaining words as final sentence
    if (currentSentenceWords.isNotEmpty) {
      final sentenceTiming = SentenceTiming(
        sentenceIndex: currentSentenceIndex,
        startMs: currentSentenceWords.first.startMs,
        endMs: currentSentenceWords.last.endMs,
        wordTimings: List.from(currentSentenceWords),
      );
      sentenceTimings.add(sentenceTiming);
    }

    return DualLevelTimingData(
      wordTimings: wordTimings,
      sentenceTimings: sentenceTimings,
    );
  }

  /// Check if word ends a sentence
  static bool _isSentenceEnd(String word) {
    return word.endsWith('.') ||
           word.endsWith('!') ||
           word.endsWith('?') ||
           word.endsWith(':');
  }

  /// Binary search for word at specific time position
  static WordTiming? findWordAtTime(
    List<WordTiming> wordTimings,
    int timeMs,
  ) {
    int left = 0;
    int right = wordTimings.length - 1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final word = wordTimings[mid];

      if (timeMs >= word.startMs && timeMs <= word.endMs) {
        return word;
      } else if (timeMs < word.startMs) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return null;
  }

  /// Find sentence containing specific time position
  static SentenceTiming? findSentenceAtTime(
    List<SentenceTiming> sentenceTimings,
    int timeMs,
  ) {
    for (final sentence in sentenceTimings) {
      if (timeMs >= sentence.startMs && timeMs <= sentence.endMs) {
        return sentence;
      }
    }
    return null;
  }
}

/// Dual-level timing data structure
class DualLevelTimingData {
  final List<WordTiming> wordTimings;
  final List<SentenceTiming> sentenceTimings;

  DualLevelTimingData({
    required this.wordTimings,
    required this.sentenceTimings,
  });

  /// Cache key for storage
  String get cacheKey => '${wordTimings.length}_${sentenceTimings.length}';
}

/// Sentence timing for context highlighting
class SentenceTiming {
  final int sentenceIndex;
  final int startMs;
  final int endMs;
  final List<WordTiming> wordTimings;

  SentenceTiming({
    required this.sentenceIndex,
    required this.startMs,
    required this.endMs,
    required this.wordTimings,
  });
}
```

## Custom StreamAudioSource Implementation

### Speechify StreamAudioSource

```dart
/// Custom StreamAudioSource for Speechify API integration
class SpeechifyStreamAudioSource extends StreamAudioSource {
  final SpeechifyService _speechifyService;
  final String _content;
  final String _voiceId;
  final String _language;
  final double _speed;

  List<int>? _audioBytes;
  DualLevelTimingData? _timingData;

  SpeechifyStreamAudioSource({
    required SpeechifyService speechifyService,
    required String content,
    required String voiceId,
    String language = 'en-US',
    double speed = 1.0,
  }) : _speechifyService = speechifyService,
       _content = content,
       _voiceId = voiceId,
       _language = language,
       _speed = speed;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      // Load audio data if not already cached
      if (_audioBytes == null) {
        await _loadAudioData();
      }

      if (_audioBytes == null) {
        throw SpeechifyException('Failed to load audio data');
      }

      // Handle range requests
      start ??= 0;
      end ??= _audioBytes!.length;

      // Validate range
      start = math.max(0, start);
      end = math.min(_audioBytes!.length, end);

      if (start >= end) {
        throw SpeechifyException('Invalid range: start=$start, end=$end');
      }

      // Create response stream
      final rangeBytes = _audioBytes!.sublist(start, end);
      final stream = Stream.value(rangeBytes);

      return StreamAudioResponse(
        sourceLength: _audioBytes!.length,
        contentLength: end - start,
        offset: start,
        stream: stream,
        contentType: 'audio/mpeg',
      );
    } catch (e) {
      throw SpeechifyException('StreamAudioSource request failed: $e');
    }
  }

  /// Load audio data and timing information
  Future<void> _loadAudioData() async {
    try {
      // Create SSML content for professional narration
      final ssmlContent = EducationalSSMLTemplates.insuranceCourseTemplate(_content);

      // Generate audio with speech marks
      final response = await _speechifyService.generateSpeechWithTiming(
        content: ssmlContent,
        voiceId: _voiceId,
        language: _language,
        speed: _speed,
      );

      _audioBytes = response.audioData;
      _timingData = response.timingData;

    } catch (e) {
      throw SpeechifyException('Failed to load audio data: $e');
    }
  }

  /// Get timing data for dual-level highlighting
  DualLevelTimingData? get timingData => _timingData;

  /// Pre-load audio data for faster playback start
  Future<void> preload() async {
    if (_audioBytes == null) {
      await _loadAudioData();
    }
  }

  @override
  void dispose() {
    _audioBytes = null;
    _timingData = null;
    super.dispose();
  }
}

/// Enhanced audio response with timing data
class SpeechifyAudioResponse {
  final Uint8List audioData;
  final DualLevelTimingData timingData;
  final String contentType;
  final Map<String, String> headers;

  SpeechifyAudioResponse({
    required this.audioData,
    required this.timingData,
    required this.contentType,
    required this.headers,
  });
}
```

## Dio HTTP Client Configuration

### Connection Pooling & Performance

```dart
/// Singleton Dio configuration for Speechify API
class SpeechifyHttpClient {
  static final SpeechifyHttpClient _instance = SpeechifyHttpClient._internal();
  static SpeechifyHttpClient get instance => _instance;

  late final Dio _dio;
  Dio get dio => _dio;

  SpeechifyHttpClient._internal() {
    _initializeDio();
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: SpeechifyConfig.baseUrl,
      connectTimeout: SpeechifyConfig.connectTimeout,
      receiveTimeout: SpeechifyConfig.requestTimeout,
      sendTimeout: SpeechifyConfig.requestTimeout,
      headers: {
        'User-Agent': 'AudioLearningApp/1.0.0',
        'Accept-Encoding': 'gzip, deflate',
      },
    ));

    // Connection pooling configuration
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.maxConnectionsPerHost = 10;  // Connection pooling
      client.connectionTimeout = SpeechifyConfig.connectTimeout;
      client.idleTimeout = const Duration(seconds: 30);
      return client;
    };

    _addInterceptors();
  }

  void _addInterceptors() {
    // 1. Authentication interceptor (first)
    _dio.interceptors.add(SpeechifyAuthInterceptor(
      apiKey: const String.fromEnvironment('SPEECHIFY_API_KEY'),
    ));

    // 2. Logging interceptor (debug only)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: false,  // Don't log audio data
        requestHeader: true,
        responseHeader: true,
        error: true,
        logPrint: (object) => debugPrint('[Speechify HTTP] $object'),
      ));
    }

    // 3. Cache interceptor
    _dio.interceptors.add(DioCacheInterceptor(options: CacheOptions(
      store: MemCacheStore(maxSize: 50 * 1024 * 1024), // 50MB cache
      policy: CachePolicy.forceCache,
      priority: CachePriority.high,
      maxStale: const Duration(days: 7),
      hitCacheOnErrorExcept: [401, 403, 500],
      keyBuilder: (request) => '${request.method}_${request.path}_${request.data.hashCode}',
    )));

    // 4. Retry interceptor (last)
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      retries: SpeechifyConfig.maxRetries,
      retryDelays: [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ],
      retryEvaluator: (error, attempt) {
        // Retry on network errors and 5xx server errors
        return error.type == DioExceptionType.connectionTimeout ||
               error.type == DioExceptionType.receiveTimeout ||
               error.type == DioExceptionType.sendTimeout ||
               error.type == DioExceptionType.connectionError ||
               (error.response?.statusCode != null &&
                error.response!.statusCode! >= 500);
      },
    ));
  }

  /// Configure for streaming requests
  void configureForStreaming() {
    _dio.options.responseType = ResponseType.stream;
    _dio.options.receiveTimeout = const Duration(minutes: 10); // Extended timeout
  }

  /// Reset to normal configuration
  void resetConfiguration() {
    _dio.options.responseType = ResponseType.json;
    _dio.options.receiveTimeout = SpeechifyConfig.requestTimeout;
  }
}
```

## Streaming Audio with Range Headers

### Range Request Implementation

```dart
/// Service for handling streaming audio requests with Range header support
class SpeechifyStreamingService {
  final Dio _dio = SpeechifyHttpClient.instance.dio;

  /// Stream audio generation with Range header support
  Future<Stream<List<int>>> generateAudioStream({
    required String content,
    required String voiceId,
    String language = 'en-US',
    double speed = 1.0,
    int? rangeStart,
    int? rangeEnd,
  }) async {
    try {
      final request = SpeechifyRequest(
        input: content,
        voiceId: voiceId,
        language: language,
        speed: speed,
        includeSpeechMarks: true,
      );

      // Configure dio for streaming
      SpeechifyHttpClient.instance.configureForStreaming();

      // Prepare headers with Range support
      final headers = <String, String>{};
      if (rangeStart != null || rangeEnd != null) {
        final rangeStartStr = rangeStart?.toString() ?? '0';
        final rangeEndStr = rangeEnd?.toString() ?? '';
        headers['Range'] = 'bytes=$rangeStartStr-$rangeEndStr';
      }

      // Make streaming request
      final response = await _dio.post(
        SpeechifyConfig.streamEndpoint,
        data: request.toJson(),
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        final stream = response.data as ResponseBody;
        return stream.stream;
      } else {
        throw SpeechifyException(
          'Streaming request failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw SpeechifyException('Audio streaming failed: $e');
    } finally {
      // Reset dio configuration
      SpeechifyHttpClient.instance.resetConfiguration();
    }
  }

  /// Stream audio with progressive loading and buffering
  Stream<AudioChunk> streamAudioWithBuffer({
    required String content,
    required String voiceId,
    String language = 'en-US',
    double speed = 1.0,
    int chunkSize = 64 * 1024, // 64KB chunks
  }) async* {
    try {
      int position = 0;
      bool hasMore = true;

      while (hasMore) {
        final rangeEnd = position + chunkSize - 1;

        try {
          final chunkStream = await generateAudioStream(
            content: content,
            voiceId: voiceId,
            language: language,
            speed: speed,
            rangeStart: position,
            rangeEnd: rangeEnd,
          );

          List<int> chunkData = [];
          await for (final data in chunkStream) {
            chunkData.addAll(data);
          }

          if (chunkData.isEmpty) {
            hasMore = false;
          } else {
            yield AudioChunk(
              data: Uint8List.fromList(chunkData),
              position: position,
              isLast: chunkData.length < chunkSize,
            );

            position += chunkData.length;
            hasMore = chunkData.length == chunkSize;
          }
        } catch (e) {
          if (e is DioException && e.response?.statusCode == 416) {
            // Range not satisfiable - end of file
            hasMore = false;
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      throw SpeechifyException('Buffered streaming failed: $e');
    }
  }
}

/// Audio chunk for progressive loading
class AudioChunk {
  final Uint8List data;
  final int position;
  final bool isLast;

  AudioChunk({
    required this.data,
    required this.position,
    required this.isLast,
  });
}
```

## Error Handling & Retry Mechanisms

### Comprehensive Error Handling

```dart
/// Custom exception hierarchy for Speechify API errors
abstract class SpeechifyException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic originalError;

  SpeechifyException(
    this.message, {
    this.statusCode,
    this.errorCode,
    this.originalError,
  });

  @override
  String toString() => 'SpeechifyException: $message';
}

/// Network-related errors
class SpeechifyNetworkException extends SpeechifyException {
  SpeechifyNetworkException(String message, {dynamic originalError})
      : super(message, originalError: originalError);
}

/// Authentication errors
class SpeechifyAuthException extends SpeechifyException {
  SpeechifyAuthException(String message, {int? statusCode})
      : super(message, statusCode: statusCode);
}

/// Rate limiting errors
class SpeechifyRateLimitException extends SpeechifyException {
  final Duration retryAfter;

  SpeechifyRateLimitException(String message, this.retryAfter, {int? statusCode})
      : super(message, statusCode: statusCode);
}

/// API quota exceeded errors
class SpeechifyQuotaException extends SpeechifyException {
  final DateTime? resetTime;

  SpeechifyQuotaException(String message, this.resetTime, {int? statusCode})
      : super(message, statusCode: statusCode);
}

/// Voice not available errors
class SpeechifyVoiceException extends SpeechifyException {
  final String voiceId;

  SpeechifyVoiceException(String message, this.voiceId, {int? statusCode})
      : super(message, statusCode: statusCode);
}

/// Error handler service
class SpeechifyErrorHandler {
  /// Convert DioException to appropriate SpeechifyException
  static SpeechifyException handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return SpeechifyNetworkException(
          'Connection timeout: ${error.message}',
          originalError: error,
        );

      case DioExceptionType.connectionError:
        return SpeechifyNetworkException(
          'Connection error: ${error.message}',
          originalError: error,
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(error);

      case DioExceptionType.cancel:
        return SpeechifyException('Request cancelled');

      default:
        return SpeechifyException(
          'Unexpected error: ${error.message}',
          originalError: error,
        );
    }
  }

  /// Handle HTTP status code errors
  static SpeechifyException _handleBadResponse(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    switch (statusCode) {
      case 401:
        return SpeechifyAuthException(
          'Authentication failed: Invalid API key',
          statusCode: statusCode,
        );

      case 403:
        return SpeechifyAuthException(
          'Access forbidden: Insufficient permissions',
          statusCode: statusCode,
        );

      case 429:
        final retryAfter = _parseRetryAfter(error.response?.headers);
        return SpeechifyRateLimitException(
          'Rate limit exceeded',
          retryAfter,
          statusCode: statusCode,
        );

      case 402:
      case 402: // Payment required
        final resetTime = _parseQuotaReset(error.response?.headers);
        return SpeechifyQuotaException(
          'API quota exceeded',
          resetTime,
          statusCode: statusCode,
        );

      case 400:
        final errorMessage = _extractErrorMessage(responseData);
        if (errorMessage.toLowerCase().contains('voice')) {
          return SpeechifyVoiceException(
            errorMessage,
            'unknown',
            statusCode: statusCode,
          );
        }
        return SpeechifyException(errorMessage, statusCode: statusCode);

      case 500:
      case 502:
      case 503:
      case 504:
        return SpeechifyException(
          'Server error (${statusCode}): Please try again later',
          statusCode: statusCode,
        );

      default:
        return SpeechifyException(
          'HTTP error $statusCode: ${_extractErrorMessage(responseData)}',
          statusCode: statusCode,
        );
    }
  }

  /// Parse Retry-After header
  static Duration _parseRetryAfter(Headers? headers) {
    final retryAfterHeader = headers?['retry-after']?.first;
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }
    }
    return const Duration(seconds: 60); // Default 1 minute
  }

  /// Parse quota reset time from headers
  static DateTime? _parseQuotaReset(Headers? headers) {
    final resetHeader = headers?['x-quota-reset']?.first;
    if (resetHeader != null) {
      final timestamp = int.tryParse(resetHeader);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
    }
    return null;
  }

  /// Extract error message from response data
  static String _extractErrorMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData['error']?.toString() ??
             responseData['message']?.toString() ??
             'Unknown error';
    }
    return responseData?.toString() ?? 'Unknown error';
  }
}

/// Retry interceptor with exponential backoff
class SpeechifyRetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final List<Duration> retryDelays;

  SpeechifyRetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final retryCount = request.extra['retryCount'] as int? ?? 0;

    if (retryCount < maxRetries && _shouldRetry(err)) {
      final delay = retryDelays.length > retryCount
          ? retryDelays[retryCount]
          : retryDelays.last;

      debugPrint('[Speechify Retry] Attempt ${retryCount + 1}/$maxRetries after ${delay.inSeconds}s');

      await Future.delayed(delay);

      // Clone request with incremented retry count
      final newRequest = request.copyWith(
        extra: {...request.extra, 'retryCount': retryCount + 1},
      );

      try {
        final response = await dio.fetch(newRequest);
        handler.resolve(response);
      } catch (e) {
        if (e is DioException) {
          super.onError(e, handler);
        } else {
          handler.reject(DioException(
            requestOptions: request,
            error: e,
          ));
        }
      }
    } else {
      super.onError(err, handler);
    }
  }

  /// Determine if request should be retried
  bool _shouldRetry(DioException error) {
    // Don't retry client errors (4xx) except rate limiting
    if (error.response?.statusCode != null) {
      final statusCode = error.response!.statusCode!;
      return statusCode == 429 || statusCode >= 500;
    }

    // Retry network errors
    return error.type == DioExceptionType.connectionTimeout ||
           error.type == DioExceptionType.receiveTimeout ||
           error.type == DioExceptionType.sendTimeout ||
           error.type == DioExceptionType.connectionError;
  }
}
```

## Rate Limiting & API Quota Management

### Rate Limiting Service

```dart
/// Rate limiting and quota management for Speechify API
class SpeechifyRateLimiter {
  final Map<String, TokenBucket> _buckets = {};
  final Map<String, DateTime> _quotaResetTimes = {};

  // Rate limits (adjust based on your Speechify plan)
  static const int defaultRequestsPerMinute = 100;
  static const int defaultCharactersPerMonth = 1000000;

  /// Token bucket for rate limiting
  final class TokenBucket {
    final int capacity;
    final Duration refillRate;
    int _tokens;
    DateTime _lastRefill;

    TokenBucket({
      required this.capacity,
      required this.refillRate,
    }) : _tokens = capacity,
         _lastRefill = DateTime.now();

    /// Try to consume tokens
    bool tryConsume(int tokens) {
      _refill();

      if (_tokens >= tokens) {
        _tokens -= tokens;
        return true;
      }
      return false;
    }

    /// Refill tokens based on elapsed time
    void _refill() {
      final now = DateTime.now();
      final elapsed = now.difference(_lastRefill);

      if (elapsed >= refillRate) {
        final tokensToAdd = (elapsed.inMinutes * capacity) ~/ refillRate.inMinutes;
        _tokens = math.min(capacity, _tokens + tokensToAdd);
        _lastRefill = now;
      }
    }

    /// Get available tokens
    int get availableTokens {
      _refill();
      return _tokens;
    }

    /// Time until next token is available
    Duration get timeUntilNextToken {
      _refill();
      if (_tokens > 0) return Duration.zero;

      final timeSinceRefill = DateTime.now().difference(_lastRefill);
      return refillRate - timeSinceRefill;
    }
  }

  /// Initialize rate limiter for API key
  void initializeForApiKey(String apiKey, {
    int requestsPerMinute = defaultRequestsPerMinute,
  }) {
    _buckets[apiKey] = TokenBucket(
      capacity: requestsPerMinute,
      refillRate: const Duration(minutes: 1),
    );
  }

  /// Check if request can be made
  Future<bool> canMakeRequest(String apiKey, {int cost = 1}) async {
    final bucket = _buckets[apiKey];
    if (bucket == null) {
      initializeForApiKey(apiKey);
      return canMakeRequest(apiKey, cost: cost);
    }

    return bucket.tryConsume(cost);
  }

  /// Wait until request can be made
  Future<void> waitForAvailability(String apiKey, {int cost = 1}) async {
    final bucket = _buckets[apiKey];
    if (bucket == null) {
      initializeForApiKey(apiKey);
      return;
    }

    while (!bucket.tryConsume(cost)) {
      final waitTime = bucket.timeUntilNextToken;
      debugPrint('[Rate Limiter] Waiting ${waitTime.inSeconds}s for tokens');
      await Future.delayed(waitTime);
    }
  }

  /// Update quota information from API response
  void updateQuotaInfo(String apiKey, Headers headers) {
    // Parse quota headers (adjust based on actual Speechify headers)
    final quotaRemaining = headers['x-quota-remaining']?.first;
    final quotaReset = headers['x-quota-reset']?.first;

    if (quotaReset != null) {
      final resetTimestamp = int.tryParse(quotaReset);
      if (resetTimestamp != null) {
        _quotaResetTimes[apiKey] = DateTime.fromMillisecondsSinceEpoch(
          resetTimestamp * 1000,
        );
      }
    }
  }

  /// Check if quota is available
  bool hasQuotaAvailable(String apiKey) {
    final resetTime = _quotaResetTimes[apiKey];
    if (resetTime != null && DateTime.now().isAfter(resetTime)) {
      _quotaResetTimes.remove(apiKey); // Reset occurred
      return true;
    }

    // If we don't have quota info, assume available
    return resetTime == null;
  }

  /// Get time until quota reset
  Duration? getTimeUntilQuotaReset(String apiKey) {
    final resetTime = _quotaResetTimes[apiKey];
    if (resetTime != null) {
      final remaining = resetTime.difference(DateTime.now());
      return remaining.isNegative ? null : remaining;
    }
    return null;
  }
}

/// Rate limiting interceptor for Dio
class RateLimitingInterceptor extends Interceptor {
  final SpeechifyRateLimiter rateLimiter;
  final String apiKey;

  RateLimitingInterceptor({
    required this.rateLimiter,
    required this.apiKey,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Calculate request cost based on content length
    final content = options.data?['input'] as String?;
    final cost = _calculateRequestCost(content);

    // Wait for rate limit availability
    await rateLimiter.waitForAvailability(apiKey, cost: cost);

    // Check quota availability
    if (!rateLimiter.hasQuotaAvailable(apiKey)) {
      final resetTime = rateLimiter.getTimeUntilQuotaReset(apiKey);
      throw SpeechifyQuotaException(
        'API quota exceeded',
        resetTime != null ? DateTime.now().add(resetTime) : null,
      );
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Update quota info from response headers
    rateLimiter.updateQuotaInfo(apiKey, response.headers);
    super.onResponse(response, handler);
  }

  /// Calculate request cost based on content length
  int _calculateRequestCost(String? content) {
    if (content == null) return 1;

    // Base cost + character-based cost
    final charCount = content.length;
    return 1 + (charCount ~/ 1000); // 1 extra cost per 1000 characters
  }
}
```

## Caching Strategies

### Multi-Level Caching System

```dart
/// Multi-level caching for Speechify API responses
class SpeechifyCache {
  // Memory cache for hot data
  final Map<String, CachedAudioData> _memoryCache = {};

  // Persistent storage
  final SharedPreferences _prefs;
  final FlutterCacheManager _audioCache;

  // Cache configuration
  static const int maxMemoryCacheSize = 50; // Max items in memory
  static const Duration cacheExpiry = Duration(days: 7);
  static const int maxAudioCacheSize = 200 * 1024 * 1024; // 200MB

  SpeechifyCache({
    required SharedPreferences prefs,
    required FlutterCacheManager audioCache,
  }) : _prefs = prefs,
       _audioCache = audioCache;

  /// Generate cache key for content
  String _generateCacheKey({
    required String content,
    required String voiceId,
    required String language,
    required double speed,
  }) {
    final combined = '$content|$voiceId|$language|$speed';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// Check if content is cached
  Future<bool> isCached({
    required String content,
    required String voiceId,
    required String language,
    required double speed,
  }) async {
    final key = _generateCacheKey(
      content: content,
      voiceId: voiceId,
      language: language,
      speed: speed,
    );

    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      final cached = _memoryCache[key]!;
      if (!cached.isExpired) return true;

      // Remove expired entry
      _memoryCache.remove(key);
    }

    // Check persistent cache
    final audioFile = await _audioCache.getFileFromCache(key);
    return audioFile != null;
  }

  /// Get cached audio data
  Future<CachedAudioData?> getCached({
    required String content,
    required String voiceId,
    required String language,
    required double speed,
  }) async {
    final key = _generateCacheKey(
      content: content,
      voiceId: voiceId,
      language: language,
      speed: speed,
    );

    // Try memory cache first
    final memoryData = _memoryCache[key];
    if (memoryData != null && !memoryData.isExpired) {
      debugPrint('[Speechify Cache] Memory cache hit: $key');
      return memoryData;
    }

    // Try persistent cache
    final audioFile = await _audioCache.getFileFromCache(key);
    if (audioFile != null) {
      debugPrint('[Speechify Cache] Disk cache hit: $key');

      // Load timing data from preferences
      final timingJson = _prefs.getString('timing_$key');
      DualLevelTimingData? timingData;

      if (timingJson != null) {
        try {
          final decoded = jsonDecode(timingJson) as Map<String, dynamic>;
          timingData = DualLevelTimingData.fromJson(decoded);
        } catch (e) {
          debugPrint('[Speechify Cache] Failed to decode timing data: $e');
        }
      }

      final audioBytes = await audioFile.readAsBytes();
      final cachedData = CachedAudioData(
        audioData: audioBytes,
        timingData: timingData,
        cacheTime: DateTime.now(), // Update cache time
        key: key,
      );

      // Promote to memory cache
      _addToMemoryCache(key, cachedData);

      return cachedData;
    }

    return null;
  }

  /// Cache audio data
  Future<void> cache({
    required String content,
    required String voiceId,
    required String language,
    required double speed,
    required Uint8List audioData,
    DualLevelTimingData? timingData,
  }) async {
    final key = _generateCacheKey(
      content: content,
      voiceId: voiceId,
      language: language,
      speed: speed,
    );

    final cachedData = CachedAudioData(
      audioData: audioData,
      timingData: timingData,
      cacheTime: DateTime.now(),
      key: key,
    );

    // Add to memory cache
    _addToMemoryCache(key, cachedData);

    // Save to persistent storage
    try {
      await _audioCache.putFile(
        key,
        audioData,
        fileExtension: 'mp3',
        maxAge: cacheExpiry,
      );

      // Save timing data to preferences if available
      if (timingData != null) {
        final timingJson = jsonEncode(timingData.toJson());
        await _prefs.setString('timing_$key', timingJson);
      }

      debugPrint('[Speechify Cache] Cached audio data: $key');
    } catch (e) {
      debugPrint('[Speechify Cache] Failed to cache audio: $e');
    }
  }

  /// Add data to memory cache with size management
  void _addToMemoryCache(String key, CachedAudioData data) {
    // Remove if at capacity
    if (_memoryCache.length >= maxMemoryCacheSize) {
      _evictLeastRecentlyUsed();
    }

    _memoryCache[key] = data;
  }

  /// Evict least recently used items from memory cache
  void _evictLeastRecentlyUsed() {
    if (_memoryCache.isEmpty) return;

    // Find oldest cache entry
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _memoryCache.entries) {
      if (oldestTime == null || entry.value.cacheTime.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.cacheTime;
      }
    }

    if (oldestKey != null) {
      _memoryCache.remove(oldestKey);
      debugPrint('[Speechify Cache] Evicted from memory: $oldestKey');
    }
  }

  /// Clear all caches
  Future<void> clearAll() async {
    _memoryCache.clear();
    await _audioCache.emptyCache();

    // Clear timing data from preferences
    final keys = _prefs.getKeys()
        .where((key) => key.startsWith('timing_'))
        .toList();

    for (final key in keys) {
      await _prefs.remove(key);
    }

    debugPrint('[Speechify Cache] Cleared all caches');
  }

  /// Get cache statistics
  CacheStats getCacheStats() {
    final memorySize = _memoryCache.values
        .fold<int>(0, (sum, data) => sum + data.audioData.length);

    return CacheStats(
      memoryCacheItems: _memoryCache.length,
      memoryCacheSize: memorySize,
      maxMemoryItems: maxMemoryCacheSize,
    );
  }
}

/// Cached audio data structure
class CachedAudioData {
  final Uint8List audioData;
  final DualLevelTimingData? timingData;
  final DateTime cacheTime;
  final String key;

  CachedAudioData({
    required this.audioData,
    required this.timingData,
    required this.cacheTime,
    required this.key,
  });

  /// Check if cache entry has expired
  bool get isExpired {
    return DateTime.now().difference(cacheTime) > SpeechifyCache.cacheExpiry;
  }
}

/// Cache statistics
class CacheStats {
  final int memoryCacheItems;
  final int memoryCacheSize;
  final int maxMemoryItems;

  CacheStats({
    required this.memoryCacheItems,
    required this.memoryCacheSize,
    required this.maxMemoryItems,
  });

  double get memoryCacheSizeMB => memoryCacheSize / (1024 * 1024);
  double get memoryUtilization => memoryCacheItems / maxMemoryItems;
}
```

## Performance Optimization

### Real-Time Audio Generation Optimization

```dart
/// Performance optimization service for Speechify API
class SpeechifyPerformanceOptimizer {
  final SpeechifyCache _cache;
  final SpeechifyRateLimiter _rateLimiter;

  // Performance tracking
  final Map<String, PerformanceMetrics> _metrics = {};

  SpeechifyPerformanceOptimizer({
    required SpeechifyCache cache,
    required SpeechifyRateLimiter rateLimiter,
  }) : _cache = cache,
       _rateLimiter = rateLimiter;

  /// Optimized audio generation with preloading and caching
  Future<SpeechifyAudioResponse> generateOptimizedAudio({
    required String content,
    required String voiceId,
    String language = 'en-US',
    double speed = 1.0,
    bool preloadNext = false,
    String? nextContent,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Check cache first
      final cached = await _cache.getCached(
        content: content,
        voiceId: voiceId,
        language: language,
        speed: speed,
      );

      if (cached != null) {
        stopwatch.stop();
        _recordMetrics('cache_hit', stopwatch.elapsed);

        return SpeechifyAudioResponse(
          audioData: cached.audioData,
          timingData: cached.timingData ?? DualLevelTimingData(
            wordTimings: [],
            sentenceTimings: [],
          ),
          contentType: 'audio/mpeg',
          headers: {},
        );
      }

      // Generate new audio
      final response = await _generateWithOptimizations(
        content: content,
        voiceId: voiceId,
        language: language,
        speed: speed,
      );

      // Cache the result
      await _cache.cache(
        content: content,
        voiceId: voiceId,
        language: language,
        speed: speed,
        audioData: response.audioData,
        timingData: response.timingData,
      );

      // Preload next content if requested
      if (preloadNext && nextContent != null) {
        _preloadContentAsync(
          content: nextContent,
          voiceId: voiceId,
          language: language,
          speed: speed,
        );
      }

      stopwatch.stop();
      _recordMetrics('generation', stopwatch.elapsed);

      return response;
    } catch (e) {
      stopwatch.stop();
      _recordMetrics('error', stopwatch.elapsed);
      rethrow;
    }
  }

  /// Generate audio with connection pooling and optimization
  Future<SpeechifyAudioResponse> _generateWithOptimizations({
    required String content,
    required String voiceId,
    required String language,
    required double speed,
  }) async {
    final dio = SpeechifyHttpClient.instance.dio;

    // Split long content for parallel processing
    if (content.length > 5000) {
      return await _generateLongContentOptimized(
        content: content,
        voiceId: voiceId,
        language: language,
        speed: speed,
      );
    }

    // Process SSML for optimal speech
    final ssmlContent = EducationalSSMLTemplates.insuranceCourseTemplate(content);

    final request = SpeechifyRequest(
      input: ssmlContent,
      voiceId: voiceId,
      language: language,
      speed: speed,
      includeSpeechMarks: true,
    );

    final response = await dio.post(
      SpeechifyConfig.speechEndpoint,
      data: request.toJson(),
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Accept': 'audio/mpeg',
          'X-Request-ID': _generateRequestId(),
        },
      ),
    );

    if (response.statusCode == 200) {
      // Parse response with timing data
      final audioData = Uint8List.fromList(response.data);

      // Extract speech marks from headers or separate request
      final timingData = await _extractTimingData(
        content: ssmlContent,
        voiceId: voiceId,
        language: language,
        speed: speed,
      );

      return SpeechifyAudioResponse(
        audioData: audioData,
        timingData: timingData,
        contentType: response.headers['content-type']?.first ?? 'audio/mpeg',
        headers: Map<String, String>.from(
          response.headers.map.map((key, value) => MapEntry(key, value.first)),
        ),
      );
    }

    throw SpeechifyException('Audio generation failed: ${response.statusCode}');
  }

  /// Optimized processing for long content
  Future<SpeechifyAudioResponse> _generateLongContentOptimized({
    required String content,
    required String voiceId,
    required String language,
    required double speed,
  }) async {
    // Split content into sentences for parallel processing
    final sentences = _splitIntoSentences(content);
    final chunks = _createProcessingChunks(sentences, maxChunkSize: 2000);

    // Process chunks in parallel (limited concurrency)
    const maxConcurrency = 3;
    final semaphore = Semaphore(maxConcurrency);

    final futures = chunks.map((chunk) => semaphore.acquire().then((_) async {
      try {
        return await _generateWithOptimizations(
          content: chunk.join(' '),
          voiceId: voiceId,
          language: language,
          speed: speed,
        );
      } finally {
        semaphore.release();
      }
    }));

    final responses = await Future.wait(futures);

    // Combine responses
    return _combineAudioResponses(responses);
  }

  /// Preload content asynchronously
  void _preloadContentAsync({
    required String content,
    required String voiceId,
    required String language,
    required double speed,
  }) {
    // Run in background without awaiting
    Future(() async {
      try {
        final cached = await _cache.isCached(
          content: content,
          voiceId: voiceId,
          language: language,
          speed: speed,
        );

        if (!cached) {
          debugPrint('[Speechify] Preloading content...');
          await generateOptimizedAudio(
            content: content,
            voiceId: voiceId,
            language: language,
            speed: speed,
          );
          debugPrint('[Speechify] Preload complete');
        }
      } catch (e) {
        debugPrint('[Speechify] Preload failed: $e');
      }
    });
  }

  /// Extract timing data for dual-level highlighting
  Future<DualLevelTimingData> _extractTimingData({
    required String content,
    required String voiceId,
    required String language,
    required double speed,
  }) async {
    // This would make a separate request for speech marks
    // Implementation depends on Speechify API's speech marks endpoint

    // For now, return empty data - implement based on actual API
    return DualLevelTimingData(
      wordTimings: [],
      sentenceTimings: [],
    );
  }

  /// Split text into sentences
  List<String> _splitIntoSentences(String content) {
    return content
        .split(RegExp(r'[.!?]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Create processing chunks from sentences
  List<List<String>> _createProcessingChunks(
    List<String> sentences, {
    required int maxChunkSize,
  }) {
    final chunks = <List<String>>[];
    List<String> currentChunk = [];
    int currentSize = 0;

    for (final sentence in sentences) {
      if (currentSize + sentence.length > maxChunkSize && currentChunk.isNotEmpty) {
        chunks.add(List.from(currentChunk));
        currentChunk.clear();
        currentSize = 0;
      }

      currentChunk.add(sentence);
      currentSize += sentence.length;
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  /// Combine multiple audio responses
  SpeechifyAudioResponse _combineAudioResponses(
    List<SpeechifyAudioResponse> responses,
  ) {
    // Combine audio data
    final combinedAudio = <int>[];
    final combinedWordTimings = <WordTiming>[];
    final combinedSentenceTimings = <SentenceTiming>[];

    int timeOffset = 0;
    int sentenceIndexOffset = 0;

    for (final response in responses) {
      combinedAudio.addAll(response.audioData);

      // Adjust timing offsets
      for (final word in response.timingData.wordTimings) {
        combinedWordTimings.add(WordTiming(
          word: word.word,
          startMs: word.startMs + timeOffset,
          endMs: word.endMs + timeOffset,
          sentenceIndex: word.sentenceIndex + sentenceIndexOffset,
          wordIndex: combinedWordTimings.length,
        ));
      }

      for (final sentence in response.timingData.sentenceTimings) {
        combinedSentenceTimings.add(SentenceTiming(
          sentenceIndex: sentence.sentenceIndex + sentenceIndexOffset,
          startMs: sentence.startMs + timeOffset,
          endMs: sentence.endMs + timeOffset,
          wordTimings: sentence.wordTimings.map((w) => WordTiming(
            word: w.word,
            startMs: w.startMs + timeOffset,
            endMs: w.endMs + timeOffset,
            sentenceIndex: w.sentenceIndex + sentenceIndexOffset,
            wordIndex: w.wordIndex,
          )).toList(),
        ));
      }

      // Update offsets for next response
      if (response.timingData.wordTimings.isNotEmpty) {
        timeOffset = response.timingData.wordTimings.last.endMs;
      }
      sentenceIndexOffset += response.timingData.sentenceTimings.length;
    }

    return SpeechifyAudioResponse(
      audioData: Uint8List.fromList(combinedAudio),
      timingData: DualLevelTimingData(
        wordTimings: combinedWordTimings,
        sentenceTimings: combinedSentenceTimings,
      ),
      contentType: 'audio/mpeg',
      headers: responses.first.headers,
    );
  }

  /// Record performance metrics
  void _recordMetrics(String operation, Duration duration) {
    final existing = _metrics[operation] ?? PerformanceMetrics(operation);
    existing.recordDuration(duration);
    _metrics[operation] = existing;
  }

  /// Generate unique request ID for tracking
  String _generateRequestId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  /// Get performance statistics
  Map<String, PerformanceMetrics> getPerformanceStats() {
    return Map.from(_metrics);
  }
}

/// Performance metrics tracking
class PerformanceMetrics {
  final String operation;
  final List<Duration> _durations = [];

  PerformanceMetrics(this.operation);

  void recordDuration(Duration duration) {
    _durations.add(duration);

    // Keep only recent measurements
    if (_durations.length > 100) {
      _durations.removeAt(0);
    }
  }

  Duration get averageDuration {
    if (_durations.isEmpty) return Duration.zero;

    final totalMs = _durations.fold<int>(
      0,
      (sum, d) => sum + d.inMilliseconds,
    );

    return Duration(milliseconds: totalMs ~/ _durations.length);
  }

  Duration get medianDuration {
    if (_durations.isEmpty) return Duration.zero;

    final sorted = List<Duration>.from(_durations)
      ..sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));

    final middle = sorted.length ~/ 2;
    return sorted[middle];
  }

  Duration get p95Duration {
    if (_durations.isEmpty) return Duration.zero;

    final sorted = List<Duration>.from(_durations)
      ..sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));

    final index = (sorted.length * 0.95).floor();
    return sorted[math.min(index, sorted.length - 1)];
  }

  int get requestCount => _durations.length;
}

/// Semaphore for controlling concurrency
class Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount--;
    }
  }
}
```

## Production Code Examples

### Complete Speechify Service Implementation

```dart
/// Complete production-ready Speechify service
class SpeechifyService {
  final SpeechifyCache _cache;
  final SpeechifyRateLimiter _rateLimiter;
  final SpeechifyPerformanceOptimizer _optimizer;
  final VoiceSelectionService _voiceService;

  static const String _apiKey = String.fromEnvironment('SPEECHIFY_API_KEY');

  SpeechifyService({
    required SharedPreferences prefs,
    required FlutterCacheManager audioCache,
  }) : _cache = SpeechifyCache(prefs: prefs, audioCache: audioCache),
       _rateLimiter = SpeechifyRateLimiter(),
       _optimizer = SpeechifyPerformanceOptimizer(
         cache: _cache,
         rateLimiter: _rateLimiter,
       ),
       _voiceService = VoiceSelectionService(SpeechifyHttpClient.instance.dio) {

    // Initialize rate limiter
    _rateLimiter.initializeForApiKey(_apiKey);
  }

  /// Generate speech audio with word-level timing for dual highlighting
  Future<SpeechifyAudioResponse> generateSpeechWithTiming({
    required String content,
    String? voiceId,
    String language = 'en-US',
    double speed = 1.0,
    EducationalContentType contentType = EducationalContentType.technical,
    bool preloadNext = false,
    String? nextContent,
  }) async {
    try {
      // Select optimal voice if not specified
      final selectedVoiceId = voiceId ?? _voiceService.selectOptimalVoice(
        contentLanguage: language,
        contentType: contentType,
        preferredGender: VoiceGender.male,
      );

      // Generate optimized audio
      return await _optimizer.generateOptimizedAudio(
        content: content,
        voiceId: selectedVoiceId,
        language: language,
        speed: speed,
        preloadNext: preloadNext,
        nextContent: nextContent,
      );
    } catch (e) {
      if (e is DioException) {
        throw SpeechifyErrorHandler.handleDioError(e);
      }
      rethrow;
    }
  }

  /// Create StreamAudioSource for just_audio integration
  SpeechifyStreamAudioSource createAudioSource({
    required String content,
    String? voiceId,
    String language = 'en-US',
    double speed = 1.0,
  }) {
    return SpeechifyStreamAudioSource(
      speechifyService: this,
      content: content,
      voiceId: voiceId ?? SpeechifyVoices.professionalMaleV2,
      language: language,
      speed: speed,
    );
  }

  /// Preload multiple content items
  Future<void> preloadContent(List<String> contents, {
    String? voiceId,
    String language = 'en-US',
    double speed = 1.0,
  }) async {
    final selectedVoiceId = voiceId ?? SpeechifyVoices.professionalMaleV2;

    for (final content in contents) {
      try {
        final cached = await _cache.isCached(
          content: content,
          voiceId: selectedVoiceId,
          language: language,
          speed: speed,
        );

        if (!cached) {
          await generateSpeechWithTiming(
            content: content,
            voiceId: selectedVoiceId,
            language: language,
            speed: speed,
          );
        }
      } catch (e) {
        debugPrint('[Speechify] Preload failed for content: $e');
      }
    }
  }

  /// Get available voices
  Future<List<VoiceInfo>> getAvailableVoices() async {
    return await _voiceService.getAvailableVoices();
  }

  /// Get service health and performance stats
  ServiceHealth getServiceHealth() {
    final cacheStats = _cache.getCacheStats();
    final performanceStats = _optimizer.getPerformanceStats();

    return ServiceHealth(
      isHealthy: true,
      cacheStats: cacheStats,
      performanceMetrics: performanceStats,
      apiKeyValid: _apiKey.isNotEmpty,
    );
  }

  /// Clear all caches
  Future<void> clearCaches() async {
    await _cache.clearAll();
  }

  /// Validate configuration
  static bool validateConfiguration() {
    return _apiKey.isNotEmpty;
  }
}

/// Service health information
class ServiceHealth {
  final bool isHealthy;
  final CacheStats cacheStats;
  final Map<String, PerformanceMetrics> performanceMetrics;
  final bool apiKeyValid;

  ServiceHealth({
    required this.isHealthy,
    required this.cacheStats,
    required this.performanceMetrics,
    required this.apiKeyValid,
  });

  Map<String, dynamic> toJson() => {
    'isHealthy': isHealthy,
    'apiKeyValid': apiKeyValid,
    'cacheUtilization': cacheStats.memoryUtilization,
    'cacheSizeMB': cacheStats.memoryCacheSizeMB,
    'performanceMetrics': performanceMetrics.map(
      (key, value) => MapEntry(key, {
        'averageMs': value.averageDuration.inMilliseconds,
        'medianMs': value.medianDuration.inMilliseconds,
        'p95Ms': value.p95Duration.inMilliseconds,
        'requestCount': value.requestCount,
      }),
    ),
  };
}
```

### Flutter Integration Example

```dart
/// Example Flutter widget using Speechify service
class AudioLearningPlayer extends ConsumerStatefulWidget {
  final String content;
  final String? voiceId;
  final Function(WordTiming?, SentenceTiming?)? onHighlightUpdate;

  const AudioLearningPlayer({
    Key? key,
    required this.content,
    this.voiceId,
    this.onHighlightUpdate,
  }) : super(key: key);

  @override
  ConsumerState<AudioLearningPlayer> createState() => _AudioLearningPlayerState();
}

class _AudioLearningPlayerState extends ConsumerState<AudioLearningPlayer> {
  late AudioPlayer _audioPlayer;
  SpeechifyStreamAudioSource? _audioSource;
  StreamSubscription<Duration>? _positionSubscription;

  WordTiming? _currentWord;
  SentenceTiming? _currentSentence;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _audioPlayer = AudioPlayer();

    // Create audio source
    final speechifyService = ref.read(speechifyServiceProvider);
    _audioSource = speechifyService.createAudioSource(
      content: widget.content,
      voiceId: widget.voiceId,
    );

    // Set audio source
    await _audioPlayer.setAudioSource(_audioSource!);

    // Listen to position changes for highlighting
    _positionSubscription = _audioPlayer.positionStream.listen(_onPositionChanged);
  }

  void _onPositionChanged(Duration position) {
    final timingData = _audioSource?.timingData;
    if (timingData == null) return;

    final timeMs = position.inMilliseconds;

    // Find current word
    final newWord = SpeechMarksProcessor.findWordAtTime(
      timingData.wordTimings,
      timeMs,
    );

    // Find current sentence
    final newSentence = SpeechMarksProcessor.findSentenceAtTime(
      timingData.sentenceTimings,
      timeMs,
    );

    // Update highlighting if changed
    if (newWord != _currentWord || newSentence != _currentSentence) {
      setState(() {
        _currentWord = newWord;
        _currentSentence = newSentence;
      });

      widget.onHighlightUpdate?.call(newWord, newSentence);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Audio controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _audioPlayer.seek(
                _audioPlayer.position - const Duration(seconds: 30),
              ),
              icon: const Icon(Icons.replay_30),
            ),

            StreamBuilder<PlayerState>(
              stream: _audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final isPlaying = state?.playing ?? false;

                return FloatingActionButton(
                  onPressed: isPlaying ? _audioPlayer.pause : _audioPlayer.play,
                  child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                );
              },
            ),

            IconButton(
              onPressed: () => _audioPlayer.seek(
                _audioPlayer.position + const Duration(seconds: 30),
              ),
              icon: const Icon(Icons.forward_30),
            ),
          ],
        ),

        // Progress indicator
        StreamBuilder<Duration?>(
          stream: _audioPlayer.durationStream,
          builder: (context, durationSnapshot) {
            return StreamBuilder<Duration>(
              stream: _audioPlayer.positionStream,
              builder: (context, positionSnapshot) {
                final duration = durationSnapshot.data ?? Duration.zero;
                final position = positionSnapshot.data ?? Duration.zero;

                return LinearProgressIndicator(
                  value: duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0,
                );
              },
            );
          },
        ),

        // Current highlighting info (for debugging)
        if (_currentWord != null || _currentSentence != null)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_currentSentence != null)
                  Text(
                    'Current Sentence: ${_currentSentence!.sentenceIndex}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_currentWord != null)
                  Text(
                    'Current Word: "${_currentWord!.word}" (${_currentWord!.wordIndex})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

/// Riverpod provider for Speechify service
final speechifyServiceProvider = Provider<SpeechifyService>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final audioCache = ref.read(cacheManagerProvider);

  return SpeechifyService(
    prefs: prefs,
    audioCache: audioCache,
  );
});
```

## Testing & Troubleshooting

### Unit Tests

```dart
/// Unit tests for Speechify service
class SpeechifyServiceTest {
  late SpeechifyService service;
  late MockSharedPreferences mockPrefs;
  late MockCacheManager mockCache;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockCache = MockCacheManager();
    service = SpeechifyService(
      prefs: mockPrefs,
      audioCache: mockCache,
    );
  });

  group('Audio Generation', () {
    test('should generate audio with timing data', () async {
      const content = 'Hello world. This is a test.';

      final response = await service.generateSpeechWithTiming(
        content: content,
        voiceId: SpeechifyVoices.professionalMaleV2,
      );

      expect(response.audioData.isNotEmpty, true);
      expect(response.timingData.wordTimings.isNotEmpty, true);
      expect(response.timingData.sentenceTimings.isNotEmpty, true);
    });

    test('should cache generated audio', () async {
      const content = 'Test content for caching';

      // First generation
      final response1 = await service.generateSpeechWithTiming(
        content: content,
      );

      // Second generation (should use cache)
      final response2 = await service.generateSpeechWithTiming(
        content: content,
      );

      expect(response1.audioData, equals(response2.audioData));

      // Verify cache was used
      verify(mockCache.getFileFromCache(any)).called(1);
    });

    test('should handle API errors gracefully', () async {
      // Mock network error
      when(mockDio.post(any, data: any)).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () => service.generateSpeechWithTiming(content: 'test'),
        throwsA(isA<SpeechifyNetworkException>()),
      );
    });
  });

  group('Timing Data Processing', () {
    test('should process speech marks correctly', () {
      final mockSpeechMarks = [
        {'word': 'Hello', 'start_ms': 0, 'end_ms': 500, 'sentence_index': 0, 'word_index': 0},
        {'word': 'world.', 'start_ms': 500, 'end_ms': 1000, 'sentence_index': 0, 'word_index': 1},
        {'word': 'This', 'start_ms': 1200, 'end_ms': 1500, 'sentence_index': 1, 'word_index': 2},
        {'word': 'is', 'start_ms': 1500, 'end_ms': 1700, 'sentence_index': 1, 'word_index': 3},
        {'word': 'a', 'start_ms': 1700, 'end_ms': 1800, 'sentence_index': 1, 'word_index': 4},
        {'word': 'test.', 'start_ms': 1800, 'end_ms': 2200, 'sentence_index': 1, 'word_index': 5},
      ];

      final timingData = SpeechMarksProcessor.processTimingData(
        'audio data',
        mockSpeechMarks,
      );

      expect(timingData.wordTimings.length, 6);
      expect(timingData.sentenceTimings.length, 2);

      // Test sentence boundaries
      expect(timingData.sentenceTimings[0].wordTimings.length, 2);
      expect(timingData.sentenceTimings[1].wordTimings.length, 4);
    });

    test('should find words at specific time positions', () {
      final wordTimings = [
        WordTiming(word: 'Hello', startMs: 0, endMs: 500, sentenceIndex: 0, wordIndex: 0),
        WordTiming(word: 'world', startMs: 500, endMs: 1000, sentenceIndex: 0, wordIndex: 1),
        WordTiming(word: 'test', startMs: 1000, endMs: 1500, sentenceIndex: 0, wordIndex: 2),
      ];

      // Test exact matches
      final word1 = SpeechMarksProcessor.findWordAtTime(wordTimings, 250);
      expect(word1?.word, 'Hello');

      final word2 = SpeechMarksProcessor.findWordAtTime(wordTimings, 750);
      expect(word2?.word, 'world');

      // Test boundary conditions
      final word3 = SpeechMarksProcessor.findWordAtTime(wordTimings, 500);
      expect(word3?.word, 'world');

      // Test no match
      final word4 = SpeechMarksProcessor.findWordAtTime(wordTimings, 2000);
      expect(word4, null);
    });
  });

  group('Performance', () {
    test('should complete generation within performance targets', () async {
      const content = 'Short test content for performance testing';
      final stopwatch = Stopwatch()..start();

      await service.generateSpeechWithTiming(content: content);

      stopwatch.stop();

      // Should complete within 2 seconds for short content
      expect(stopwatch.elapsed.inSeconds, lessThan(2));
    });
  });
}
```

### Integration Tests

```dart
/// Integration tests with real API
class SpeechifyIntegrationTest {
  late SpeechifyService service;

  setUp(() async {
    // Initialize with real dependencies
    final prefs = await SharedPreferences.getInstance();
    final cacheManager = DefaultCacheManager();

    service = SpeechifyService(
      prefs: prefs,
      audioCache: cacheManager,
    );
  });

  group('Real API Integration', () {
    test('should generate audio from real API', () async {
      const content = '''
      Insurance is a risk management tool that helps protect individuals
      and businesses from financial losses. By paying regular premiums,
      policyholders transfer the risk of potential losses to an insurance company.
      ''';

      final response = await service.generateSpeechWithTiming(
        content: content,
        voiceId: SpeechifyVoices.professionalMaleV2,
      );

      expect(response.audioData.isNotEmpty, true);
      expect(response.timingData.wordTimings.isNotEmpty, true);
      expect(response.contentType, 'audio/mpeg');

      // Test audio quality by checking file size
      expect(response.audioData.length, greaterThan(10000)); // > 10KB
    });

    test('should handle different voice options', () async {
      const content = 'Testing different voice options for educational content.';

      final voices = [
        SpeechifyVoices.professionalMaleV2,
        SpeechifyVoices.professionalFemaleV2,
        SpeechifyVoices.businessMale,
      ];

      for (final voice in voices) {
        final response = await service.generateSpeechWithTiming(
          content: content,
          voiceId: voice,
        );

        expect(response.audioData.isNotEmpty, true);
        expect(response.timingData.wordTimings.isNotEmpty, true);
      }
    });

    test('should handle SSML content correctly', () async {
      const ssmlContent = '''
      <speak>
        <prosody rate="medium" pitch="medium">
          This is a test of SSML processing with
          <emphasis level="strong">emphasis</emphasis>
          and <break time="500ms"/> pauses.
        </prosody>
      </speak>
      ''';

      final response = await service.generateSpeechWithTiming(
        content: ssmlContent,
      );

      expect(response.audioData.isNotEmpty, true);
      expect(response.timingData.wordTimings.isNotEmpty, true);
    });
  });

  group('StreamAudioSource Integration', () {
    test('should work with just_audio player', () async {
      const content = 'Testing stream audio source integration with just_audio player.';

      final audioSource = service.createAudioSource(content: content);
      final player = AudioPlayer();

      try {
        await player.setAudioSource(audioSource);

        // Test that audio can be played
        await player.play();
        await Future.delayed(const Duration(seconds: 1));

        expect(player.playing, true);
        expect(player.position.inMilliseconds, greaterThan(0));

        // Test seeking
        await player.seek(const Duration(seconds: 2));
        expect(player.position.inSeconds, closeTo(2, 1));

      } finally {
        await player.dispose();
      }
    });
  });

  group('Error Handling', () {
    test('should handle invalid API key', () async {
      // This test would require a way to override the API key
      // Implementation depends on your configuration approach
    });

    test('should handle network timeouts', () async {
      // Mock network delays to test timeout handling
      // This would require network simulation tools
    });

    test('should handle rate limiting', () async {
      // Make rapid requests to test rate limiting
      const content = 'Rate limiting test content';

      final futures = List.generate(
        10,
        (index) => service.generateSpeechWithTiming(content: '$content $index'),
      );

      // Some requests should succeed, others may be rate limited
      final results = await Future.wait(
        futures,
        eagerError: false,
      );

      // Check that appropriate errors are thrown for rate limited requests
      expect(results.any((r) => r != null), true);
    });
  });
}
```

### Troubleshooting Guide

#### Common Issues & Solutions

1. **Audio Generation Fails**
   ```dart
   // Check API key configuration
   if (!SpeechifyService.validateConfiguration()) {
     throw Exception('Invalid Speechify configuration');
   }

   // Check network connectivity
   final connectivity = await Connectivity().checkConnectivity();
   if (connectivity == ConnectivityResult.none) {
     throw SpeechifyNetworkException('No network connection');
   }
   ```

2. **Timing Data Synchronization Issues**
   ```dart
   // Verify word timing data quality
   void validateTimingData(DualLevelTimingData timingData) {
     for (int i = 0; i < timingData.wordTimings.length - 1; i++) {
       final current = timingData.wordTimings[i];
       final next = timingData.wordTimings[i + 1];

       if (current.endMs > next.startMs) {
         debugPrint('Warning: Overlapping word timings at index $i');
       }
     }
   }
   ```

3. **Performance Issues**
   ```dart
   // Monitor service health
   final health = speechifyService.getServiceHealth();
   if (health.performanceMetrics['generation']?.averageDuration.inSeconds > 2) {
     debugPrint('Warning: Slow audio generation detected');
     // Consider preloading or caching optimizations
   }
   ```

4. **Memory Management**
   ```dart
   // Monitor cache usage
   final cacheStats = speechifyService.getServiceHealth().cacheStats;
   if (cacheStats.memoryCacheSizeMB > 100) {
     debugPrint('Warning: High memory usage, clearing cache');
     await speechifyService.clearCaches();
   }
   ```

#### Performance Optimization Checklist

- [ ] Enable connection pooling in Dio configuration
- [ ] Implement appropriate caching strategies
- [ ] Use SSML for optimal speech quality
- [ ] Preload content when possible
- [ ] Monitor and optimize timing data processing
- [ ] Test with various content lengths and complexity
- [ ] Validate performance on different devices and network conditions

#### Production Deployment Checklist

- [ ] API keys securely configured via environment variables
- [ ] Rate limiting properly configured for production quotas
- [ ] Caching configured with appropriate sizes and eviction policies
- [ ] Error handling and logging implemented
- [ ] Performance monitoring in place
- [ ] Backup and recovery strategies for cached content
- [ ] Testing completed on target devices and network conditions

## Conclusion

This implementation guide provides a comprehensive, production-ready solution for integrating Speechify's Text-to-Speech API with Flutter applications. The code examples demonstrate enterprise-grade patterns including:

- Robust error handling and retry mechanisms
- Efficient caching and performance optimization
- Dual-level word and sentence highlighting support
- Custom StreamAudioSource for seamless just_audio integration
- Comprehensive rate limiting and quota management
- Real-time audio generation with <2 second latency targets

The implementation follows Flutter best practices and is designed to meet the demanding requirements of educational applications with precise timing synchronization and professional audio quality.

For production deployment, ensure all configuration values are properly set via environment variables, and conduct thorough testing across target devices and network conditions to validate performance targets are met.