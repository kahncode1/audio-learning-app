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
import '../services/word_timing_service_simplified.dart';
import '../models/word_timing.dart';
import '../utils/app_logger.dart';
import '../theme/app_theme.dart';

/// Simplified widget for dual-level highlighting with optimal performance
class SimplifiedDualLevelHighlightedText extends ConsumerStatefulWidget {
  final String text;
  final String contentId;
  final TextStyle baseStyle;
  final Color? sentenceHighlightColor;
  final Color? wordHighlightColor;
  final ScrollController? scrollController;

  /// Average number of characters per line for scroll estimation
  /// This can be overridden based on actual font metrics
  static const double defaultCharsPerLine = 40.0;

  const SimplifiedDualLevelHighlightedText({
    super.key,
    required this.text,
    required this.contentId,
    required this.baseStyle,
    this.sentenceHighlightColor,
    this.wordHighlightColor,
    this.scrollController,
  });

  @override
  ConsumerState<SimplifiedDualLevelHighlightedText> createState() =>
      _SimplifiedDualLevelHighlightedTextState();
}

class _SimplifiedDualLevelHighlightedTextState
    extends ConsumerState<SimplifiedDualLevelHighlightedText> {
  // Minimal state - let WordTimingService handle complexity
  late final WordTimingServiceSimplified _timingService;
  WordTimingCollection? _timingCollection;
  int _currentWordIndex = -1;
  int _currentSentenceIndex = -1;
  StreamSubscription<int>? _wordSubscription;
  StreamSubscription<int>? _sentenceSubscription;

  // Track seeks to force complete repaint for a fixed duration
  // Using a fixed window that doesn't extend prevents cascading effects
  DateTime? _seekWindowStartTime;

  // Single TextPainter instance for efficiency
  late TextPainter _textPainter;
  Size? _lastLayoutSize;

  @override
  void initState() {
    super.initState();
    _timingService = WordTimingServiceSimplified.instance;
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
      if (mounted && wordIndex != _currentWordIndex) {
        // Detect large jumps (seeks/fast-forward)
        // A jump of more than 50 words indicates a seek operation
        if (_currentWordIndex >= 0 && (wordIndex - _currentWordIndex).abs() > 50) {
          // Only set the window start time if we're not already in a seek window
          // This prevents extending the window on rapid consecutive seeks
          if (_seekWindowStartTime == null ||
              DateTime.now().difference(_seekWindowStartTime!).inMilliseconds > 500) {
            _seekWindowStartTime = DateTime.now();
            AppLogger.info('🎨 WIDGET: Seek window opened', {
              'oldIndex': _currentWordIndex,
              'newIndex': wordIndex,
              'jumpDistance': (wordIndex - _currentWordIndex).abs(),
            });
          } else {
            AppLogger.info('🎨 WIDGET: Additional seek in active window', {
              'oldIndex': _currentWordIndex,
              'newIndex': wordIndex,
              'windowAge': DateTime.now().difference(_seekWindowStartTime!).inMilliseconds,
            });
          }
        }

        AppLogger.info('🎨 WIDGET: Word index update received', {
          'oldIndex': _currentWordIndex,
          'newIndex': wordIndex,
        });
        setState(() => _currentWordIndex = wordIndex);
        _autoScroll();
      }
    });

    _sentenceSubscription = _timingService.currentSentenceStream.listen((sentenceIndex) {
      if (mounted && sentenceIndex != _currentSentenceIndex) {
        AppLogger.info('🎨 WIDGET: Sentence index update received', {
          'oldIndex': _currentSentenceIndex,
          'newIndex': sentenceIndex,
        });
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

      if (mounted && timings.isNotEmpty) {
        final nonNullTimings = timings;  // Create non-nullable local variable
        AppLogger.info('🎨 WIDGET: Timing data loaded', {
          'contentId': widget.contentId,
          'wordCount': nonNullTimings.length,
          'firstWord': nonNullTimings.first.word,
          'lastWord': nonNullTimings.last.word,
        });
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
        _timingCollection == null ||
        _textPainter.text == null) {
      return;
    }

    final scrollController = widget.scrollController!;

    // Ensure we have a valid position
    if (!scrollController.hasClients || !scrollController.position.hasContentDimensions) {
      return;
    }

    final viewportHeight = scrollController.position.viewportDimension;

    // Get text boxes for the current word
    final boxes = _getWordBoxes(_currentWordIndex);
    if (boxes.isEmpty) return;

    // Use the first box (words rarely span multiple lines)
    final wordRect = boxes.first;
    final wordTop = wordRect.top;
    final wordBottom = wordRect.bottom;

    // Define the reading zone (20-40% from top)
    // This keeps the highlighted text consistently in the upper-middle portion
    final readingZoneTop = viewportHeight * 0.20;
    final readingZoneBottom = viewportHeight * 0.40;

    // Get current scroll offset
    final currentOffset = scrollController.offset;

    // Calculate word's position in viewport
    final wordViewportTop = wordTop - currentOffset;
    final wordViewportBottom = wordBottom - currentOffset;

    // Determine if scrolling is needed
    bool needsScroll = false;
    double targetOffset = currentOffset;

    if (wordViewportTop < readingZoneTop) {
      // Word is too high - scroll up to bring it into zone
      needsScroll = true;
      targetOffset = wordTop - readingZoneTop;
    } else if (wordViewportBottom > readingZoneBottom) {
      // Word is getting too low - scroll down immediately to keep it in zone
      // This triggers scroll as soon as word exits the 40% mark
      needsScroll = true;
      targetOffset = wordTop - readingZoneTop;
    }

    // Handle edge cases
    if (targetOffset < 0) {
      targetOffset = 0;
    } else if (targetOffset > scrollController.position.maxScrollExtent) {
      targetOffset = scrollController.position.maxScrollExtent;
    }

    // Perform smooth scroll if needed
    if (needsScroll && (targetOffset - currentOffset).abs() > 5) {
      // Only scroll if the difference is significant (>5 pixels)
      final distance = (targetOffset - currentOffset).abs();
      final duration = _calculateScrollDuration(distance);

      scrollController.animateTo(
        targetOffset,
        duration: duration,
        curve: Curves.easeOutCubic, // Natural deceleration
      );
    }
  }

  // Get actual text boxes for a word using TextPainter
  List<TextBox> _getWordBoxes(int wordIndex) {
    if (wordIndex < 0 || wordIndex >= _timingCollection!.timings.length) {
      return [];
    }

    final word = _timingCollection!.timings[wordIndex];
    if (word.charStart == null) return [];

    // Use the same logic as OptimizedHighlightPainter for consistency
    final textLen = widget.text.length;
    int start = (word.charStart ?? 0).clamp(0, textLen);
    int length = word.word.length;
    int end = (start + length).clamp(0, textLen);

    // Adjust for API inconsistencies if needed
    if (word.charEnd != null) {
      final apiEnd = word.charEnd!.clamp(0, textLen);
      if (apiEnd > start && apiEnd <= textLen) {
        end = apiEnd;
      }
    }

    return _textPainter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
  }

  // Calculate appropriate scroll duration based on distance
  Duration _calculateScrollDuration(double distance) {
    // Minimum 150ms, maximum 300ms for faster response
    // Scale based on distance for natural feeling
    final milliseconds = (150 + (distance / 15)).clamp(150, 300).toInt();
    return Duration(milliseconds: milliseconds);
  }

  @override
  void didUpdateWidget(SimplifiedDualLevelHighlightedText oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the base style (specifically font size) has changed
    if (oldWidget.baseStyle.fontSize != widget.baseStyle.fontSize ||
        oldWidget.baseStyle != widget.baseStyle) {
      // Update the text painter with the new style
      if (_lastLayoutSize != null) {
        _updateTextPainter(_lastLayoutSize!.width);
      }
    }

    // Also check if text content has changed
    if (oldWidget.text != widget.text) {
      if (_lastLayoutSize != null) {
        _updateTextPainter(_lastLayoutSize!.width);
      }
      _loadTimings(); // Reload timings if text changed
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we have valid character position data
    final hasValidCharPositions = _hasValidCharacterPositions();

    if (_timingCollection == null || !hasValidCharPositions) {
      // Show plain text with status bar when highlighting not available
      // Layout fixed: Using MainAxisSize.min and Flexible instead of Expanded
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
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

        final theme = Theme.of(context);
        final sentenceColor = widget.sentenceHighlightColor ?? theme.sentenceHighlight;
        final wordColor = widget.wordHighlightColor ?? theme.wordHighlight;

        // Check if we're within the fixed seek window (500ms)
        // The window doesn't extend - it's exactly 500ms from when the first seek was detected
        final bool isWithinSeekWindow = _seekWindowStartTime != null &&
            DateTime.now().difference(_seekWindowStartTime!).inMilliseconds < 500;

        return CustomPaint(
          size: Size(constraints.maxWidth, _textPainter.height),
          painter: OptimizedHighlightPainter(
            text: widget.text,
            textPainter: _textPainter,
            timingCollection: _timingCollection!,
            currentWordIndex: _currentWordIndex,
            currentSentenceIndex: _currentSentenceIndex,
            baseStyle: widget.baseStyle,
            sentenceHighlightColor: sentenceColor,
            wordHighlightColor: wordColor,
            justSeeked: isWithinSeekWindow,
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
  final bool justSeeked;

  OptimizedHighlightPainter({
    required this.text,
    required this.textPainter,
    required this.timingCollection,
    required this.currentWordIndex,
    required this.currentSentenceIndex,
    required this.baseStyle,
    required this.sentenceHighlightColor,
    required this.wordHighlightColor,
    this.justSeeked = false,
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
      final (int s, int e) = _getWordSelection(
        timingCollection.timings.indexOf(w),
      );
      startChar = startChar == null ? s : (s < startChar ? s : startChar);
      endExclusive = endExclusive == null ? e : (e > endExclusive ? e : endExclusive);
    }

    final paint = Paint()
      ..color = sentenceHighlightColor
      ..style = PaintingStyle.fill;

    if (startChar != null && endExclusive != null && endExclusive >= startChar) {
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: startChar, extentOffset: endExclusive),
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

    // Get the character positions from the lookup table
    final (int start, int end) = _getWordSelection(wordIndex);

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

  // Get the selection range for a word using direct character positions from the lookup table
  (int, int) _getWordSelection(int wordIndex) {
    final word = timingCollection.timings[wordIndex];
    final textLen = text.length;

    // Use the character positions from our pre-processed lookup table
    // These positions are already validated and correct
    int start = (word.charStart ?? 0).clamp(0, textLen);
    int end = (word.charEnd ?? (start + word.word.length)).clamp(0, textLen);

    return (start, end);
  }

  @override
  bool shouldRepaint(OptimizedHighlightPainter oldDelegate) {
    // Force repaint after seek to clear any visual artifacts
    if (justSeeked) {
      return true;
    }

    // Repaint when highlighting changes or style changes
    return currentWordIndex != oldDelegate.currentWordIndex ||
           currentSentenceIndex != oldDelegate.currentSentenceIndex ||
           text != oldDelegate.text ||
           baseStyle != oldDelegate.baseStyle ||
           baseStyle.fontSize != oldDelegate.baseStyle.fontSize;
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
