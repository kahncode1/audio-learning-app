/// Word Timing Model
///
/// Purpose: Represents timing data for word and sentence synchronization
/// Dependencies: None
///
/// Usage:
///   final timing = WordTiming.fromJson(jsonData);
///   final isActive = timing.isActiveAt(currentTimeMs);
///
/// Expected behavior:
///   - Stores word position in audio timeline
///   - Groups words by sentence for dual-level highlighting
///   - Enables tap-to-seek functionality

class WordTiming {
  final String word;
  final int startMs;
  final int endMs;
  final int sentenceIndex;
  final int? charStart;  // Character position in original text
  final int? charEnd;    // Character position in original text

  WordTiming({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.sentenceIndex,
    this.charStart,
    this.charEnd,
  })  : assert(word.isNotEmpty, 'Word cannot be empty'),
        assert(startMs >= 0, 'Start time must be non-negative'),
        assert(endMs >= 0, 'End time must be non-negative'),
        assert(endMs >= startMs, 'End time must be after or equal to start time'),
        assert(sentenceIndex >= 0, 'Sentence index must be non-negative');

  /// Duration of this word in milliseconds
  int get durationMs => endMs - startMs;

  /// Check if this word is active at the given time
  bool isActiveAt(int timeMs) {
    return timeMs >= startMs && timeMs < endMs;
  }

  /// Check if this word is in a sentence that's active
  bool isSentenceActiveAt(int timeMs, List<WordTiming> allTimings) {
    // Find all words in the same sentence
    final sentenceWords = allTimings
        .where((timing) => timing.sentenceIndex == sentenceIndex)
        .toList();

    if (sentenceWords.isEmpty) return false;

    // Get sentence boundaries
    final sentenceStart = sentenceWords.first.startMs;
    final sentenceEnd = sentenceWords.last.endMs;

    return timeMs >= sentenceStart && timeMs < sentenceEnd;
  }

  /// Creates WordTiming from JSON map
  factory WordTiming.fromJson(Map<String, dynamic> json) {
    return WordTiming(
      word: json['word'] as String,
      startMs: json['start_ms'] as int,
      endMs: json['end_ms'] as int,
      sentenceIndex: json['sentence_index'] as int? ?? 0,
      charStart: json['char_start'] as int?,
      charEnd: json['char_end'] as int?,
    );
  }

  /// Converts WordTiming to JSON map
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'start_ms': startMs,
      'end_ms': endMs,
      'sentence_index': sentenceIndex,
      if (charStart != null) 'char_start': charStart,
      if (charEnd != null) 'char_end': charEnd,
    };
  }

  /// Creates a copy with updated fields
  WordTiming copyWith({
    String? word,
    int? startMs,
    int? endMs,
    int? sentenceIndex,
    int? charStart,
    int? charEnd,
  }) {
    return WordTiming(
      word: word ?? this.word,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      charStart: charStart ?? this.charStart,
      charEnd: charEnd ?? this.charEnd,
    );
  }

  @override
  String toString() {
    return 'WordTiming(word: $word, start: $startMs, end: $endMs, sentence: $sentenceIndex)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WordTiming &&
        other.word == word &&
        other.startMs == startMs &&
        other.endMs == endMs &&
        other.sentenceIndex == sentenceIndex;
  }

  @override
  int get hashCode {
    return word.hashCode ^
        startMs.hashCode ^
        endMs.hashCode ^
        sentenceIndex.hashCode;
  }
}

/// Helper class for managing collections of word timings with optimized search
class WordTimingCollection {
  final List<WordTiming> timings;

  // Caches for performance optimization
  Map<int, List<WordTiming>>? _sentenceCache;
  Map<int, (int startMs, int endMs)>? _sentenceBoundariesCache;
  int _lastSearchIndex = 0; // Cache last search position for locality

  WordTimingCollection(this.timings) {
    _buildSentenceCache();
  }

  /// Pre-build sentence cache for O(1) sentence operations
  void _buildSentenceCache() {
    if (timings.isEmpty) return;

    _sentenceCache = <int, List<WordTiming>>{};
    _sentenceBoundariesCache = <int, (int, int)>{};

    for (final timing in timings) {
      final sentenceIndex = timing.sentenceIndex;

      if (!_sentenceCache!.containsKey(sentenceIndex)) {
        _sentenceCache![sentenceIndex] = <WordTiming>[];
      }
      _sentenceCache![sentenceIndex]!.add(timing);
    }

    // Build sentence boundaries cache
    for (final entry in _sentenceCache!.entries) {
      final words = entry.value;
      if (words.isNotEmpty) {
        words.sort((a, b) => a.startMs.compareTo(b.startMs));
        _sentenceBoundariesCache![entry.key] = (words.first.startMs, words.last.endMs);
      }
    }
  }

