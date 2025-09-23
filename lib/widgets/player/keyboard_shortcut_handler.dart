/// Keyboard Shortcut Handler
///
/// Purpose: Handles keyboard input for audio player controls
/// Manages keyboard focus and shortcut bindings
///
/// Keyboard Shortcuts:
/// - Space: Play/Pause
/// - Left Arrow: Skip backward 30s
/// - Right Arrow: Skip forward 30s
/// - Up Arrow: Increase speed
/// - Down Arrow: Decrease speed
/// - F: Toggle fullscreen (if supported)
///
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/audio_player_service_local.dart';
import '../../utils/app_logger.dart';

class KeyboardShortcutHandler extends StatefulWidget {
  final AudioPlayerServiceLocal audioService;
  final Widget child;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onInteraction;
  final bool requestFocus;

  const KeyboardShortcutHandler({
    super.key,
    required this.audioService,
    required this.child,
    this.onToggleFullscreen,
    this.onInteraction,
    this.requestFocus = true,
  });

  @override
  State<KeyboardShortcutHandler> createState() => _KeyboardShortcutHandlerState();
}

class _KeyboardShortcutHandlerState extends State<KeyboardShortcutHandler> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    if (widget.requestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Call interaction callback for any key press
    widget.onInteraction?.call();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _togglePlayPause();
        break;
      case LogicalKeyboardKey.arrowLeft:
        _skipBackward();
        break;
      case LogicalKeyboardKey.arrowRight:
        _skipForward();
        break;
      case LogicalKeyboardKey.arrowUp:
        _increaseSpeed();
        break;
      case LogicalKeyboardKey.arrowDown:
        _decreaseSpeed();
        break;
      case LogicalKeyboardKey.keyF:
        widget.onToggleFullscreen?.call();
        break;
      default:
        // No action for other keys
        break;
    }
  }

  void _togglePlayPause() {
    final isPlaying = widget.audioService.playingStream.value;
    if (isPlaying) {
      widget.audioService.pausePlayback();
    } else {
      widget.audioService.resumePlayback();
    }
    AppLogger.info('Keyboard: Toggle play/pause');
  }

  void _skipBackward() {
    widget.audioService.skipBackward();
    AppLogger.info('Keyboard: Skip backward');
  }

  void _skipForward() {
    widget.audioService.skipForward();
    AppLogger.info('Keyboard: Skip forward');
  }

  void _increaseSpeed() {
    final currentSpeed = widget.audioService.speedStream.value ?? 1.0;
    final speeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
    final currentIndex = speeds.indexOf(currentSpeed);

    if (currentIndex < speeds.length - 1) {
      widget.audioService.setPlaybackSpeed(speeds[currentIndex + 1]);
      AppLogger.info('Keyboard: Increased speed to ${speeds[currentIndex + 1]}x');
    }
  }

  void _decreaseSpeed() {
    final currentSpeed = widget.audioService.speedStream.value ?? 1.0;
    final speeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
    final currentIndex = speeds.indexOf(currentSpeed);

    if (currentIndex > 0) {
      widget.audioService.setPlaybackSpeed(speeds[currentIndex - 1]);
      AppLogger.info('Keyboard: Decreased speed to ${speeds[currentIndex - 1]}x');
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () {
          // Request focus when tapped
          _focusNode.requestFocus();
        },
        child: widget.child,
      ),
    );
  }
}

/// Keyboard shortcut documentation widget
class KeyboardShortcutHelp extends StatelessWidget {
  const KeyboardShortcutHelp({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShortcutItem(
            keys: 'Space',
            description: 'Play / Pause',
          ),
          _ShortcutItem(
            keys: '←',
            description: 'Skip back 30 seconds',
          ),
          _ShortcutItem(
            keys: '→',
            description: 'Skip forward 30 seconds',
          ),
          _ShortcutItem(
            keys: '↑',
            description: 'Increase playback speed',
          ),
          _ShortcutItem(
            keys: '↓',
            description: 'Decrease playback speed',
          ),
          _ShortcutItem(
            keys: 'F',
            description: 'Toggle fullscreen',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String keys;
  final String description;

  const _ShortcutItem({
    required this.keys,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context).cardColor,
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(description),
        ],
      ),
    );
  }
}