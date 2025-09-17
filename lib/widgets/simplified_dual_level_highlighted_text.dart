/// Simplified Dual-Level Highlighted Text Widget
///
/// Purpose: Ultra-simple word and sentence highlighting with 60fps performance
/// Dependencies:
/// - flutter_riverpod: ^2.4.9 (for state management)
/// - ../services/word_timing_service.dart (for timing data)
/// - ../models/word_timing.dart (for timing models)
///
/// Performance Targets:
///   - Binary search: <1ms word lookup (Speechify API shows 549μs achievable)
///   - Paint cycle: <16ms for 60fps
///   - Memory usage: Minimal state with direct service integration
///
/// Architecture:
///   - Three-layer paint system (sentence → word → text)
///   - Single IMMUTABLE TextPainter - never modified during paint
///   - Direct binary search from WordTimingCollection
///   - No text style changes - highlighting via background colors only
///
/// Key Principle: TextPainter is configured once and NEVER modified during paint.
/// All highlighting effects come from colored rectangles painted behind static text.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/word_timing_service.dart';
import '../models/word_timing.dart';
import '../utils/app_logger.dart';

/// Simplified widget for dual-level highlighting with optimal performance
class SimplifiedDualLevelHighlightedText extends ConsumerStatefulWidget {
  final String text;
  final String contentId;
  final TextStyle baseStyle;
  final Color sentenceHighlightColor;
  final Color wordHighlightColor;
  final ScrollController? scrollController;

  /// Average number of characters per line for scroll estimation
  /// This can be overridden based on actual font metrics
  static const double defaultCharsPerLine = 40.0;

  const SimplifiedDualLevelHighlightedText({
    super.key,
    required this.text,
    required this.contentId,
    required this.baseStyle,
    this.sentenceHighlightColor = const Color(0xFFE3F2FD), // Light blue
    this.wordHighlightColor = const Color(0xFFFFF59D), // Yellow
    this.scrollController,
  });

  @override
  ConsumerState<SimplifiedDualLevelHighlightedText> createState() =>
      _SimplifiedDualLevelHighlightedTextState();
}