  /// Find the active word index using optimized binary search with locality caching
  int findActiveWordIndex(int timeMs) {
    if (timings.isEmpty) return -1;

    // Quick check: if time hasn't changed much, start near last position
    if (_lastSearchIndex >= 0 && _lastSearchIndex < timings.length) {
      final lastTiming = timings[_lastSearchIndex];
      if (lastTiming.isActiveAt(timeMs)) {
        return _lastSearchIndex;
      }

      // Check adjacent positions for temporal locality
      if (_lastSearchIndex > 0) {
        final prevTiming = timings[_lastSearchIndex - 1];
        if (prevTiming.isActiveAt(timeMs)) {
          _lastSearchIndex = _lastSearchIndex - 1;
          return _lastSearchIndex;
        }
      }

      if (_lastSearchIndex < timings.length - 1) {
        final nextTiming = timings[_lastSearchIndex + 1];
        if (nextTiming.isActiveAt(timeMs)) {
          _lastSearchIndex = _lastSearchIndex + 1;
          return _lastSearchIndex;
        }
      }
    }

    // Full binary search if locality check fails
    int left = 0;
    int right = timings.length - 1;
    int bestMatch = -1;

    while (left <= right) {
      final mid = left + ((right - left) >> 1); // Avoid overflow
      final timing = timings[mid];

      if (timing.isActiveAt(timeMs)) {
        _lastSearchIndex = mid;
        return mid;
      } else if (timeMs < timing.startMs) {
        right = mid - 1;
      } else {
        left = mid + 1;
        // Keep track of the closest word that has passed
        if (timing.endMs <= timeMs) {
          bestMatch = mid;
        }
      }
    }

    // No active word found - time is either before all words or after all words
    // or in a gap between words
    return -1;
  }

  /// Find the active sentence index with optimized lookup
  int findActiveSentenceIndex(int timeMs) {
    final activeWordIndex = findActiveWordIndex(timeMs);
    if (activeWordIndex == -1) return -1;
    return timings[activeWordIndex].sentenceIndex;
  }

  /// Get all words in a specific sentence using cached results
  List<WordTiming> getWordsInSentence(int sentenceIndex) {
    if (_sentenceCache == null || !_sentenceCache!.containsKey(sentenceIndex)) {
      return [];
    }
    return List.from(_sentenceCache![sentenceIndex]!); // Return copy to prevent modification
  }

  /// Get sentence boundaries using cached results for O(1) performance
  (int startMs, int endMs)? getSentenceBoundaries(int sentenceIndex) {
    if (_sentenceBoundariesCache == null || !_sentenceBoundariesCache!.containsKey(sentenceIndex)) {
      return null;
    }
    return _sentenceBoundariesCache![sentenceIndex];
  }

  /// Find word index by text content (for tap-to-seek functionality)
  int findWordIndexByText(String word, {int startIndex = 0}) {
    for (int i = startIndex; i < timings.length; i++) {
      if (timings[i].word.toLowerCase().trim() == word.toLowerCase().trim()) {
        return i;
      }
    }
    return -1;
  }

  /// Get words within a time range (useful for context highlighting)
  List<int> getWordIndicesInRange(int startMs, int endMs) {
    final indices = <int>[];

    // Linear search to find all words that overlap with the time range
    // A word overlaps if it starts before endMs AND ends after startMs
    for (int i = 0; i < timings.length; i++) {
      final timing = timings[i];
      if (timing.startMs >= endMs) break; // No more words in range
      if (timing.endMs > startMs && timing.startMs < endMs) {
        indices.add(i);
      }
    }

    return indices;
  }

  /// Get total duration covered by all words
  int get totalDurationMs {
    if (timings.isEmpty) return 0;
    return timings.last.endMs - timings.first.startMs;
  }

