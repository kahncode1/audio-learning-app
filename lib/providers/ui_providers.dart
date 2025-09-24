/// UI State Management Providers
///
/// Purpose: Manages user interface preferences and settings
/// Dependencies:
///   - flutter_riverpod: State management
///   - models: ProgressState for font size constants
///
/// CRITICAL: Font size provider is essential for the highlighting widget
/// The SimplifiedDualLevelHighlightedText widget depends on font size changes
/// to properly recalculate word boundaries and maintain accurate highlighting

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';

// =============================================================================
// FONT SIZE MANAGEMENT - CRITICAL FOR HIGHLIGHTING SYSTEM
// =============================================================================

/// Font size index provider (0-3: Small, Medium, Large, X-Large)
/// CRITICAL: Used by SimplifiedDualLevelHighlightedText widget
/// Changes trigger TextPainter recalculation for word boundaries
/// Must maintain accurate word position mapping after size changes
final fontSizeIndexProvider =
    StateNotifierProvider<FontSizeNotifier, int>((ref) {
  return FontSizeNotifier();
});

/// Font size state notifier with cycling capability
class FontSizeNotifier extends StateNotifier<int> {
  FontSizeNotifier() : super(1); // Default to Medium (index 1)

  void setFontSize(int index) {
    if (index >= 0 && index < ProgressState.fontSizeNames.length) {
      state = index;
    }
  }

  void cycleToNext() {
    state = (state + 1) % ProgressState.fontSizeNames.length;
  }

  String get fontSizeName => ProgressState.fontSizeNames[state];
  double get fontSizeValue => ProgressState.fontSizeValues[state];
}

// =============================================================================
// PLAYBACK SPEED MANAGEMENT
// =============================================================================

/// Playback speed provider for audio control
/// Affects audio playback rate but not highlighting timing
final playbackSpeedProvider =
    StateNotifierProvider<PlaybackSpeedNotifier, double>((ref) {
  return PlaybackSpeedNotifier();
});

/// Playback speed state notifier with preset speeds
class PlaybackSpeedNotifier extends StateNotifier<double> {
  static const List<double> speeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];

  PlaybackSpeedNotifier() : super(1.0); // Default to 1.0x

  void setSpeed(double speed) {
    if (speeds.contains(speed)) {
      state = speed;
    }
  }

  void cycleToNext() {
    final currentIndex = speeds.indexOf(state);
    final nextIndex = (currentIndex + 1) % speeds.length;
    state = speeds[nextIndex];
  }

  String get formattedSpeed => '${state}x';
}
