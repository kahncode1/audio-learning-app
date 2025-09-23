/// Player Controls Widget
///
/// Purpose: Audio player control interface
/// Provides play/pause, seek, speed adjustment controls
///
/// Features:
/// - FloatingActionButton for play/pause
/// - Skip forward/backward controls
/// - Playback speed adjustment
/// - Interactive seek bar with time labels
/// - Responsive to stream updates
///
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/audio_player_service_local.dart';
import '../../utils/app_logger.dart';

class PlayerControlsWidget extends StatelessWidget {
  final AudioPlayerServiceLocal audioService;
  final VoidCallback? onInteraction;

  const PlayerControlsWidget({
    super.key,
    required this.audioService,
    this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Full-width progress bar
        _buildSeekBar(context),
        // Control buttons row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed control
              _buildSpeedControl(context),
              // Skip backward
              _buildSkipBackward(context),
              // Play/Pause FAB
              _buildPlayPauseButton(context),
              // Skip forward
              _buildSkipForward(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeekBar(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: audioService.positionStream,
      builder: (context, positionSnapshot) {
        if (positionSnapshot.hasError) {
          AppLogger.error('Position stream error', error: positionSnapshot.error);
          return const SizedBox.shrink();
        }
        final position = positionSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: audioService.durationStream,
          builder: (context, durationSnapshot) {
            if (durationSnapshot.hasError) {
              AppLogger.error('Duration stream error', error: durationSnapshot.error);
              return const SizedBox.shrink();
            }
            final duration = durationSnapshot.data ?? Duration.zero;

            return Column(
              children: [
                // Full-width seek bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12.0,
                    ),
                    trackShape: const RectangularSliderTrackShape(),
                  ),
                  child: SizedBox(
                    height: 20,
                    child: Slider(
                      value: duration.inMilliseconds > 0 &&
                             position.inMilliseconds <= duration.inMilliseconds
                          ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0,
                      onChanged: (value) {
                        final newPosition = Duration(
                          milliseconds: (duration.inMilliseconds * value).round(),
                        );
                        audioService.seekToPosition(newPosition);
                        onInteraction?.call();
                      },
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                // Time labels
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                      Text(
                        _formatDuration(duration - position),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSpeedControl(BuildContext context) {
    return StreamBuilder<double>(
      stream: audioService.speedStream,
      builder: (context, snapshot) {
        final speed = snapshot.data ?? 1.0;
        final speeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
        final speedIndex = speeds.indexOf(speed);

        return Tooltip(
          message: 'Playback Speed',
          child: Container(
            width: 65,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  final nextIndex = (speedIndex + 1) % speeds.length;
                  audioService.setPlaybackSpeed(speeds[nextIndex]);
                  onInteraction?.call();
                },
                child: Center(
                  child: Text(
                    '${speed}x',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkipBackward(BuildContext context) {
    return Tooltip(
      message: 'Skip Back 30s (←)',
      child: IconButton(
        iconSize: 40,
        icon: const Icon(Icons.replay_30),
        onPressed: () {
          audioService.skipBackward();
          onInteraction?.call();
        },
      ),
    );
  }

  Widget _buildPlayPauseButton(BuildContext context) {
    return StreamBuilder<bool>(
      stream: audioService.playingStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return StreamBuilder<ProcessingState>(
          stream: audioService.processingStateStream,
          builder: (context, stateSnapshot) {
            final processingState = stateSnapshot.data ?? ProcessingState.idle;
            final isLoading = processingState == ProcessingState.loading ||
                             processingState == ProcessingState.buffering;

            return Tooltip(
              message: isPlaying ? 'Pause (Space)' : 'Play (Space)',
              child: SizedBox(
                width: 64,
                height: 64,
                child: FloatingActionButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (isPlaying) {
                            audioService.pausePlayback();
                          } else {
                            audioService.resumePlayback();
                          }
                          onInteraction?.call();
                        },
                  elevation: 4,
                  child: isLoading
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 36,
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSkipForward(BuildContext context) {
    return Tooltip(
      message: 'Skip Forward 30s (→)',
      child: IconButton(
        iconSize: 40,
        icon: const Icon(Icons.forward_30),
        onPressed: () {
          audioService.skipForward();
          onInteraction?.call();
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}