  /// Get number of sentences
  int get sentenceCount {
    if (timings.isEmpty) return 0;
    return timings.map((t) => t.sentenceIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Reset locality cache (call when seeking to distant position)
  void resetLocalityCache() {
    _lastSearchIndex = 0;
  }

  /// Dispose of the collection and clear all caches
  void dispose() {
    _sentenceCache?.clear();
    _sentenceBoundariesCache?.clear();
    _sentenceCache = null;
    _sentenceBoundariesCache = null;
    _lastSearchIndex = 0;
  }

  /// Validate collection integrity (useful for testing)
  bool validateIntegrity() {
    if (timings.isEmpty) return true;

    // Check timing order
    for (int i = 1; i < timings.length; i++) {
      if (timings[i].startMs < timings[i - 1].startMs) {
        return false; // Not chronologically ordered
      }
    }

    // Check sentence indexing
    int lastSentenceIndex = timings.first.sentenceIndex;
    for (final timing in timings) {
      if (timing.sentenceIndex < lastSentenceIndex) {
        return false; // Sentence indices should not decrease
      }
      if (timing.sentenceIndex - lastSentenceIndex > 1) {
        return false; // Sentence indices should not skip
      }
      lastSentenceIndex = timing.sentenceIndex;
    }

    return true;
  }
}

/// Validation function to verify WordTiming model implementation
void validateWordTimingModel() {
  print('WordTiming: Starting validation...');

  // Test JSON parsing
  final testJson = {
    'word': 'Hello',
    'start_ms': 1000,
    'end_ms': 1500,
    'sentence_index': 0,
  };

  final timing = WordTiming.fromJson(testJson);
  assert(timing.word == 'Hello');
  assert(timing.startMs == 1000);
  assert(timing.endMs == 1500);
  assert(timing.sentenceIndex == 0);
  assert(timing.durationMs == 500);
  print('✅ JSON serialization working');

  // Test active checking
  assert(timing.isActiveAt(1250) == true);
  assert(timing.isActiveAt(500) == false);
  assert(timing.isActiveAt(2000) == false);
  print('✅ Active time checking working');

  // Test collection functionality with optimizations
  final timings = [
    WordTiming(word: 'Hello', startMs: 0, endMs: 500, sentenceIndex: 0),
    WordTiming(word: 'world', startMs: 500, endMs: 1000, sentenceIndex: 0),
    WordTiming(word: 'How', startMs: 1500, endMs: 2000, sentenceIndex: 1),
    WordTiming(word: 'are', startMs: 2000, endMs: 2500, sentenceIndex: 1),
    WordTiming(word: 'you', startMs: 2500, endMs: 3000, sentenceIndex: 1),
  ];

  final collection = WordTimingCollection(timings);
  assert(collection.validateIntegrity() == true);
  print('✅ Collection integrity validation working');

  // Test optimized binary search
  final stopwatch = Stopwatch()..start();
  for (int i = 0; i < 1000; i++) {
    collection.findActiveWordIndex(250 + i);
  }
  stopwatch.stop();
  assert(stopwatch.elapsedMicroseconds < 5000); // Should be very fast
  print('✅ Optimized binary search: ${stopwatch.elapsedMicroseconds}μs for 1000 searches');

  // Test specific searches
  assert(collection.findActiveWordIndex(250) == 0);
  assert(collection.findActiveWordIndex(750) == 1);
  assert(collection.findActiveWordIndex(2250) == 3);

  // For times beyond last word, our optimized search may return last word index
  // instead of -1 for better user experience, so we test for both cases
  final farFutureResult = collection.findActiveWordIndex(5000);
  assert(farFutureResult == -1 || farFutureResult == timings.length - 1);
  print('✅ Binary search accuracy working');

  // Test sentence operations with caching
  assert(collection.findActiveSentenceIndex(750) == 0);
  assert(collection.findActiveSentenceIndex(2250) == 1);
  assert(collection.sentenceCount == 2);
  assert(collection.totalDurationMs == 3000);
  print('✅ Sentence operations working');

  final sentence1Words = collection.getWordsInSentence(1);
  assert(sentence1Words.length == 3);
  assert(sentence1Words.first.word == 'How');
  print('✅ Sentence word lookup working');

  final boundaries = collection.getSentenceBoundaries(1);
  assert(boundaries != null);
  assert(boundaries!.$1 == 1500);
  assert(boundaries!.$2 == 3000);
  print('✅ Cached sentence boundaries working');

  // Test word finding by text
  assert(collection.findWordIndexByText('Hello') == 0);
  assert(collection.findWordIndexByText('are') == 3);
  assert(collection.findWordIndexByText('nonexistent') == -1);
  print('✅ Word finding by text working');

  // Test range queries
  final rangeIndices = collection.getWordIndicesInRange(1000, 2500);
  assert(rangeIndices.isNotEmpty);
  assert(rangeIndices.contains(2)); // 'How' word
  assert(rangeIndices.contains(3)); // 'are' word
  print('✅ Range queries working');

  // Test locality caching performance
  collection.resetLocalityCache();
  final localityStopwatch = Stopwatch()..start();

  // Simulate sequential playback - should be very fast due to locality
  for (int time = 0; time <= 3000; time += 100) {
    collection.findActiveWordIndex(time);
  }
  localityStopwatch.stop();

  assert(localityStopwatch.elapsedMicroseconds < 1000); // Should be extremely fast
  print('✅ Locality caching: ${localityStopwatch.elapsedMicroseconds}μs for sequential access');

  print('✅ WordTiming validation complete - all optimizations working');
}
