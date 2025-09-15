import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_player_service.dart';
import '../services/word_timing_service.dart';
import '../widgets/dual_level_highlighted_text.dart';
import '../models/learning_object.dart';
import '../providers/providers.dart';
import '../utils/app_logger.dart';

/// AudioPlayerScreen provides the main audio playback interface
/// with dual-level word highlighting and advanced controls
class AudioPlayerScreen extends ConsumerStatefulWidget {
  final String learningObjectId;
  final String title;

  const AudioPlayerScreen({
    super.key,
    required this.learningObjectId,
    required this.title,
  });

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> {
  late final AudioPlayerService _audioService;
  late final WordTimingService _wordTimingService;
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _positionSubscription;
  bool _isLoading = true;
  String _contentText = '';
  LearningObject? _learningObject;

  // Font size options
  final List<double> _fontSizes = [14.0, 16.0, 18.0, 20.0]; // Small, Medium, Large, XLarge
  int _fontSizeIndex = 1; // Default to Medium

  // Keyboard focus for shortcuts
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _audioService = AudioPlayerService.instance;
    _wordTimingService = WordTimingService.instance;
    _initializeAudio();
    _focusNode.requestFocus(); // Get keyboard focus for shortcuts
  }

  Future<void> _initializeAudio() async {
    try {
      AppLogger.info('Initializing audio for learning object',
        {'id': widget.learningObjectId});

      // Load learning object content - fetch directly from Supabase
      final supabaseService = ref.read(supabaseServiceProvider);
      final learningObjects = await supabaseService.fetchLearningObjects('');
      _learningObject = learningObjects.firstWhere(
        (lo) => lo.id == widget.learningObjectId,
        orElse: () => LearningObject(
          id: widget.learningObjectId,
          assignmentId: '',
          title: widget.title,
          ssmlContent: null,
          plainText: null,
          orderIndex: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (_learningObject != null) {
        // Get content for display
        String displayText = '';
        if (_learningObject!.ssmlContent != null && _learningObject!.ssmlContent!.isNotEmpty) {
          // Convert SSML to plain text for display
          displayText = _convertSSMLToPlainText(_learningObject!.ssmlContent!);
          AppLogger.info('Converted SSML to display text', {
            'ssmlLength': _learningObject!.ssmlContent!.length,
            'displayTextLength': displayText.length,
            'displayText': displayText,
          });
        } else if (_learningObject!.plainText != null && _learningObject!.plainText!.isNotEmpty) {
          // Use plain text if available
          displayText = _learningObject!.plainText!;
          AppLogger.info('Using plain text for display', {
            'displayTextLength': displayText.length,
            'displayText': displayText,
          });
        }

        if (displayText.isNotEmpty) {
          setState(() {
            _contentText = displayText;
            _isLoading = false;
          });

          AppLogger.info('Set content text for display', {
            'contentTextLength': _contentText.length,
            'contentText': _contentText,
          });

          // Load audio for the learning object
          // This will also share word timings with WordTimingService
          await _audioService.loadLearningObject(_learningObject!);

          AppLogger.info('Fetching word timings for full text', {
            'textLength': displayText.length,
            'text': displayText,
          });

          // Fetch the cached timings (won't make API call, just gets from cache)
          await _wordTimingService.fetchTimings(
            widget.learningObjectId,
            displayText,
          );

          // Log what timings we got
          final cachedTimings = _wordTimingService.getCachedTimings(widget.learningObjectId);
          AppLogger.info('Word timings loaded', {
            'timingCount': cachedTimings?.length ?? 0,
            'firstWord': cachedTimings?.isNotEmpty == true ? cachedTimings!.first.word : 'none',
            'lastWord': cachedTimings?.isNotEmpty == true ? cachedTimings!.last.word : 'none',
          });

          // Set up position listener for word highlighting
          _setupPositionListener();
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to initialize audio', error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupPositionListener() {
    _positionSubscription = _audioService.positionStream.listen((position) {
      final positionMs = position.inMilliseconds;

      // Debug: Log position updates periodically
      if (positionMs % 1000 < 100) { // Log roughly every second
        AppLogger.debug('Audio position update', {
          'positionMs': positionMs,
          'positionSeconds': position.inSeconds,
          'learningObjectId': widget.learningObjectId,
        });
      }

      _wordTimingService.updatePosition(positionMs, widget.learningObjectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          // Font size selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.text_fields),
            tooltip: 'Font Size',
            onSelected: (index) {
              setState(() {
                _fontSizeIndex = index;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Small')),
              const PopupMenuItem(value: 1, child: Text('Medium')),
              const PopupMenuItem(value: 2, child: Text('Large')),
              const PopupMenuItem(value: 3, child: Text('Extra Large')),
            ],
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Content area with dual-level highlighted text
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _contentText.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.article,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No content available',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              child: DualLevelHighlightedText(
                                text: _contentText,
                                contentId: widget.learningObjectId,
                                baseStyle: TextStyle(
                                  fontSize: _fontSizes[_fontSizeIndex],
                                  height: 1.5,
                                  color: Colors.black87,
                                ),
                                onWordTap: _seekToWord,
                                scrollController: _scrollController,
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
                  // Progress bar with time labels
                  StreamBuilder<Duration>(
                    stream: _audioService.positionStream,
                    builder: (context, positionSnapshot) {
                      return StreamBuilder<Duration>(
                        stream: _audioService.durationStream,
                        builder: (context, durationSnapshot) {
                          final position = positionSnapshot.data ?? Duration.zero;
                          final duration = durationSnapshot.data ?? Duration.zero;
                          final progress = duration.inMilliseconds > 0
                              ? position.inMilliseconds / duration.inMilliseconds
                              : 0.0;

                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                ),
                                child: Slider(
                                  value: progress.clamp(0.0, 1.0),
                                  onChanged: (value) {
                                    final newPosition = Duration(
                                      milliseconds: (duration.inMilliseconds * value).round(),
                                    );
                                    _audioService.seekToPosition(newPosition);
                                  },
                                  activeColor: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Control buttons
                  StreamBuilder<bool>(
                    stream: _audioService.isPlayingStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_30),
                            iconSize: 32,
                            onPressed: _skipBackward,
                            tooltip: 'Skip back 30s',
                          ),
                          FloatingActionButton(
                            onPressed: _togglePlayPause,
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 32,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.forward_30),
                            iconSize: 32,
                            onPressed: _skipForward,
                            tooltip: 'Skip forward 30s',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Speed control
                  StreamBuilder<double>(
                    stream: _audioService.speedStream,
                    builder: (context, snapshot) {
                      final speed = snapshot.data ?? 1.0;
                      return TextButton.icon(
                        icon: const Icon(Icons.speed),
                        label: Text('${speed}x'),
                        onPressed: _cycleSpeed,
                      );
                    },
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

  // Convert SSML content to plain text for display
  String _convertSSMLToPlainText(String ssml) {
    // Remove all XML/SSML tags
    String plainText = ssml;

    // Remove <speak> tags
    plainText = plainText.replaceAll(RegExp(r'</?speak>'), '');

    // Remove <p> tags but keep the content
    plainText = plainText.replaceAll(RegExp(r'</?p>'), ' ');

    // Remove <mark> tags but keep the content
    plainText = plainText.replaceAll(RegExp(r'</?mark>'), '');

    // Remove any other XML tags
    plainText = plainText.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Clean up multiple spaces
    plainText = plainText.replaceAll(RegExp(r'\s+'), ' ');

    // Trim whitespace
    plainText = plainText.trim();

    return plainText;
  }

  // Player control methods
  void _togglePlayPause() {
    if (_audioService.isPlaying) {
      _audioService.pause();
    } else {
      _audioService.play();
    }
  }

  void _skipForward() {
    _audioService.skipForward();
  }

  void _skipBackward() {
    _audioService.skipBackward();
  }

  void _cycleSpeed() {
    _audioService.cycleSpeed();
  }

  // Seek to a specific word when tapped
  void _seekToWord(int wordIndex) async {
    try {
      final timings = _wordTimingService.getCachedTimings(widget.learningObjectId);
      if (timings != null && wordIndex >= 0 && wordIndex < timings.length) {
        final timing = timings[wordIndex];
        final position = Duration(milliseconds: timing.startMs);
        await _audioService.seekToPosition(position);
        AppLogger.debug('Seeked to word', {'index': wordIndex, 'word': timing.word});
      }
    } catch (e) {
      AppLogger.error('Failed to seek to word', error: e);
    }
  }

  // Handle keyboard shortcuts
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _skipBackward();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _skipForward();
      }
    }
  }

  // Format duration for display
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
