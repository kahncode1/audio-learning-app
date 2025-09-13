# /implementations/audio-player-screen.dart

```dart
/// Audio Player Screen with Advanced Controls and Dual-Level Highlighting
/// 
/// This implementation provides the complete audio player UI with:
/// - Dual-level word and sentence highlighting
/// - Advanced playback controls (play/pause, skip, speed, font size)
/// - Keyboard shortcuts for power users
/// - Progress tracking with preference persistence
/// - Material Design with FloatingActionButton

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_learning_app/models/learning_object.dart';
import 'package:audio_learning_app/services/word_timing_service.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final LearningObject learningObject;

  const PlayerPage({
    super.key,
    required this.learningObject,
  });

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late AudioPlayer _audioPlayer;
  late WordTimingService _wordTimingService;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  // Font size options
  final List<String> fontSizes = ['Small', 'Medium', 'Large', 'XLarge'];
  
  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus(); // For keyboard shortcuts
    _initializePlayer();
  }
  
  Future<void> _initializePlayer() async {
    _audioPlayer = AudioPlayer();
    _wordTimingService = WordTimingService(dio: ref.read(dioProvider));
    
    // Configure audio session for speech
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    
    // Load word timings
    await _wordTimingService.fetchTimings(widget.learningObject.loid);
    
    // Get saved preferences
    final savedSpeed = ref.read(playbackSpeedProvider);
    final savedFontSize = ref.read(fontSizeIndexProvider);
    
    // Create audio source with connection pooling
    final audioSource = SpeechifyAudioSource(
      ssml: widget.learningObject.ssmlContent,
      speed: savedSpeed,
      dio: ref.read(dioProvider),
    );
    
    await _audioPlayer.setAudioSource(audioSource);
    await _audioPlayer.setSpeed(savedSpeed);
    
    // Resume from last position if available
    if (widget.learningObject.lastPosition != null) {
      await _audioPlayer.seek(widget.learningObject.lastPosition!);
    }
    
    // Listen to position updates for highlighting
    _audioPlayer.positionStream.listen((position) {
      _wordTimingService.updatePosition(position);
      
      // Update UI state for word and sentence highlighting
      ref.read(positionProvider.notifier).state = 
          position.inMilliseconds / (_audioPlayer.duration?.inMilliseconds ?? 1);
    });
    
    // Auto-save progress every 5 seconds
    _audioPlayer.positionStream
        .throttleTime(const Duration(seconds: 5))
        .listen((position) {
          ref.read(progressProvider.notifier).saveProgress(
            widget.learningObject.loid,
            position,
            ref.read(playbackSpeedProvider),
            ref.read(fontSizeIndexProvider),
          );
        });
    
    // Update playing state
    _audioPlayer.playerStateStream.listen((state) {
      ref.read(isPlayingProvider.notifier).state = state.playing;
    });
  }
  
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _skip(-30);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _skip(30);
      }
    }
  }
  
  void _togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }
  
  void _skip(int seconds) {
    final newPosition = _audioPlayer.position + Duration(seconds: seconds);
    _audioPlayer.seek(newPosition.clamp(
      Duration.zero,
      _audioPlayer.duration ?? Duration.zero,
    ));
  }
  
  void _seekToWord(int wordIndex) {
    final timing = _wordTimingService.getWordTiming(wordIndex);
    if (timing != null) {
      _audioPlayer.seek(Duration(milliseconds: timing.startMs));
    }
  }
  
  double _getFontSize() {
    final fontSizeIndex = ref.watch(fontSizeIndexProvider);
    switch (fontSizeIndex) {
      case 0:
        return 14; // Small
      case 1:
        return 18; // Medium
      case 2:
        return 22; // Large
      case 3:
        return 26; // XLarge
      default:
        return 18;
    }
  }
  
  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(isPlayingProvider);
    final position = ref.watch(positionProvider);
    final playbackSpeed = ref.watch(playbackSpeedProvider);
    final fontSizeIndex = ref.watch(fontSizeIndexProvider);
    
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.learningObject.title),
        ),
        body: Column(
          children: [
            // Text Area with dual-level highlighting
            Expanded(
              child: Container(
                color: Colors.white,
                width: double.infinity,
                child: StreamBuilder<int>(
                  stream: _wordTimingService.currentWordIndex,
                  builder: (context, wordSnapshot) {
                    return StreamBuilder<int>(
                      stream: _wordTimingService.currentSentenceIndex,
                      builder: (context, sentenceSnapshot) {
                        return SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(20),
                          child: RepaintBoundary(
                            child: _buildHighlightedText(
                              text: widget.learningObject.ssmlContent,
                              fontSize: _getFontSize(),
                              currentSentenceIndex: sentenceSnapshot.data ?? -1,
                              currentWordIndex: wordSnapshot.data ?? -1,
                              onWordTap: _seekToWord,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            
            // Controls
            Material(
              elevation: 4,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  children: [
                    // Seek bar with time labels
                    StreamBuilder<Duration>(
                      stream: _audioPlayer.positionStream,
                      builder: (context, snapshot) {
                        final currentPosition = snapshot.data ?? Duration.zero;
                        final duration = _audioPlayer.duration ?? Duration.zero;
                        
                        return Row(
                          children: [
                            Text(
                              _formatDuration(currentPosition),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: duration.inMilliseconds > 0 
                                    ? (currentPosition.inMilliseconds / duration.inMilliseconds)
                                        .clamp(0.0, 1.0)
                                    : 0.0,
                                onChanged: (double value) {
                                  final newPosition = Duration(
                                    milliseconds: (value * duration.inMilliseconds).round(),
                                  );
                                  _audioPlayer.seek(newPosition);
                                },
                                activeColor: const Color(0xFF2196F3),
                                inactiveColor: Colors.grey.shade300,
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    
                    // Control buttons with speed and font size
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Left-aligned playback speed button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () {
                                double newSpeed = playbackSpeed + 0.25;
                                if (newSpeed > 2.0) newSpeed = 0.8;
                                ref.read(playbackSpeedProvider.notifier).state = newSpeed;
                                _audioPlayer.setSpeed(newSpeed);
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFF5F5F5),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                '${playbackSpeed}x',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF424242),
                                ),
                              ),
                            ),
                          ),
                          
                          // Right-aligned font size button
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                ref.read(fontSizeIndexProvider.notifier).update(
                                      (state) => (state + 1) % fontSizes.length,
                                    );
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFF5F5F5),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.text_fields,
                                    size: 20,
                                    color: Color(0xFF424242),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    fontSizes[fontSizeIndex],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF424242),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Centered playback controls with FAB
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlayerControlIcon(
                                icon: Icons.replay_30,
                                onPressed: () => _skip(-30),
                                tooltip: 'Replay 30s (←)',
                              ),
                              const SizedBox(width: 24),
                              SizedBox(
                                width: 64,
                                height: 64,
                                child: FloatingActionButton(
                                  elevation: 4,
                                  backgroundColor: const Color(0xFF2196F3),
                                  onPressed: _togglePlayPause,
                                  child: StreamBuilder<PlayerState>(
                                    stream: _audioPlayer.playerStateStream,
                                    builder: (context, snapshot) {
                                      final state = snapshot.data;
                                      final processingState = state?.processingState;
                                      
                                      if (processingState == ProcessingState.loading ||
                                          processingState == ProcessingState.buffering) {
                                        return const CircularProgressIndicator(
                                          color: Colors.white,
                                        );
                                      }
                                      
                                      return Icon(
                                        isPlaying ? Icons.pause : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 32,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              PlayerControlIcon(
                                icon: Icons.forward_30,
                                onPressed: () => _skip(30),
                                tooltip: 'Forward 30s (→)',
                              ),
                            ],
                          ),
                        ],
                      ),
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
  
  // Build text with dual-level highlighting
  Widget _buildHighlightedText({
    required String text,
    required double fontSize,
    required int currentSentenceIndex,
    required int currentWordIndex,
    required Function(int) onWordTap,
  }) {
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    final allWords = text.split(' ');
    
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          height: 1.8,
          color: const Color(0xFF424242),
        ),
        children: sentences.asMap().entries.expand<TextSpan>((sentenceEntry) {
          final sentenceIndex = sentenceEntry.key;
          final sentence = sentenceEntry.value;
          final isCurrentSentence = sentenceIndex == currentSentenceIndex;
          final words = sentence.split(' ');
          
          List<TextSpan> spans = [];
          int globalWordStart = 0;
          
          // Calculate global word index start for this sentence
          for (int i = 0; i < sentenceIndex; i++) {
            globalWordStart += sentences[i].split(' ').length;
          }
          
          if (isCurrentSentence) {
            // Current sentence with light blue background
            spans.addAll(words.asMap().entries.map((wordEntry) {
              final wordIndex = wordEntry.key;
              final word = wordEntry.value;
              final globalWordIndex = globalWordStart + wordIndex;
              final isCurrentWord = globalWordIndex == currentWordIndex;
              
              return TextSpan(
                text: wordIndex == words.length - 1 ? word : '$word ',
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.8,
                  color: isCurrentWord
                      ? const Color(0xFF1976D2) // Darker blue for current word
                      : const Color(0xFF424242),
                  backgroundColor: isCurrentWord
                      ? const Color(0xFFFFF59D) // Yellow for current word
                      : const Color(0xFFE3F2FD), // Light blue for sentence
                  fontWeight: isCurrentWord ? FontWeight.w600 : FontWeight.normal,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => onWordTap(globalWordIndex),
              );
            }).toList());
          } else {
            // Regular sentence
            spans.add(
              TextSpan(
                text: sentence,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    // Find first word of this sentence
                    onWordTap(globalWordStart);
                  },
              ),
            );
          }
          
          if (sentenceIndex < sentences.length - 1) {
            spans.add(const TextSpan(text: ' '));
          }
          
          return spans;
        }).toList(),
      ),
    );
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    _wordTimingService.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class PlayerControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const PlayerControlIcon({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Icon(
                icon,
                color: const Color(0xFF757575),
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```