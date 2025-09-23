/// Fullscreen Controller
///
/// Purpose: Manages fullscreen mode for audio player
/// Handles auto-fullscreen, timer management, and UI state
///
/// Features:
/// - Auto-enter fullscreen after 10 seconds of inactivity
/// - Exit fullscreen on tap
/// - Cancel timer on user interaction
/// - Smooth animations for UI transitions
///
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/app_logger.dart';

class FullscreenController extends StatefulWidget {
  final Widget child;
  final Duration autoEnterDelay;
  final bool enabled;
  final Widget Function(BuildContext context, bool isFullscreen, Widget child) builder;

  const FullscreenController({
    super.key,
    required this.child,
    this.autoEnterDelay = const Duration(seconds: 10),
    this.enabled = true,
    required this.builder,
  });

  @override
  State<FullscreenController> createState() => FullscreenControllerState();
}

class FullscreenControllerState extends State<FullscreenController> {
  Timer? _fullscreenTimer;
  bool _isFullscreen = false;

  bool get isFullscreen => _isFullscreen;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _startFullscreenTimer();
    }
  }

  @override
  void dispose() {
    _cancelFullscreenTimer();
    super.dispose();
  }

  /// Start the auto-fullscreen timer
  void _startFullscreenTimer() {
    _cancelFullscreenTimer();

    if (!widget.enabled || _isFullscreen) return;

    _fullscreenTimer = Timer(widget.autoEnterDelay, () {
      if (mounted) {
        enterFullscreen();
      }
    });

    AppLogger.info('Started fullscreen timer', {
      'delay': widget.autoEnterDelay.inSeconds,
    });
  }

  /// Cancel the auto-fullscreen timer
  void _cancelFullscreenTimer() {
    _fullscreenTimer?.cancel();
    _fullscreenTimer = null;
  }

  /// Enter fullscreen mode
  void enterFullscreen() {
    if (_isFullscreen) return;

    setState(() {
      _isFullscreen = true;
    });

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    AppLogger.info('Entered fullscreen mode');
  }

  /// Exit fullscreen mode
  Future<void> exitFullscreen() async {
    if (!_isFullscreen) return;

    setState(() {
      _isFullscreen = false;
    });

    // Show system UI
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // Restart timer for next auto-fullscreen
    if (widget.enabled) {
      _startFullscreenTimer();
    }

    AppLogger.info('Exited fullscreen mode');
  }

  /// Toggle fullscreen mode
  void toggleFullscreen() {
    if (_isFullscreen) {
      exitFullscreen();
    } else {
      enterFullscreen();
    }
  }

  /// Handle user interaction (restart timer)
  void handleInteraction() {
    if (!_isFullscreen && widget.enabled) {
      _startFullscreenTimer();
      AppLogger.info('Restarted fullscreen timer due to interaction');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isFullscreen, widget.child);
  }
}

/// Fullscreen wrapper widget with default behavior
class FullscreenWrapper extends StatelessWidget {
  final bool isFullscreen;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? fullscreenPadding;
  final EdgeInsets? normalPadding;

  const FullscreenWrapper({
    super.key,
    required this.isFullscreen,
    required this.child,
    this.onTap,
    this.fullscreenPadding,
    this.normalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isFullscreen ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: isFullscreen ? Colors.black : null,
        padding: isFullscreen
            ? (fullscreenPadding ?? const EdgeInsets.all(24))
            : (normalPadding ?? const EdgeInsets.all(16)),
        child: child,
      ),
    );
  }
}

/// Animated visibility widget for fullscreen transitions
class FullscreenVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;

  const FullscreenVisibility({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: duration,
      child: AnimatedContainer(
        duration: duration,
        height: visible ? null : 0,
        child: visible ? child : const SizedBox.shrink(),
      ),
    );
  }
}