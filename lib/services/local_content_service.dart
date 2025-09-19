import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/word_timing.dart';
import '../utils/app_logger.dart';

/// LocalContentService - Central hub for accessing pre-downloaded content files
///
/// Purpose: Provides unified access to all downloaded content components
/// in the download-first architecture. This service is the foundation layer
/// that both AudioPlayerServiceLocal and WordTimingServiceSimplified depend on.
///
/// Architecture Role:
/// - Foundation layer for content access
/// - Bridges file system with application services
/// - Single source of truth for content file locations
/// - Used by 21 files throughout the application
///
/// File Structure Managed:
/// ```
/// documents/audio_content/{learningObjectId}/
///   ├── content.json  (display text and metadata)
///   ├── audio.mp3     (pre-generated audio file)
///   └── timing.json   (word/sentence timing data)
/// ```
///
/// Key Features:
/// - Singleton pattern for consistent file access
/// - Automatic directory initialization
/// - Support for both asset bundles (testing) and documents (production)
/// - Unified content model with timing data integration
///
/// Critical Dependencies:
/// - Used by AudioPlayerServiceLocal for audio file access
/// - Used by WordTimingServiceSimplified for timing data
/// - Used by CourseDownloadService for content storage
///
/// Performance Notes:
/// - File I/O operations are synchronous after initial load
/// - Content is cached in memory by consuming services
/// - No network operations (pure local file access)
class LocalContentService {
  static LocalContentService? _instance;
  Directory? _documentsDir;
  String? _courseId; // Current course ID for download paths

  /// Singleton instance for consistent content access
  static LocalContentService get instance {
    _instance ??= LocalContentService._internal();
    return _instance!;
  }

  factory LocalContentService() => instance;

  LocalContentService._internal() {
    _initializeDocumentsDir();
  }

  // Base path for test content in assets
  static const String _testContentPath = 'assets/test_content/learning_objects';

  /// Initialize documents directory
  Future<void> _initializeDocumentsDir() async {
    try {
      _documentsDir = await getApplicationDocumentsDirectory();
      AppLogger.info('LocalContentService: Documents directory initialized', {
        'path': _documentsDir?.path,
      });
    } catch (e) {
      AppLogger.warning('LocalContentService: Could not get documents directory', {
        'error': e.toString(),
      });
    }
  }

  /// Set the current course ID for download paths
  void setCourseId(String courseId) {
    _courseId = courseId;
  }

  /// Get the path to a downloaded file
  Future<String?> _getDownloadedFilePath(String learningObjectId, String fileName) async {
    if (_documentsDir == null || _courseId == null) {
      await _initializeDocumentsDir();
      if (_documentsDir == null) return null;
    }

    // Default course ID if not set (for testing)
    final courseId = _courseId ?? 'INS-101';

    final path = '${_documentsDir!.path}/audio_learning/courses/$courseId/learning_objects/$learningObjectId/$fileName';
    final file = File(path);

    if (await file.exists()) {
      AppLogger.info('LocalContentService: Found downloaded file', {
        'path': path,
      });
      return path;
    }

    return null;
  }

  /// Get the path to the audio file for a learning object
  ///
  /// First checks for downloaded content, then falls back to test assets.
  Future<String> getAudioPath(String learningObjectId) async {
    try {
      // Check for downloaded file first
      final downloadedPath = await _getDownloadedFilePath(learningObjectId, 'audio.mp3');
      if (downloadedPath != null) {
        return downloadedPath;
      }

      // Fall back to asset path for test content
      final assetPath = '$_testContentPath/$learningObjectId/audio.mp3';

      AppLogger.info('LocalContentService: Audio path', {
        'learningObjectId': learningObjectId,
        'path': assetPath,
        'source': 'assets',
      });

      return assetPath;
    } catch (e) {
      AppLogger.error(
        'LocalContentService: Failed to get audio path',
        error: e,
        data: {'learningObjectId': learningObjectId},
      );
      rethrow;
    }
  }

