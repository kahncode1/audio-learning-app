import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/word_timing.dart';
import '../utils/app_logger.dart';
import 'local_content_service.dart';

/// WordTimingServiceSimplified - Simplified word timing service for pre-processed data
///
/// Purpose: Manages word and sentence timing data from pre-processed JSON files
/// This is a simplified version that works with the download-first architecture.
///
/// Key differences from original:
/// - No sentence detection algorithm (uses pre-processed sentences)
/// - No SSML to plain text conversion
/// - No character position inference
/// - Direct loading from timing.json files
/// - Simplified caching (data is already local)
///
/// Features:
/// - Load pre-processed timing data
/// - Cache timing data in memory for quick access
/// - Find current word/sentence based on playback position
/// - Support for dual-level highlighting
class WordTimingServiceSimplified {
  static WordTimingServiceSimplified? _instance;

  final LocalContentService _localContentService;

  // Cache for timing data (in-memory only, data is already local)
  final Map<String, TimingData> _timingCache = {};

  // Current timing data
  TimingData? _currentTimingData;
  String? _currentLearningObjectId;

  // Stream controllers for compatibility with original service
  final BehaviorSubject<int> _currentWordIndexSubject = BehaviorSubject.seeded(-1);
  final BehaviorSubject<int> _currentSentenceIndexSubject = BehaviorSubject.seeded(0);

  WordTimingServiceSimplified._() : _localContentService = LocalContentService();

  /// Get singleton instance
  static WordTimingServiceSimplified get instance {
  _instance ??= WordTimingServiceSimplified._();
  return _instance!;
  }

  /// Load timing data for a learning object
  ///
  /// This replaces the complex fetchTimings method
  Future<List<WordTiming>> loadTimings(String learningObjectId) async {
  try {
    AppLogger.info('Loading timing data', {
      'learningObjectId': learningObjectId,
      'cached': _timingCache.containsKey(learningObjectId),
    });

    // Check memory cache first
    if (_timingCache.containsKey(learningObjectId)) {
      final cached = _timingCache[learningObjectId]!;
      _currentTimingData = cached;
      _currentLearningObjectId = learningObjectId;

      AppLogger.info('Using cached timing data', {
        'wordCount': cached.words.length,
        'sentenceCount': cached.sentences.length,
      });

      return cached.words;
    }

    // Load from local content service
    final timingData = await _localContentService.getTimingData(learningObjectId);

    // Cache in memory
    _timingCache[learningObjectId] = timingData;
    _currentTimingData = timingData;
    _currentLearningObjectId = learningObjectId;

    // Implement simple LRU cache eviction (keep last 10 items)
    if (_timingCache.length > 10) {
      final keysToRemove = _timingCache.keys.take(_timingCache.length - 10).toList();
      for (final key in keysToRemove) {
        _timingCache.remove(key);
      }

      AppLogger.info('Evicted old timing data from cache', {
        'removed': keysToRemove.length,
        'remaining': _timingCache.length,
      });
    }

    AppLogger.info('Loaded timing data', {
      'learningObjectId': learningObjectId,
      'wordCount': timingData.words.length,
      'sentenceCount': timingData.sentences.length,
      'duration': '${timingData.totalDurationMs / 1000}s',
    });

    return timingData.words;
  } catch (e) {
    AppLogger.error(
      'Failed to load timing data',
      error: e,
      data: {'learningObjectId': learningObjectId},
    );
    return [];
  }
  }

  /// Get cached timing data (no async needed)
  List<WordTiming>? getCachedTimings(String learningObjectId) {
  final cached = _timingCache[learningObjectId];
  return cached?.words;
  }

  /// Set cached timings (for compatibility with AudioPlayerService)
  void setCachedTimings(String learningObjectId, List<WordTiming> timings) {
  // This is called by AudioPlayerService after loading
  // We don't need to do anything since data is already in cache
  AppLogger.debug('setCachedTimings called (no-op in simplified version)', {
    'learningObjectId': learningObjectId,
    'count': timings.length,
  });
  }

