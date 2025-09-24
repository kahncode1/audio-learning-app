/// Sentence Timing Model
///
/// Purpose: Represents sentence-level timing data for dual-level highlighting
/// Dependencies: None
///
/// Status: ✅ Created for DATA_ARCHITECTURE_PLAN (Phase 3)
///   - Direct JSONB field mapping with snake_case
///   - Provides continuous coverage for all audio positions
///
/// Usage:
///   final sentenceTiming = SentenceTiming.fromJson(jsonData);
///   final isActive = sentenceTiming.isActiveAt(currentTimeMs);

class SentenceTiming {
  final String text;
  final int startMs;
  final int endMs;
  final int sentenceIndex;
  final int wordStartIndex;
  final int wordEndIndex;
  final int charStart;
  final int charEnd;

  SentenceTiming({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.sentenceIndex,
    required this.wordStartIndex,
    required this.wordEndIndex,
    required this.charStart,
    required this.charEnd,
  })  : assert(text.isNotEmpty, 'Sentence text cannot be empty'),
        assert(startMs >= 0, 'Start time must be non-negative'),
        assert(endMs >= 0, 'End time must be non-negative'),
        assert(
            endMs >= startMs, 'End time must be after or equal to start time'),
        assert(sentenceIndex >= 0, 'Sentence index must be non-negative'),
        assert(wordStartIndex >= 0, 'Word start index must be non-negative'),
        assert(wordEndIndex >= wordStartIndex,
            'Word end index must be >= start index'),
        assert(charStart >= 0, 'Character start must be non-negative'),
        assert(charEnd >= charStart, 'Character end must be >= start');

  /// Duration of this sentence in milliseconds
  int get durationMs => endMs - startMs;

  /// Number of words in this sentence
  int get wordCount => wordEndIndex - wordStartIndex + 1;

  /// Check if this sentence is active at the given time
  bool isActiveAt(int timeMs) {
    return timeMs >= startMs && timeMs < endMs;
  }

  /// Creates SentenceTiming from JSON map with snake_case fields
  factory SentenceTiming.fromJson(Map<String, dynamic> json) {
    return SentenceTiming(
      text: json['text'] as String,
      startMs: json['start_ms'] as int? ?? (json['startMs'] as int? ?? 0),
      endMs: json['end_ms'] as int? ?? (json['endMs'] as int? ?? 0),
      sentenceIndex: json['sentence_index'] as int? ?? (json['sentenceIndex'] as int? ?? 0),
      // Handle both snake_case and camelCase for backward compatibility
      wordStartIndex: json['word_start_index'] as int? ?? (json['wordStartIndex'] as int? ?? 0),
      wordEndIndex: json['word_end_index'] as int? ?? (json['wordEndIndex'] as int? ?? 0),
      charStart: json['char_start'] as int? ?? (json['charStart'] as int? ?? 0),
      charEnd: json['char_end'] as int? ?? (json['charEnd'] as int? ?? 0),
    );
  }

  /// Converts SentenceTiming to JSON map with snake_case fields
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'start_ms': startMs,
      'end_ms': endMs,
      'sentence_index': sentenceIndex,
      'word_start_index': wordStartIndex,
      'word_end_index': wordEndIndex,
      'char_start': charStart,
      'char_end': charEnd,
    };
  }

  /// Creates a copy with updated fields
  SentenceTiming copyWith({
    String? text,
    int? startMs,
    int? endMs,
    int? sentenceIndex,
    int? wordStartIndex,
    int? wordEndIndex,
    int? charStart,
    int? charEnd,
  }) {
    return SentenceTiming(
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      sentenceIndex: sentenceIndex ?? this.sentenceIndex,
      wordStartIndex: wordStartIndex ?? this.wordStartIndex,
      wordEndIndex: wordEndIndex ?? this.wordEndIndex,
      charStart: charStart ?? this.charStart,
      charEnd: charEnd ?? this.charEnd,
    );
  }

  @override
  String toString() {
    return 'SentenceTiming(index: $sentenceIndex, start: $startMs, end: $endMs, words: $wordCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SentenceTiming &&
        other.sentenceIndex == sentenceIndex &&
        other.startMs == startMs &&
        other.endMs == endMs;
  }

  @override
  int get hashCode {
    return sentenceIndex.hashCode ^ startMs.hashCode ^ endMs.hashCode;
  }
}

