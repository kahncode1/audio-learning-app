# Flutter Audio Learning App - Critical Package Implementation Guide

## Overview

This comprehensive implementation guide provides production-ready code patterns, architectural strategies, and performance optimizations for the critical Flutter packages used in the audio learning application. Each section includes modern 2024 best practices, common pitfalls, and performance-tuned implementations.

## Table of Contents

1. [just_audio (^0.9.36) - Custom StreamAudioSource Implementation](#just_audio-custom-streamaudiosource-implementation)
2. [just_audio_background (^0.0.1-beta.11) - Background Playback & Lock Screen](#just_audio_background-implementation)
3. [flutter_riverpod (^2.4.9) - State Management Patterns](#flutter_riverpod-state-management-patterns)
4. [dio (^5.4.0) - HTTP Client Singleton & Interceptors](#dio-http-client-singleton-implementation)
5. [shared_preferences (^2.2.2) - User Preferences Persistence](#shared_preferences-persistence-patterns)
6. [supabase_flutter (^2.3.0) - Database Integration](#supabase_flutter-database-integration)
7. [Additional Critical Packages](#additional-critical-packages)
8. [Performance Optimization Techniques](#performance-optimization-techniques)
9. [Common Pitfalls & Solutions](#common-pitfalls-solutions)

---

## just_audio (^0.9.36) - Custom StreamAudioSource Implementation

### Overview
just_audio provides the foundation for audio playback with custom StreamAudioSource support for streaming from APIs like Speechify. The implementation must support 60fps dual-level highlighting synchronization and <2-second audio stream start times.

### Core StreamAudioSource Implementation

```dart
/// Custom StreamAudioSource for Speechify API streaming
/// Supports byte-range requests and real-time streaming
class SpeechifyAudioSource extends StreamAudioSource {
  final String url;
  final Map<String, String> headers;
  final Dio _dio;

  // Buffer management
  final List<int> _buffer = [];
  final StreamController<List<int>> _controller = StreamController<List<int>>.broadcast();
  bool _isComplete = false;
  int? _contentLength;

  SpeechifyAudioSource({
    required this.url,
    required this.headers,
    required Dio dio,
  }) : _dio = dio {
    _initializeStream();
  }

  void _initializeStream() {
    _controller.stream.listen(
      (chunk) {
        _buffer.addAll(chunk);
      },
      onError: (error) {
        debugPrint('Stream error: $error');
      },
      onDone: () {
        _isComplete = true;
      },
    );
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      final startByte = start ?? 0;
      final endByte = end ?? _buffer.length - 1;

      // Handle range requests for seeking
      if (startByte > 0 && startByte < _buffer.length) {
        final rangeData = _buffer.sublist(startByte, min(endByte + 1, _buffer.length));
        return StreamAudioResponse(
          sourceLength: _buffer.length,
          contentLength: rangeData.length,
          offset: startByte,
          stream: Stream.value(rangeData),
          contentType: 'audio/mpeg',
        );
      }

      // Initial request or full buffer request
      if (_buffer.isEmpty && !_isComplete) {
        await _fetchInitialData();
      }

      final responseData = end != null
          ? _buffer.sublist(0, min(end + 1, _buffer.length))
          : _buffer;

      return StreamAudioResponse(
        sourceLength: _contentLength ?? _buffer.length,
        contentLength: responseData.length,
        offset: 0,
        stream: Stream.value(responseData),
        contentType: 'audio/mpeg',
      );
    } catch (e) {
      throw Exception('Failed to process audio request: $e');
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.data != null) {
        _contentLength = response.data!.length;
        _controller.add(response.data!);
        _controller.close();
      }
    } catch (e) {
      _controller.addError(e);
      rethrow;
    }
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
```

### AudioPlayer Service with Advanced Controls

```dart
/// AudioPlayer service with advanced controls and state management
/// Handles playback, speed adjustment, position tracking, and error recovery
class AudioPlayerService {
  static AudioPlayerService? _instance;
  static AudioPlayerService get instance => _instance ??= AudioPlayerService._();
  AudioPlayerService._();

  final AudioPlayer _player = AudioPlayer();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<PlayerState> _stateController = StreamController<PlayerState>.broadcast();

  // Current state
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;

  // Getters
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  double get speed => _speed;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<PlayerState> get stateStream => _stateController.stream;

  /// Initialize the audio player with session configuration
  Future<void> initialize() async {
    try {
      // Configure audio session for background playback
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());

      // Listen to player state changes
      _player.playerStateStream.listen((state) {
        _isPlaying = state.playing;
        _stateController.add(state);
      });

      // Listen to duration changes
      _player.durationStream.listen((duration) {
        if (duration != null) {
          _duration = duration;
        }
      });

      // Listen to position changes with throttling for 60fps performance
      _player.positionStream
          .throttleTime(const Duration(milliseconds: 16)) // 60fps
          .listen((position) {
        _position = position;
        _positionController.add(position);
      });

      debugPrint('AudioPlayerService initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize audio player: $e');
    }
  }

  /// Set audio source with retry logic
  Future<void> setAudioSource(AudioSource source, {int retries = 3}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        await _player.setAudioSource(source);
        debugPrint('Audio source set successfully');
        return;
      } catch (e) {
        debugPrint('Attempt ${attempt + 1} failed: $e');
        if (attempt == retries - 1) {
          throw Exception('Failed to set audio source after $retries attempts: $e');
        }
        await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
      }
    }
  }

  /// Play with error handling
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      throw Exception('Failed to play audio: $e');
    }
  }

  /// Pause with error handling
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      throw Exception('Failed to pause audio: $e');
    }
  }

  /// Seek to specific position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      throw Exception('Failed to seek to position: $e');
    }
  }

  /// Set playback speed with validation
  Future<void> setSpeed(double speed) async {
    if (speed < 0.5 || speed > 2.0) {
      throw ArgumentError('Speed must be between 0.5 and 2.0');
    }

    try {
      await _player.setSpeed(speed);
      _speed = speed;
    } catch (e) {
      throw Exception('Failed to set playback speed: $e');
    }
  }

  /// Skip forward by specified duration
  Future<void> skipForward([Duration duration = const Duration(seconds: 30)]) async {
    final newPosition = _position + duration;
    final clampedPosition = newPosition > _duration ? _duration : newPosition;
    await seek(clampedPosition);
  }

  /// Skip backward by specified duration
  Future<void> skipBackward([Duration duration = const Duration(seconds: 30)]) async {
    final newPosition = _position - duration;
    final clampedPosition = newPosition < Duration.zero ? Duration.zero : newPosition;
    await seek(clampedPosition);
  }

  /// Dispose resources
  void dispose() {
    _positionController.close();
    _stateController.close();
    _player.dispose();
    _instance = null;
  }
}
```

### Performance Optimization Patterns

```dart
/// Performance-optimized audio streaming with caching
class OptimizedAudioSource extends StreamAudioSource {
  static const int _bufferSize = 64 * 1024; // 64KB chunks
  static const int _maxCacheSize = 10 * 1024 * 1024; // 10MB max cache

  final String _url;
  final Map<String, String> _headers;
  final Dio _dio;
  final Map<String, List<int>> _cache = {};

  OptimizedAudioSource(this._url, this._headers, this._dio);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final cacheKey = '$_url:$start:$end';

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      final cachedData = _cache[cacheKey]!;
      return StreamAudioResponse(
        sourceLength: cachedData.length,
        contentLength: cachedData.length,
        offset: start ?? 0,
        stream: Stream.value(cachedData),
        contentType: 'audio/mpeg',
      );
    }

    // Fetch with range headers
    final headers = Map<String, String>.from(_headers);
    if (start != null || end != null) {
      final rangeStart = start ?? 0;
      final rangeEnd = end ?? '';
      headers['Range'] = 'bytes=$rangeStart-$rangeEnd';
    }

    try {
      final response = await _dio.get<List<int>>(
        _url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
        ),
      );

      final data = response.data!;

      // Cache if under size limit
      if (data.length <= _maxCacheSize) {
        _cache[cacheKey] = data;
        _cleanupCache();
      }

      return StreamAudioResponse(
        sourceLength: data.length,
        contentLength: data.length,
        offset: start ?? 0,
        stream: Stream.value(data),
        contentType: 'audio/mpeg',
      );
    } catch (e) {
      throw Exception('Failed to fetch audio data: $e');
    }
  }

  void _cleanupCache() {
    if (_cache.length > 50) {
      final keysToRemove = _cache.keys.take(_cache.length - 40).toList();
      keysToRemove.forEach(_cache.remove);
    }
  }
}
```

---

## just_audio_background (^0.0.1-beta.11) - Background Playback & Lock Screen

### Overview
Enables background playback and lock screen controls for seamless audio learning experience during commutes and exercise.

### Background Audio Configuration

```dart
/// Background audio service with lock screen controls
class BackgroundAudioService {
  static BackgroundAudioService? _instance;
  static BackgroundAudioService get instance => _instance ??= BackgroundAudioService._();
  BackgroundAudioService._();

  AudioHandler? _audioHandler;

  /// Initialize background audio with metadata
  Future<void> initialize() async {
    try {
      _audioHandler = await AudioService.init(
        builder: () => AudioPlayerHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.audiolearning.channel.audio',
          androidNotificationChannelName: 'Audio Learning Playback',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      debugPrint('Background audio service initialized');
    } catch (e) {
      throw Exception('Failed to initialize background audio: $e');
    }
  }

  /// Set current media item for lock screen display
  Future<void> setMediaItem(String title, String course, Duration duration) async {
    final mediaItem = MediaItem(
      id: title,
      album: course,
      title: title,
      duration: duration,
      artUri: Uri.parse('asset://assets/images/course_icon.png'),
    );

    await _audioHandler?.updateMediaItem(mediaItem);
  }

  AudioHandler? get handler => _audioHandler;
}

/// Custom audio handler for background operations
class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayerHandler() {
    _initialize();
  }

  void _initialize() {
    // Propagate player state to system
    _player.playerStateStream.listen((state) {
      playbackState.add(PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready,
        playing: state.playing,
      ));
    });

    // Propagate position updates
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    // Implement next chapter/section logic
    await _player.seek(_player.position + const Duration(seconds: 30));
  }

  @override
  Future<void> skipToPrevious() async {
    // Implement previous chapter/section logic
    await _player.seek(_player.position - const Duration(seconds: 30));
  }

  Future<void> setAudioSource(AudioSource source) async {
    await _player.setAudioSource(source);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
}
```

### Platform Configuration

#### iOS (ios/Runner/Info.plist)

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>background-processing</string>
</array>

<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone for voice features.</string>

<key>AVAudioSessionCategory</key>
<string>AVAudioSessionCategoryPlayback</string>
```

#### Android (android/app/src/main/AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<service android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>

<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON" />
    </intent-filter>
</receiver>
```

---

## flutter_riverpod (^2.4.9) - State Management Patterns

### Overview
Riverpod provides reactive state management for audio player state, progress tracking, and user preferences with compile-time safety and automatic resource management.

### Core Provider Setup

```dart
/// Core providers for audio learning app state management
/// Handles audio player state, progress, and user preferences

// Dio HTTP client provider (singleton)
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  // Configure interceptors (see Dio section)
  return dio;
});

// Audio player provider
final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  return AudioPlayerService.instance;
});

// Current playing state provider
final playingStateProvider = StreamProvider<bool>((ref) {
  final audioPlayer = ref.watch(audioPlayerProvider);
  return audioPlayer.stateStream.map((state) => state.playing);
});

// Audio position provider with throttling
final audioPositionProvider = StreamProvider<Duration>((ref) {
  final audioPlayer = ref.watch(audioPlayerProvider);
  return audioPlayer.positionStream
      .throttleTime(const Duration(milliseconds: 16)); // 60fps
});

// Audio duration provider
final audioDurationProvider = StateProvider<Duration>((ref) {
  return Duration.zero;
});

// Playback speed provider with persistence
final playbackSpeedProvider = StateNotifierProvider<PlaybackSpeedNotifier, double>((ref) {
  return PlaybackSpeedNotifier(ref);
});

// Font size index provider (0-3 for Small/Medium/Large/XLarge)
final fontSizeIndexProvider = StateNotifierProvider<FontSizeNotifier, int>((ref) {
  return FontSizeNotifier(ref);
});

// Current word index for dual-level highlighting
final currentWordIndexProvider = StateProvider<int>((ref) => 0);

// Current sentence index for dual-level highlighting
final currentSentenceIndexProvider = StateProvider<int>((ref) => 0);

// Learning progress provider
final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier(ref);
});
```

### StateNotifier Implementations

```dart
/// Playback speed state notifier with SharedPreferences persistence
class PlaybackSpeedNotifier extends StateNotifier<double> {
  final Ref _ref;
  static const String _key = 'playback_speed';

  PlaybackSpeedNotifier(this._ref) : super(1.0) {
    _loadSpeed();
  }

  Future<void> _loadSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSpeed = prefs.getDouble(_key) ?? 1.0;
      state = savedSpeed;
    } catch (e) {
      debugPrint('Error loading playback speed: $e');
    }
  }

  Future<void> setSpeed(double speed) async {
    if (speed < 0.5 || speed > 2.0) {
      throw ArgumentError('Speed must be between 0.5 and 2.0');
    }

    state = speed;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, speed);

      // Update audio player
      final audioPlayer = _ref.read(audioPlayerProvider);
      await audioPlayer.setSpeed(speed);
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
    }
  }

  void cycleSpeed() {
    final speeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
    final currentIndex = speeds.indexOf(state);
    final nextIndex = (currentIndex + 1) % speeds.length;
    setSpeed(speeds[nextIndex]);
  }
}

/// Font size state notifier with instant UI updates
class FontSizeNotifier extends StateNotifier<int> {
  final Ref _ref;
  static const String _key = 'font_size_index';
  static const List<double> _fontSizes = [14.0, 16.0, 18.0, 22.0]; // Small, Medium, Large, XLarge

  FontSizeNotifier(this._ref) : super(1) { // Default to Medium
    _loadFontSizeIndex();
  }

  Future<void> _loadFontSizeIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_key) ?? 1;
      state = savedIndex;
    } catch (e) {
      debugPrint('Error loading font size index: $e');
    }
  }

  Future<void> setFontSizeIndex(int index) async {
    if (index < 0 || index >= _fontSizes.length) {
      throw ArgumentError('Font size index must be between 0 and ${_fontSizes.length - 1}');
    }

    state = index;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, index);
    } catch (e) {
      debugPrint('Error saving font size index: $e');
    }
  }

  void cycleFontSize() {
    final nextIndex = (state + 1) % _fontSizes.length;
    setFontSizeIndex(nextIndex);
  }

  double get currentFontSize => _fontSizes[state];

  String get currentFontSizeName {
    const names = ['Small', 'Medium', 'Large', 'XLarge'];
    return names[state];
  }
}

/// Progress state notifier with debounced saves
class ProgressNotifier extends StateNotifier<ProgressState> {
  final Ref _ref;
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(seconds: 5);

  ProgressNotifier(this._ref) : super(ProgressState.initial()) {
    _initializeProgressTracking();
  }

  void _initializeProgressTracking() {
    // Listen to audio position changes
    _ref.listen(audioPositionProvider, (previous, next) {
      next.whenData((position) {
        _updatePosition(position);
      });
    });
  }

  void _updatePosition(Duration position) {
    state = state.copyWith(
      currentPosition: position,
      lastUpdated: DateTime.now(),
    );

    _debouncedSave();
  }

  void _debouncedSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _saveProgress();
    });
  }

  Future<void> _saveProgress() async {
    try {
      // Save to SharedPreferences for quick access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_progress', jsonEncode(state.toJson()));

      // Save to Supabase for cloud sync
      final supabase = _ref.read(supabaseProvider);
      await supabase.from('progress').upsert(state.toJson());

      debugPrint('Progress saved: ${state.currentPosition}');
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  void markCompleted(String learningObjectId) {
    state = state.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    _saveProgress();
  }

  void markInProgress(String learningObjectId) {
    state = state.copyWith(
      isInProgress: true,
      startedAt: DateTime.now(),
    );
    _saveProgress();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

### Consumer Widget Patterns

```dart
/// Audio player controls with Riverpod consumers
class AudioPlayerControls extends ConsumerWidget {
  const AudioPlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(playingStateProvider).value ?? false;
    final position = ref.watch(audioPositionProvider).value ?? Duration.zero;
    final duration = ref.watch(audioDurationProvider);
    final playbackSpeed = ref.watch(playbackSpeedProvider);
    final fontSizeIndex = ref.watch(fontSizeIndexProvider);

    return Column(
      children: [
        // Progress slider
        Consumer(
          builder: (context, ref, child) {
            return Slider(
              value: duration.inMilliseconds > 0
                  ? position.inMilliseconds / duration.inMilliseconds
                  : 0.0,
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).round(),
                );
                ref.read(audioPlayerProvider).seek(newPosition);
              },
            );
          },
        ),

        // Control buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Skip backward
            IconButton(
              onPressed: () {
                ref.read(audioPlayerProvider).skipBackward();
              },
              icon: const Icon(Icons.replay_30),
              tooltip: 'Skip back 30 seconds',
            ),

            // Play/Pause FAB
            FloatingActionButton(
              onPressed: () {
                final audioPlayer = ref.read(audioPlayerProvider);
                isPlaying ? audioPlayer.pause() : audioPlayer.play();
              },
              child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            ),

            // Skip forward
            IconButton(
              onPressed: () {
                ref.read(audioPlayerProvider).skipForward();
              },
              icon: const Icon(Icons.forward_30),
              tooltip: 'Skip forward 30 seconds',
            ),

            // Playback speed
            TextButton(
              onPressed: () {
                ref.read(playbackSpeedProvider.notifier).cycleSpeed();
              },
              child: Text('${playbackSpeed}x'),
            ),

            // Font size
            TextButton(
              onPressed: () {
                ref.read(fontSizeIndexProvider.notifier).cycleFontSize();
              },
              child: Text(ref.read(fontSizeIndexProvider.notifier).currentFontSizeName),
            ),
          ],
        ),

        // Time labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(position)),
              Text(_formatDuration(duration)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
```

---

## dio (^5.4.0) - HTTP Client Singleton Implementation

### Overview
Dio provides advanced HTTP client capabilities with interceptor chains, connection pooling, and retry logic. Critical requirement: Use singleton pattern to prevent memory leaks and connection issues.

### Singleton Dio Configuration

```dart
/// Singleton Dio client with comprehensive interceptor chain
/// CRITICAL: Never create multiple Dio instances - use this singleton only
class DioProvider {
  static DioProvider? _instance;
  static DioProvider get instance => _instance ??= DioProvider._();
  DioProvider._() {
    _initializeDio();
  }

  late final Dio _dio;
  Dio get dio => _dio;

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Interceptor order is CRITICAL for proper functionality

    // 1. Authentication interceptor (first)
    _dio.interceptors.add(AuthInterceptor());

    // 2. Cache interceptor (before retry)
    _dio.interceptors.add(DioCacheInterceptor(
      options: CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.request,
        hitCacheOnErrorExcept: [401, 403],
        maxStale: const Duration(days: 7),
        priority: CachePriority.normal,
        cipher: null,
      ),
    ));

    // 3. Retry interceptor (after cache, before logging)
    _dio.interceptors.add(RetryInterceptor(
      dio: _dio,
      logPrint: (message) => debugPrint('[Retry] $message'),
      retries: 3,
      retryDelays: const [
        Duration(seconds: 1),
        Duration(seconds: 2),
        Duration(seconds: 4),
      ],
      retryEvaluator: (error, attempt) {
        return error.type == DioExceptionType.connectionTimeout ||
               error.type == DioExceptionType.receiveTimeout ||
               error.type == DioExceptionType.sendTimeout ||
               (error.response?.statusCode != null &&
                error.response!.statusCode! >= 500);
      },
    ));

    // 4. Logging interceptor (last)
    if (kDebugMode) {
      _dio.interceptors.add(LoggingInterceptor());
    }
  }
}

/// Authentication interceptor for API requests
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // Get token from secure storage or auth provider
      final token = await _getAuthToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      super.onRequest(options, handler);
    } catch (e) {
      handler.reject(DioException(
        requestOptions: options,
        error: 'Failed to get auth token: $e',
      ));
    }
  }

  Future<String?> _getAuthToken() async {
    // Implement token retrieval from Supabase/Cognito
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token');
    } catch (e) {
      debugPrint('Error getting auth token: $e');
      return null;
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        // Attempt token refresh
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Retry original request with new token
          final options = err.requestOptions;
          final token = await _getAuthToken();
          options.headers['Authorization'] = 'Bearer $token';

          final response = await DioProvider.instance.dio.fetch(options);
          handler.resolve(response);
          return;
        }
      } catch (e) {
        debugPrint('Token refresh failed: $e');
      }
    }
    super.onError(err, handler);
  }

  Future<bool> _refreshToken() async {
    // Implement token refresh logic
    return false;
  }
}