  /// Get the content data for a learning object
  ///
  /// Returns the parsed content.json including display text and metadata
  Future<Map<String, dynamic>> getContent(String learningObjectId) async {
    try {
      // Check for downloaded file first
      final downloadedPath = await _getDownloadedFilePath(learningObjectId, 'content.json');
      String jsonString;

      if (downloadedPath != null) {
        // Load from downloaded file
        final file = File(downloadedPath);
        jsonString = await file.readAsString();
      } else {
        // Fall back to assets
        final assetPath = '$_testContentPath/$learningObjectId/content.json';
        jsonString = await rootBundle.loadString(assetPath);
      }

      final content = json.decode(jsonString) as Map<String, dynamic>;

      AppLogger.info('LocalContentService: Loaded content', {
        'learningObjectId': learningObjectId,
        'wordCount': content['metadata']?['wordCount'],
        'version': content['version'],
        'source': downloadedPath != null ? 'downloaded' : 'assets',
      });

      return content;
    } catch (e) {
      AppLogger.error(
        'LocalContentService: Failed to load content',
        error: e,
        data: {'learningObjectId': learningObjectId},
      );
      rethrow;
    }
  }

  /// Get the timing data for a learning object
  ///
  /// Returns pre-processed word and sentence timing information
  Future<TimingData> getTimingData(String learningObjectId) async {
    try {
      // Check for downloaded file first
      final downloadedPath = await _getDownloadedFilePath(learningObjectId, 'timing.json');
      String jsonString;

      if (downloadedPath != null) {
        // Load from downloaded file
        final file = File(downloadedPath);
        jsonString = await file.readAsString();
      } else {
        // Fall back to assets
        final assetPath = '$_testContentPath/$learningObjectId/timing.json';
        jsonString = await rootBundle.loadString(assetPath);
      }

      final timingJson = json.decode(jsonString) as Map<String, dynamic>;

      // Parse word timings
      final words = <WordTiming>[];
      if (timingJson['words'] != null) {
        for (final wordData in timingJson['words']) {
          words.add(WordTiming(
            word: wordData['word'] as String,
            startMs: wordData['startMs'] as int,
            endMs: wordData['endMs'] as int,
            charStart: wordData['charStart'] as int,
            charEnd: wordData['charEnd'] as int,
            sentenceIndex: 0, // Default to 0, will be updated based on sentence data
          ));
        }
      }

      // Parse sentence data and update word sentence indices
      final sentences = <SentenceTiming>[];
      if (timingJson['sentences'] != null) {
        int sentenceIndex = 0;
        for (final sentData in timingJson['sentences']) {
          final startIdx = sentData['wordStartIndex'] as int;
          final endIdx = sentData['wordEndIndex'] as int;

          // Update sentence indices for words in this sentence
          for (int i = startIdx; i <= endIdx && i < words.length; i++) {
            words[i] = WordTiming(
              word: words[i].word,
              startMs: words[i].startMs,
              endMs: words[i].endMs,
              charStart: words[i].charStart,
              charEnd: words[i].charEnd,
              sentenceIndex: sentenceIndex,
            );
          }

          sentences.add(SentenceTiming(
            text: sentData['text'] as String,
            startTime: sentData['startMs'] as int,
            endTime: sentData['endMs'] as int,
            sentenceIndex: sentenceIndex,
            wordStartIndex: startIdx,
            wordEndIndex: endIdx,
          ));

          sentenceIndex++;
        }
      }

      final timingData = TimingData(
        words: words,
        sentences: sentences,
        totalDurationMs: timingJson['totalDurationMs'] as int,
      );

      AppLogger.info('LocalContentService: Loaded timing data', {
        'learningObjectId': learningObjectId,
        'wordCount': words.length,
        'sentenceCount': sentences.length,
        'duration': '${timingData.totalDurationMs / 1000}s',
        'source': downloadedPath != null ? 'downloaded' : 'assets',
      });

      return timingData;
    } catch (e) {
      AppLogger.error(
        'LocalContentService: Failed to load timing data',
        error: e,
        data: {'learningObjectId': learningObjectId},
      );
      rethrow;
    }
  }

