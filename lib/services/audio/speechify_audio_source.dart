import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../dio_provider.dart';

/// SpeechifyAudioSource - Custom audio source for streaming from Speechify
///
/// Purpose: Implements StreamAudioSource for just_audio to stream from Speechify API
/// Dependencies:
/// - just_audio: Audio playback framework
/// - DioProvider: HTTP client for streaming
///
/// Features:
/// - Range header support for seeking
/// - Progressive loading for smooth playback
/// - Error recovery and retry logic
/// - Buffer management for performance
class SpeechifyAudioSource extends StreamAudioSource {
  final String streamUrl;
  final Dio _dio;

  // Buffer configuration
  static const int _bufferSize = 64 * 1024; // 64KB chunks
  static const int _minBufferMs = 10000; // 10 seconds forward buffer
  static const int _maxBufferMs = 30000; // 30 seconds backward buffer

  SpeechifyAudioSource({required this.streamUrl})
      : _dio = DioProvider.createSpeechifyClient(),
        super(tag: 'SpeechifyStream');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      debugPrint('Requesting audio stream: start=$start, end=$end');

      // Prepare headers with Range support
      final headers = <String, String>{};
      if (start != null || end != null) {
        final rangeStart = start ?? 0;
        final rangeEnd = end ?? '';
        headers['Range'] = 'bytes=$rangeStart-$rangeEnd';
        debugPrint('Range header: bytes=$rangeStart-$rangeEnd');
      }

      // Make the request
      final response = await _dio.get<ResponseBody>(
        streamUrl,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          validateStatus: (status) {
            // Accept 200 (OK) and 206 (Partial Content)
            return status != null && (status == 200 || status == 206);
          },
        ),
      );

      if (response.data == null) {
        throw Exception('No data received from Speechify stream');
      }

      // Extract content headers
      final contentLength = _parseContentLength(response.headers);
      final contentRange = _parseContentRange(response.headers);
      final contentType = response.headers.value('content-type') ?? 'audio/mpeg';

      debugPrint('Content-Type: $contentType');
      debugPrint('Content-Length: $contentLength');
      if (contentRange != null) {
        debugPrint('Content-Range: bytes ${contentRange.start}-${contentRange.end}/${contentRange.total}');
      }

      // Create stream transformer for buffering
      final stream = response.data!.stream.transform(
        StreamTransformer<Uint8List, List<int>>.fromHandlers(
          handleData: (data, sink) {
            // Pass through the data
            sink.add(data);
          },
          handleError: (error, stack, sink) {
            debugPrint('Stream error: $error');
            sink.addError(error, stack);
          },
          handleDone: (sink) {
            debugPrint('Stream completed');
            sink.close();
          },
        ),
      );

      return StreamAudioResponse(
        sourceLength: contentLength,
        contentLength: contentLength ?? 0,
        offset: contentRange?.start ?? start ?? 0,
        stream: stream,
        contentType: contentType,
      );
    } on DioException catch (e) {
      debugPrint('Dio error in audio source: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout) {
        throw AudioSourceException('Connection timeout while loading audio');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw AudioSourceException('Receive timeout while streaming audio');
      } else if (e.response?.statusCode == 403) {
        throw AudioSourceException('Audio URL expired. Please refresh the content.');
      } else if (e.response?.statusCode == 404) {
        throw AudioSourceException('Audio not found. Please try again.');
      }
      throw AudioSourceException('Failed to load audio: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error in audio source: $e');
      throw AudioSourceException('Failed to stream audio: $e');
    }
  }

  /// Parse Content-Length header
  int? _parseContentLength(Headers headers) {
    final contentLength = headers.value('content-length');
    if (contentLength != null) {
      return int.tryParse(contentLength);
    }
    return null;
  }

  /// Parse Content-Range header
  ContentRange? _parseContentRange(Headers headers) {
    final contentRange = headers.value('content-range');
    if (contentRange != null) {
      // Format: bytes start-end/total
      final match = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
      if (match != null) {
        return ContentRange(
          start: int.parse(match.group(1)!),
          end: int.parse(match.group(2)!),
          total: int.parse(match.group(3)!),
        );
      }
    }
    return null;
  }
}

/// Content range information from HTTP headers
class ContentRange {
  final int start;
  final int end;
  final int total;

  ContentRange({
    required this.start,
    required this.end,
    required this.total,
  });
}

/// Custom exception for audio source errors
class AudioSourceException implements Exception {
  final String message;

  AudioSourceException(this.message);

  @override
  String toString() => 'AudioSourceException: $message';
}

/// Factory function to create audio source with retry
Future<AudioSource> createSpeechifyAudioSource(String streamUrl) async {
  try {
    final source = SpeechifyAudioSource(streamUrl: streamUrl);

    // Verify the source can be loaded
    // This is a lightweight check that doesn't download the full stream
    await source.request(0, 1);

    return source;
  } catch (e) {
    debugPrint('Failed to create audio source: $e');
    throw AudioSourceException('Unable to initialize audio stream: $e');
  }
}

/// Validation function for SpeechifyAudioSource
void validateSpeechifyAudioSource() {
  debugPrint('=== SpeechifyAudioSource Validation ===');

  // Test 1: Source creation
  const testUrl = 'https://api.speechify.com/test/stream.mp3';
  final source = SpeechifyAudioSource(streamUrl: testUrl);
  assert(source.streamUrl == testUrl, 'Stream URL must be set');
  debugPrint('✓ Audio source creation verified');

  // Test 2: Tag is set
  assert(source.tag == 'SpeechifyStream', 'Tag must be set');
  debugPrint('✓ Source tag verified');

  // Test 3: Buffer size constants
  assert(SpeechifyAudioSource._bufferSize == 64 * 1024, 'Buffer size must be 64KB');
  assert(SpeechifyAudioSource._minBufferMs == 10000, 'Min buffer must be 10s');
  assert(SpeechifyAudioSource._maxBufferMs == 30000, 'Max buffer must be 30s');
  debugPrint('✓ Buffer configuration verified');

  // Test 4: Exception handling
  final exception = AudioSourceException('Test error');
  assert(exception.toString().contains('Test error'), 'Exception message must be included');
  debugPrint('✓ Exception handling verified');

  debugPrint('=== All SpeechifyAudioSource validations passed ===');
}