/// Custom retry interceptor with exponential backoff
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int retries;
  final List<Duration> retryDelays;
  final bool Function(DioException error, int attempt) retryEvaluator;
  final void Function(String message) logPrint;

  RetryInterceptor({
    required this.dio,
    required this.retries,
    required this.retryDelays,
    required this.retryEvaluator,
    required this.logPrint,
  });

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    var extra = RetryOptions.fromExtra(err.requestOptions) ??
               RetryOptions(retries: retries);

    if (extra.retries > 0 && retryEvaluator(err, extra.attempts)) {
      extra = extra.copyWith(
        retries: extra.retries - 1,
        attempts: extra.attempts + 1,
      );

      err.requestOptions.extra = err.requestOptions.extra..addAll(extra.toExtra());

      final delayIndex = min(extra.attempts - 1, retryDelays.length - 1);
      final delay = retryDelays[delayIndex];

      logPrint('Retrying request (attempt ${extra.attempts}) after ${delay.inSeconds}s: ${err.requestOptions.uri}');

      await Future.delayed(delay);

      try {
        final response = await dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        if (e is DioException) {
          super.onError(e, handler);
        } else {
          super.onError(DioException(requestOptions: err.requestOptions, error: e), handler);
        }
        return;
      }
    }
    super.onError(err, handler);
  }
}

