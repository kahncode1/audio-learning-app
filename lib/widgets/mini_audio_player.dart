/// MiniAudioPlayer - Persistent audio control widget
///
/// Purpose: Provides persistent audio controls across all screens
/// Dependencies:
///   - flutter_riverpod: State management
///   - providers/audio_providers: Audio state
///   - models: Learning object model
///
/// Features:
///   - Compact 72px height design
///   - Play/pause control
///   - Progress indicator
///   - Tap to return to full player
///   - Smooth animations
///
/// Usage:
///   Positioned above bottom navigation in MainNavigationScreen
///   Automatically shows/hides based on audio state

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_providers.dart';
import '../providers/audio_context_provider.dart';
import '../models/learning_object.dart';

class MiniAudioPlayer extends ConsumerWidget {
  const MiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioContext = ref.watch(audioContextProvider);
    final isPlayingAsync = ref.watch(audioPlayingStateProvider);
    final progress = ref.watch(audioProgressProvider);
    final audioControl = ref.watch(audioControlProvider.notifier);
    final subtitle = ref.watch(miniPlayerSubtitleProvider);
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;

    // If no audio context, don't show anything
    if (audioContext == null) {
      return const SizedBox.shrink();
    }

    final isPlaying = isPlayingAsync.valueOrNull ?? false;
    final currentObject = audioContext.learningObject;

    return Material(
      elevation: 8,
      color: backgroundColor,
      child: InkWell(
        onTap: () => audioControl.navigateToFullPlayer(context),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Progress bar at the top
              LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: Theme.of(context).dividerColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),

              // Main content
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Learning object icon
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.headphones,
                            color: Theme.of(context).colorScheme.primary,
                            size: 22,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Title and subtitle
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentObject.title,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Play/Pause button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => audioControl.togglePlayPause(),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated wrapper for the mini player with slide animation
class AnimatedMiniAudioPlayer extends ConsumerWidget {
  const AnimatedMiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShow = ref.watch(shouldShowMiniPlayerProvider);

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      offset: shouldShow ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: shouldShow ? 1.0 : 0.0,
        child: shouldShow ? const MiniAudioPlayer() : const SizedBox.shrink(),
      ),
    );
  }
}