class _SimplifiedDualLevelHighlightedTextState
    extends ConsumerState<SimplifiedDualLevelHighlightedText> {
  // Minimal state - let WordTimingService handle complexity
  late final WordTimingService _timingService;
  WordTimingCollection? _timingCollection;
  int _currentWordIndex = -1;
  int _currentSentenceIndex = -1;
  StreamSubscription<int>? _wordSubscription;
  StreamSubscription<int>? _sentenceSubscription;

  // Single TextPainter instance for efficiency
  late TextPainter _textPainter;
  Size? _lastLayoutSize;

  @override
  void initState() {
    super.initState();
    _timingService = WordTimingService.instance;
    _initializeTextPainter();
    _setupListeners();
    _loadTimings();
  }

  void _initializeTextPainter() {
    _textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
  }

  void _setupListeners() {
    // Direct stream subscription - WordTimingService handles throttling
    _wordSubscription = _timingService.currentWordStream.listen((wordIndex) {
      if (mounted && wordIndex != null && wordIndex != _currentWordIndex) {
        setState(() => _currentWordIndex = wordIndex);
        _autoScroll();
      }
    });

    _sentenceSubscription = _timingService.currentSentenceStream.listen((sentenceIndex) {
      if (mounted && sentenceIndex != null && sentenceIndex != _currentSentenceIndex) {
        setState(() => _currentSentenceIndex = sentenceIndex);
      }
    });
  }

  Future<void> _loadTimings() async {
    try {
      // Get cached timings or fetch if needed
      var timings = _timingService.getCachedTimings(widget.contentId);
      if (timings == null || timings.isEmpty) {
        timings = await _timingService.fetchTimings(widget.contentId, widget.text);
      }

      if (mounted && timings != null && timings.isNotEmpty) {
        final nonNullTimings = timings;  // Create non-nullable local variable
        setState(() {
          _timingCollection = WordTimingCollection(nonNullTimings);
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load timings', error: e);
    }
  }

  void _autoScroll() {
    if (widget.scrollController == null ||
        _currentWordIndex < 0 ||
        _timingCollection == null) return;

    // Simple scroll to keep current word visible
    final scrollController = widget.scrollController!;
    final viewportHeight = scrollController.position.viewportDimension;

    // Estimate line height and position
    final lineHeight = widget.baseStyle.fontSize! * (widget.baseStyle.height ?? 1.5);
    // Use configurable chars per line for better estimation
    final wordsPerLine = SimplifiedDualLevelHighlightedText.defaultCharsPerLine / 5; // Avg 5 chars per word
    final approximateY = (_currentWordIndex / wordsPerLine) * lineHeight;

    // Center word in viewport
    final targetScroll = approximateY - (viewportHeight / 2);

    if (targetScroll > 0 && targetScroll < scrollController.position.maxScrollExtent) {
      scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we have valid character position data
    final hasValidCharPositions = _hasValidCharacterPositions();

    if (_timingCollection == null || !hasValidCharPositions) {
      // Show plain text with status bar when highlighting not available
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(widget.text, style: widget.baseStyle),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              border: Border(
                top: BorderSide(color: Colors.grey.shade400, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  'Highlighting not available for this content',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Update text painter if size changed
        if (_lastLayoutSize != constraints.biggest) {
          _lastLayoutSize = constraints.biggest;
          _updateTextPainter(constraints.maxWidth);
        }

        return CustomPaint(
          size: Size(constraints.maxWidth, _textPainter.height),
          painter: OptimizedHighlightPainter(
            text: widget.text,
            textPainter: _textPainter,
            timingCollection: _timingCollection!,
            currentWordIndex: _currentWordIndex,
            currentSentenceIndex: _currentSentenceIndex,
            baseStyle: widget.baseStyle,
            sentenceHighlightColor: widget.sentenceHighlightColor,
            wordHighlightColor: widget.wordHighlightColor,
          ),
        );
      },
    );
  }

  void _updateTextPainter(double maxWidth) {
    // Set up the TextPainter once with the full text
    // This will never be modified during paint cycles
    _textPainter.text = TextSpan(text: widget.text, style: widget.baseStyle);
    _textPainter.layout(maxWidth: maxWidth);
  }

  bool _hasValidCharacterPositions() {
    if (_timingCollection == null || _timingCollection!.timings.isEmpty) {
      return false;
    }

    // Check if all word timings have character positions
    return _timingCollection!.timings.every((timing) =>
      timing.charStart != null && timing.charEnd != null
    );
  }

  @override
  void dispose() {
    _wordSubscription?.cancel();
    _sentenceSubscription?.cancel();
    _textPainter.dispose();
    super.dispose();
  }
}

/// Optimized painter using three-layer system with single TextPainter
class OptimizedHighlightPainter extends CustomPainter {
  final String text;
  final TextPainter textPainter;
  final WordTimingCollection timingCollection;
  final int currentWordIndex;
  final int currentSentenceIndex;
  final TextStyle baseStyle;
  final Color sentenceHighlightColor;
  final Color wordHighlightColor;

  OptimizedHighlightPainter({
    required this.text,
    required this.textPainter,
    required this.timingCollection,
    required this.currentWordIndex,
    required this.currentSentenceIndex,
    required this.baseStyle,
    required this.sentenceHighlightColor,
    required this.wordHighlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Three-layer paint system for optimal visual hierarchy

    // Layer 1: Sentence background highlight
    if (currentSentenceIndex >= 0) {
      _paintSentenceHighlight(canvas);
    }

    // Layer 2: Current word highlight
    if (currentWordIndex >= 0 && currentWordIndex < timingCollection.timings.length) {
      _paintWordHighlight(canvas);
    }

    // Layer 3: Text content
    _paintText(canvas);
  }

  void _paintSentenceHighlight(Canvas canvas) {
    final sentenceWords = timingCollection.getWordsInSentence(currentSentenceIndex);
    if (sentenceWords.isEmpty) return;

    // Prefer a continuous highlight using a single selection range per line.
    // Compute the character range for the entire sentence (end is exclusive).
    int? startChar;
    int? endExclusive;
    for (int i = 0; i < sentenceWords.length; i++) {
      final w = sentenceWords[i];
      if (w.charStart == null) continue;
      final (int s, int e) = _computeSelectionForWord(
        timingCollection.timings.indexOf(w),
      );
      startChar = startChar == null ? s : (s < startChar! ? s : startChar);
      endExclusive = endExclusive == null ? e : (e > endExclusive! ? e : endExclusive);
    }

    final paint = Paint()
      ..color = sentenceHighlightColor
      ..style = PaintingStyle.fill;

    if (startChar != null && endExclusive != null && endExclusive! >= startChar!) {
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: startChar!, extentOffset: endExclusive!),
      );

      for (final box in boxes) {
        final rect = Rect.fromLTRB(box.left, box.top, box.right, box.bottom).inflate(1);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      }
    } else {
      // Fallback: per-word rectangles (rare; when char positions are missing)
      for (final word in sentenceWords) {
        final wordIndex = timingCollection.timings.indexOf(word);
        if (wordIndex >= 0) {
          final rect = _getWordRect(wordIndex);
          if (rect != null) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(2)),
              paint,
            );
          }
        }
      }
    }
  }

  void _paintWordHighlight(Canvas canvas) {
    final rect = _getWordRect(currentWordIndex);
    if (rect == null) return;

    final paint = Paint()
      ..color = wordHighlightColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(1), const Radius.circular(2)),
      paint,
    );
  }

  void _paintText(Canvas canvas) {
    // Ultra-simple: just paint the pre-configured TextPainter
    // NO modifications, NO layout calls, NO text changes
    // The highlighting effect comes from the colored rectangles behind the text
    textPainter.paint(canvas, Offset.zero);
  }

  Rect? _getWordRect(int wordIndex) {
    if (wordIndex < 0 || wordIndex >= timingCollection.timings.length) return null;

    final word = timingCollection.timings[wordIndex];
    // If we have no character positions from API, we cannot draw a precise
    // rectangle. Return null to skip highlighting for this word.
    if (word.charStart == null) {
      return null;
    }

    // Compute a robust selection range that tolerates off-by-one differences
    // between API character offsets and the displayed text. This corrects the
    // common case where highlights appear shifted one character to the right.
    final (int start, int end) = _computeSelectionForWord(wordIndex);

    // Use TextPainter to obtain the bounding box for the computed range
    final boxes = textPainter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );

    if (boxes.isNotEmpty) {
      double left = boxes.first.left;
      double top = boxes.first.top;
      double right = boxes.first.right;
      double bottom = boxes.first.bottom;

      for (final b in boxes) {
        if (b.left < left) left = b.left;
        if (b.top < top) top = b.top;
        if (b.right > right) right = b.right;
        if (b.bottom > bottom) bottom = b.bottom;
      }

      return Rect.fromLTRB(left, top, right, bottom);
    }

    return null;
  }

  // Check whether the given word matches the text starting at offset.
  bool _matchesAt(String source, String word, int offset) {
    if (offset < 0 || offset >= source.length) return false;
    final end = offset + word.length;
    if (end > source.length) return false;
    return source.substring(offset, end) == word;
  }

  // Computes a corrected [start, endExclusive] selection for a word, using the
  // API-provided charStart/charEnd as hints but verifying against the actual
  // displayed text. This fixes 0/1-based index mismatches and minor drifts.
  (int, int) _computeSelectionForWord(int wordIndex) {
    final word = timingCollection.timings[wordIndex];
    final textLen = text.length;

    // Start with API-provided start and length derived from the word value.
    int start = (word.charStart ?? 0).clamp(0, textLen);
    int length = word.word.length;
    int end = (start + length).clamp(0, textLen);

    // Fast-path: if it already matches at start, keep it.
    if (_matchesAt(text, word.word, start)) {
      return (start, end);
    }

    // If API provided an end offset, try to honor it as either exclusive or
    // inclusive. This addresses engines that report inclusive `end`.
    if (word.charEnd != null) {
      final apiEnd = word.charEnd!.clamp(0, textLen);
      // Treat as exclusive first
      if (apiEnd > start) {
        final candidateEnd = apiEnd;
        final slice = text.substring(start, candidateEnd);
        if (slice == word.word) {
          return (start, candidateEnd);
        }
      }
      // Treat as inclusive (add 1) if in bounds
      if (apiEnd + 1 <= textLen) {
        final candidateEnd = apiEnd + 1;
        final slice = text.substring(start, candidateEnd);
        if (slice == word.word) {
          return (start, candidateEnd);
        }
      }
    }

    // Try shifting left by 1 (common when API uses 1-based indexing)
    if (start - 1 >= 0 && _matchesAt(text, word.word, start - 1)) {
      start = start - 1;
      end = (start + length).clamp(0, textLen);
      return (start, end);
    }

    // Try shifting right by 1
    if (start + 1 < textLen && _matchesAt(text, word.word, start + 1)) {
      start = start + 1;
      end = (start + length).clamp(0, textLen);
      return (start, end);
    }

    // Broader search within a small window around the hint to handle minor
    // discrepancies (e.g., unexpected punctuation or whitespace).
    final windowStart = (start - 5).clamp(0, textLen);
    final idx = text.indexOf(word.word, windowStart);
    if (idx != -1 && (idx - start).abs() <= 5) {
      start = idx;
      end = (start + length).clamp(0, textLen);
      return (start, end);
    }

    // Fallback: Use API-provided end if available, clamped to bounds.
    final apiEnd = (word.charEnd ?? end).clamp(0, textLen);
    return (start, apiEnd);
  }

  @override
  bool shouldRepaint(OptimizedHighlightPainter oldDelegate) {
    // Only repaint when highlighting changes
    return currentWordIndex != oldDelegate.currentWordIndex ||
           currentSentenceIndex != oldDelegate.currentSentenceIndex ||
           text != oldDelegate.text;
  }
}

