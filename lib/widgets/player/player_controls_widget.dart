/// Player Controls Widget
///
/// Purpose: Reusable audio player controls with play/pause, skip, speed, and font size
/// Dependencies:
/// - flutter_riverpod: ^2.4.9 (for state management)
/// - just_audio: ^0.9.36 (for audio types)
/// - ../../services/audio_player_service_local.dart (for audio control)
/// - ../../services/progress_service.dart (for font size management)
///
/// Features:
/// - Play/pause button with FloatingActionButton style
/// - Skip forward/backward 30 seconds
/// - Speed adjustment (0.5x to 2.0x)
/// - Font size cycling (Small/Medium/Large)
/// - Compact, responsive layout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/audio_player_service_local.dart';
import '../../services/progress_service.dart';

class PlayerControlsWidget extends ConsumerStatefulWidget {
  final VoidCallback? onInteraction;

  const PlayerControlsWidget({
    super.key,
    this.onInteraction,
  });

  @override
  ConsumerState<PlayerControlsWidget> createState() => _PlayerControlsWidgetState();
}

class _PlayerControlsWidgetState extends ConsumerState<PlayerControlsWidget> {
  late final AudioPlayerServiceLocal _audioService;
  ProgressService? _progressService;

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerServiceLocal.instance;
    _initProgressService();
  }

  Future<void> _initProgressService() async {
    final service = await ProgressService.getInstance();
    if (mounted) {
      setState(() {
        _progressService = service;
      });
    }
  }

  void _handleInteraction() {
    widget.onInteraction?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Speed control
          _buildSpeedControl(context),

          // Skip backward
          Semantics(
            label: 'Skip backward 30 seconds',
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.replay_30,
                color: Colors.grey.shade500,
                weight: 300,
              ),
              iconSize: 40,
              onPressed: () {
                _audioService.skipBackward();
                _handleInteraction();
              },
              tooltip: 'Skip back 30s (←)',
            ),
          ),

          // Play/Pause with FloatingActionButton
          StreamBuilder<bool>(
            stream: _audioService.isPlayingStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              return Semantics(
                label: isPlaying ? 'Pause audio' : 'Play audio',
                button: true,
                child: SizedBox(
                  height: 48,
                  width: 48,
                  child: FloatingActionButton(
                    onPressed: () {
                      _audioService.togglePlayPause();
                      _handleInteraction();
                    },
                    tooltip: 'Play/Pause (Space)',
                    elevation: 2,
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),

          // Skip forward
          Semantics(
            label: 'Skip forward 30 seconds',
            button: true,
            child: IconButton(
              icon: Icon(
                Icons.forward_30,
                color: Colors.grey.shade500,
                weight: 300,
              ),
              iconSize: 40,
              onPressed: () {
                _audioService.skipForward();
                _handleInteraction();
              },
              tooltip: 'Skip forward 30s (→)',
            ),
          ),

          // Font size control
          _buildFontSizeControl(context),
        ],
      ),
    );
  }

  Widget _buildSpeedControl(BuildContext context) {
    return StreamBuilder<double>(
      stream: _audioService.speedStream,
      builder: (context, snapshot) {
        final speed = snapshot.data ?? 1.0;
        return Semantics(
          label: 'Playback speed ${speed}x. Tap to change',
          button: true,
          child: SizedBox(
            width: 50,
            height: 28,
            child: TextButton(
              onPressed: () {
                _audioService.cycleSpeed();
                _handleInteraction();
              },
              style: _getButtonStyle(context),
              child: Text(
                '${speed}x',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontSizeControl(BuildContext context) {
    return StreamBuilder<int>(
      stream: _progressService?.fontSizeIndexStream ?? Stream.value(1),
      builder: (context, snapshot) {
        final fontSizeName = _progressService?.currentFontSizeName ?? 'Medium';
        return Semantics(
          label: 'Font size $fontSizeName. Tap to change',
          button: true,
          child: SizedBox(
            width: 50,
            height: 28,
            child: TextButton(
              onPressed: () async {
                await _progressService?.cycleFontSize();
                if (mounted) {
                  setState(() {}); // Refresh UI
                }
                _handleInteraction();
              },
              style: _getButtonStyle(context),
              child: Text(
                fontSizeName,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 11),
              ),
            ),
          ),
        );
      },
    );
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    return TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      minimumSize: const Size(50, 28),
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? Colors.grey.shade200
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      foregroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.primary
          : null,
    );
  }

  @override
  void dispose() {
    // Don't dispose services - they're singletons
    super.dispose();
  }
}