import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/learning_object.dart';
import '../services/local_content_service.dart';
import '../services/audio_player_service_local.dart';
import '../utils/app_logger.dart';

/// LocalContentTestScreen - Test screen for download-first architecture
///
/// Purpose: Demonstrates loading and playing pre-processed content
/// from local files instead of streaming TTS.
///
/// Features:
/// - Load content from assets
/// - Play MP3 audio files
/// - Display pre-processed word timings
/// - Show sentence boundaries
/// - Test all playback controls
class LocalContentTestScreen extends ConsumerStatefulWidget {
  const LocalContentTestScreen({super.key});

  @override
  ConsumerState<LocalContentTestScreen> createState() =>
      _LocalContentTestScreenState();
}

class _LocalContentTestScreenState
    extends ConsumerState<LocalContentTestScreen> {
  final LocalContentService _contentService = LocalContentService();
  final AudioPlayerServiceLocal _audioService = AudioPlayerServiceLocal.instance;

  bool _isLoading = false;
  String _status = 'Ready to load content';
  Map<String, dynamic>? _contentData;
  TimingData? _timingData;
  int _currentWordIndex = -1;
  int _currentSentenceIndex = -1;

  // Test learning object ID
  static const String testId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    // Listen to position changes to update current word/sentence
    _audioService.positionStream.listen((position) {
      if (_timingData != null) {
        final positionMs = position.inMilliseconds;
        final newWordIndex = _timingData!.getCurrentWordIndex(positionMs);
        final newSentenceIndex = _timingData!.getCurrentSentenceIndex(positionMs);

        if (newWordIndex != _currentWordIndex ||
            newSentenceIndex != _currentSentenceIndex) {
          setState(() {
            _currentWordIndex = newWordIndex;
            _currentSentenceIndex = newSentenceIndex;
          });
        }
      }
    });
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading content...';
    });

    try {
      // Check if content is available
      final isAvailable = await _contentService.isContentAvailable(testId);
      if (!isAvailable) {
        throw Exception('Test content not found');
      }

      // Load content data
      _contentData = await _contentService.getContent(testId);
      setState(() {
        _status = 'Content loaded. Loading timing data...';
      });

      // Load timing data
      _timingData = await _contentService.getTimingData(testId);
      setState(() {
        _status =
            'Timing data loaded. ${_timingData!.words.length} words, ${_timingData!.sentences.length} sentences';
      });

      // Create learning object for audio player
      final learningObject = LearningObject(
        id: testId,
        assignmentId: 'test-assignment',
        title: 'Case Reserve Management',
        contentType: 'audio',
        ssmlContent: '',
        plainText: LocalContentService.getDisplayText(_contentData!),
        orderIndex: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isCompleted: false,
        currentPositionMs: 0,
      );

      // Load audio
      setState(() {
        _status = 'Loading audio file...';
      });
      await _audioService.loadLocalAudio(learningObject);

      setState(() {
        _isLoading = false;
        _status = 'Ready to play! Duration: ${_audioService.duration.inSeconds}s';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
      AppLogger.error('Failed to load content', error: e);
    }
  }

  Widget _buildContentInfo() {
    if (_contentData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No content loaded'),
        ),
      );
    }

    final metadata = _contentData!['metadata'] as Map<String, dynamic>?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Content Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Version: ${_contentData!['version']}'),
            if (metadata != null) ...[
              Text('Word Count: ${metadata['wordCount']}'),
              Text('Character Count: ${metadata['characterCount']}'),
              Text('Reading Time: ${metadata['estimatedReadingTime']}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimingInfo() {
    if (_timingData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No timing data loaded'),
        ),
      );
    }

    final currentWord = _currentWordIndex >= 0 &&
            _currentWordIndex < _timingData!.words.length
        ? _timingData!.words[_currentWordIndex]
        : null;

    final currentSentence = _currentSentenceIndex >= 0 &&
            _currentSentenceIndex < _timingData!.sentences.length
        ? _timingData!.sentences[_currentSentenceIndex]
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timing Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Total Duration: ${_timingData!.totalDurationMs / 1000}s'),
            Text('Words: ${_timingData!.words.length}'),
            Text('Sentences: ${_timingData!.sentences.length}'),
            const Divider(),
            if (currentWord != null) ...[
              Text(
                'Current Word (#$_currentWordIndex): "${currentWord.word}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Start: ${currentWord.startMs}ms'),
              Text('End: ${currentWord.endMs}ms'),
              Text('Sentence Index: ${currentWord.sentenceIndex}'),
            ] else
              const Text('No current word'),
            const SizedBox(height: 8),
            if (currentSentence != null) ...[
              Text(
                'Current Sentence (#$_currentSentenceIndex):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '"${currentSentence.text}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              Text(
                  'Words ${currentSentence.wordStartIndex}-${currentSentence.wordEndIndex}'),
            ] else
              const Text('No current sentence'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Playback Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<bool>(
              stream: _audioService.isPlayingStream,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_30),
                      iconSize: 32,
                      onPressed: _contentData != null
                          ? () => _audioService.skipBackward()
                          : null,
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      onPressed: _contentData != null
                          ? () => _audioService.togglePlayPause()
                          : null,
                      child: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.forward_30),
                      iconSize: 32,
                      onPressed: _contentData != null
                          ? () => _audioService.skipForward()
                          : null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<Duration>(
              stream: _audioService.positionStream,
              builder: (context, posSnapshot) {
                final position = posSnapshot.data ?? Duration.zero;
                final duration = _audioService.duration;

                return Column(
                  children: [
                    Slider(
                      value: position.inMilliseconds.toDouble(),
                      max: duration.inMilliseconds.toDouble(),
                      onChanged: duration.inMilliseconds > 0
                          ? (value) {
                              _audioService.seekToPosition(
                                Duration(milliseconds: value.toInt()),
                              );
                            }
                          : null,
                    ),
                    Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<double>(
              stream: _audioService.speedStream,
              builder: (context, snapshot) {
                final speed = snapshot.data ?? 1.0;
                return ElevatedButton.icon(
                  onPressed: _contentData != null
                      ? () => _audioService.cycleSpeed()
                      : null,
                  icon: const Icon(Icons.speed),
                  label: Text('Speed: ${speed}x'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Content Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _isLoading
                  ? Colors.orange.shade50
                  : (_contentData != null
                      ? Colors.green.shade50
                      : Colors.blue.shade50),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Icon(
                        _contentData != null
                            ? Icons.check_circle
                            : Icons.download,
                        size: 48,
                        color: _contentData != null
                            ? Colors.green
                            : Colors.blue,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadContent,
                      icon: const Icon(Icons.download),
                      label: const Text('Load Test Content'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildContentInfo(),
            const SizedBox(height: 16),
            _buildTimingInfo(),
            const SizedBox(height: 16),
            _buildPlaybackControls(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioService.stop();
    super.dispose();
  }
}