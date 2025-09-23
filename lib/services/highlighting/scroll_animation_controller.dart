/// Scroll Animation Controller
///
/// Purpose: Manages auto-scroll behavior for highlighted text
/// Handles smooth scrolling animations to keep current word visible
///
/// Responsibilities:
/// - Calculate scroll positions
/// - Animate scroll to current word
/// - Manage scroll timing and duration
/// - Handle viewport calculations
///
import 'package:flutter/material.dart';
import '../../utils/app_logger.dart';

class ScrollAnimationController {
  ScrollController? _scrollController;
  double _lastScrollPosition = 0;
  bool _isAutoScrolling = false;

  /// Initialize with scroll controller
  void initialize(ScrollController scrollController) {
    _scrollController = scrollController;
  }

  /// Auto-scroll to keep word visible in viewport
  Future<void> autoScrollToWord({
    required Rect wordBounds,
    required double viewportHeight,
    Duration animationDuration = const Duration(milliseconds: 300),
    Curve animationCurve = Curves.easeInOut,
  }) async {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return;
    }

    if (_isAutoScrolling) {
      return; // Prevent overlapping animations
    }

    try {
      _isAutoScrolling = true;

      final scrollPosition = _scrollController!.position;
      final currentScroll = scrollPosition.pixels;
      final maxScroll = scrollPosition.maxScrollExtent;

      // Calculate viewport boundaries
      final viewportTop = currentScroll;
      final viewportBottom = currentScroll + viewportHeight;

      // Check if word is visible in viewport
      final wordTop = wordBounds.top;
      final wordBottom = wordBounds.bottom;
      final wordCenter = wordTop + (wordBottom - wordTop) / 2;

      // Determine if scrolling is needed
      bool needsScroll = false;
      double targetScroll = currentScroll;

      // If word is above viewport, scroll up
      if (wordTop < viewportTop + 50) {
        // Add 50px buffer at top
        targetScroll = (wordTop - 100).clamp(0.0, maxScroll);
        needsScroll = true;
      }
      // If word is below viewport, scroll down
      else if (wordBottom > viewportBottom - 50) {
        // Add 50px buffer at bottom
        // Center the word in viewport if possible
        targetScroll = (wordCenter - viewportHeight / 2).clamp(0.0, maxScroll);
        needsScroll = true;
      }

      if (needsScroll && (targetScroll - currentScroll).abs() > 10) {
        // Calculate animation duration based on distance
        final distance = (targetScroll - currentScroll).abs();
        final dynamicDuration = _calculateDuration(distance, viewportHeight);

        await _scrollController!.animateTo(
          targetScroll,
          duration: dynamicDuration,
          curve: animationCurve,
        );

        _lastScrollPosition = targetScroll;

        AppLogger.info('Auto-scrolled to word', {
          'from': currentScroll.toStringAsFixed(1),
          'to': targetScroll.toStringAsFixed(1),
          'distance': distance.toStringAsFixed(1),
          'duration': dynamicDuration.inMilliseconds,
        });
      }
    } catch (e) {
      AppLogger.error('Auto-scroll failed', error: e);
    } finally {
      _isAutoScrolling = false;
    }
  }

  /// Calculate animation duration based on distance
  Duration _calculateDuration(double distance, double viewportHeight) {
    // Base duration
    const minDuration = Duration(milliseconds: 200);
    const maxDuration = Duration(milliseconds: 800);

    // Calculate duration based on distance relative to viewport
    final distanceRatio = distance / viewportHeight;
    final durationMs = (200 + (600 * distanceRatio)).clamp(
      minDuration.inMilliseconds.toDouble(),
      maxDuration.inMilliseconds.toDouble(),
    );

    return Duration(milliseconds: durationMs.round());
  }

  /// Scroll to specific position immediately
  void jumpToPosition(double position) {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return;
    }

    final maxScroll = _scrollController!.position.maxScrollExtent;
    final targetPosition = position.clamp(0.0, maxScroll);

    _scrollController!.jumpTo(targetPosition);
    _lastScrollPosition = targetPosition;
  }

  /// Get current scroll position
  double get currentPosition {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return 0;
    }
    return _scrollController!.position.pixels;
  }

  /// Check if currently auto-scrolling
  bool get isAutoScrolling => _isAutoScrolling;

  /// Reset scroll to top
  void resetScroll() {
    jumpToPosition(0);
  }

  /// Dispose resources
  void dispose() {
    _scrollController = null;
    _isAutoScrolling = false;
    _lastScrollPosition = 0;
  }
}