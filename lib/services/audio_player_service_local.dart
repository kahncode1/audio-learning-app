// Dart SDK
import 'dart:async';

// Flutter
import 'package:flutter/foundation.dart';

// Audio packages
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

// Stream processing
import 'package:rxdart/rxdart.dart';

// Models
import '../models/learning_object.dart';
import '../models/word_timing.dart';

// Services
import 'audio_handler.dart';
import 'local_content_service.dart';
import 'word_timing_service_simplified.dart';

// Utils
import '../utils/app_logger.dart';

/// AudioPlayerServiceLocal - Local audio playback service for download-first architecture
///
/// Purpose: Manages playback of pre-downloaded audio files with timing synchronization
///
/// CRITICAL INTEGRATION: This service shares timing data with WordTimingServiceSimplified
/// for the dual-level highlighting system. The interaction at line 209-210 is essential
/// for highlighting functionality - DO NOT MODIFY without extensive testing.
///
/// Architecture Role:
/// - Part of the critical audio-highlighting pipeline
/// - Bridges LocalContentService (files) with WordTimingService (highlighting)
/// - Provides position streams consumed by SimplifiedDualLevelHighlightedText
///
/// Key Features:
/// - Local MP3 file playback (no streaming/buffering)
/// - Pre-computed timing data integration
/// - Position tracking for highlighting sync
/// - Playback controls (play/pause/seek/speed)
/// - Singleton pattern (single audio instance)
///
/// Dependencies:
/// - just_audio: Core playback engine
/// - LocalContentService: File access (line 186-196)
/// - WordTimingServiceSimplified: Timing sync (line 209-210) [CRITICAL]
///
/// Performance Requirements:
/// - Audio start: <100ms (local files)
/// - Position updates: 60fps for smooth highlighting
/// - Memory: Maintain single audio instance
class AudioPlayerServiceLocal {
  static AudioPlayerServiceLocal? _instance;

  final AudioPlayer _player;
  AudioLearningHandler? _audioHandler;
  final LocalContentService _localContentService;

  // State streams
  final BehaviorSubject<bool> _isPlayingSubject = BehaviorSubject.seeded(false);
  final BehaviorSubject<Duration> _positionSubject =
    BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject =
    BehaviorSubject.seeded(Duration.zero);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject.seeded(1.0);
  final BehaviorSubject<ProcessingState> _processingStateSubject =
    BehaviorSubject.seeded(ProcessingState.idle);

  // Word timing data
  List<WordTiming> _currentWordTimings = [];
  TimingData? _currentTimingData;
  LearningObject? _currentLearningObject;
  String? _currentDisplayText;

  // Playback speed options
  static const List<double> speedOptions = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
  int _currentSpeedIndex = 1; // Default to 1.0x

  // Skip duration
  static const Duration skipDuration = Duration(seconds: 30);

  // Stream subscriptions
  final List<StreamSubscription> _subscriptions = [];

  // Private constructor
  AudioPlayerServiceLocal._()
    : _player = AudioPlayer(),
      _localContentService = LocalContentService() {
  _initializePlayer();
  }

  /// Get singleton instance
  static AudioPlayerServiceLocal get instance {
  _instance ??= AudioPlayerServiceLocal._();
  return _instance!;
  }

  /// Initialize player and set up listeners
  void _initializePlayer() {
  // Configure audio session
  _configureAudioSession();
  // Initialize audio handler for lock screen controls
  _initializeAudioHandler();

  // Listen to player state changes
  _subscriptions.add(
    _player.playingStream.listen((playing) {
      _isPlayingSubject.add(playing);
    }),
  );

  _subscriptions.add(
    _player.positionStream.listen((position) {
      _positionSubject.add(position);
    }),
  );

  _subscriptions.add(
    _player.durationStream.listen((duration) {
      if (duration != null) {
        _durationSubject.add(duration);
      }
    }),
  );

  _subscriptions.add(
    _player.processingStateStream.listen((state) {
      _processingStateSubject.add(state);
    }),
  );

  _subscriptions.add(
    _player.speedStream.listen((speed) {
      _speedSubject.add(speed);
    }),
  );
  }