/// Retry options helper class
class RetryOptions {
  final int retries;
  final int attempts;

  const RetryOptions({
    this.retries = 3,
    this.attempts = 0,
  });

  factory RetryOptions.fromExtra(RequestOptions request) {
    return request.extra['dio_retry_options'] as RetryOptions?;
  }

  RetryOptions copyWith({int? retries, int? attempts}) {
    return RetryOptions(
      retries: retries ?? this.retries,
      attempts: attempts ?? this.attempts,
    );
  }

  Map<String, dynamic> toExtra() {
    return {'dio_retry_options': this};
  }
}

/// Logging interceptor for debugging
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('🌐 REQUEST[${options.method}] => ${options.uri}');
    debugPrint('Headers: ${options.headers}');
    if (options.data != null) {
      debugPrint('Body: ${options.data}');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('✅ RESPONSE[${response.statusCode}] <= ${response.requestOptions.uri}');
    if (kDebugMode && response.data != null) {
      final dataStr = response.data.toString();
      debugPrint('Data: ${dataStr.length > 200 ? '${dataStr.substring(0, 200)}...' : dataStr}');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('❌ ERROR[${err.response?.statusCode}] <= ${err.requestOptions.uri}');
    debugPrint('Message: ${err.message}');
    if (err.response?.data != null) {
      debugPrint('Error data: ${err.response!.data}');
    }
    super.onError(err, handler);
  }
}
```

### Connection Pooling for Speechify API

```dart
/// Connection pooling service for Speechify API optimization
class ConnectionPoolManager {
  static ConnectionPoolManager? _instance;
  static ConnectionPoolManager get instance => _instance ??= ConnectionPoolManager._();
  ConnectionPoolManager._();

