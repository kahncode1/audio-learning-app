/// Highlight Calculator
///
/// Purpose: Calculates word and sentence boundaries for highlighting
/// Determines current highlight positions based on timing data
///
/// Responsibilities:
/// - Calculate current word/sentence indices
/// - Determine highlight boundaries
/// - Handle timing synchronization
/// - Validate character positions
///
import '../../models/word_timing.dart';
import '../../services/word_timing_service_simplified.dart';
import '../../utils/app_logger.dart';

class HighlightCalculator {
  final WordTimingServiceSimplified _wordTimingService;
  TimingData? _timingData;
  int _currentWordIndex = -1;
  int _currentSentenceIndex = -1;

  HighlightCalculator({
    required WordTimingServiceSimplified wordTimingService,
  }) : _wordTimingService = wordTimingService;

  /// Get current word index
  int get currentWordIndex => _currentWordIndex;

  /// Get current sentence index
  int get currentSentenceIndex => _currentSentenceIndex;

  /// Load timing data for content
  Future<void> loadTimingData(String contentId) async {
    try {
      _timingData = await _wordTimingService.getTimingData(contentId);
      if (_timingData == null) {
        AppLogger.warning('No timing data found for content', {
          'contentId': contentId,
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load timing data', error: e);
    }
  }

  /// Update current indices based on position
  void updateIndices(Duration position) {
    if (_timingData == null) return;

    final positionMs = position.inMilliseconds;

    // Update word index
    final newWordIndex = findCurrentWordIndex(positionMs);
    if (newWordIndex != _currentWordIndex) {
      _currentWordIndex = newWordIndex;
    }

    // Update sentence index
    final newSentenceIndex = findCurrentSentenceIndex(positionMs);
    if (newSentenceIndex != _currentSentenceIndex) {
      _currentSentenceIndex = newSentenceIndex;
    }
  }

  /// Find current word index for position
  int findCurrentWordIndex(int positionMs) {
    if (_timingData?.words == null || _timingData!.words!.isEmpty) {
      return -1;
    }

    // Binary search for efficiency
    final words = _timingData!.words!;
    int left = 0;
    int right = words.length - 1;
    int result = -1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final word = words[mid];

      if (positionMs >= word.startMs && positionMs <= word.endMs) {
        return mid;
      } else if (positionMs < word.startMs) {
        right = mid - 1;
      } else {
        result = mid; // Keep track of last word before position
        left = mid + 1;
      }
    }

    // If position is between words, return the last word before position
    return result;
  }

  /// Find current sentence index for position
  int findCurrentSentenceIndex(int positionMs) {
    if (_timingData?.sentences == null || _timingData!.sentences!.isEmpty) {
      return -1;
    }

    // Binary search for efficiency
    final sentences = _timingData!.sentences!;
    int left = 0;
    int right = sentences.length - 1;
    int result = -1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final sentence = sentences[mid];

      if (positionMs >= sentence.startMs && positionMs <= sentence.endMs) {
        return mid;
      } else if (positionMs < sentence.startMs) {
        right = mid - 1;
      } else {
        result = mid; // Keep track of last sentence before position
        left = mid + 1;
      }
    }

    return result;
  }

  /// Get character boundaries for current word
  CharacterBoundaries? getCurrentWordBoundaries() {
    if (_currentWordIndex < 0 || _timingData?.words == null) {
      return null;
    }

    final words = _timingData!.words!;
    if (_currentWordIndex >= words.length) {
      return null;
    }

    final word = words[_currentWordIndex];
    return CharacterBoundaries(
      start: word.charStart,
      end: word.charEnd,
    );
  }

  /// Get character boundaries for current sentence
  CharacterBoundaries? getCurrentSentenceBoundaries() {
    if (_currentSentenceIndex < 0 || _timingData?.sentences == null) {
      return null;
    }

    final sentences = _timingData!.sentences!;
    if (_currentSentenceIndex >= sentences.length) {
      return null;
    }

    final sentence = sentences[_currentSentenceIndex];
    return CharacterBoundaries(
      start: sentence.charStart,
      end: sentence.charEnd,
    );
  }

  /// Check if timing data has valid character positions
  bool hasValidCharacterPositions() {
    if (_timingData == null) return false;

    // Check words
    if (_timingData!.words != null) {
      for (final word in _timingData!.words!) {
        if (word.charStart < 0 || word.charEnd < 0) {
          return false;
        }
      }
    }

    // Check sentences
    if (_timingData!.sentences != null) {
      for (final sentence in _timingData!.sentences!) {
        if (sentence.charStart < 0 || sentence.charEnd < 0) {
          return false;
        }
      }
    }

    return true;
  }

  /// Reset indices
  void reset() {
    _currentWordIndex = -1;
    _currentSentenceIndex = -1;
  }

  /// Dispose resources
  void dispose() {
    _timingData = null;
    reset();
  }
}

/// Character boundaries for highlighting
class CharacterBoundaries {
  final int start;
  final int end;

  CharacterBoundaries({
    required this.start,
    required this.end,
  });

  bool get isValid => start >= 0 && end >= 0 && end >= start;
}