/// Audio Playback State Management Providers
///
/// Purpose: Centralized state management for audio playback across the app
/// Dependencies:
///   - flutter_riverpod: State management
///   - services/audio_player_service: Core audio functionality
///   - models: Learning object and timing models
///
/// Features:
///   - Global audio playback state
///   - Current learning object tracking
///   - Position and duration streams
///   - Mini player visibility control
///
/// Usage:
///   final isPlaying = ref.watch(audioPlayingStateProvider);
///   final currentObject = ref.watch(currentLearningObjectProvider);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_player_service_local.dart';
import '../models/learning_object_v2.dart';
import 'audio_context_provider.dart';

/// Singleton AudioPlayerServiceLocal provider (using download-first architecture)
final audioPlayerServiceProvider = Provider<AudioPlayerServiceLocal>((ref) {
  return AudioPlayerServiceLocal.instance;
});

/// Current learning object being played
final currentLearningObjectProvider = StateProvider<LearningObjectV2?>((ref) => null);

/// Whether audio is currently loaded (not necessarily playing)
final isAudioLoadedProvider = StreamProvider<bool>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);

  // Combine playing state and processing state to determine if audio is loaded
  return audioService.processingStateStream.map((state) {
    // Audio is considered loaded if it's not idle
    return state != ProcessingState.idle;
  });
});

/// Audio playing state stream
final audioPlayingStateProvider = StreamProvider<bool>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.isPlayingStream;
});

/// Audio position stream
final audioPositionProvider = StreamProvider<Duration>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.positionStream;
});

/// Audio duration stream
final audioDurationProvider = StreamProvider<Duration>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.durationStream;
});

/// Audio loading state
final audioLoadingStateProvider = StreamProvider<ProcessingState>((ref) {
  final audioService = ref.watch(audioPlayerServiceProvider);
  return audioService.processingStateStream;
});

/// Computed provider for progress percentage
final audioProgressProvider = Provider<double>((ref) {
  final position = ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
  final duration = ref.watch(audioDurationProvider).valueOrNull ?? Duration.zero;

  if (duration.inMilliseconds == 0) return 0.0;

  final progress = position.inMilliseconds / duration.inMilliseconds;
  return progress.clamp(0.0, 1.0);
});

/// Provider to determine if mini player should be shown
final shouldShowMiniPlayerProvider = Provider<bool>((ref) {
  final isLoaded = ref.watch(isAudioLoadedProvider).valueOrNull ?? false;
  final audioContext = ref.watch(audioContextProvider);

  // Show mini player if audio is loaded and we have audio context
  return isLoaded && audioContext != null;
});

/// Provider for formatted current time
final formattedPositionProvider = Provider<String>((ref) {
  final position = ref.watch(audioPositionProvider).valueOrNull ?? Duration.zero;
  return _formatDuration(position);
});

/// Provider for formatted total duration
final formattedDurationProvider = Provider<String>((ref) {
  final duration = ref.watch(audioDurationProvider).valueOrNull ?? Duration.zero;
  return _formatDuration(duration);
});

/// Helper function to format duration
String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
}

/// Audio control notifier for mini player actions
class AudioControlNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  AudioControlNotifier(this.ref) : super(const AsyncValue.data(null));

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    state = const AsyncValue.loading();
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.togglePlayPause();
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Navigate to full player
  void navigateToFullPlayer(context) {
    final audioContext = ref.read(audioContextProvider);
    if (audioContext != null) {
      Navigator.pushNamed(
        context,
        '/player',
        arguments: {
          'learningObject': audioContext.learningObject,
          'courseNumber': audioContext.courseNumber,
          'courseTitle': audioContext.courseTitle,
          'assignmentTitle': audioContext.assignmentTitle,
          'assignmentNumber': audioContext.assignmentNumber,
        },
      );
    }
  }

  /// Stop audio and clear state
  Future<void> stopAudio() async {
    state = const AsyncValue.loading();
    try {
      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.pause();
      // Clear the audio context to hide mini player
      ref.read(audioContextProvider.notifier).state = null;
      // Also clear legacy provider for backward compatibility
      ref.read(currentLearningObjectProvider.notifier).state = null;
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for audio control actions
final audioControlProvider =
    StateNotifierProvider<AudioControlNotifier, AsyncValue<void>>((ref) {
  return AudioControlNotifier(ref);
});

// =============================================================================
// CRITICAL HIGHLIGHTING PROVIDERS - DO NOT MODIFY WITHOUT EXTENSIVE TESTING
// =============================================================================
// These providers were moved from the original providers.dart file
// They are essential for the dual-level highlighting system to work correctly

/// Current word index for highlighting
/// CRITICAL: Used by SimplifiedDualLevelHighlightedText widget
/// Controls which word is highlighted in yellow (#FFF59D)
final currentWordIndexProvider = StateProvider<int>((ref) => -1);

/// Current sentence index for highlighting
/// CRITICAL: Used by SimplifiedDualLevelHighlightedText widget
/// Controls which sentence has blue background (#E3F2FD)
final currentSentenceIndexProvider = StateProvider<int>((ref) => -1);

/// Audio playback position in milliseconds
/// CRITICAL: Drives word timing synchronization
/// Updated by WordTimingServiceSimplified via RxDart streams
/// NOTE: This is different from audioPositionProvider which uses Duration
final playbackPositionProvider = StateProvider<int>((ref) => 0);

/// Audio playback state (playing/paused)
/// Simple state provider used by some legacy components
/// NOTE: This is different from audioPlayingStateProvider which is a stream
final isPlayingProvider = StateProvider<bool>((ref) => false);