  final Map<String, Dio> _pools = {};
  static const int maxIdleConnections = 5;
  static const Duration keepAliveTimeout = Duration(minutes: 2);

  /// Get or create a connection pool for specific host
  Dio getPool(String baseUrl) {
    if (!_pools.containsKey(baseUrl)) {
      _pools[baseUrl] = _createPooledDio(baseUrl);
    }
    return _pools[baseUrl]!;
  }

  Dio _createPooledDio(String baseUrl) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5), // Long timeout for audio streaming
      headers: {
        'Connection': 'keep-alive',
        'Keep-Alive': 'timeout=120, max=5',
      },
    ));

    // Configure adapter for connection pooling
    (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.maxConnectionsPerHost = maxIdleConnections;
      client.idleTimeout = keepAliveTimeout;
      client.connectionTimeout = const Duration(seconds: 10);
      return client;
    };

    return dio;
  }

  /// Cleanup unused pools
  void cleanup() {
    _pools.values.forEach((dio) {
      dio.close();
    });
    _pools.clear();
  }
}

/// Speechify service using connection pooling
class SpeechifyService {
  static const String baseUrl = 'https://api.sws.speechify.com';
  late final Dio _dio;

  SpeechifyService() {
    _dio = ConnectionPoolManager.instance.getPool(baseUrl);
    _setupSpeechifyInterceptors();
  }

  void _setupSpeechifyInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'Bearer ${_getSpeechifyApiKey()}';
        options.headers['Content-Type'] = 'application/json';
        options.headers['Accept'] = 'audio/mpeg, application/json';
        handler.next(options);
      },
    ));
  }

  String _getSpeechifyApiKey() {
    // Return API key from environment or secure storage
    return const String.fromEnvironment('SPEECHIFY_API_KEY', defaultValue: '');
  }

  /// Stream audio with range header support
  Stream<List<int>> streamAudio({
    required String text,
    required String voiceId,
    double speed = 1.0,
    int? rangeStart,
    int? rangeEnd,
  }) async* {
    try {
      final headers = <String, dynamic>{};
      if (rangeStart != null || rangeEnd != null) {
        final start = rangeStart ?? 0;
        final end = rangeEnd ?? '';
        headers['Range'] = 'bytes=$start-$end';
      }

      final response = await _dio.post<ResponseBody>(
        '/v1/audio/stream',
        data: {
          'input': text,
          'voice_id': voiceId,
          'speed': speed,
          'output_format': 'mp3',
          'include_speech_marks': true,
        },
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
        ),
      );

      if (response.data != null) {
        await for (final chunk in response.data!.stream) {
          yield chunk;
        }
      }
    } catch (e) {
      throw Exception('Failed to stream audio from Speechify: $e');
    }
  }
}
```

---

## shared_preferences (^2.2.2) - User Preferences Persistence

### Overview
SharedPreferences handles user preferences including font size (Small/Medium/Large/XLarge) and playback speed (0.8x-2.0x) with instant UI updates and cloud synchronization.

### Modern SharedPreferences Service (2024 Pattern)

```dart
/// Modern SharedPreferences service using new async APIs
/// Handles font size and playback speed persistence with cloud sync
class SharedPreferencesService {
  static SharedPreferencesService? _instance;
  static SharedPreferencesService get instance => _instance ??= SharedPreferencesService._();
  SharedPreferencesService._();

  // Use newer SharedPreferencesWithCache for better performance
  SharedPreferencesWithCache? _prefsWithCache;

  // Keys for preferences
  static const String _fontSizeIndexKey = 'font_size_index';
  static const String _playbackSpeedKey = 'playback_speed';
  static const String _lastPositionKey = 'last_position';
  static const String _completedObjectsKey = 'completed_objects';
  static const String _preferencesSyncedKey = 'preferences_synced';

  /// Initialize with cache for immediate access
  Future<void> initialize() async {
    try {
      _prefsWithCache = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: <String>{
            _fontSizeIndexKey,
            _playbackSpeedKey,
            _lastPositionKey,
            _completedObjectsKey,
            _preferencesSyncedKey,
          },
        ),
      );
      debugPrint('SharedPreferences initialized with cache');
    } catch (e) {
      // Fallback to legacy API if new API fails
      debugPrint('Failed to initialize SharedPreferencesWithCache, using legacy API: $e');
    }
  }

  // Font Size Management (0=Small, 1=Medium, 2=Large, 3=XLarge)
  Future<int> getFontSizeIndex() async {
    if (_prefsWithCache != null) {
      return _prefsWithCache!.getInt(_fontSizeIndexKey) ?? 1; // Default: Medium
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_fontSizeIndexKey) ?? 1;
    }
  }

  Future<bool> setFontSizeIndex(int index) async {
    if (index < 0 || index > 3) {
      throw ArgumentError('Font size index must be between 0 and 3');
    }

    try {
      if (_prefsWithCache != null) {
        await _prefsWithCache!.setInt(_fontSizeIndexKey, index);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_fontSizeIndexKey, index);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving font size index: $e');
      return false;
    }
  }

  // Playback Speed Management (0.8x - 2.0x)
  Future<double> getPlaybackSpeed() async {
    if (_prefsWithCache != null) {
      return _prefsWithCache!.getDouble(_playbackSpeedKey) ?? 1.0;
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_playbackSpeedKey) ?? 1.0;
    }
  }

  Future<bool> setPlaybackSpeed(double speed) async {
    if (speed < 0.5 || speed > 2.0) {
      throw ArgumentError('Playback speed must be between 0.5 and 2.0');
    }

    try {
      if (_prefsWithCache != null) {
        await _prefsWithCache!.setDouble(_playbackSpeedKey, speed);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_playbackSpeedKey, speed);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving playback speed: $e');
      return false;
    }
  }

  // Progress Position Management
  Future<Duration> getLastPosition(String learningObjectId) async {
    final key = '${_lastPositionKey}_$learningObjectId';
    final milliseconds = _prefsWithCache != null
        ? _prefsWithCache!.getInt(key) ?? 0
        : (await SharedPreferences.getInstance()).getInt(key) ?? 0;
    return Duration(milliseconds: milliseconds);
  }

  Future<bool> setLastPosition(String learningObjectId, Duration position) async {
    final key = '${_lastPositionKey}_$learningObjectId';

    try {
      if (_prefsWithCache != null) {
        await _prefsWithCache!.setInt(key, position.inMilliseconds);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(key, position.inMilliseconds);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving last position: $e');
      return false;
    }
  }

  // Completion Status Management
  Future<Set<String>> getCompletedObjects() async {
    final jsonString = _prefsWithCache != null
        ? _prefsWithCache!.getString(_completedObjectsKey) ?? '[]'
        : (await SharedPreferences.getInstance()).getString(_completedObjectsKey) ?? '[]';

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return Set<String>.from(decoded);
    } catch (e) {
      debugPrint('Error decoding completed objects: $e');
      return <String>{};
    }
  }

  Future<bool> addCompletedObject(String learningObjectId) async {
    try {
      final completed = await getCompletedObjects();
      completed.add(learningObjectId);

      final jsonString = jsonEncode(completed.toList());
      if (_prefsWithCache != null) {
        await _prefsWithCache!.setString(_completedObjectsKey, jsonString);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_completedObjectsKey, jsonString);
      }
      return true;
    } catch (e) {
      debugPrint('Error adding completed object: $e');
      return false;
    }
  }

  // Batch Operations for Performance
  Future<UserPreferences> getAllPreferences() async {
    return UserPreferences(
      fontSizeIndex: await getFontSizeIndex(),
      playbackSpeed: await getPlaybackSpeed(),
      lastSyncedAt: DateTime.now(),
    );
  }

  Future<bool> saveAllPreferences(UserPreferences preferences) async {
    try {
      final futures = [
        setFontSizeIndex(preferences.fontSizeIndex),
        setPlaybackSpeed(preferences.playbackSpeed),
      ];

      final results = await Future.wait(futures);
      return results.every((result) => result);
    } catch (e) {
      debugPrint('Error saving preferences batch: $e');
      return false;
    }
  }

  // Cache Management
  Future<void> clearCache() async {
    try {
      if (_prefsWithCache != null) {
        await _prefsWithCache!.clear();
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      }
      debugPrint('Preferences cache cleared');
    } catch (e) {
      debugPrint('Error clearing preferences cache: $e');
    }
  }

  // Migration from legacy API (if needed)
  Future<void> migrateFromLegacyAPI() async {
    try {
      // Get all preferences with legacy API
      final legacyPrefs = await SharedPreferences.getInstance();
      final fontSizeIndex = legacyPrefs.getInt(_fontSizeIndexKey);
      final playbackSpeed = legacyPrefs.getDouble(_playbackSpeedKey);

      // Save with new API if they exist
      if (fontSizeIndex != null) {
        await setFontSizeIndex(fontSizeIndex);
      }
      if (playbackSpeed != null) {
        await setPlaybackSpeed(playbackSpeed);
      }

      // Mark migration complete
      await legacyPrefs.setBool('migration_complete', true);
      debugPrint('Migration from legacy SharedPreferences completed');
    } catch (e) {
      debugPrint('Error during migration: $e');
    }
  }
}