/// Helper class for managing collections of sentence timings
class SentenceTimingCollection {
  final List<SentenceTiming> timings;

  SentenceTimingCollection(this.timings) {
    // Validate continuous coverage on construction
    _validateContinuousCoverage();
  }

  /// Validates that sentences provide continuous coverage
  void _validateContinuousCoverage() {
    if (timings.isEmpty) return;

    for (int i = 1; i < timings.length; i++) {
      final prevEnd = timings[i - 1].endMs;
      final currentStart = timings[i].startMs;

      // Allow for boundary meeting (prevEnd == currentStart)
      // This ensures continuous coverage without gaps
      assert(
        currentStart == prevEnd,
        'Gap detected between sentences ${i - 1} and $i: $prevEnd to $currentStart',
      );
    }
  }

  /// Find the active sentence index at a given time
  int findActiveSentenceIndex(int timeMs) {
    for (int i = 0; i < timings.length; i++) {
      if (timings[i].isActiveAt(timeMs)) {
        return i;
      }
    }
    return -1;
  }

  /// Get the active sentence at a given time
  SentenceTiming? getActiveSentence(int timeMs) {
    final index = findActiveSentenceIndex(timeMs);
    return index != -1 ? timings[index] : null;
  }

  /// Get total duration covered by all sentences
  int get totalDurationMs {
    if (timings.isEmpty) return 0;
    return timings.last.endMs - timings.first.startMs;
  }

  /// Get total number of sentences
  int get count => timings.length;
}

/// Validation function to verify SentenceTiming model implementation
void validateSentenceTimingModel() {
  // Test JSON parsing
  final testJson = {
    'text': 'This is a test sentence.',
    'start_ms': 1000,
    'end_ms': 3000,
    'sentence_index': 0,
    'word_start_index': 0,
    'word_end_index': 4,
    'char_start': 0,
    'char_end': 24,
  };

  final timing = SentenceTiming.fromJson(testJson);
  assert(timing.text == 'This is a test sentence.');
  assert(timing.startMs == 1000);
  assert(timing.endMs == 3000);
  assert(timing.sentenceIndex == 0);
  assert(timing.wordCount == 5);
  assert(timing.durationMs == 2000);

  // Test active checking
  assert(timing.isActiveAt(1500) == true);
  assert(timing.isActiveAt(500) == false);
  assert(timing.isActiveAt(3500) == false);

  // Test collection with continuous coverage
  final timings = [
    SentenceTiming(
      text: 'First sentence.',
      startMs: 0,
      endMs: 2000,
      sentenceIndex: 0,
      wordStartIndex: 0,
      wordEndIndex: 1,
      charStart: 0,
      charEnd: 15,
    ),
    SentenceTiming(
      text: 'Second sentence.',
      startMs: 2000, // Meets at boundary
      endMs: 4000,
      sentenceIndex: 1,
      wordStartIndex: 2,
      wordEndIndex: 3,
      charStart: 16,
      charEnd: 32,
    ),
  ];

  final collection = SentenceTimingCollection(timings);
  assert(collection.count == 2);
  assert(collection.totalDurationMs == 4000);
  assert(collection.findActiveSentenceIndex(1000) == 0);
  assert(collection.findActiveSentenceIndex(3000) == 1);

  final activeSentence = collection.getActiveSentence(2500);
  assert(activeSentence != null);
  assert(activeSentence!.sentenceIndex == 1);
}
