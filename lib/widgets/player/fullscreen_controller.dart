/// Fullscreen Controller
///
/// Purpose: Manages fullscreen mode timing and UI transitions
/// Dependencies:
/// - flutter/services.dart (for system UI control)
///
/// Features:
/// - Auto-hide controls after 3 seconds of inactivity
/// - System UI overlay management
/// - Timer management for fullscreen mode
/// - Clean disposal of resources

import 'dart:async';
import 'package:flutter/services.dart';

class FullscreenController {
  Timer? _fullscreenTimer;
  bool _isFullscreen = false;
  final Function(bool) onFullscreenChanged;

  FullscreenController({
    required this.onFullscreenChanged,
  });

  bool get isFullscreen => _isFullscreen;

  /// Start fullscreen timer when playing
  void startFullscreenTimer() {
    cancelFullscreenTimer();
    _fullscreenTimer = Timer(const Duration(seconds: 3), () {
      enterFullscreen();
    });
  }

  /// Cancel fullscreen timer
  void cancelFullscreenTimer() {
    _fullscreenTimer?.cancel();
    _fullscreenTimer = null;
  }

  /// Restart timer on user interaction
  void restartTimerOnInteraction() {
    if (_isFullscreen) {
      exitFullscreen();
    }
    cancelFullscreenTimer();
    startFullscreenTimer();
  }

  /// Enter fullscreen mode
  void enterFullscreen() {
    if (!_isFullscreen) {
      _isFullscreen = true;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      onFullscreenChanged(true);
    }
  }

  /// Exit fullscreen mode
  void exitFullscreen() {
    if (_isFullscreen) {
      _isFullscreen = false;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      onFullscreenChanged(false);
      // Restart timer after exiting fullscreen
      startFullscreenTimer();
    }
  }

  /// Clean up resources
  void dispose() {
    cancelFullscreenTimer();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}