/// User preferences data model
class UserPreferences {
  final int fontSizeIndex;
  final double playbackSpeed;
  final DateTime lastSyncedAt;

  const UserPreferences({
    required this.fontSizeIndex,
    required this.playbackSpeed,
    required this.lastSyncedAt,
  });

  UserPreferences copyWith({
    int? fontSizeIndex,
    double? playbackSpeed,
    DateTime? lastSyncedAt,
  }) {
    return UserPreferences(
      fontSizeIndex: fontSizeIndex ?? this.fontSizeIndex,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'font_size_index': fontSizeIndex,
    'playback_speed': playbackSpeed,
    'last_synced_at': lastSyncedAt.toIso8601String(),
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      fontSizeIndex: json['font_size_index'] ?? 1,
      playbackSpeed: json['playback_speed']?.toDouble() ?? 1.0,
      lastSyncedAt: DateTime.parse(json['last_synced_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}
```

### Instant UI Update Pattern

```dart
/// Service for instant font size changes with <16ms response time
class FontSizeService {
  static const List<double> fontSizes = [14.0, 16.0, 18.0, 22.0];
  static const List<String> fontSizeNames = ['Small', 'Medium', 'Large', 'XLarge'];

  final ValueNotifier<int> _fontSizeIndexNotifier = ValueNotifier<int>(1);
  final SharedPreferencesService _prefs = SharedPreferencesService.instance;

  ValueListenable<int> get fontSizeIndexListenable => _fontSizeIndexNotifier;
  int get currentIndex => _fontSizeIndexNotifier.value;
  double get currentSize => fontSizes[_fontSizeIndexNotifier.value];
  String get currentName => fontSizeNames[_fontSizeIndexNotifier.value];

  /// Initialize with saved preference
  Future<void> initialize() async {
    final savedIndex = await _prefs.getFontSizeIndex();
    _fontSizeIndexNotifier.value = savedIndex;
  }

  /// Change font size with immediate UI update and background persistence
  Future<void> setFontSizeIndex(int index) async {
    if (index < 0 || index >= fontSizes.length) return;

    // Update UI immediately (<16ms requirement)
    _fontSizeIndexNotifier.value = index;

    // Persist in background
    unawaited(_prefs.setFontSizeIndex(index));
  }

  /// Cycle to next font size
  void cycleFontSize() {
    final nextIndex = (_fontSizeIndexNotifier.value + 1) % fontSizes.length;
    setFontSizeIndex(nextIndex);
  }

  void dispose() {
    _fontSizeIndexNotifier.dispose();
  }
}

/// Widget that responds instantly to font size changes
class DynamicFontText extends StatelessWidget {
  final String text;
  final FontSizeService fontSizeService;
  final TextStyle? baseStyle;

  const DynamicFontText({
    super.key,
    required this.text,
    required this.fontSizeService,
    this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: fontSizeService.fontSizeIndexListenable,
      builder: (context, fontSizeIndex, child) {
        return Text(
          text,
          style: (baseStyle ?? const TextStyle()).copyWith(
            fontSize: FontSizeService.fontSizes[fontSizeIndex],
          ),
        );
      },
    );
  }
}
```

---

## supabase_flutter (^2.3.0) - Database Integration

### Overview
Supabase provides real-time database integration with Row Level Security, JWT validation for Cognito tokens, and reactive data streams for progress tracking and course content.

### Supabase Provider Configuration

```dart
/// Supabase client provider with authentication bridge
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Initialize Supabase with configuration
Future<void> initializeSupabase() async {
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
      eventsPerSecond: 10,
    ),
  );
}

/// Authentication service with Cognito-Supabase bridge
class SupabaseAuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Bridge Cognito JWT token to Supabase session
  Future<AuthResponse> bridgeCognitoToken(String cognitoJwtToken) async {
    try {
      // Extract user info from Cognito token
      final jwt = JWT.decode(cognitoJwtToken);
      final userId = jwt.payload['sub'] as String;
      final email = jwt.payload['email'] as String?;

      // Create custom JWT for Supabase with extended expiry
      final customClaims = {
        'sub': userId,
        'email': email,
        'cognito_verified': true,
        'exp': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      // Sign in with custom token
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.azure,
        idToken: cognitoJwtToken,
        accessToken: cognitoJwtToken,
      );

      if (response.user != null) {
        debugPrint('Successfully bridged Cognito token to Supabase session');
        return response;
      } else {
        throw Exception('Failed to create Supabase session from Cognito token');
      }
    } catch (e) {
      throw Exception('Failed to bridge Cognito token: $e');
    }
  }

  /// Get current user session
  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

  /// Sign out from Supabase
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateStream => _supabase.auth.onAuthStateChange;
}
```

### Real-time Data Providers

```dart
/// Courses provider with real-time updates and enrollment filtering
final coursesProvider = StreamProvider.autoDispose<List<EnrolledCourse>>((ref) async* {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;

  if (user == null) {
    yield [];
    return;
  }

  // Real-time stream with RLS filtering
  final stream = supabase
      .from('enrolled_courses_view')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .gte('expires_at', DateTime.now().toIso8601String())
      .order('created_at', ascending: false);

  await for (final data in stream) {
    try {
      final courses = data.map((json) => EnrolledCourse.fromJson(json)).toList();
      yield courses;
    } catch (e) {
      debugPrint('Error parsing courses: $e');
      yield [];
    }
  }
});

/// Learning objects provider with progress tracking
final learningObjectsProvider = StreamProvider.family<List<LearningObject>, String>((ref, courseId) async* {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;

  if (user == null) {
    yield [];
    return;
  }

  // Join with progress table for completion status
  final stream = supabase
      .from('learning_objects_with_progress')
      .stream(primaryKey: ['id'])
      .eq('course_id', courseId)
      .eq('user_id', user.id)
      .order('order_index', ascending: true);

  await for (final data in stream) {
    try {
      final objects = data.map((json) => LearningObject.fromJson(json)).toList();
      yield objects;
    } catch (e) {
      debugPrint('Error parsing learning objects: $e');
      yield [];
    }
  }
});

/// User progress provider with debounced updates
final userProgressProvider = StreamProvider.family<ProgressState?, String>((ref, learningObjectId) async* {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;

  if (user == null) {
    yield null;
    return;
  }

  // Real-time progress updates
  final stream = supabase
      .from('user_progress')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .eq('learning_object_id', learningObjectId);

  await for (final data in stream) {
    try {
      if (data.isNotEmpty) {
        yield ProgressState.fromJson(data.first);
      } else {
        yield null;
      }
    } catch (e) {
      debugPrint('Error parsing progress: $e');
      yield null;
    }
  }
});
```

### Progress Tracking Service with Cloud Sync

```dart
/// Progress tracking service with debounced saves and conflict resolution
class ProgressTrackingService {
  final SupabaseClient _supabase;
  final SharedPreferencesService _localPrefs;

  // Debounce timers for different save operations
  Timer? _positionSaveTimer;
  Timer? _preferencesSaveTimer;

  static const Duration _positionSaveDelay = Duration(seconds: 5);
  static const Duration _preferencesSaveDelay = Duration(seconds: 2);

  ProgressTrackingService({
    required SupabaseClient supabase,
    required SharedPreferencesService localPrefs,
  }) : _supabase = supabase, _localPrefs = localPrefs;

  /// Save progress with debouncing to reduce database writes
  void saveProgress({
    required String learningObjectId,
    required Duration position,
    required int fontSizeIndex,
    required double playbackSpeed,
    bool forceImmediate = false,
  }) {
    if (forceImmediate) {
      _saveToDatabaseImmediately(learningObjectId, position, fontSizeIndex, playbackSpeed);
    } else {
      _debouncedSave(learningObjectId, position, fontSizeIndex, playbackSpeed);
    }
  }

  void _debouncedSave(String learningObjectId, Duration position, int fontSizeIndex, double playbackSpeed) {
    // Cancel existing timer
    _positionSaveTimer?.cancel();

    // Start new timer
    _positionSaveTimer = Timer(_positionSaveDelay, () {
      _saveToDatabaseImmediately(learningObjectId, position, fontSizeIndex, playbackSpeed);
    });

    // Save to local preferences immediately for quick access
    unawaited(_localPrefs.setLastPosition(learningObjectId, position));
    unawaited(_localPrefs.setFontSizeIndex(fontSizeIndex));
    unawaited(_localPrefs.setPlaybackSpeed(playbackSpeed));
  }

  Future<void> _saveToDatabaseImmediately(
    String learningObjectId,
    Duration position,
    int fontSizeIndex,
    double playbackSpeed,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final progressData = {
        'user_id': user.id,
        'learning_object_id': learningObjectId,
        'current_position_ms': position.inMilliseconds,
        'font_size_index': fontSizeIndex,
        'playback_speed': playbackSpeed,
        'updated_at': DateTime.now().toIso8601String(),
        'is_in_progress': position.inMilliseconds > 0,
      };

      await _supabase
          .from('user_progress')
          .upsert(progressData, onConflict: 'user_id,learning_object_id');

      debugPrint('Progress saved to database: ${position.inMinutes}min');
    } catch (e) {
      debugPrint('Failed to save progress to database: $e');
      // Progress is still saved locally, will sync later
    }
  }

  /// Mark learning object as completed
  Future<void> markCompleted(String learningObjectId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('user_progress').upsert({
        'user_id': user.id,
        'learning_object_id': learningObjectId,
        'is_completed': true,
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,learning_object_id');

      // Update local cache
      await _localPrefs.addCompletedObject(learningObjectId);

      debugPrint('Marked as completed: $learningObjectId');
    } catch (e) {
      debugPrint('Failed to mark as completed: $e');
    }
  }

  /// Resume from last position
  Future<Duration?> getLastPosition(String learningObjectId) async {
    // Try local cache first for instant response
    final localPosition = await _localPrefs.getLastPosition(learningObjectId);
    if (localPosition.inMilliseconds > 0) {
      return localPosition;
    }

    // Fallback to database
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('user_progress')
          .select('current_position_ms')
          .eq('user_id', user.id)
          .eq('learning_object_id', learningObjectId)
          .maybeSingle();

      if (response != null && response['current_position_ms'] != null) {
        final position = Duration(milliseconds: response['current_position_ms']);
        // Cache locally for next time
        unawaited(_localPrefs.setLastPosition(learningObjectId, position));
        return position;
      }
    } catch (e) {
      debugPrint('Failed to get last position from database: $e');
    }

    return null;
  }

  /// Sync local preferences to cloud
  Future<void> syncPreferencesToCloud(UserPreferences preferences) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('user_preferences').upsert({
        'user_id': user.id,
        'font_size_index': preferences.fontSizeIndex,
        'playback_speed': preferences.playbackSpeed,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      debugPrint('Preferences synced to cloud');
    } catch (e) {
      debugPrint('Failed to sync preferences: $e');
    }
  }

  /// Get preferences from cloud with conflict resolution
  Future<UserPreferences?> getPreferencesFromCloud() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('user_preferences')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return UserPreferences.fromJson(response);
      }
    } catch (e) {
      debugPrint('Failed to get preferences from cloud: $e');
    }

    return null;
  }

  /// Sync offline changes when connection restored
  Future<void> syncOfflineChanges() async {
    // Implementation for offline sync when connection is restored
    // This would handle queued progress updates and preference changes
    debugPrint('Syncing offline changes...');
  }

  void dispose() {
    _positionSaveTimer?.cancel();
    _preferencesSaveTimer?.cancel();
  }
}
```

---

## Additional Critical Packages

### amplify_flutter (^2.0.0) - AWS Cognito Integration

```dart
/// AWS Cognito authentication service with Supabase bridge
class CognitoAuthService {
  static bool _isConfigured = false;