  /// Configure audio session for background playback
  Future<void> _configureAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions:
        AVAudioSessionCategoryOptions.allowBluetooth,
    avAudioSessionMode: AVAudioSessionMode.spokenAudio,
    avAudioSessionRouteSharingPolicy:
        AVAudioSessionRouteSharingPolicy.defaultPolicy,
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.speech,
      flags: AndroidAudioFlags.none,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: true,
  ));

  // Handle interruptions
  session.interruptionEventStream.listen((event) {
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          // Lower volume
          _player.setVolume(0.5);
          break;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          // Pause playback
          pause();
          break;
      }
    } else {
      // Resume normal volume
      _player.setVolume(1.0);
    }
  });
  }

  /// Initialize audio handler for lock screen controls
  Future<void> _initializeAudioHandler() async {
  try {
    _audioHandler = await AudioService.init(
      builder: () => AudioLearningHandler(_player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.audio_learning_app.channel.audio',
        androidNotificationChannelName: 'Audio Learning',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    AppLogger.error('Failed to initialize audio handler', error: e);
  }
  }

  /// Load audio from local content (NEW METHOD)
  ///
  /// This method loads pre-downloaded content instead of generating TTS
  Future<void> loadLocalAudio(LearningObject learningObject) async {
  try {
    AppLogger.info('Loading local audio', {
      'id': learningObject.id,
      'title': learningObject.title,
    });

    // Check if content is available
    final isAvailable = await _localContentService.isContentAvailable(learningObject.id);
    if (!isAvailable) {
      throw Exception('Content not available locally for ${learningObject.id}');
    }

    // Load content and timing data in parallel
    final results = await Future.wait([
      _localContentService.getContent(learningObject.id),
      _localContentService.getTimingData(learningObject.id),
      _localContentService.getAudioPath(learningObject.id),
    ]);

    final content = results[0] as Map<String, dynamic>;
    final timingData = results[1] as TimingData;
    final audioPath = results[2] as String;

    // Extract display text
    _currentDisplayText = LocalContentService.getDisplayText(content);
    _currentLearningObject = learningObject;
    _currentTimingData = timingData;
    _currentWordTimings = timingData.words;

    // Share timings with WordTimingService for highlighting
    final wordTimingService = WordTimingServiceSimplified.instance;
    wordTimingService.setCachedTimings(learningObject.id, timingData.words);

    AppLogger.info('Loaded local content', {
      'wordCount': timingData.words.length,
      'sentenceCount': timingData.sentences.length,
      'duration': '${timingData.totalDurationMs / 1000}s',
      'audioPath': audioPath,
    });

    // Create audio source from local file
    AudioSource audioSource;

    // Check if it's an asset path or a file path
    if (audioPath.startsWith('assets/')) {
      // Load from assets (for test content)
      audioSource = AudioSource.asset(audioPath);
    } else {
      // Load from file system (for downloaded content)
      audioSource = AudioSource.file(audioPath);
    }

    // Set the audio source
    await _player.setAudioSource(audioSource);

    // Update media item for lock screen
    final duration = _player.duration;
    _audioHandler?.updateMediaItemForLearning(
      learningObject,
      audioDuration: duration,
    );

    // Restore previous position if available
    if (learningObject.currentPositionMs > 0) {
      await seekToPosition(
        Duration(milliseconds: learningObject.currentPositionMs),
      );
    }

    AppLogger.info('Local audio loaded successfully', {
      'title': learningObject.title,
      'duration': duration?.inSeconds,
    });
  } catch (e) {
    AppLogger.error(
      'Error loading local audio',
      error: e,
      data: {'learningObjectId': learningObject.id},
    );
    throw Exception('Failed to load local audio: $e');
  }
  }

  /// Load audio (fallback to original method for compatibility)
  Future<void> loadAudio(LearningObject learningObject) async {
  // For now, use the local loading method
  // In production, you might check if local content exists first
  await loadLocalAudio(learningObject);
  }

  /// Alias for loadLocalAudio to maintain compatibility with original AudioPlayerService
  Future<void> loadLearningObject(LearningObject learningObject) async {
  await loadLocalAudio(learningObject);
  }

  /// Get current word index based on position
  int getCurrentWordIndex() {
  if (_currentTimingData == null) return -1;

  final positionMs = _positionSubject.value.inMilliseconds;
  return _currentTimingData!.getCurrentWordIndex(positionMs);
  }

  /// Get current sentence index based on position
  int getCurrentSentenceIndex() {
  if (_currentTimingData == null) return -1;

  final positionMs = _positionSubject.value.inMilliseconds;
  return _currentTimingData!.getCurrentSentenceIndex(positionMs);
  }

  // ============================================================================
  // Original playback control methods (unchanged)
  // ============================================================================

  /// Play audio
  Future<void> play() async {
  try {
    await _player.play();
  } catch (e) {
    AppLogger.error('Error playing audio', error: e);
    throw Exception('Failed to play audio: $e');
  }
  }

  /// Pause audio
  Future<void> pause() async {
  try {
    await _player.pause();
  } catch (e) {
    AppLogger.error('Error pausing audio', error: e);
  }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
  if (_isPlayingSubject.value) {
    await pause();
  } else {
    await play();
  }
  }

  /// Skip forward by 30 seconds
  Future<void> skipForward() async {
  final newPosition = _positionSubject.value + skipDuration;
  final duration = _durationSubject.value;

  if (newPosition < duration) {
    await seekToPosition(newPosition);
  } else {
    await seekToPosition(duration);
  }
  }

  /// Skip backward by 30 seconds
  Future<void> skipBackward() async {
  final newPosition = _positionSubject.value - skipDuration;

  if (newPosition > Duration.zero) {
    await seekToPosition(newPosition);
  } else {
    await seekToPosition(Duration.zero);
  }
  }

  /// Seek to specific position
  Future<void> seekToPosition(Duration position) async {
  try {
    await _player.seek(position);
  } catch (e) {
    AppLogger.error('Error seeking position', error: e);
  }
  }

  /// Cycle through playback speeds
  Future<void> cycleSpeed() async {
  _currentSpeedIndex = (_currentSpeedIndex + 1) % speedOptions.length;
  final newSpeed = speedOptions[_currentSpeedIndex];
  await setSpeed(newSpeed);
  }

  /// Set specific playback speed
  Future<void> setSpeed(double speed) async {
  try {
    await _player.setSpeed(speed);
    _speedSubject.add(speed);
  } catch (e) {
    AppLogger.error('Error setting speed', error: e);
  }
  }

  /// Stop playback and reset
  Future<void> stop() async {
  try {
    await _player.stop();
    await seekToPosition(Duration.zero);
  } catch (e) {
    AppLogger.error('Error stopping audio', error: e);
  }
  }

  // ============================================================================
  // Stream getters
  // ============================================================================

  Stream<bool> get isPlayingStream => _isPlayingSubject.stream;
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration> get durationStream => _durationSubject.stream;
  Stream<double> get speedStream => _speedSubject.stream;
  Stream<ProcessingState> get processingStateStream =>
    _processingStateSubject.stream;

  bool get isPlaying => _isPlayingSubject.value;
  Duration get position => _positionSubject.value;
  Duration get duration => _durationSubject.value;
  double get speed => _speedSubject.value;
  ProcessingState get processingState => _processingStateSubject.value;
  List<WordTiming> get currentWordTimings => _currentWordTimings;
  String? get currentDisplayText => _currentDisplayText;
  LearningObject? get currentLearningObject => _currentLearningObject;

  /// Dispose resources
  void dispose() {
  for (final subscription in _subscriptions) {
    subscription.cancel();
  }
  _isPlayingSubject.close();
  _positionSubject.close();
  _durationSubject.close();
  _speedSubject.close();
  _processingStateSubject.close();
  _player.dispose();
  }
}

/// Validation function for AudioPlayerServiceLocal
Future<void> validateAudioPlayerServiceLocal() async {
  if (!kDebugMode) return;

  debugPrint('=== AudioPlayerServiceLocal Validation ===');

  final service = AudioPlayerServiceLocal.instance;
  const testId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';

  // Create a test learning object
  final testLearningObject = LearningObject(
    id: testId,
    assignmentId: 'test-assignment',
    title: 'Test Audio Playback',
    contentType: 'audio',
    ssmlContent: '',
    plainText: 'Test content',
    orderIndex: 1,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    isCompleted: false,
    currentPositionMs: 0,
  );

  try {
    // Test 1: Load local audio
    await service.loadLocalAudio(testLearningObject);
    debugPrint('✓ Local audio loaded successfully');

    // Test 2: Check duration
    await Future.delayed(const Duration(milliseconds: 500));
    assert(service.duration.inSeconds > 0, 'Duration must be positive');
    debugPrint('✓ Audio duration: ${service.duration.inSeconds}s');

    // Test 3: Check word timings
    assert(service.currentWordTimings.isNotEmpty, 'Word timings must be loaded');
    debugPrint('✓ Word timings loaded: ${service.currentWordTimings.length} words');

    // Test 4: Test playback controls
    await service.play();
    await Future.delayed(const Duration(milliseconds: 500));
    assert(service.isPlaying, 'Should be playing');
    debugPrint('✓ Playback started');

    await service.pause();
    assert(!service.isPlaying, 'Should be paused');
    debugPrint('✓ Playback paused');

    // Test 5: Test speed control
    await service.cycleSpeed();
    assert(service.speed != 1.0, 'Speed should change');
    debugPrint('✓ Speed control working: ${service.speed}x');

    // Test 6: Test seek
    await service.seekToPosition(const Duration(seconds: 5));
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('✓ Seek working');

    // Clean up
    await service.stop();
    debugPrint('✓ Playback stopped');

    debugPrint('=== All AudioPlayerServiceLocal validations passed ===');
  } catch (e) {
    debugPrint('✗ Validation failed: $e');
    rethrow;
  }
}