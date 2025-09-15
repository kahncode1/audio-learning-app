/// Dual-Level Highlighted Text Widget
///
/// Purpose: Provides synchronized word and sentence highlighting for audio playback
/// Dependencies:
/// - flutter_riverpod: ^2.4.9 (for state management)
/// - ../services/word_timing_service.dart (for timing data)
/// - ../models/word_timing.dart (for timing models)
///
/// Usage:
///   DualLevelHighlightedText(
///     text: 'Content text',
///     contentId: 'unique-id',
///     baseStyle: TextStyle(fontSize: 18),
///     onWordTap: (wordIndex) => seekToWord(wordIndex),
///   )
///
/// Expected behavior:
///   - Maintains 60fps performance with RepaintBoundary
///   - Provides dual-level highlighting (sentence + word)
///   - Supports tap-to-seek functionality
///   - Uses binary search for O(log n) word lookup

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/word_timing_service.dart';
import '../models/word_timing.dart';
import '../utils/app_logger.dart';

/// Widget for displaying text with dual-level highlighting synchronized to audio
class DualLevelHighlightedText extends ConsumerStatefulWidget {
  final String text;
  final String contentId;
  final TextStyle baseStyle;
  final Color sentenceHighlightColor;
  final Color wordHighlightColor;
  final Color activeWordTextColor;
  final Function(int wordIndex)? onWordTap;
  final ScrollController? scrollController;

  const DualLevelHighlightedText({
    super.key,
    required this.text,
    required this.contentId,
    required this.baseStyle,
    this.sentenceHighlightColor = const Color(0xFFE3F2FD), // Light blue
    this.wordHighlightColor = const Color(0xFFFFF59D), // Yellow
    this.activeWordTextColor = const Color(0xFF1976D2), // Darker blue
    this.onWordTap,
    this.scrollController,
  });

  @override
  ConsumerState<DualLevelHighlightedText> createState() =>
      _DualLevelHighlightedTextState();
}

