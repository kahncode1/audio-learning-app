/// Enhanced Audio Player Screen (Refactored)
///
/// Purpose: Provides complete audio playback interface using modular widgets
/// This is the refactored version using extracted components
///
/// Features:
/// - Uses extracted player controls widget
/// - Uses keyboard shortcut handler
/// - Uses fullscreen controller
/// - Uses highlighted text display
/// - Maintains all original functionality with better organization
///
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../theme/app_theme.dart';
import '../services/audio_player_service_local.dart';
import '../services/progress_service.dart';
import '../services/word_timing_service_simplified.dart';
import '../models/learning_object.dart';
import '../providers/providers.dart';
import '../widgets/player/player_controls_widget.dart';
import '../widgets/player/keyboard_shortcut_handler.dart';
import '../widgets/player/fullscreen_controller.dart';
import '../widgets/player/highlighted_text_display.dart';
import '../utils/app_logger.dart';

class EnhancedAudioPlayerScreenRefactored extends ConsumerStatefulWidget {
  final LearningObject learningObject;
  final bool autoPlay;
  final String? courseNumber;
  final String? courseTitle;
  final String? assignmentTitle;
  final int? assignmentNumber;

  const EnhancedAudioPlayerScreenRefactored({
    super.key,
    required this.learningObject,
    this.autoPlay = true,
    this.courseNumber,
    this.courseTitle,
    this.assignmentTitle,
    this.assignmentNumber,
  });

  @override
  ConsumerState<EnhancedAudioPlayerScreenRefactored> createState() =>
      _EnhancedAudioPlayerScreenRefactoredState();
}

class _EnhancedAudioPlayerScreenRefactoredState
    extends ConsumerState<EnhancedAudioPlayerScreenRefactored> {
  late final AudioPlayerServiceLocal _audioService;
  late final WordTimingServiceSimplified _wordTimingService;
  final GlobalKey<FullscreenControllerState> _fullscreenKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  ProgressService? _progressService;
  StreamSubscription<bool>? _playingStateSub;
  StreamSubscription<ProcessingState>? _processingStateSub;

  bool _isInitialized = false;
  String? _errorMessage;
  String? _displayText;

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerServiceLocal.instance;
    _wordTimingService = WordTimingServiceSimplified.instance;
    _initializePlayer();
    _setupPlayingStateListener();
    _setupCompletionListener();
  }

  Future<void> _initializePlayer() async {
    try {
      AppLogger.info('🟢 ENHANCED AUDIO PLAYER SCREEN (REFACTORED) - Initializing');

      // Get progress service
      _progressService = await ProgressService.getInstance();

      // Check if we're resuming the same learning object from mini player
      final currentObject = _audioService.currentLearningObject;
      final isResumingFromMiniPlayer = currentObject?.id == widget.learningObject.id;

      if (isResumingFromMiniPlayer) {
        debugPrint('Resuming same learning object from mini player');
        _displayText = _audioService.currentDisplayText ?? widget.learningObject.plainText;
      } else {
        _displayText = widget.learningObject.plainText;

        if (_displayText == null || _displayText!.isEmpty) {
          AppLogger.warning('No display text available', {
            'learningObjectId': widget.learningObject.id,
          });
        }

        // Initialize audio service with learning object
        await _audioService.initializeFromLearningObject(
          widget.learningObject,
          autoPlay: widget.autoPlay,
        );

        // Initialize word timing service
        await _wordTimingService.loadTimings(widget.learningObject.id);

        // Set audio context for mini player
        ref.read(audioContextProvider.notifier).setContext(
          courseNumber: widget.courseNumber,
          courseTitle: widget.courseTitle,
          assignmentTitle: widget.assignmentTitle,
          assignmentNumber: widget.assignmentNumber,
          learningObjectTitle: widget.learningObject.title,
        );
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      AppLogger.error('Failed to initialize player', error: e);
      setState(() {
        _errorMessage = 'Failed to initialize: $e';
        _isInitialized = true;
      });
    }
  }

  void _setupPlayingStateListener() {
    _playingStateSub = _audioService.playingStream.listen((isPlaying) {
      if (isPlaying) {
        _fullscreenKey.currentState?.handleInteraction();
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
    AppLogger.info('Audio completed, returning to previous screen');
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleInteraction() {
    _fullscreenKey.currentState?.handleInteraction();
  }

  void _toggleFullscreen() {
    _fullscreenKey.currentState?.toggleFullscreen();
  }

  @override
  void dispose() {
    _playingStateSub?.cancel();
    _processingStateSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.learningObject.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.learningObject.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Audio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return KeyboardShortcutHandler(
      audioService: _audioService,
      onToggleFullscreen: _toggleFullscreen,
      onInteraction: _handleInteraction,
      child: FullscreenController(
        key: _fullscreenKey,
        enabled: true,
        autoEnterDelay: const Duration(seconds: 10),
        builder: (context, isFullscreen, child) {
          return Scaffold(
            backgroundColor: isFullscreen ? Colors.black : null,
            appBar: isFullscreen
                ? null
                : AppBar(
                    title: Text(widget.learningObject.title),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.help_outline),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const KeyboardShortcutHelp(),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ],
                  ),
            body: Column(
              children: [
                // Highlighted text content
                Expanded(
                  child: GestureDetector(
                    onTap: isFullscreen
                        ? () => _fullscreenKey.currentState?.exitFullscreen()
                        : null,
                    child: HighlightedTextDisplay(
                      displayText: _displayText,
                      contentId: widget.learningObject.id,
                      scrollController: _scrollController,
                      progressService: _progressService,
                      isFullscreen: isFullscreen,
                    ),
                  ),
                ),
                // Player controls
                AnimatedOpacity(
                  opacity: isFullscreen ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: isFullscreen ? 0 : null,
                    child: isFullscreen
                        ? const SizedBox.shrink()
                        : PlayerControlsWidget(
                            audioService: _audioService,
                            onInteraction: _handleInteraction,
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}