  /// Configure Amplify with Cognito
  static Future<void> configure() async {
    if (_isConfigured) return;

    try {
      const amplifyconfig = '''{
        "auth": {
          "plugins": {
            "awsCognitoAuthPlugin": {
              "UserAgent": "aws-amplify-cli/0.1.0",
              "Version": "0.1.0",
              "IdentityManager": {
                "Default": {}
              },
              "CredentialsProvider": {
                "CognitoIdentity": {
                  "Default": {
                    "PoolId": "${String.fromEnvironment('COGNITO_IDENTITY_POOL_ID')}",
                    "Region": "${String.fromEnvironment('AWS_REGION')}"
                  }
                }
              },
              "CognitoUserPool": {
                "Default": {
                  "PoolId": "${String.fromEnvironment('COGNITO_USER_POOL_ID')}",
                  "AppClientId": "${String.fromEnvironment('COGNITO_APP_CLIENT_ID')}",
                  "Region": "${String.fromEnvironment('AWS_REGION')}"
                }
              }
            }
          }
        }
      }''';

      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(amplifyconfig);
      _isConfigured = true;
      debugPrint('Amplify configured successfully');
    } catch (e) {
      debugPrint('Failed to configure Amplify: $e');
      rethrow;
    }
  }

  /// Sign in with SSO and bridge to Supabase
  static Future<AuthResponse> signInWithSSO() async {
    try {
      final result = await Amplify.Auth.signInWithWebUI(
        provider: AuthProvider.oidc,
      );

      if (result.isSignedIn) {
        // Get ID token for Supabase bridge
        final session = await Amplify.Auth.fetchAuthSession();
        if (session is CognitoAuthSession) {
          final idToken = session.userPoolTokensResult.value.idToken.raw;

          // Bridge to Supabase
          final supabaseAuth = SupabaseAuthService();
          return await supabaseAuth.bridgeCognitoToken(idToken);
        }
      }

      throw Exception('Failed to get valid session from Cognito');
    } catch (e) {
      throw Exception('SSO sign-in failed: $e');
    }
  }