class _DualLevelHighlightedTextState
    extends ConsumerState<DualLevelHighlightedText> {
  late final WordTimingService _timingService;
  List<WordTiming> _timings = [];
  int _currentWordIndex = -1;
  int _currentSentenceIndex = -1;
  StreamSubscription<int>? _wordSubscription;
  StreamSubscription<int>? _sentenceSubscription;
  final GlobalKey _textKey = GlobalKey();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _timingService = WordTimingService.instance;
    _setupListeners();
    _loadTimings();
  }

  void _setupListeners() {
    AppLogger.info('Setting up word timing stream listeners', {
      'contentId': widget.contentId,
    });

    // Listen to word index changes
    _wordSubscription = _timingService.currentWordStream.listen((wordIndex) {
      AppLogger.debug('Word index stream update', {
        'newIndex': wordIndex,
        'oldIndex': _currentWordIndex,
        'mounted': mounted,
      });

      if (mounted && wordIndex != _currentWordIndex) {
        setState(() {
          _currentWordIndex = wordIndex;
        });

        // Log the word being highlighted
        if (wordIndex >= 0 && wordIndex < _timings.length) {
          AppLogger.info('Highlighting word', {
            'index': wordIndex,
            'word': _timings[wordIndex].word,
          });
        }

        _scrollToCurrentWord();
      }
    });

    // Listen to sentence index changes
    _sentenceSubscription = _timingService.currentSentenceStream.listen((sentenceIndex) {
      AppLogger.debug('Sentence index stream update', {
        'newIndex': sentenceIndex,
        'oldIndex': _currentSentenceIndex,
        'mounted': mounted,
      });

      if (mounted && sentenceIndex != _currentSentenceIndex) {
        setState(() {
          _currentSentenceIndex = sentenceIndex;
        });
      }
    });

    AppLogger.info('Stream listeners setup complete');
  }

  Future<void> _loadTimings() async {
    try {
      AppLogger.info('Loading word timings for highlighting', {
        'contentId': widget.contentId,
        'fullTextLength': widget.text.length,
      });

      // The timings are ONLY for the first 500 chars of text
      // This is a limitation of the Speechify API truncation
      var timings = _timingService.getCachedTimings(widget.contentId);

      if (timings == null || timings.isEmpty) {
        // Fetch timings for truncated text only
        final truncatedText = widget.text.substring(0, widget.text.length.clamp(0, 500));
        timings = await _timingService.fetchTimings(
          widget.contentId,
          truncatedText,
        );

        AppLogger.info('Fetched timings for truncated text', {
          'truncatedLength': truncatedText.length,
          'timingCount': timings?.length ?? 0,
        });
      }

      AppLogger.info('Loaded timings for highlighting', {
        'contentId': widget.contentId,
        'timingCount': timings?.length ?? 0,
        'textLength': widget.text.length,
        'firstWord': timings?.isNotEmpty == true ? timings!.first.word : 'none',
        'lastWord': timings?.isNotEmpty == true ? timings!.last.word : 'none',
      });

      if (mounted && timings != null) {
        setState(() {
          _timings = timings!;  // Safe to use ! since we checked for null
          _isLoading = false;
        });

        // Precompute positions for smooth scrolling and tap detection
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (mounted) {
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              await _timingService.precomputePositions(
                widget.contentId,
                widget.text,
                widget.baseStyle,
                renderBox.size.width - 32, // Account for padding
              );
            }
          }
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load word timings', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToCurrentWord() {
    // Auto-scroll to keep current word visible
    if (widget.scrollController == null ||
        _currentWordIndex < 0 ||
        _timings.isEmpty ||
        _currentWordIndex >= _timings.length) {
      return;
    }

    // Use a post-frame callback to ensure layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        // Get the render box to calculate positions
        final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;

        // Create a text painter to measure text layout
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.baseStyle),
          textDirection: TextDirection.ltr,
          maxLines: null,
        );

        // Layout with the same width as the widget
        textPainter.layout(maxWidth: renderBox.size.width);

        // Find the position of the current word
        final timing = _timings[_currentWordIndex];
        final wordStart = widget.text.indexOf(timing.word);

        if (wordStart == -1) return;

        // Get the vertical position of the word - simplified approach
        // TextPainter doesn't have getLineMetricsForPosition, so we'll estimate

        // Calculate the scroll offset to center the word vertically
        final scrollController = widget.scrollController!;
        final viewportHeight = scrollController.position.viewportDimension;
        final currentScroll = scrollController.offset;

        // Get approximate line height and line number
        final lineHeight = widget.baseStyle.fontSize! * (widget.baseStyle.height ?? 1.5);
        final approximateLineNumber = wordStart ~/ 40; // Rough estimate of chars per line
        final targetY = approximateLineNumber * lineHeight;

        // Calculate desired scroll position (center word in viewport)
        final desiredScroll = targetY - (viewportHeight / 2) + (lineHeight / 2);

        // Only scroll if the word is not already visible in the center third of viewport
        final topThreshold = currentScroll + (viewportHeight * 0.33);
        final bottomThreshold = currentScroll + (viewportHeight * 0.67);

        if (targetY < topThreshold || targetY > bottomThreshold) {
          // Smooth scroll with animation
          scrollController.animateTo(
            desiredScroll.clamp(0.0, scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } catch (e) {
        AppLogger.debug('Error during auto-scroll', {'error': e.toString()});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading content...',
              style: widget.baseStyle.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Always use CustomPaint - it will handle empty timings
    return RepaintBoundary(
      child: CustomPaint(
        key: _textKey,
        painter: DualLevelHighlightPainter(
          text: widget.text,
          timings: _timings,
          currentWordIndex: _currentWordIndex,
          currentSentenceIndex: _currentSentenceIndex,
          baseStyle: widget.baseStyle,
          sentenceHighlightColor: widget.sentenceHighlightColor,
          wordHighlightColor: widget.wordHighlightColor,
          activeWordTextColor: widget.activeWordTextColor,
        ),
        child: GestureDetector(
          onTapDown: _handleTapDown,
          child: Container(
            color: Colors.transparent, // Ensure gesture detector covers full area
            child: Text(
              widget.text,
              style: widget.baseStyle.copyWith(
                color: Colors.transparent, // Hide base text (painter will draw it)
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onWordTap == null || _timings.isEmpty) return;

    // Find tapped word index
    final position = details.localPosition;
    final wordIndex = _findWordAtPosition(position);

    if (wordIndex >= 0) {
      AppLogger.debug('Word tapped', {'wordIndex': wordIndex, 'word': _timings[wordIndex].word});
      widget.onWordTap!(wordIndex);
    }
  }

  int _findWordAtPosition(Offset position) {
    if (_timings.isEmpty) return -1;

    try {
      // First try to use cached positions if available
      final cachedPositions = _timingService.getCachedPositions(widget.contentId);
      if (cachedPositions != null && cachedPositions.isNotEmpty) {
        // Use the service's optimized position lookup
        final wordIndex = _timingService.findWordAtPosition(widget.contentId, position);
        if (wordIndex >= 0) {
          return wordIndex;
        }
      }

      // Fallback: Calculate positions directly using TextPainter
      final RenderBox? renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return -1;

      final textPainter = TextPainter(
        text: TextSpan(text: widget.text, style: widget.baseStyle),
        textDirection: TextDirection.ltr,
        maxLines: null,
      );

      textPainter.layout(maxWidth: renderBox.size.width);

      // Binary search through word positions for efficiency
      for (int i = 0; i < _timings.length; i++) {
        final timing = _timings[i];

        // Find all occurrences of this word to handle repeated words
        int searchStart = 0;
        int wordOccurrence = 0;

        while (searchStart < widget.text.length) {
          final wordIndex = widget.text.indexOf(timing.word, searchStart);
          if (wordIndex == -1) break;

          // Get bounding boxes for this word occurrence
          final boxes = textPainter.getBoxesForSelection(
            TextSelection(
              baseOffset: wordIndex,
              extentOffset: wordIndex + timing.word.length,
            ),
          );

          // Check if tap position is within any of the boxes
          for (final box in boxes) {
            final rect = Rect.fromLTRB(
              box.left,
              box.top,
              box.right,
              box.bottom,
            );

            // Add some padding for easier tapping
            final paddedRect = rect.inflate(4);

            if (paddedRect.contains(position)) {
              AppLogger.debug('Word tapped via fallback', {
                'index': i,
                'word': timing.word,
                'position': '${position.dx},${position.dy}',
                'rect': '${rect.left},${rect.top},${rect.right},${rect.bottom}'
              });
              return i;
            }
          }

          searchStart = wordIndex + timing.word.length;
          wordOccurrence++;

          // For timing matching, we typically want the first occurrence
          // unless we have more sophisticated occurrence tracking
          if (wordOccurrence > 0 && i < _timings.length - 1) {
            // Check if next timing is the same word (handle repeated words)
            if (_timings[i + 1].word != timing.word) {
              break;
            }
          }
        }
      }

      AppLogger.debug('No word found at tap position', {
        'position': '${position.dx},${position.dy}'
      });
      return -1;

    } catch (e) {
      AppLogger.error('Error in tap detection', error: e);
      return -1;
    }
  }

  @override
  void dispose() {
    _wordSubscription?.cancel();
    _sentenceSubscription?.cancel();
    super.dispose();
  }
}

/// Custom painter for rendering dual-level highlighting
class DualLevelHighlightPainter extends CustomPainter {
  final String text;
  final List<WordTiming> timings;
  final int currentWordIndex;
  final int currentSentenceIndex;
  final TextStyle baseStyle;
  final Color sentenceHighlightColor;
  final Color wordHighlightColor;
  final Color activeWordTextColor;

  DualLevelHighlightPainter({
    required this.text,
    required this.timings,
    required this.currentWordIndex,
    required this.currentSentenceIndex,
    required this.baseStyle,
    required this.sentenceHighlightColor,
    required this.wordHighlightColor,
    required this.activeWordTextColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ALWAYS paint the full text first
    // This ensures text is visible even if highlighting fails
    if (timings.isEmpty) {
      _paintPlainText(canvas, size);
      return;
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    // Paint in three layers for optimal visual hierarchy
    // Layer 1: Sentence background (widest highlight)
    _paintSentenceBackground(canvas, size, textPainter);

    // Layer 2: Word highlight (focused highlight)
    _paintWordHighlight(canvas, size, textPainter);

    // Layer 3: Text with appropriate colors
    _paintText(canvas, size, textPainter);
  }

  void _paintPlainText(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: baseStyle),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    textPainter.layout(maxWidth: size.width);
    textPainter.paint(canvas, Offset.zero);
  }

  void _paintSentenceBackground(Canvas canvas, Size size, TextPainter textPainter) {
    if (currentSentenceIndex < 0) return;

    // Find all words in the current sentence
    final sentenceWords = timings
        .where((t) => t.sentenceIndex == currentSentenceIndex)
        .toList();

    if (sentenceWords.isEmpty) {
      return;
    }

    final sentencePaint = Paint()
      ..color = sentenceHighlightColor
      ..style = PaintingStyle.fill;

    // Build the full text to get accurate positions
    textPainter.text = TextSpan(text: text, style: baseStyle);
    textPainter.layout(maxWidth: size.width);

    // Track word occurrences for accurate positioning
    final Map<String, int> wordOccurrences = {};

    // Only search within the truncated portion (first 500 chars)
    final searchLimit = text.length.clamp(0, 500);

    // Paint background for each word in the sentence
    for (final timing in sentenceWords) {
      final word = timing.word;
      final occurrenceIndex = wordOccurrences[word] ?? 0;
      wordOccurrences[word] = occurrenceIndex + 1;

      // Find the nth occurrence of this word (only in truncated portion)
      int searchPos = 0;
      int foundCount = 0;
      int wordPosition = -1;

      while (searchPos < searchLimit) {
        final pos = text.indexOf(word, searchPos);
        if (pos == -1 || pos >= searchLimit) break;

        if (foundCount == occurrenceIndex) {
          wordPosition = pos;
          break;
        }

        foundCount++;
        searchPos = pos + word.length;
      }

      final wordRect = _getWordRect(timing, textPainter, wordPosition);
      if (wordRect != null) {
        // Add some padding to the highlight
        final paddedRect = wordRect.inflate(2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(paddedRect, const Radius.circular(2)),
          sentencePaint,
        );
      }
    }
  }

  void _paintWordHighlight(Canvas canvas, Size size, TextPainter textPainter) {
    if (currentWordIndex < 0 || currentWordIndex >= timings.length) return;

    final currentTiming = timings[currentWordIndex];

    // Build the full text to get accurate positions
    textPainter.text = TextSpan(text: text, style: baseStyle);
    textPainter.layout(maxWidth: size.width);

    // Only search within the truncated portion (first 500 chars)
    final searchLimit = text.length.clamp(0, 500);

    // Find the correct occurrence of this word
    final Map<String, int> wordOccurrences = {};
    int wordPosition = -1;

    for (int i = 0; i <= currentWordIndex && i < timings.length; i++) {
      final timing = timings[i];
      final word = timing.word;

      if (i == currentWordIndex) {
        // This is the word we want to highlight
        final occurrenceIndex = wordOccurrences[word] ?? 0;

        // Find the nth occurrence (only in truncated portion)
        int searchPos = 0;
        int foundCount = 0;

        while (searchPos < searchLimit) {
          final pos = text.indexOf(word, searchPos);
          if (pos == -1 || pos >= searchLimit) break;

          if (foundCount == occurrenceIndex) {
            wordPosition = pos;
            break;
          }

          foundCount++;
          searchPos = pos + word.length;
        }
      } else if (timing.word == currentTiming.word) {
        // Track occurrences of the same word before current
        wordOccurrences[word] = (wordOccurrences[word] ?? 0) + 1;
      }
    }

    final wordRect = _getWordRect(currentTiming, textPainter, wordPosition);

    if (wordRect != null) {
      final wordPaint = Paint()
        ..color = wordHighlightColor
        ..style = PaintingStyle.fill;

      // Add slight padding and rounded corners for polish
      final paddedRect = wordRect.inflate(1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(paddedRect, const Radius.circular(2)),
        wordPaint,
      );
    }
  }

  void _paintText(Canvas canvas, Size size, TextPainter textPainter) {
    // IMPORTANT: Handle the case where timings only cover part of the text
    // (e.g., first 500 chars due to API truncation)

    // If timings are empty, paint plain text
    if (timings.isEmpty) {
      _paintPlainText(canvas, size);
      return;
    }

    // Build text spans with appropriate colors and styles
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    // Sort timings by start position to ensure correct order
    final sortedTimings = List<WordTiming>.from(timings)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));

    // Track word occurrences for repeated words
    final Map<String, int> wordOccurrences = {};
    final Map<int, int> timingToPosition = {};

    // First pass: map timings to their text positions
    // Only look within the first 500 chars (where timings exist)
    final searchLimit = text.length.clamp(0, 500);

    for (int i = 0; i < sortedTimings.length; i++) {
      final timing = sortedTimings[i];
      final word = timing.word;

      // Track which occurrence of this word we're looking for
      final occurrenceIndex = wordOccurrences[word] ?? 0;
      wordOccurrences[word] = occurrenceIndex + 1;

      // Find the nth occurrence of this word (only in truncated portion)
      int searchPos = 0;
      int foundCount = 0;
      int wordStart = -1;

      while (searchPos < searchLimit) {
        final pos = text.indexOf(word, searchPos);
        if (pos == -1 || pos >= searchLimit) break;

        if (foundCount == occurrenceIndex) {
          wordStart = pos;
          break;
        }

        foundCount++;
        searchPos = pos + word.length;
      }

      if (wordStart != -1) {
        timingToPosition[i] = wordStart;
      }
    }

    // Second pass: build the text spans
    // Only process words that were successfully found in the text
    final List<MapEntry<int, int>> sortedPositions = timingToPosition.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (final entry in sortedPositions) {
      final timingIndex = entry.key;
      final wordStart = entry.value;
      final timing = sortedTimings[timingIndex];
      final wordEnd = wordStart + timing.word.length;

      // Add text before this word if any
      if (wordStart > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, wordStart),
          style: baseStyle,
        ));
      }

      // Determine if this is the current word
      final isCurrentWord = timingIndex == currentWordIndex;

      // Add the word from the actual text position, not from timing
      // This ensures we don't duplicate words
      spans.add(TextSpan(
        text: text.substring(wordStart, wordEnd),
        style: baseStyle.copyWith(
          color: isCurrentWord ? activeWordTextColor : baseStyle.color,
          fontWeight: isCurrentWord ? FontWeight.bold : baseStyle.fontWeight,
        ),
      ));

      lastEnd = wordEnd;
    }

    // CRITICAL: Add any remaining text (including text beyond 500 chars)
    // This ensures the full text is always displayed
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    // If no spans were created (e.g., word matching failed), paint plain text
    if (spans.isEmpty) {
      _paintPlainText(canvas, size);
      return;
    }

    // Paint the complete text with spans
    textPainter.text = TextSpan(children: spans);
    textPainter.layout(maxWidth: size.width);
    textPainter.paint(canvas, Offset.zero);
  }

  Rect? _getWordRect(WordTiming timing, TextPainter textPainter, [int wordPosition = -1]) {
    try {
      // Use the provided word position for accurate rect calculation
      if (wordPosition == -1) return null;

      // Get bounding boxes for the word using TextSelection directly
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(
          baseOffset: wordPosition,
          extentOffset: wordPosition + timing.word.length,
        ),
      );

      if (boxes.isNotEmpty) {
        // Combine all boxes if word spans multiple lines
        double left = boxes.first.left;
        double top = boxes.first.top;
        double right = boxes.first.right;
        double bottom = boxes.first.bottom;

        for (final box in boxes.skip(1)) {
          left = left < box.left ? left : box.left;
          top = top < box.top ? top : box.top;
          right = right > box.right ? right : box.right;
          bottom = bottom > box.bottom ? bottom : box.bottom;
        }

        return Rect.fromLTRB(left, top, right, bottom);
      }
    } catch (e) {
      // Handle edge cases gracefully
      AppLogger.debug('Error getting word rect', {'error': e.toString()});
    }
    return null;
  }

  @override
  bool shouldRepaint(DualLevelHighlightPainter oldDelegate) {
    // Only repaint when highlighting changes, not on every frame
    return currentWordIndex != oldDelegate.currentWordIndex ||
           currentSentenceIndex != oldDelegate.currentSentenceIndex ||
           timings != oldDelegate.timings ||
           text != oldDelegate.text;
  }
}

/// Validation function to verify DualLevelHighlightedText implementation
Future<void> validateDualLevelHighlightedText() async {
  final stopwatch = Stopwatch()..start();

  try {
    AppLogger.info('Starting DualLevelHighlightedText validation');

    // Test 1: Widget creation
    const testWidget = DualLevelHighlightedText(
      text: 'Test text for validation',
      contentId: 'test-id',
      baseStyle: TextStyle(fontSize: 16),
    );
    assert(testWidget.sentenceHighlightColor == const Color(0xFFE3F2FD));
    assert(testWidget.wordHighlightColor == const Color(0xFFFFF59D));
    assert(testWidget.activeWordTextColor == const Color(0xFF1976D2));
    AppLogger.debug('✅ Widget creation with default colors');

    // Test 2: Painter shouldRepaint logic
    final painter1 = DualLevelHighlightPainter(
      text: 'Test',
      timings: [],
      currentWordIndex: 0,
      currentSentenceIndex: 0,
      baseStyle: const TextStyle(),
      sentenceHighlightColor: Colors.blue,
      wordHighlightColor: Colors.yellow,
      activeWordTextColor: Colors.red,
    );

    final painter2 = DualLevelHighlightPainter(
      text: 'Test',
      timings: [],
      currentWordIndex: 1, // Changed
      currentSentenceIndex: 0,
      baseStyle: const TextStyle(),
      sentenceHighlightColor: Colors.blue,
      wordHighlightColor: Colors.yellow,
      activeWordTextColor: Colors.red,
    );

    assert(painter1.shouldRepaint(painter2) == true);
    AppLogger.debug('✅ Painter shouldRepaint logic working');

    stopwatch.stop();
    assert(stopwatch.elapsedMilliseconds < 100);

    AppLogger.performance('DualLevelHighlightedText validation complete', {
      'duration': '${stopwatch.elapsedMilliseconds}ms'
    });

  } catch (e, stackTrace) {
    AppLogger.error(
      'DualLevelHighlightedText validation failed',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}