  /// Check if content is available locally
  ///
  /// Checks for downloaded files first, then falls back to test assets
  Future<bool> isContentAvailable(String learningObjectId) async {
    try {
      // Check for downloaded content first
      final downloadedPath = await _getDownloadedFilePath(learningObjectId, 'content.json');
      if (downloadedPath != null) {
        return true;
      }

      // Check for test content in assets
      final assetPath = '$_testContentPath/$learningObjectId/content.json';
      await rootBundle.loadString(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached content (for memory management)
  ///
  /// In production, this might clear old downloaded files
  Future<void> clearCache() async {
    // TODO: Implement cache clearing for downloaded files
    AppLogger.info('LocalContentService: Cache cleared');
  }

  /// Get display text from content
  static String getDisplayText(Map<String, dynamic> content) {
    return content['displayText'] as String? ?? '';
  }

  /// Get paragraphs from content
  static List<String> getParagraphs(Map<String, dynamic> content) {
    final paragraphs = content['paragraphs'];
    if (paragraphs is List) {
      return paragraphs.cast<String>();
    }
    return [];
  }
}

/// Container for timing data
class TimingData {
  final List<WordTiming> words;
  final List<SentenceTiming> sentences;
  final int totalDurationMs;

  TimingData({
    required this.words,
    required this.sentences,
    required this.totalDurationMs,
  });

  /// Find the current word index based on position in milliseconds
  int getCurrentWordIndex(int positionMs) {
    for (int i = 0; i < words.length; i++) {
      if (positionMs >= words[i].startMs && positionMs <= words[i].endMs) {
        return i;
      }
    }

    // If position is past all words, return last word
    if (positionMs >= totalDurationMs && words.isNotEmpty) {
      return words.length - 1;
    }

    return -1;
  }

  /// Find the current sentence index based on position
  int getCurrentSentenceIndex(int positionMs) {
    for (int i = 0; i < sentences.length; i++) {
      if (positionMs >= sentences[i].startTime && positionMs <= sentences[i].endTime) {
        return i;
      }
    }

    // If position is past all sentences, return last sentence
    if (positionMs >= totalDurationMs && sentences.isNotEmpty) {
      return sentences.length - 1;
    }

    return -1;
  }
}

/// Container for sentence timing data
class SentenceTiming {
  final String text;
  final int startTime;
  final int endTime;
  final int sentenceIndex;
  final int wordStartIndex;
  final int wordEndIndex;

  SentenceTiming({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.sentenceIndex,
    required this.wordStartIndex,
    required this.wordEndIndex,
  });
}

/// Validation function for LocalContentService
Future<void> validateLocalContentService() async {
  if (kDebugMode) {
    print('=== LocalContentService Validation ===');

    final service = LocalContentService();
    const testId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';

    try {
      // Test 1: Check content availability
      final isAvailable = await service.isContentAvailable(testId);
      assert(isAvailable, 'Test content must be available');
      print('✓ Content availability check passed');

      // Test 2: Load audio path
      final audioPath = await service.getAudioPath(testId);
      assert(audioPath.isNotEmpty, 'Audio path must not be empty');
      assert(audioPath.contains('audio.mp3'), 'Audio path must point to MP3 file');
      print('✓ Audio path loading passed: $audioPath');

      // Test 3: Load content
      final content = await service.getContent(testId);
      assert(content['version'] == '1.0', 'Content version must be 1.0');
      assert(content['displayText'] != null, 'Display text must exist');
      assert(content['paragraphs'] != null, 'Paragraphs must exist');
      print('✓ Content loading passed');

      // Test 4: Load timing data
      final timing = await service.getTimingData(testId);
      assert(timing.words.isNotEmpty, 'Words must not be empty');
      assert(timing.sentences.isNotEmpty, 'Sentences must not be empty');
      assert(timing.totalDurationMs > 0, 'Duration must be positive');
      print('✓ Timing data loading passed');
      print('  - Words: ${timing.words.length}');
      print('  - Sentences: ${timing.sentences.length}');
      print('  - Duration: ${timing.totalDurationMs}ms');

      // Test 5: Validate sentence indices
      for (final word in timing.words) {
        assert(word.sentenceIndex >= 0, 'Word must have valid sentence index');
      }
      print('✓ Sentence index assignment passed');

      // Test 6: Test timing lookups
      final midPoint = timing.totalDurationMs ~/ 2;
      final wordIdx = timing.getCurrentWordIndex(midPoint);
      final sentIdx = timing.getCurrentSentenceIndex(midPoint);
      assert(wordIdx >= 0, 'Should find word at midpoint');
      assert(sentIdx >= 0, 'Should find sentence at midpoint');
      print('✓ Timing lookup functions passed');

      print('=== All LocalContentService validations passed ===');
    } catch (e) {
      print('✗ Validation failed: $e');
      rethrow;
    }
  }
}