  /// Get the current word index based on playback position
  int getCurrentWordIndex(int positionMs) {
  if (_currentTimingData == null) return -1;
  return _currentTimingData!.getCurrentWordIndex(positionMs);
  }

  /// Get the current sentence index based on playback position
  int getCurrentSentenceIndex(int positionMs) {
  if (_currentTimingData == null) return -1;
  return _currentTimingData!.getCurrentSentenceIndex(positionMs);
  }

  /// Get sentence boundaries for a learning object
  ///
  /// Returns pre-processed sentence data (no runtime detection needed)
  Future<List<SentenceBoundary>> getSentenceBoundaries(String learningObjectId) async {
  try {
    // Ensure timing data is loaded
    if (!_timingCache.containsKey(learningObjectId)) {
      await loadTimings(learningObjectId);
    }

    final timingData = _timingCache[learningObjectId];
    if (timingData == null) {
      return [];
    }

    // Convert SentenceTiming to SentenceBoundary for compatibility
    return timingData.sentences.map((sentence) {
      return SentenceBoundary(
        text: sentence.text,
        startWordIndex: sentence.wordStartIndex,
        endWordIndex: sentence.wordEndIndex,
        startTime: sentence.startTime,
        endTime: sentence.endTime,
      );
    }).toList();
  } catch (e) {
    AppLogger.error(
      'Failed to get sentence boundaries',
      error: e,
      data: {'learningObjectId': learningObjectId},
    );
    return [];
  }
  }

  /// Clear all cached timing data
  void clearCache() {
  _timingCache.clear();
  _currentTimingData = null;
  _currentLearningObjectId = null;

  AppLogger.info('Timing cache cleared');
  }

  /// Clear timing data for a specific learning object
  void clearTimingsForObject(String learningObjectId) {
  _timingCache.remove(learningObjectId);

  if (_currentLearningObjectId == learningObjectId) {
    _currentTimingData = null;
    _currentLearningObjectId = null;
  }

  AppLogger.info('Cleared timing data', {
    'learningObjectId': learningObjectId,
  });
  }

  /// Get word at specific index (for highlighting)
  WordTiming? getWordAtIndex(int index) {
  if (_currentTimingData == null ||
      index < 0 ||
      index >= _currentTimingData!.words.length) {
    return null;
  }
  return _currentTimingData!.words[index];
  }

  /// Get all words for current learning object
  List<WordTiming> getCurrentWords() {
  return _currentTimingData?.words ?? [];
  }

  /// Get all sentences for current learning object
  List<SentenceTiming> getCurrentSentences() {
  return _currentTimingData?.sentences ?? [];
  }

  /// Get display text for a learning object
  Future<String> getDisplayText(String learningObjectId) async {
  try {
    final content = await _localContentService.getContent(learningObjectId);
    return LocalContentService.getDisplayText(content);
  } catch (e) {
    AppLogger.error(
      'Failed to get display text',
      error: e,
      data: {'learningObjectId': learningObjectId},
    );
    return '';
  }
  }

  // ============================================================================
  // Compatibility methods for original WordTimingService
  // ============================================================================

  /// Update position and emit current word/sentence indices
  void updatePosition(int positionMs, String learningObjectId) {
  if (_currentTimingData == null || _currentLearningObjectId != learningObjectId) {
    return;
  }

  final wordIndex = getCurrentWordIndex(positionMs);
  final sentenceIndex = getCurrentSentenceIndex(positionMs);

  _currentWordIndexSubject.add(wordIndex);
  _currentSentenceIndexSubject.add(sentenceIndex);
  }

  // Track last reset time to prevent cache thrashing during rapid seeks
  DateTime? _lastCacheReset;
  static const int _cacheResetDebounceMs = 100; // Minimum time between resets

