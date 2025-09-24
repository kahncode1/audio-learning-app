/// Audio Progress Bar Widget
///
/// Purpose: Interactive seek bar with time display for audio playback
/// Dependencies:
/// - flutter_riverpod: ^2.4.9 (for state management)
/// - ../../services/audio_player_service_local.dart (for position/duration streams)
///
/// Features:
/// - Full-width interactive seek bar
/// - Current time and remaining time display
/// - Smooth slider interaction
/// - Responsive to position and duration changes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/audio_player_service_local.dart';
import '../../utils/app_logger.dart';

class AudioProgressBar extends ConsumerWidget {
  final VoidCallback? onInteraction;

  const AudioProgressBar({
    super.key,
    this.onInteraction,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioService = AudioPlayerServiceLocal.instance;

    return StreamBuilder<Duration>(
      stream: audioService.positionStream,
      builder: (context, positionSnapshot) {
        // Handle stream errors gracefully
        if (positionSnapshot.hasError) {
          AppLogger.error('Position stream error', error: positionSnapshot.error);
          return const SizedBox.shrink();
        }
        final position = positionSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: audioService.durationStream,
          builder: (context, durationSnapshot) {
            // Handle stream errors gracefully
            if (durationSnapshot.hasError) {
              AppLogger.error('Duration stream error', error: durationSnapshot.error);
              return const SizedBox.shrink();
            }
            final duration = durationSnapshot.data ?? Duration.zero;

            return Column(
              children: [
                // Full-width seek bar without horizontal padding
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
                          ? (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0.0, 1.0)
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
                // Time labels close to the bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 2, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(position),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11),
                      ),
                      Text(
                        _formatDuration(duration - position),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 11),
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
}