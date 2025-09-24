import 'package:flutter/material.dart';
import '../models/word_timing.dart';

/// Optimized painter using three-layer system with single TextPainter
///
/// Purpose: Efficiently renders dual-level word and sentence highlighting
/// Features:
/// - Three-layer paint system (background, sentence, word)
/// - TextBox caching for performance
/// - Direct character position lookups
/// - Optimized shouldRepaint logic
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

  // Cache for TextBox calculations to avoid expensive layout operations
  static final Map<String, List<TextBox>> textBoxCache = {};
  static const int maxCacheSize = 100; // Limit cache size to prevent memory issues

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

  /// Get cached TextBoxes for a selection to avoid expensive layout operations
  List<TextBox> _getCachedTextBoxes(int start, int end) {
    // Create cache key from text hash, font size, and selection range
    final cacheKey = '${text.hashCode}_${baseStyle.fontSize?.hashCode ?? 0}_${start}_$end';

    if (textBoxCache.containsKey(cacheKey)) {
      return textBoxCache[cacheKey]!;
    }

    // Calculate new text boxes
    final boxes = textPainter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );

    // Cache the result with LRU eviction
    if (textBoxCache.length >= maxCacheSize) {
      // Remove oldest entry (simple LRU - remove first key)
      final oldestKey = textBoxCache.keys.first;
      textBoxCache.remove(oldestKey);
    }

    textBoxCache[cacheKey] = boxes;
    return boxes;
  }

  /// Clear the TextBox cache when text or font changes
  static void clearTextBoxCache() {
    textBoxCache.clear();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Three-layer paint system for optimal visual hierarchy

    // Layer 1: Paint base text (background)
    textPainter.paint(canvas, Offset.zero);

    // Layer 2: Paint sentence highlight (if active)
    if (currentSentenceIndex >= 0) {
      _paintSentenceHighlight(canvas, currentSentenceIndex);
    }

    // Layer 3: Paint word highlight (if active)
    if (currentWordIndex >= 0 &&
        currentWordIndex < timingCollection.timings.length) {
      _paintWordHighlight(canvas, currentWordIndex);
    }
  }

  void _paintSentenceHighlight(Canvas canvas, int sentenceIndex) {
    // Get all words in the current sentence
    final sentenceWords = timingCollection.getWordsInSentence(sentenceIndex);
    if (sentenceWords.isEmpty) return;

    // Get character positions for the sentence using pre-processed lookup table
    final firstWord = sentenceWords.first;
    final lastWord = sentenceWords.last;

    // Use the pre-processed character positions from our lookup table
    final startChar = firstWord.charStart;
    final endExclusive = lastWord.charEnd;

    final paint = Paint()
      ..color = sentenceHighlightColor
      ..style = PaintingStyle.fill;

    if (startChar != null &&
        endExclusive != null &&
        endExclusive >= startChar) {
      final boxes = _getCachedTextBoxes(startChar, endExclusive);

      for (final box in boxes) {
        final rect =
            Rect.fromLTRB(box.left, box.top, box.right, box.bottom).inflate(1);
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _paintWordHighlight(Canvas canvas, int wordIndex) {
    // Get the bounding box for the current word using direct character positions
    final rect = _getWordRect(wordIndex);
    if (rect != null) {
      final paint = Paint()
        ..color = wordHighlightColor
        ..style = PaintingStyle.fill;

      // Inflate the rect slightly for better visual appearance
      final highlightRect = rect.inflate(2);
      canvas.drawRect(highlightRect, paint);
    }
  }

  // Get the bounding box for a word using direct character positions from the lookup table
  Rect? _getWordRect(int wordIndex) {
    if (wordIndex < 0 || wordIndex >= timingCollection.timings.length) {
      return null;
    }

    // Get the character positions from the lookup table
    final (int start, int end) = _getWordSelection(wordIndex);

    // Use cached TextBoxes to obtain the bounding box for the computed range
    final boxes = _getCachedTextBoxes(start, end);

    if (boxes.isNotEmpty) {
      double left = boxes.first.left;
      double top = boxes.first.top;
      double right = boxes.first.right;
      double bottom = boxes.first.bottom;

      // Combine all boxes if word spans multiple lines
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