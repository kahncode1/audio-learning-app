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

  WordTiming({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.sentenceIndex,
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
    );
  }

  /// Converts WordTiming to JSON map
  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'start_ms': startMs,
      'end_ms': endMs,
      'sentence_index': sentenceIndex,
    };
  }

  /// Creates a copy with updated fields
  WordTiming copyWith({
    String? word,
    int? startMs,
    int? endMs,
    int? sentenceIndex,
  }) {
    return WordTiming(
      word: word ?? this.word,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
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

/// Helper class for managing collections of word timings
class WordTimingCollection {
  final List<WordTiming> timings;

  WordTimingCollection(this.timings);

  /// Find the active word index at a given time using binary search
  int findActiveWordIndex(int timeMs) {
    if (timings.isEmpty) return -1;

    int left = 0;
    int right = timings.length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final timing = timings[mid];

      if (timing.isActiveAt(timeMs)) {
        return mid;
      } else if (timeMs < timing.startMs) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }

    return -1;
  }

  /// Find the active sentence index at a given time
  int findActiveSentenceIndex(int timeMs) {
    final activeWordIndex = findActiveWordIndex(timeMs);
    if (activeWordIndex == -1) return -1;
    return timings[activeWordIndex].sentenceIndex;
  }

  /// Get all words in a specific sentence
  List<WordTiming> getWordsInSentence(int sentenceIndex) {
    return timings
        .where((timing) => timing.sentenceIndex == sentenceIndex)
        .toList();
  }

  /// Get sentence boundaries
  (int startMs, int endMs)? getSentenceBoundaries(int sentenceIndex) {
    final sentenceWords = getWordsInSentence(sentenceIndex);
    if (sentenceWords.isEmpty) return null;

    return (sentenceWords.first.startMs, sentenceWords.last.endMs);
  }
}

/// Validation function to verify WordTiming model implementation
void validateWordTimingModel() {
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

  // Test active checking
  assert(timing.isActiveAt(1250) == true);
  assert(timing.isActiveAt(500) == false);
  assert(timing.isActiveAt(2000) == false);

  // Test collection functionality
  final timings = [
    WordTiming(word: 'Hello', startMs: 0, endMs: 500, sentenceIndex: 0),
    WordTiming(word: 'world', startMs: 500, endMs: 1000, sentenceIndex: 0),
    WordTiming(word: 'How', startMs: 1500, endMs: 2000, sentenceIndex: 1),
    WordTiming(word: 'are', startMs: 2000, endMs: 2500, sentenceIndex: 1),
    WordTiming(word: 'you', startMs: 2500, endMs: 3000, sentenceIndex: 1),
  ];

  final collection = WordTimingCollection(timings);

  // Test binary search
  assert(collection.findActiveWordIndex(250) == 0);
  assert(collection.findActiveWordIndex(750) == 1);
  assert(collection.findActiveWordIndex(2250) == 3);
  assert(collection.findActiveWordIndex(5000) == -1);

  // Test sentence operations
  assert(collection.findActiveSentenceIndex(750) == 0);
  assert(collection.findActiveSentenceIndex(2250) == 1);

  final sentence1Words = collection.getWordsInSentence(1);
  assert(sentence1Words.length == 3);
  assert(sentence1Words.first.word == 'How');

  final boundaries = collection.getSentenceBoundaries(1);
  assert(boundaries != null);
  assert(boundaries!.$1 == 1500);
  assert(boundaries?.$2 == 3000);
}
