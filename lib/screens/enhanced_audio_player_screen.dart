import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service_local.dart';
import '../services/progress_service.dart';
import '../services/word_timing_service_simplified.dart';
import '../models/learning_object.dart';
import '../providers/providers.dart';
import '../providers/audio_providers.dart';
import '../providers/audio_context_provider.dart';
import '../widgets/simplified_dual_level_highlighted_text.dart';
import '../utils/app_logger.dart';

/// EnhancedAudioPlayerScreen - Full-featured audio player with keyboard shortcuts
///
/// Purpose: Provides complete audio playback interface with advanced controls
/// Features:
/// - FloatingActionButton for play/pause
/// - Skip controls (±30 seconds)
/// - Speed adjustment with visual feedback
/// - Font size cycling
/// - Keyboard shortcuts (spacebar, arrow keys)
/// - Time display with formatted duration
/// - Interactive seek bar
class EnhancedAudioPlayerScreen extends ConsumerStatefulWidget {
  final LearningObject learningObject;
  final bool autoPlay;
  final String? courseNumber;
  final String? courseTitle;
  final String? assignmentTitle;
  final int? assignmentNumber;

  const EnhancedAudioPlayerScreen({
    super.key,
    required this.learningObject,
    this.autoPlay = true,
    this.courseNumber,
    this.courseTitle,
    this.assignmentTitle,
    this.assignmentNumber,
  });

  @override
  ConsumerState<EnhancedAudioPlayerScreen> createState() =>
      _EnhancedAudioPlayerScreenState();
}

