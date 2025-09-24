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
import 'optimized_highlight_painter.dart';

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

  // Use ValueNotifier for efficient rebuilds - only CustomPaint rebuilds, not whole tree
  final ValueNotifier<int> _wordIndexNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<int> _sentenceIndexNotifier = ValueNotifier<int>(-1);

  StreamSubscription<int>? _wordSubscription;
  StreamSubscription<int>? _sentenceSubscription;

  // Auto-scroll debouncing to reduce scroll animations during playback
  Timer? _scrollDebounceTimer;
  int _pendingScrollWordIndex = -1;

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
    // Use ValueNotifier to avoid full widget rebuilds
    _wordSubscription = _timingService.currentWordStream.listen((wordIndex) {
      if (mounted && wordIndex != _wordIndexNotifier.value) {
        // Only log significant changes (not every word)
        if ((wordIndex - _wordIndexNotifier.value).abs() > 5 || wordIndex % 10 == 0) {
          AppLogger.info('🎨 WIDGET: Word index update received', {
            'oldIndex': _wordIndexNotifier.value,
            'newIndex': wordIndex,
          });
        }
        _wordIndexNotifier.value = wordIndex;
        _autoScrollDebounced(wordIndex);
      }
    });

    _sentenceSubscription =
        _timingService.currentSentenceStream.listen((sentenceIndex) {
      if (mounted && sentenceIndex != _sentenceIndexNotifier.value) {
        // Only rebuild CustomPaint, not entire widget
        AppLogger.info('🎨 WIDGET: Sentence index update received', {
          'oldIndex': _sentenceIndexNotifier.value,
          'newIndex': sentenceIndex,
        });
        _sentenceIndexNotifier.value = sentenceIndex;
      }
    });
  }

  Future<void> _loadTimings() async {
    try {
      // Get cached timings or fetch if needed
      var timings = _timingService.getCachedTimings(widget.contentId);
      if (timings == null || timings.isEmpty) {
        timings =
            await _timingService.fetchTimings(widget.contentId, widget.text);
      }

      if (mounted && timings.isNotEmpty) {
        final nonNullTimings = timings; // Create non-nullable local variable
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

  // Debounced auto-scroll to reduce scroll animations during rapid word changes
  void _autoScrollDebounced(int wordIndex) {
    // Cancel any pending scroll
    _scrollDebounceTimer?.cancel();
    _pendingScrollWordIndex = wordIndex;

    // Wait 150ms before scrolling to let playback stabilize
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted && _pendingScrollWordIndex >= 0) {
        _autoScroll(_pendingScrollWordIndex);
      }
    });
  }

  void _autoScroll(int wordIndex) {
    if (widget.scrollController == null ||
        wordIndex < 0 ||
        _timingCollection == null ||
        _textPainter.text == null) {
      return;
    }

    final scrollController = widget.scrollController!;

    // Ensure we have a valid position
    if (!scrollController.hasClients ||
        !scrollController.position.hasContentDimensions) {
      return;
    }

    final viewportHeight = scrollController.position.viewportDimension;

    // Get text boxes for the specified word
    final boxes = _getWordBoxes(wordIndex);
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

    // Use cached implementation consistent with OptimizedHighlightPainter
    return _getCachedTextBoxes(start, end);
  }

  // Get cached TextBoxes for a selection (mirror of OptimizedHighlightPainter method)
  List<TextBox> _getCachedTextBoxes(int start, int end) {
    final cacheKey = '${widget.text.hashCode}_${widget.baseStyle.fontSize?.hashCode ?? 0}_${start}_$end';

    if (OptimizedHighlightPainter.textBoxCache.containsKey(cacheKey)) {
      return OptimizedHighlightPainter.textBoxCache[cacheKey]!;
    }

    final boxes = _textPainter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );

    // Use the same cache as OptimizedHighlightPainter
    if (OptimizedHighlightPainter.textBoxCache.length >= OptimizedHighlightPainter.maxCacheSize) {
      final oldestKey = OptimizedHighlightPainter.textBoxCache.keys.first;
      OptimizedHighlightPainter.textBoxCache.remove(oldestKey);
    }

    OptimizedHighlightPainter.textBoxCache[cacheKey] = boxes;
    return boxes;
  }

  // Calculate appropriate scroll duration based on distance
  Duration _calculateScrollDuration(double distance) {
    // Shorter durations for snappier response (100-200ms)
    // Scale based on distance for natural feeling
    final milliseconds = (100 + (distance / 20)).clamp(100, 200).toInt();
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
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
        final sentenceColor =
            widget.sentenceHighlightColor ?? theme.sentenceHighlight;
        final wordColor = widget.wordHighlightColor ?? theme.wordHighlight;

        // Use ValueListenableBuilder to rebuild only CustomPaint, not whole tree
        return RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _wordIndexNotifier,
            builder: (context, wordIndex, child) {
              return ValueListenableBuilder<int>(
                valueListenable: _sentenceIndexNotifier,
                builder: (context, sentenceIndex, _) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, _textPainter.height),
                    painter: OptimizedHighlightPainter(
                      text: widget.text,
                      textPainter: _textPainter,
                      timingCollection: _timingCollection!,
                      currentWordIndex: wordIndex,
                      currentSentenceIndex: sentenceIndex,
                      baseStyle: widget.baseStyle,
                      sentenceHighlightColor: sentenceColor,
                      wordHighlightColor: wordColor,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _updateTextPainter(double maxWidth) {
    // Clear TextBox cache when text or font changes to ensure accuracy
    OptimizedHighlightPainter.clearTextBoxCache();

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
    return _timingCollection!.timings
        .every((timing) => timing.charStart != null && timing.charEnd != null);
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _wordSubscription?.cancel();
    _sentenceSubscription?.cancel();
    _wordIndexNotifier.dispose();
    _sentenceIndexNotifier.dispose();
    _textPainter.dispose();
    super.dispose();
  }
}


/// Performance validation for the simplified widget
Future<void> validateSimplifiedHighlighting() async {
  final stopwatch = Stopwatch()..start();

  AppLogger.info('Validating simplified dual-level highlighting');

  // Test binary search performance
  final testTimings = List.generate(
      1000,
      (i) => WordTiming(
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
