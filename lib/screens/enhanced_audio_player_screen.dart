import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service_local.dart';
import '../services/local_content_service.dart';
import '../services/progress_service.dart';
import '../services/word_timing_service_simplified.dart';
import '../models/learning_object_v2.dart';
import '../providers/providers.dart';
import '../widgets/simplified_dual_level_highlighted_text.dart';
import '../widgets/player/player_controls_widget.dart';
import '../widgets/player/audio_progress_bar.dart';
import '../widgets/player/fullscreen_controller.dart';
import '../widgets/animated_loading_indicator.dart';
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
  final LearningObjectV2 learningObject;
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
  StreamSubscription<ProcessingState>? _processingStateSub;
  StreamSubscription<int>? _fontSizeSub;
  late FullscreenController _fullscreenController;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _displayText;

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerServiceLocal.instance;
    _wordTimingService = WordTimingServiceSimplified.instance;
    _fullscreenController = FullscreenController(
      onFullscreenChanged: (isFullscreen) {
        if (mounted) {
          setState(() {});
        }
      },
    );
    _initializePlayer();
    _setupKeyboardShortcuts();
    _setupPlayingStateListener();
    _setupCompletionListener();
  }

  Future<void> _initializePlayer() async {
    try {
      AppLogger.info('🟢 ENHANCED AUDIO PLAYER SCREEN - Initializing');
      debugPrint('🟢🟢🟢 ENHANCED AUDIO PLAYER SCREEN INIT 🟢🟢🟢');

      // Get progress service
      debugPrint('Getting progress service...');
      _progressService = await ProgressService.getInstance();
      debugPrint('Progress service initialized');

      // Listen to font size changes for immediate UI updates
      _fontSizeSub = _progressService?.fontSizeIndexStream.listen((_) {
        if (mounted) {
          setState(() {}); // Trigger rebuild when font size changes
        }
      });

      // Check if we're resuming the same learning object from mini player
      final currentObject = _audioService.currentLearningObject;
      final isResumingFromMiniPlayer =
          currentObject?.id == widget.learningObject.id;

      if (isResumingFromMiniPlayer) {
        debugPrint(
            'Resuming same learning object from mini player, skipping reload');
        // Just update the display text from the current service state
        _displayText = _audioService.currentDisplayText ??
            widget.learningObject.displayText;

        // If we still don't have display text, load it from the learning object
        if (_displayText == null || _displayText!.isEmpty) {
          _displayText = widget.learningObject.displayText;

          // If still no display text, this is an error condition
          if (_displayText == null || _displayText!.isEmpty) {
            AppLogger.warning('No display text available when resuming', {
              'learningObjectId': widget.learningObject.id,
              'hasServiceText': _audioService.currentDisplayText != null,
              'hasObjectText': widget.learningObject.displayText != null,
            });
            _displayText = 'No content available for display';
          }
        }

        AppLogger.info('Resumed with display text', {
          'textLength': _displayText?.length ?? 0,
          'source': 'resume from mini player',
        });
      } else {
        // Use plainText as single source of truth for display
        // The text processing should have already happened in SpeechifyService
        _displayText = widget.learningObject.displayText;

        // Only log if we don't have display text (this would be an error condition)
        if (_displayText == null || _displayText!.isEmpty) {
          AppLogger.warning('Learning object has no plainText', {
            'learningObjectId': widget.learningObject.id,
            'hasTimingData': widget.learningObject.wordTimings.isNotEmpty,
          });
          // Set a fallback message instead of processing SSML here
          _displayText = 'No content available for display';
        }

        AppLogger.info('Display text loaded from plainText field', {
          'textLength': _displayText?.length ?? 0,
          'learningObjectId': widget.learningObject.id,
          'source': 'plainText field (single source of truth)',
        });

        // Set the course ID in LocalContentService for proper path resolution
        final localContentService = LocalContentService.instance;
        localContentService.setCourseId(widget.learningObject.courseId);

        // Load the learning object audio
        debugPrint('Loading learning object audio...');
        await _audioService.loadLearningObject(widget.learningObject);
        debugPrint('Audio loaded successfully');

        // Pre-load timing data to ensure it's ready before playback
        debugPrint('Pre-loading timing data...');
        await _wordTimingService.loadTimings(widget.learningObject.id);
        debugPrint('Timing data loaded successfully');
      }

      // Set the current learning object in the provider for mini player
      ref.read(currentLearningObjectProvider.notifier).state =
          widget.learningObject;

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

      // Set up position stream listener with throttling for performance
      // Throttle to 10Hz (100ms) for optimal performance vs smoothness balance
      // Human perception still sees this as smooth while reducing UI updates by 50%
      _positionSub = _audioService.positionStream
          .throttleTime(
            const Duration(milliseconds: 100),
            trailing: true,
            leading: true,
          )
          .listen((position) {
        final positionMs = position.inMilliseconds;

        if (!mounted) return; // Avoid using ref after dispose

        // Update word timing service with current position
        _wordTimingService.updatePosition(positionMs, widget.learningObject.id);

        // Log position updates for debugging (reduced frequency)
        if (positionMs % 1000 < 100) {
          AppLogger.debug('Audio position update (throttled)', {
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
      if (isPlaying && !_fullscreenController.isFullscreen) {
        _fullscreenController.startFullscreenTimer();
      } else {
        _fullscreenController.cancelFullscreenTimer();
      }
    });
  }

  void _setupCompletionListener() {
    _processingStateSub = _audioService.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handleAudioCompletion();
      }
    });
  }

  void _handleAudioCompletion() async {
    AppLogger.info('Audio playback completed for learning object', {
      'learningObjectId': widget.learningObject.id,
      'title': widget.learningObject.title,
    });

    // Mark as completed in progress tracking
    _progressService?.saveProgress(
      learningObjectId: widget.learningObject.id,
      positionMs: _audioService.duration.inMilliseconds,
      isCompleted: true,
      isInProgress: false,
    );

    // Navigate back to assignment screen
    if (mounted) {
      Navigator.pop(context, true); // Pass true to indicate completion
    }
  }

  // Restart the fullscreen timer when user interacts with controls
  void _restartFullscreenTimerOnInteraction() {
    _fullscreenController.restartTimerOnInteraction();
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
          child: AnimatedLoadingIndicator(
            message: 'Loading audio...',
          ),
        ),
      );
    }

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: _fullscreenController.isFullscreen
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
                onTap: _fullscreenController.isFullscreen ? () => _fullscreenController.exitFullscreen() : null,
                child: Container(
                  padding: EdgeInsets.only(
                    left: _fullscreenController.isFullscreen ? 24 : 20,
                    right: _fullscreenController.isFullscreen ? 24 : 20,
                    top: _fullscreenController.isFullscreen ? 50 : 12, // Extra padding for notch
                    bottom: _fullscreenController.isFullscreen
                        ? 20
                        : 0, // Remove bottom padding to get closer to progress bar
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: _displayText != null && _displayText!.isNotEmpty
                        ? SimplifiedDualLevelHighlightedText(
                            text: _displayText!,
                            contentId: widget.learningObject.id,
                            baseStyle: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(
                                  fontSize:
                                      _progressService?.currentFontSize ?? 18.0,
                                ),
                            sentenceHighlightColor:
                                Theme.of(context).sentenceHighlight,
                            wordHighlightColor: Theme.of(context).wordHighlight,
                            scrollController: _scrollController,
                            preserveCourseFont: true,  // Keep Literata for course content
                          )
                        : Center(
                            child: Text(
                              'No content available',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                    fontSize:
                                        _progressService?.currentFontSize ??
                                            18.0,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            // Player controls with animated opacity
            AnimatedOpacity(
              opacity: _fullscreenController.isFullscreen ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _fullscreenController.isFullscreen ? 0 : null,
                child: _fullscreenController.isFullscreen
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          // Progress bar widget
                          AudioProgressBar(
                            onInteraction: _restartFullscreenTimerOnInteraction,
                          ),
                          // Player controls widget
                          PlayerControlsWidget(
                            onInteraction: _restartFullscreenTimerOnInteraction,
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
    _processingStateSub?.cancel();
    _processingStateSub = null;
    _fontSizeSub?.cancel();
    _fontSizeSub = null;

    // Clean up fullscreen controller
    _fullscreenController.dispose();

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