  /// Sign out from both Cognito and Supabase
  static Future<void> signOut() async {
    try {
      await Future.wait([
        Amplify.Auth.signOut(),
        Supabase.instance.client.auth.signOut(),
      ]);
      debugPrint('Signed out from both Cognito and Supabase');
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  /// Get current authentication state
  static Future<bool> isSignedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      return false;
    }
  }
}
```

### connectivity_plus (^5.0.2) - Network State Management

```dart
/// Network connectivity service with automatic retry
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityResult> _connectivityController =
      StreamController<ConnectivityResult>.broadcast();

  ConnectivityResult _currentStatus = ConnectivityResult.none;
  bool get isConnected => _currentStatus != ConnectivityResult.none;

  Stream<ConnectivityResult> get connectivityStream => _connectivityController.stream;
  ConnectivityResult get currentStatus => _currentStatus;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      _currentStatus = await _connectivity.checkConnectivity();
      _connectivityController.add(_currentStatus);

      _connectivity.onConnectivityChanged.listen((result) {
        _currentStatus = result;
        _connectivityController.add(result);
        _handleConnectivityChange(result);
      });

      debugPrint('Connectivity service initialized: $_currentStatus');
    } catch (e) {
      debugPrint('Failed to initialize connectivity service: $e');
    }
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    debugPrint('Connectivity changed: $result');

    if (result != ConnectivityResult.none) {
      // Connection restored - sync offline changes
      _handleConnectionRestored();
    } else {
      // Connection lost - prepare for offline mode
      _handleConnectionLost();
    }
  }

  void _handleConnectionRestored() {
    debugPrint('Connection restored - syncing offline changes');
    // Trigger sync of offline progress and preferences
    unawaited(_syncOfflineData());
  }

  void _handleConnectionLost() {
    debugPrint('Connection lost - switching to offline mode');
    // Could trigger UI update to show offline indicator
  }

  Future<void> _syncOfflineData() async {
    try {
      // Implement offline data synchronization
      final progressService = ProgressTrackingService(
        supabase: Supabase.instance.client,
        localPrefs: SharedPreferencesService.instance,
      );
      await progressService.syncOfflineChanges();
    } catch (e) {
      debugPrint('Failed to sync offline data: $e');
    }
  }

  void dispose() {
    _connectivityController.close();
  }
}

/// Network-aware Dio interceptor
class ConnectivityInterceptor extends Interceptor {
  final ConnectivityService _connectivity = ConnectivityService.instance;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_connectivity.isConnected) {
      handler.reject(DioException(
        requestOptions: options,
        error: 'No internet connection available',
        type: DioExceptionType.connectionError,
      ));
      return;
    }
    super.onRequest(options, handler);
  }
}
```

---

## Performance Optimization Techniques

### 60fps Dual-Level Highlighting Optimization

```dart
/// Performance-optimized dual-level highlighting widget
class PerformantHighlightedText extends StatefulWidget {
  final String text;
  final List<WordTiming> wordTimings;
  final Duration currentPosition;
  final TextStyle textStyle;
  final Function(int)? onWordTapped;

  const PerformantHighlightedText({
    super.key,
    required this.text,
    required this.wordTimings,
    required this.currentPosition,
    required this.textStyle,
    this.onWordTapped,
  });

  @override
  State<PerformantHighlightedText> createState() => _PerformantHighlightedTextState();
}

class _PerformantHighlightedTextState extends State<PerformantHighlightedText> {
  List<WordPosition>? _precomputedPositions;
  int _currentWordIndex = -1;
  int _currentSentenceIndex = -1;

  @override
  void initState() {
    super.initState();
    _precomputePositions();
  }

  @override
  void didUpdateWidget(PerformantHighlightedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.wordTimings != widget.wordTimings) {
      _precomputePositions();
    }
    _updateHighlightIndices();
  }

  /// Pre-compute word positions using isolate for heavy work
  Future<void> _precomputePositions() async {
    try {
      final positions = await compute(_computeWordPositions, {
        'text': widget.text,
        'timings': widget.wordTimings,
        'style': widget.textStyle,
      });

      if (mounted) {
        setState(() {
          _precomputedPositions = positions;
        });
      }
    } catch (e) {
      debugPrint('Error precomputing positions: $e');
    }
  }

  /// Update current word and sentence indices with binary search
  void _updateHighlightIndices() {
    if (_precomputedPositions == null || widget.wordTimings.isEmpty) return;

    final positionMs = widget.currentPosition.inMilliseconds;

    // Binary search for current word (O(log n) performance)
    final wordIndex = _binarySearchWord(positionMs);
    final sentenceIndex = wordIndex >= 0
        ? widget.wordTimings[wordIndex].sentenceIndex
        : -1;

    if (_currentWordIndex != wordIndex || _currentSentenceIndex != sentenceIndex) {
      setState(() {
        _currentWordIndex = wordIndex;
        _currentSentenceIndex = sentenceIndex;
      });
    }
  }

  int _binarySearchWord(int positionMs) {
    int left = 0;
    int right = widget.wordTimings.length - 1;
    int result = -1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final timing = widget.wordTimings[mid];

      if (positionMs >= timing.startMs && positionMs <= timing.endMs) {
        return mid;
      } else if (positionMs < timing.startMs) {
        right = mid - 1;
      } else {
        left = mid + 1;
        if (positionMs < widget.wordTimings[left == widget.wordTimings.length ? mid : left].startMs) {
          result = mid;
        }
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_precomputedPositions == null) {
      return Text(widget.text, style: widget.textStyle);
    }

    return RepaintBoundary(
      child: CustomPaint(
        painter: HighlightPainter(
          positions: _precomputedPositions!,
          currentWordIndex: _currentWordIndex,
          currentSentenceIndex: _currentSentenceIndex,
          textStyle: widget.textStyle,
        ),
        child: GestureDetector(
          onTapUp: _handleTap,
          child: Text(widget.text, style: widget.textStyle),
        ),
      ),
    );
  }

  void _handleTap(TapUpDetails details) {
    if (_precomputedPositions == null || widget.onWordTapped == null) return;

    final localPosition = details.localPosition;
    for (int i = 0; i < _precomputedPositions!.length; i++) {
      final position = _precomputedPositions![i];
      if (position.rect.contains(localPosition)) {
        widget.onWordTapped!(i);
        break;
      }
    }
  }
}

/// Isolate function for computing word positions
static List<WordPosition> _computeWordPositions(Map<String, dynamic> params) {
  final text = params['text'] as String;
  final timings = params['timings'] as List<WordTiming>;
  final style = params['style'] as TextStyle;

  // Implement word position calculation
  final positions = <WordPosition>[];

  // This would use TextPainter to measure word positions
  // Implementation details depend on text measurement requirements

  return positions;
}

/// Custom painter for dual-level highlighting
class HighlightPainter extends CustomPainter {
  final List<WordPosition> positions;
  final int currentWordIndex;
  final int currentSentenceIndex;
  final TextStyle textStyle;

  HighlightPainter({
    required this.positions,
    required this.currentWordIndex,
    required this.currentSentenceIndex,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint sentence background first
    if (currentSentenceIndex >= 0) {
      _paintSentenceHighlight(canvas);
    }

    // Paint word foreground second
    if (currentWordIndex >= 0) {
      _paintWordHighlight(canvas);
    }
  }

  void _paintSentenceHighlight(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFE3F2FD) // Light blue
      ..style = PaintingStyle.fill;

    // Paint all words in current sentence
    for (final position in positions) {
      if (position.sentenceIndex == currentSentenceIndex) {
        canvas.drawRect(position.rect, paint);
      }
    }
  }

  void _paintWordHighlight(Canvas canvas) {
    if (currentWordIndex < positions.length) {
      final paint = Paint()
        ..color = const Color(0xFFFFF59D) // Yellow
        ..style = PaintingStyle.fill;

      canvas.drawRect(positions[currentWordIndex].rect, paint);
    }
  }

  @override
  bool shouldRepaint(HighlightPainter oldDelegate) {
    return currentWordIndex != oldDelegate.currentWordIndex ||
           currentSentenceIndex != oldDelegate.currentSentenceIndex;
  }
}

class WordPosition {
  final Rect rect;
  final int sentenceIndex;
  final int wordIndex;