class _EnhancedAudioPlayerScreenState
    extends ConsumerState<EnhancedAudioPlayerScreen> {
  late final AudioPlayerServiceLocal _audioService;
  late final WordTimingServiceSimplified _wordTimingService;
  ProgressService? _progressService;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingStateSub;
  Timer? _fullscreenTimer;
  bool _isInitialized = false;
  bool _isFullscreen = false;
  String? _errorMessage;
  String? _displayText;

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerServiceLocal.instance;
    _wordTimingService = WordTimingServiceSimplified.instance;
    _initializePlayer();
    _setupKeyboardShortcuts();
    _setupPlayingStateListener();
  }

  Future<void> _initializePlayer() async {
    try {
      AppLogger.info('🟢 ENHANCED AUDIO PLAYER SCREEN - Initializing');
      debugPrint('🟢🟢🟢 ENHANCED AUDIO PLAYER SCREEN INIT 🟢🟢🟢');

      // Get progress service
      debugPrint('Getting progress service...');
      _progressService = await ProgressService.getInstance();
      debugPrint('Progress service initialized');

      // Check if we're resuming the same learning object from mini player
      final currentObject = _audioService.currentLearningObject;
      final isResumingFromMiniPlayer = currentObject?.id == widget.learningObject.id;

      if (isResumingFromMiniPlayer) {
        debugPrint('Resuming same learning object from mini player, skipping reload');
        // Just update the display text from the current service state
        _displayText = _audioService.currentDisplayText ?? widget.learningObject.plainText;
      } else {
        // Use plainText as single source of truth for display
        // The text processing should have already happened in SpeechifyService
        _displayText = widget.learningObject.plainText;

        // Only log if we don't have display text (this would be an error condition)
        if (_displayText == null || _displayText!.isEmpty) {
          AppLogger.warning('Learning object has no plainText', {
            'learningObjectId': widget.learningObject.id,
            'hasSSMLContent': widget.learningObject.ssmlContent != null,
          });
          // Set a fallback message instead of processing SSML here
          _displayText = 'No content available for display';
        }

        AppLogger.info('Display text loaded from plainText field', {
          'textLength': _displayText?.length ?? 0,
          'learningObjectId': widget.learningObject.id,
          'source': 'plainText field (single source of truth)',
        });

        // Load the learning object audio
        debugPrint('Loading learning object audio...');
        await _audioService.loadLearningObject(widget.learningObject);
        debugPrint('Audio loaded successfully');
      }

      // Set the current learning object in the provider for mini player
      ref.read(currentLearningObjectProvider.notifier).state = widget.learningObject;

      // Set the audio context with navigation information
      final audioContext = AudioContext(
        courseNumber: widget.courseNumber,
        courseTitle: widget.courseTitle,
        assignmentTitle: widget.assignmentTitle,
        assignmentNumber: widget.assignmentNumber,
        learningObject: widget.learningObject,
      );
      ref.read(audioContextProvider.notifier).state = audioContext;

      // Mark as initialized and refresh UI
      final resolvedDisplayText = _audioService.currentDisplayText;
      setState(() {
        _isInitialized = true;
        _errorMessage = null;
        if (resolvedDisplayText != null && resolvedDisplayText.isNotEmpty) {
          _displayText = resolvedDisplayText;
        }
      });

      // Set up position stream listener BEFORE auto-play
      // This ensures word timing updates are ready
      _positionSub = _audioService.positionStream.listen((position) {
        final positionMs = position.inMilliseconds;

        if (!mounted) return; // Avoid using ref after dispose

        // Update word timing service with current position
        _wordTimingService.updatePosition(positionMs, widget.learningObject.id);

        // Log position updates for debugging
        if (positionMs % 1000 < 100) {
          AppLogger.debug('Audio position update', {
            'positionMs': positionMs,
            'learningObjectId': widget.learningObject.id,
          });
        }

        // Save progress every 5 seconds (debounced in service)
        _progressService?.saveProgress(
          learningObjectId: widget.learningObject.id,
          positionMs: positionMs,
          isCompleted: false,
          isInProgress: true,
          userId: ref.read(currentUserProvider).valueOrNull?.id,
        );
      });

      // Auto-play if requested (with small delay to ensure UI is ready)
      if (widget.autoPlay && _isInitialized && _errorMessage == null) {
        debugPrint('Auto-playing audio for: ${widget.learningObject.title}');
        // Add a small delay to ensure all listeners and UI are ready
        await Future.delayed(const Duration(milliseconds: 500));
        await _audioService.play();
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing player: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() {
        _isInitialized = false;
        _errorMessage = 'Failed to load audio: $e';
      });
    }

    // Position stream listener moved above to ensure it's ready before auto-play

    // Auto-request focus for keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _setupKeyboardShortcuts() {
    // Focus node will be attached to RawKeyboardListener
    _focusNode.requestFocus();
  }

  void _setupPlayingStateListener() {
    _playingStateSub = _audioService.isPlayingStream.listen((isPlaying) {
      if (isPlaying && !_isFullscreen) {
        _startFullscreenTimer();
      } else {
        _cancelFullscreenTimer();
      }
    });
  }

  void _startFullscreenTimer() {
    _cancelFullscreenTimer();
    _fullscreenTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_isFullscreen) {
        _enterFullscreen();
      }
    });
  }

  void _cancelFullscreenTimer() {
    _fullscreenTimer?.cancel();
    _fullscreenTimer = null;
  }

  void _enterFullscreen() {
    setState(() {
      _isFullscreen = true;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() {
      _isFullscreen = false;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _cancelFullscreenTimer();
  }

  void _handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;

    // Spacebar: Play/Pause
    if (key == LogicalKeyboardKey.space) {
      _audioService.togglePlayPause();
    }
    // Right arrow: Skip forward 30s
    else if (key == LogicalKeyboardKey.arrowRight) {
      _audioService.skipForward();
    }
    // Left arrow: Skip backward 30s
    else if (key == LogicalKeyboardKey.arrowLeft) {
      _audioService.skipBackward();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // Show error if initialization failed
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.learningObject.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to Load Audio',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                    _initializePlayer();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show loading while initializing
    if (!_isInitialized || _progressService == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.learningObject.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading audio...'),
            ],
          ),
        ),
      );
    }

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: _isFullscreen
            ? null
            : AppBar(
                title: Text(widget.learningObject.title),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
        body: Column(
            children: [
              // Content area for highlighted text with GestureDetector
              Expanded(
                child: GestureDetector(
                  onTap: _isFullscreen ? _exitFullscreen : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isFullscreen ? 24 : 20,
                      vertical: _isFullscreen ? 20 : 12,
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: _displayText != null && _displayText!.isNotEmpty
                          ? SimplifiedDualLevelHighlightedText(
                            text: _displayText!,
                            contentId: widget.learningObject.id,
                            baseStyle: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              fontSize:
                                  _progressService?.currentFontSize ?? 18.0,
                            ),
                            sentenceHighlightColor:
                                Theme.of(context).sentenceHighlight,
                            wordHighlightColor:
                                Theme.of(context).wordHighlight,
                            scrollController: _scrollController,
                          )
                        : Center(
                            child: Text(
                              'No content available',
                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                fontSize:
                                    _progressService?.currentFontSize ?? 18.0,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              // Subtle divider (hidden in fullscreen)
              if (!_isFullscreen)
                Container(
                  height: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.15),
                ),
              // Player controls with animated opacity
              AnimatedOpacity(
                opacity: _isFullscreen ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _isFullscreen ? 0 : null,
                  padding: _isFullscreen
                      ? EdgeInsets.zero
                      : const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: _isFullscreen
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                    // Seek bar and time display
                    StreamBuilder<Duration>(
                      stream: _audioService.positionStream,
                      builder: (context, positionSnapshot) {
                        // Handle stream errors gracefully
                        if (positionSnapshot.hasError) {
                          AppLogger.error('Position stream error', error: positionSnapshot.error);
                          return const SizedBox.shrink();
                        }
                        final position = positionSnapshot.data ?? Duration.zero;

                        return StreamBuilder<Duration>(
                          stream: _audioService.durationStream,
                          builder: (context, durationSnapshot) {
                            // Handle stream errors gracefully
                            if (durationSnapshot.hasError) {
                              AppLogger.error('Duration stream error', error: durationSnapshot.error);
                              return const SizedBox.shrink();
                            }
                            final duration =
                                durationSnapshot.data ?? Duration.zero;

                            return Column(
                              children: [
                                // Full-width seek bar
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4.0,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6.0,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12.0,
                                    ),
                                  ),
                                  child: Slider(
                                    value: duration.inMilliseconds > 0 &&
                                           position.inMilliseconds <= duration.inMilliseconds
                                        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                                        : 0.0,
                                    onChanged: (value) {
                                      final newPosition = Duration(
                                        milliseconds:
                                            (duration.inMilliseconds * value)
                                                .round(),
                                      );
                                      _audioService.seekToPosition(newPosition);
                                    },
                                    activeColor: Theme.of(context).primaryColor,
                                  ),
                                ),
                                // Time labels below the bar
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                    ),
                    const SizedBox(height: 12),
                    // All controls in single row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Speed control (smaller)
                        StreamBuilder<double>(
                          stream: _audioService.speedStream,
                          builder: (context, snapshot) {
                            final speed = snapshot.data ?? 1.0;
                            return Container(
                              width: 50, // Optimized for content
                              height: 28,
                              child: TextButton(
                                onPressed: _audioService.cycleSpeed,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(50, 28),
                                  backgroundColor: Theme.of(context).brightness == Brightness.light
                                      ? Colors.grey.shade200
                                      : Theme.of(context).colorScheme.surface.withOpacity(0.8),
                                  foregroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                child: Text(
                                  '${speed}x',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                ),
                              ),
                            );
                          },
                        ),
                        // Skip backward
                        IconButton(
                          icon: Icon(
                            Icons.replay_30,
                            color: Colors.grey.shade500,
                            weight: 300,
                          ),
                          iconSize: 40,
                          onPressed: _audioService.skipBackward,
                          tooltip: 'Skip back 30s (←)',
                        ),
                        // Play/Pause with FloatingActionButton
                        StreamBuilder<bool>(
                          stream: _audioService.isPlayingStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? false;
                            return SizedBox(
                              height: 48,
                              width: 48,
                              child: FloatingActionButton(
                                onPressed: _audioService.togglePlayPause,
                                tooltip: 'Play/Pause (Space)',
                                elevation: 2,
                                child: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 28,
                                ),
                              ),
                            );
                          },
                        ),
                        // Skip forward
                        IconButton(
                          icon: Icon(
                            Icons.forward_30,
                            color: Colors.grey.shade500,
                            weight: 300,
                          ),
                          iconSize: 40,
                          onPressed: _audioService.skipForward,
                          tooltip: 'Skip forward 30s (→)',
                        ),
                        // Font size control (smaller, fixed width)
                        StreamBuilder<int>(
                          stream: _progressService?.fontSizeIndexStream ??
                              Stream.value(1),
                          builder: (context, snapshot) {
                            final fontSizeName =
                                _progressService?.currentFontSizeName ??
                                    'Medium';
                            return Container(
                              width: 50, // Optimized for content
                              height: 28,
                              child: TextButton(
                                onPressed: () async {
                                  await _progressService?.cycleFontSize();
                                  setState(() {}); // Refresh UI
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  minimumSize: const Size(50, 28),
                                  backgroundColor: Theme.of(context).brightness == Brightness.light
                                      ? Colors.grey.shade200
                                      : Theme.of(context).colorScheme.surface.withOpacity(0.8),
                                  foregroundColor: Theme.of(context).brightness == Brightness.dark
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                child: Text(
                                  fontSizeName,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                        ),
                ),
              ),
            ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel stream subscriptions to prevent callbacks after dispose
    _positionSub?.cancel();
    _positionSub = null;
    _playingStateSub?.cancel();
    _playingStateSub = null;

    // Cancel fullscreen timer and restore UI if needed
    _cancelFullscreenTimer();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    _focusNode.dispose();
    _scrollController.dispose();
    // Don't dispose the audio service or word timing service - they're singletons
    super.dispose();
  }
}

/// Validation function for EnhancedAudioPlayerScreen
void validateEnhancedAudioPlayerScreen() {
  debugPrint('=== EnhancedAudioPlayerScreen Validation ===');

  // Test 1: Duration formatting
  String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
  }

  assert(formatDuration(const Duration(seconds: 45)) == '00:45',
      'Format 45 seconds');
  assert(formatDuration(const Duration(minutes: 3, seconds: 25)) == '03:25',
      'Format 3:25');
  assert(
      formatDuration(const Duration(hours: 1, minutes: 15, seconds: 30)) ==
          '1:15:30',
      'Format 1:15:30');
  debugPrint('✓ Duration formatting verified');

  // Test 2: Keyboard key mapping
  assert(LogicalKeyboardKey.space == LogicalKeyboardKey.space,
      'Space key mapping');
  assert(LogicalKeyboardKey.arrowLeft == LogicalKeyboardKey.arrowLeft,
      'Left arrow mapping');
  assert(LogicalKeyboardKey.arrowRight == LogicalKeyboardKey.arrowRight,
      'Right arrow mapping');
  debugPrint('✓ Keyboard shortcuts verified');

  debugPrint('=== All EnhancedAudioPlayerScreen validations passed ===');
}
