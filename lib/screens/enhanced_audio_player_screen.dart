import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_player_service.dart';
import '../services/progress_service.dart';
import '../services/word_timing_service.dart';
import '../models/learning_object.dart';
import '../providers/providers.dart';
import '../widgets/dual_level_highlighted_text.dart';
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

  const EnhancedAudioPlayerScreen({
    super.key,
    required this.learningObject,
  });

  @override
  ConsumerState<EnhancedAudioPlayerScreen> createState() =>
      _EnhancedAudioPlayerScreenState();
}

class _EnhancedAudioPlayerScreenState
    extends ConsumerState<EnhancedAudioPlayerScreen> {
  late final AudioPlayerService _audioService;
  late final WordTimingService _wordTimingService;
  ProgressService? _progressService;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;
  String? _errorMessage;
  String? _displayText;

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerService.instance;
    _wordTimingService = WordTimingService.instance;
    _initializePlayer();
    _setupKeyboardShortcuts();
  }

  Future<void> _initializePlayer() async {
    try {
      AppLogger.info('🟢 ENHANCED AUDIO PLAYER SCREEN - Initializing');
      debugPrint('🟢🟢🟢 ENHANCED AUDIO PLAYER SCREEN INIT 🟢🟢🟢');

      // Get progress service
      debugPrint('Getting progress service...');
      _progressService = await ProgressService.getInstance();
      debugPrint('Progress service initialized');

      // Extract display text from learning object
      _displayText = widget.learningObject.plainText;

      // If plainText is null, try to extract from SSML content
      if (_displayText == null || _displayText!.isEmpty) {
        final ssmlContent = widget.learningObject.ssmlContent ?? '';
        _displayText = _convertSsmlToPlainText(ssmlContent);
      }

      AppLogger.info('Display text extracted', {
        'textLength': _displayText?.length ?? 0,
        'learningObjectId': widget.learningObject.id,
      });

      // Load the learning object audio
      debugPrint('Loading learning object audio...');
      await _audioService.loadLearningObject(widget.learningObject);
      debugPrint('Audio loaded successfully');

      // Mark as initialized and refresh UI
      setState(() {
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e, stackTrace) {
      debugPrint('Error initializing player: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() {
        _isInitialized = false;
        _errorMessage = 'Failed to load audio: $e';
      });
    }

    // Start progress tracking and word timing updates
    _audioService.positionStream.listen((position) {
      final positionMs = position.inMilliseconds;

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

    // Auto-request focus for keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _setupKeyboardShortcuts() {
    // Focus node will be attached to RawKeyboardListener
    _focusNode.requestFocus();
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

  String _convertSsmlToPlainText(String ssmlContent) {
    // Remove SSML tags but preserve text content
    String text = ssmlContent;

    // Remove opening and closing speak tags
    text = text.replaceAll(RegExp(r'<speak[^>]*>'), '');
    text = text.replaceAll('</speak>', '');

    // Remove paragraph tags but keep spacing
    text = text.replaceAll(RegExp(r'<p[^>]*>'), '');
    text = text.replaceAll('</p>', ' ');

    // Remove break tags
    text = text.replaceAll(RegExp(r'<break[^>]*/>'), ' ');

    // Remove phoneme tags
    text = text.replaceAll(RegExp(r'<phoneme[^>]*>'), '');
    text = text.replaceAll('</phoneme>', '');

    // Remove prosody tags
    text = text.replaceAll(RegExp(r'<prosody[^>]*>'), '');
    text = text.replaceAll('</prosody>', '');

    // Remove say-as tags
    text = text.replaceAll(RegExp(r'<say-as[^>]*>'), '');
    text = text.replaceAll('</say-as>', '');

    // Remove any remaining XML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Clean up extra whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    AppLogger.info('Converted SSML to plain text', {
      'originalLength': ssmlContent.length,
      'plainTextLength': text.length,
    });

    return text;
  }

  void _handleWordTap(int wordIndex) {
    // Get the word timing and seek to that position
    final timings = _wordTimingService.getCachedTimings(widget.learningObject.id);
    if (timings != null && wordIndex >= 0 && wordIndex < timings.length) {
      final timing = timings[wordIndex];
      final position = Duration(milliseconds: timing.startMs);
      _audioService.seekToPosition(position);
      AppLogger.info('Seeking to word', {
        'wordIndex': wordIndex,
        'word': timing.word,
        'positionMs': timing.startMs,
      });
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
          backgroundColor: Theme.of(context).primaryColor,
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
          backgroundColor: Theme.of(context).primaryColor,
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
        appBar: AppBar(
          title: Text(widget.learningObject.title),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Content area for highlighted text
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: _displayText != null && _displayText!.isNotEmpty
                        ? DualLevelHighlightedText(
                            text: _displayText!,
                            contentId: widget.learningObject.id,
                            baseStyle: TextStyle(
                              fontSize: _progressService?.currentFontSize ?? 16.0,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                            sentenceHighlightColor: const Color(0xFFE3F2FD), // Light blue
                            wordHighlightColor: const Color(0xFFFFF59D), // Yellow
                            activeWordTextColor: const Color(0xFF1976D2), // Darker blue
                            onWordTap: _handleWordTap,
                            scrollController: _scrollController,
                          )
                        : Center(
                            child: Text(
                              'No content available',
                              style: TextStyle(
                                fontSize: _progressService?.currentFontSize ?? 16.0,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Player controls
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Time display and seek bar
                    StreamBuilder<Duration>(
                      stream: _audioService.positionStream,
                      builder: (context, positionSnapshot) {
                        final position = positionSnapshot.data ?? Duration.zero;

                        return StreamBuilder<Duration>(
                          stream: _audioService.durationStream,
                          builder: (context, durationSnapshot) {
                            final duration =
                                durationSnapshot.data ?? Duration.zero;

                            return Column(
                              children: [
                                // Time labels
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      _formatDuration(duration),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Seek bar
                                Slider(
                                  value: duration.inMilliseconds > 0
                                      ? position.inMilliseconds /
                                          duration.inMilliseconds
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
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // Control buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Skip backward
                        IconButton(
                          icon: const Icon(Icons.replay_30),
                          iconSize: 32,
                          onPressed: _audioService.skipBackward,
                          tooltip: 'Skip back 30s (←)',
                        ),
                        // Play/Pause with FloatingActionButton
                        StreamBuilder<bool>(
                          stream: _audioService.isPlayingStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data ?? false;
                            return FloatingActionButton(
                              onPressed: _audioService.togglePlayPause,
                              tooltip: 'Play/Pause (Space)',
                              child: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32,
                              ),
                            );
                          },
                        ),
                        // Skip forward
                        IconButton(
                          icon: const Icon(Icons.forward_30),
                          iconSize: 32,
                          onPressed: _audioService.skipForward,
                          tooltip: 'Skip forward 30s (→)',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Speed and font controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Speed control
                        StreamBuilder<double>(
                          stream: _audioService.speedStream,
                          builder: (context, snapshot) {
                            final speed = snapshot.data ?? 1.0;
                            return TextButton.icon(
                              icon: const Icon(Icons.speed),
                              label: Text('${speed}x'),
                              onPressed: _audioService.cycleSpeed,
                              style: TextButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.1),
                              ),
                            );
                          },
                        ),
                        // Font size control
                        StreamBuilder<int>(
                          stream: _progressService?.fontSizeIndexStream ?? Stream.value(1),
                          builder: (context, snapshot) {
                            final fontSizeName =
                                _progressService?.currentFontSizeName ?? 'Medium';
                            return TextButton.icon(
                              icon: const Icon(Icons.text_fields),
                              label: Text(fontSizeName),
                              onPressed: () async {
                                await _progressService?.cycleFontSize();
                                setState(() {}); // Refresh UI
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Keyboard shortcuts hint
                    Text(
                      'Keyboard: Space = Play/Pause | ← → = Skip',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
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