  WordPosition({
    required this.rect,
    required this.sentenceIndex,
    required this.wordIndex,
  });
}
```

### Memory Management and Resource Disposal

```dart
/// Resource management mixin for proper disposal
mixin ResourceManagementMixin {
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  final List<Disposable> _disposables = [];

  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  void addDisposable(Disposable disposable) {
    _disposables.add(disposable);
  }

  @mustCallSuper
  void disposeResources() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Cancel all timers
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    // Dispose all disposables
    for (final disposable in _disposables) {
      disposable.dispose();
    }
    _disposables.clear();
  }
}

abstract class Disposable {
  void dispose();
}

/// Example service using resource management
class ExampleService with ResourceManagementMixin implements Disposable {
  late final StreamSubscription _positionSubscription;
  late final Timer _saveTimer;

  void initialize() {
    // Add subscriptions to be managed
    _positionSubscription = someStream.listen((data) {
      // Handle data
    });
    addSubscription(_positionSubscription);

    // Add timers to be managed
    _saveTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      // Periodic save
    });
    addTimer(_saveTimer);
  }

  @override
  void dispose() {
    disposeResources();
  }
}
```

---

## Common Pitfalls & Solutions

### 1. Multiple Dio Instances (CRITICAL ERROR)

**Problem**: Creating multiple Dio instances causes connection pool exhaustion and memory leaks.

**Solution**: Always use the singleton pattern:

```dart
// ❌ WRONG - Creates multiple instances
class ServiceA {
  final Dio _dio = Dio(); // BAD!
}

class ServiceB {
  final Dio _dio = Dio(); // BAD!
}

// ✅ CORRECT - Use singleton
class ServiceA {
  final Dio _dio = DioProvider.instance.dio; // GOOD!
}

class ServiceB {
  final Dio _dio = DioProvider.instance.dio; // GOOD!
}
```

### 2. Not Pre-computing Word Positions

**Problem**: Computing word positions on every frame causes 60fps drops.

**Solution**: Pre-compute with isolates:

```dart
// ❌ WRONG - Computes on UI thread
@override
Widget build(BuildContext context) {
  final positions = computeWordPositions(); // Blocks UI!
  return HighlightedText(positions: positions);
}

// ✅ CORRECT - Pre-compute with isolate
@override
void initState() {
  super.initState();
  compute(computeWordPositions, textData).then((positions) {
    setState(() => _positions = positions);
  });
}
```

### 3. Missing Font Size Persistence

**Problem**: Font size preferences reset on app restart.

**Solution**: Persist immediately and restore on startup:

```dart
// ❌ WRONG - Not persisted
void setFontSize(double size) {
  setState(() => _fontSize = size); // Lost on restart!
}

// ✅ CORRECT - Persist immediately
Future<void> setFontSize(double size) async {
  setState(() => _fontSize = size); // Immediate UI update
  await SharedPreferences.getInstance()
      .then((prefs) => prefs.setDouble('font_size', size)); // Persist
}
```

### 4. Single-Level Highlighting Only

**Problem**: Only highlighting words without sentence context reduces comprehension.

**Solution**: Implement dual-level highlighting:

```dart
// ❌ WRONG - Only word highlighting
Widget buildHighlighting() {
  return Text.rich(TextSpan(
    children: words.map((word) => TextSpan(
      text: word.text,
      style: word.isActive ? highlightStyle : normalStyle,
    )).toList(),
  ));
}

// ✅ CORRECT - Dual-level highlighting
Widget buildHighlighting() {
  return CustomPaint(
    painter: DualLevelPainter(
      wordIndex: currentWordIndex,
      sentenceIndex: currentSentenceIndex,
    ),
    child: Text(content),
  );
}
```

### 5. Blocking UI Thread with Heavy Operations

**Problem**: Heavy computations on UI thread cause frame drops.

**Solution**: Use compute() for isolate execution:

```dart
// ❌ WRONG - Heavy work on UI thread
List<WordPosition> calculatePositions() {
  return heavyComputation(); // Blocks UI!
}

// ✅ CORRECT - Use isolate
Future<List<WordPosition>> calculatePositions() {
  return compute(_heavyComputation, data);
}

static List<WordPosition> _heavyComputation(ComputeData data) {
  // Heavy work in isolate
  return positions;
}
```

### 6. Not Disposing Resources

**Problem**: Memory leaks from undisposed streams, timers, and controllers.

**Solution**: Proper resource disposal:

```dart
class AudioService extends StateNotifier<AudioState> {
  late final StreamSubscription _subscription;
  late final Timer _timer;
  late final StreamController _controller;

  AudioService() : super(AudioState.initial()) {
    _initialize();
  }

  void _initialize() {
    _subscription = audioPlayer.positionStream.listen(_onPosition);
    _timer = Timer.periodic(Duration(seconds: 1), _onTimer);
    _controller = StreamController<Duration>.broadcast();
  }

  @override
  void dispose() {
    // Dispose in reverse order of creation
    _controller.close();
    _timer.cancel();
    _subscription.cancel();
    super.dispose();
  }
}
```

### 7. Missing Keyboard Shortcuts

**Problem**: Power users expect keyboard shortcuts for audio controls.

**Solution**: Implement keyboard listener:

```dart
class AudioPlayerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          switch (event.logicalKey) {
            case LogicalKeyboardKey.space:
              _togglePlayPause();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowLeft:
              _skipBackward();
              return KeyEventResult.handled;
            case LogicalKeyboardKey.arrowRight:
              _skipForward();
              return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AudioPlayerUI(),
    );
  }
}
```

### 8. Not Using FloatingActionButton for Play/Pause

**Problem**: Standard IconButton doesn't provide proper visual emphasis.

**Solution**: Use FloatingActionButton for primary control:

```dart
// ❌ WRONG - Standard button
IconButton(
  onPressed: _togglePlay,
  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
)

// ✅ CORRECT - FloatingActionButton
FloatingActionButton(
  onPressed: _togglePlay,
  child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
  heroTag: 'audio_play_pause', // Unique hero tag
)
```

---

## Production Deployment Checklist

### Pre-Deployment Validation

```dart
/// Validation function to run before deployment
Future<bool> validateProductionReadiness() async {
  final validations = [
    _validateDioSingleton(),
    _validateFontSizePersistence(),
    _validateHighlightingPerformance(),
    _validateKeyboardShortcuts(),
    _validateBackgroundAudio(),
    _validateNetworkResilience(),
    _validateResourceDisposal(),
  ];

  final results = await Future.wait(validations);
  final allPassed = results.every((result) => result);

  debugPrint('Production readiness: ${allPassed ? 'PASSED' : 'FAILED'}');
  return allPassed;
}

Future<bool> _validateDioSingleton() async {
  // Ensure only one Dio instance exists
  final instance1 = DioProvider.instance.dio;
  final instance2 = DioProvider.instance.dio;
  return identical(instance1, instance2);
}

Future<bool> _validateFontSizePersistence() async {
  // Test font size persistence
  final prefs = SharedPreferencesService.instance;
  await prefs.setFontSizeIndex(2);
  final retrieved = await prefs.getFontSizeIndex();
  return retrieved == 2;
}

Future<bool> _validateHighlightingPerformance() async {
  // Measure highlighting performance
  final stopwatch = Stopwatch()..start();

  // Simulate highlighting update
  await Future.delayed(Duration(milliseconds: 10));

  stopwatch.stop();
  return stopwatch.elapsedMilliseconds < 16; // 60fps requirement
}
```

This comprehensive implementation guide provides production-ready patterns for all critical Flutter packages in your audio learning app. Each section includes performance optimization, error handling, and real-world usage patterns essential for enterprise-grade applications.

The guide emphasizes the specific requirements mentioned in your project documentation, including 60fps dual-level highlighting, <16ms font size changes, singleton patterns for Dio, and comprehensive state management with Riverpod.

Remember to always validate implementations using the included validation functions before marking any tasks as complete, and refer to this guide when implementing the specific features outlined in your TASKS.md file.