/// Performance validation for the simplified widget
Future<void> validateSimplifiedHighlighting() async {
  final stopwatch = Stopwatch()..start();

  AppLogger.info('Validating simplified dual-level highlighting');

  // Test binary search performance
  final testTimings = List.generate(1000, (i) => WordTiming(
    word: 'word$i',
    startMs: i * 100,
    endMs: (i + 1) * 100,
    sentenceIndex: i ~/ 10,
  ));

  final collection = WordTimingCollection(testTimings);

  // Benchmark binary search
  final searchStopwatch = Stopwatch()..start();
  for (int i = 0; i < 1000; i++) {
    collection.findActiveWordIndex(i * 50);
  }
  searchStopwatch.stop();

  assert(searchStopwatch.elapsedMicroseconds < 1000,
    'Binary search should complete 1000 searches in <1ms, took ${searchStopwatch.elapsedMicroseconds}μs');

  AppLogger.performance('Binary search performance', {
    'searches': 1000,
    'duration': '${searchStopwatch.elapsedMicroseconds}μs',
    'perSearch': '${searchStopwatch.elapsedMicroseconds / 1000}μs',
  });

  stopwatch.stop();
  AppLogger.info('Simplified highlighting validation complete', {
    'totalDuration': '${stopwatch.elapsedMilliseconds}ms',
  });
}
