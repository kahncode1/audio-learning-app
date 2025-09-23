/// Text Painting Service
///
/// Purpose: Handles custom text painting and layout calculations
/// Manages TextPainter configuration and rendering operations
///
/// Responsibilities:
/// - Text layout and measurement
/// - Custom painting operations
/// - Highlight rendering (word and sentence)
/// - Text position calculations
///
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../utils/app_logger.dart';

class TextPaintingService {
  TextPainter? _textPainter;
  TextStyle? _currentStyle;
  String? _currentText;

  /// Initialize or update the text painter
  void initializeTextPainter({
    required String text,
    required TextStyle style,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    if (_currentText == text && _currentStyle == style) {
      return; // No changes needed
    }

    _currentText = text;
    _currentStyle = style;

    _textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
    );

    AppLogger.info('TextPainter initialized', {
      'textLength': text.length,
      'fontSize': style.fontSize,
    });
  }

  /// Layout the text with given constraints
  void layout(double maxWidth) {
    _textPainter?.layout(maxWidth: maxWidth);
  }

  /// Paint sentence highlight
  void paintSentenceHighlight({
    required Canvas canvas,
    required int startChar,
    required int endChar,
    required Color highlightColor,
    required Size size,
  }) {
    if (_textPainter == null || startChar < 0 || endChar < 0) return;

    try {
      // Get text boxes for the sentence range
      final boxes = _textPainter!.getBoxesForSelection(
        TextSelection(baseOffset: startChar, extentOffset: endChar),
        boxHeightStyle: ui.BoxHeightStyle.max,
        boxWidthStyle: ui.BoxWidthStyle.max,
      );

      if (boxes.isEmpty) return;

      // Paint highlight rectangles
      final paint = Paint()
        ..color = highlightColor
        ..style = PaintingStyle.fill;

      for (final box in boxes) {
        final rect = Rect.fromLTWH(
          box.left,
          box.top,
          box.right - box.left,
          box.bottom - box.top,
        );
        canvas.drawRect(rect, paint);
      }
    } catch (e) {
      AppLogger.error('Failed to paint sentence highlight', error: e);
    }
  }

  /// Paint word highlight
  void paintWordHighlight({
    required Canvas canvas,
    required int startChar,
    required int endChar,
    required Color highlightColor,
    required Size size,
  }) {
    if (_textPainter == null || startChar < 0 || endChar < 0) return;

    try {
      // Get text boxes for the word range
      final boxes = _textPainter!.getBoxesForSelection(
        TextSelection(baseOffset: startChar, extentOffset: endChar),
        boxHeightStyle: ui.BoxHeightStyle.max,
        boxWidthStyle: ui.BoxWidthStyle.max,
      );

      if (boxes.isNotEmpty) {
        final paint = Paint()
          ..color = highlightColor
          ..style = PaintingStyle.fill;

        // Paint the first box (usually the only one for a single word)
        final box = boxes.first;
        final rect = Rect.fromLTWH(
          box.left,
          box.top,
          box.right - box.left,
          box.bottom - box.top,
        );
        canvas.drawRect(rect, paint);
      }
    } catch (e) {
      AppLogger.error('Failed to paint word highlight', error: e);
    }
  }

  /// Paint the text itself
  void paintText(Canvas canvas) {
    _textPainter?.paint(canvas, Offset.zero);
  }

  /// Get position of a character
  Offset? getPositionForCharacter(int offset) {
    if (_textPainter == null) return null;

    try {
      return _textPainter!.getPositionForOffset(
        _textPainter!.getOffsetForCaret(
          TextPosition(offset: offset),
          Rect.zero,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get bounding box for character range
  Rect? getBoundingBoxForRange(int start, int end) {
    if (_textPainter == null) return null;

    try {
      final boxes = _textPainter!.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );

      if (boxes.isEmpty) return null;

      // Combine all boxes into a single bounding rect
      double minLeft = double.infinity;
      double minTop = double.infinity;
      double maxRight = double.negativeInfinity;
      double maxBottom = double.negativeInfinity;

      for (final box in boxes) {
        minLeft = minLeft < box.left ? minLeft : box.left;
        minTop = minTop < box.top ? minTop : box.top;
        maxRight = maxRight > box.right ? maxRight : box.right;
        maxBottom = maxBottom > box.bottom ? maxBottom : box.bottom;
      }

      return Rect.fromLTRB(minLeft, minTop, maxRight, maxBottom);
    } catch (e) {
      return null;
    }
  }

  /// Get the height of the painted text
  double? get height => _textPainter?.height;

  /// Get the width of the painted text
  double? get width => _textPainter?.width;

  /// Check if text painter is initialized
  bool get isInitialized => _textPainter != null;

  /// Dispose resources
  void dispose() {
    _textPainter = null;
    _currentStyle = null;
    _currentText = null;
  }
}