  /// Reset the locality cache for accurate lookups after seeks
  /// Should be called when a seek operation is performed
  /// Includes debouncing to prevent cache thrashing during slider drags
  void resetLocalityCacheForSeek() {
    if (_currentTimingData != null) {
      // Debounce rapid resets (e.g., from slider dragging)
      final now = DateTime.now();
      if (_lastCacheReset != null) {
        final timeSinceLastReset = now.difference(_lastCacheReset!).inMilliseconds;
        if (timeSinceLastReset < _cacheResetDebounceMs) {
          // Skip this reset - too soon after the last one
          return;
        }
      }

      _currentTimingData!.resetLocalityCache();
      _lastCacheReset = now;
      AppLogger.debug('Locality cache reset for seek operation');
    }
  }

  /// Stream of current word index
  Stream<int> get currentWordStream => _currentWordIndexSubject.stream;

  /// Stream of current sentence index
  Stream<int> get currentSentenceStream => _currentSentenceIndexSubject.stream;

  /// Alias for loadTimings to maintain compatibility
  Future<List<WordTiming>> fetchTimings(String learningObjectId, String text) async {
  // Ignore text parameter in simplified version (we load from pre-processed files)
  return await loadTimings(learningObjectId);
  }

  /// Dispose resources
  void dispose() {
  _currentWordIndexSubject.close();
  _currentSentenceIndexSubject.close();
  }
}

/// Sentence boundary data for compatibility with existing code
class SentenceBoundary {
  final String text;
  final int startWordIndex;
  final int endWordIndex;
  final int startTime;
  final int endTime;

  SentenceBoundary({
  required this.text,
  required this.startWordIndex,
  required this.endWordIndex,
  required this.startTime,
  required this.endTime,
  });
}

/// Validation function for WordTimingServiceSimplified
Future<void> validateWordTimingServiceSimplified() async {
  if (!kDebugMode) return;

  debugPrint('=== WordTimingServiceSimplified Validation ===');

  final service = WordTimingServiceSimplified.instance;
  const testId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';

  try {
    // Test 1: Load timing data
    final words = await service.loadTimings(testId);
    assert(words.isNotEmpty, 'Words must be loaded');
    debugPrint('✓ Timing data loaded: ${words.length} words');

    // Test 2: Check sentence indices
    final hasValidSentenceIndices = words.every((w) => w.sentenceIndex >= 0);
    assert(hasValidSentenceIndices, 'All words must have valid sentence indices');
    debugPrint('✓ Sentence indices valid');

    // Test 3: Get sentence boundaries
    final boundaries = await service.getSentenceBoundaries(testId);
    assert(boundaries.isNotEmpty, 'Sentence boundaries must be loaded');
    debugPrint('✓ Sentence boundaries loaded: ${boundaries.length} sentences');

    // Test 4: Test position lookups
    final wordIdx = service.getCurrentWordIndex(5000); // 5 seconds
    assert(wordIdx >= 0, 'Should find word at 5s');
    debugPrint('✓ Word lookup at 5s: index $wordIdx');

    final sentIdx = service.getCurrentSentenceIndex(5000);
    assert(sentIdx >= 0, 'Should find sentence at 5s');
    debugPrint('✓ Sentence lookup at 5s: index $sentIdx');

    // Test 5: Test caching
    final cachedWords = service.getCachedTimings(testId);
    assert(cachedWords != null, 'Timing data should be cached');
    assert(cachedWords!.length == words.length, 'Cached data should match');
    debugPrint('✓ Caching working correctly');

    // Test 6: Get display text
    final displayText = await service.getDisplayText(testId);
    assert(displayText.isNotEmpty, 'Display text must be loaded');
    debugPrint('✓ Display text loaded: ${displayText.length} characters');

    // Test 7: Test cache eviction
    service.clearTimingsForObject(testId);
    final afterClear = service.getCachedTimings(testId);
    assert(afterClear == null, 'Cache should be cleared');
    debugPrint('✓ Cache clearing working');

    // Reload for final test
    await service.loadTimings(testId);

    // Test 8: Get word at index
    final wordAt10 = service.getWordAtIndex(10);
    assert(wordAt10 != null, 'Should get word at index 10');
    debugPrint('✓ Get word at index: "${wordAt10?.word}"');

    debugPrint('=== All WordTimingServiceSimplified validations passed ===');
  } catch (e) {
    debugPrint('✗ Validation failed: $e');
    rethrow;
  }
}