import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/progress_state.dart';
import 'cache_service.dart';

/// ProgressService - Manages progress tracking with preferences
///
/// Purpose: Handles progress saving, font size persistence, and playback speed
/// Dependencies:
/// - SharedPreferences: Local storage
/// - Supabase: Cloud storage and sync
/// - RxDart: Debounced saving
/// - CacheService: Integrated cache management
///
/// Features:
/// - Debounced progress saving (5-second intervals)
/// - Font size index persistence (Small/Medium/Large/XLarge)
/// - Playback speed persistence
/// - Progress sync between local and cloud
/// - Conflict resolution (server wins)
/// - Cache-aware progress management (50 items max)
/// - Background sync with connectivity detection
class ProgressService {
  static ProgressService? _instance;
  late final SharedPreferences _prefs;
  final SupabaseClient _supabase = Supabase.instance.client;
  late final CacheService _cacheService;
  final Connectivity _connectivity = Connectivity();

  // Debounce configuration
  static const Duration _debounceDuration = Duration(seconds: 5);

  // Font size configuration
  static const List<String> fontSizeNames = [
    'Small',
    'Medium',
    'Large',
    'X-Large'
  ];
  static const List<double> fontSizeValues = [14.0, 16.0, 18.0, 20.0];
  static const int defaultFontSizeIndex = 1; // Medium

  // Preference keys
  static const String _fontSizeKey = 'font_size_index';
  static const String _playbackSpeedKey = 'playback_speed';
  static const String _progressPrefix = 'progress_';

  // State streams
  final BehaviorSubject<int> _fontSizeIndexSubject =
      BehaviorSubject.seeded(defaultFontSizeIndex);
  final BehaviorSubject<double> _playbackSpeedSubject =
      BehaviorSubject.seeded(1.0);

  // Debounce subjects for saving
  final PublishSubject<_ProgressUpdate> _progressUpdateSubject =
      PublishSubject();

  // Active timers for debouncing
  Timer? _saveTimer;
  StreamSubscription? _progressUpdateSubscription;

  // Private constructor
  ProgressService._();

  /// Get singleton instance
  static Future<ProgressService> getInstance() async {
    if (_instance == null) {
      _instance = ProgressService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize service
  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _cacheService = await CacheService.getInstance();

    // Load saved preferences
    _loadPreferences();

    // Set up debounced progress saving
    _progressUpdateSubscription = _progressUpdateSubject
        .debounceTime(_debounceDuration)
        .listen(_performProgressSave);

    // Set up background sync
    _setupBackgroundSync();

    // Clean old cache entries on startup
    await _cleanOldProgressEntries();
  }

  /// Load preferences from local storage
  void _loadPreferences() {
    // Load font size
    final savedFontSize = _prefs.getInt(_fontSizeKey) ?? defaultFontSizeIndex;
    _fontSizeIndexSubject.add(savedFontSize);

    // Load playback speed
    final savedSpeed = _prefs.getDouble(_playbackSpeedKey) ?? 1.0;
    _playbackSpeedSubject.add(savedSpeed);

    if (kDebugMode) {
      debugPrint(
          'Preferences loaded - Font size: $savedFontSize, Speed: $savedSpeed');
    }
  }

  /// Save progress for a learning object (debounced)
  void saveProgress({
    required String learningObjectId,
    required int positionMs,
    required bool isCompleted,
    required bool isInProgress,
    String? userId,
  }) {
    // Add to debounce queue
    _progressUpdateSubject.add(_ProgressUpdate(
      learningObjectId: learningObjectId,
      positionMs: positionMs,
      isCompleted: isCompleted,
      isInProgress: isInProgress,
      userId: userId,
      fontSizeIndex: _fontSizeIndexSubject.value,
      playbackSpeed: _playbackSpeedSubject.value,
    ));
  }

  /// Perform the actual progress save
  Future<void> _performProgressSave(_ProgressUpdate update) async {
    try {
      // Save to local storage first
      await _saveProgressLocal(update);

      // Then save to Supabase if user is authenticated
      if (update.userId != null) {
        await _saveProgressCloud(update);
      }

      if (kDebugMode) {
        debugPrint('Progress saved for ${update.learningObjectId}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving progress: $e');
      }
    }
  }

  /// Save progress to local storage
  Future<void> _saveProgressLocal(_ProgressUpdate update) async {
    final key = '$_progressPrefix${update.learningObjectId}';
    final progressData = {
      'position_ms': update.positionMs,
      'is_completed': update.isCompleted,
      'is_in_progress': update.isInProgress,
      'font_size_index': update.fontSizeIndex,
      'playback_speed': update.playbackSpeed,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Convert to string for storage
    final dataString =
        progressData.entries.map((e) => '${e.key}:${e.value}').join(',');

    await _prefs.setString(key, dataString);
  }

  /// Save progress to Supabase
  Future<void> _saveProgressCloud(_ProgressUpdate update) async {
    try {
      final progressData = {
        'user_id': update.userId,
        'learning_object_id': update.learningObjectId,
        'position_ms': update.positionMs,
        'is_completed': update.isCompleted,
        'is_in_progress': update.isInProgress,
        'font_size_index': update.fontSizeIndex,
        'playback_speed': update.playbackSpeed,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('progress')
          .upsert(progressData, onConflict: 'user_id,learning_object_id');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving to Supabase: $e');
      }
      // Don't throw - local save is sufficient
    }
  }

  /// Load progress for a learning object
  Future<ProgressState?> loadProgress({
    required String learningObjectId,
    String? userId,
  }) async {
    try {
      // Try cloud first if authenticated
      if (userId != null) {
        final cloudProgress =
            await _loadProgressCloud(learningObjectId, userId);
        if (cloudProgress != null) {
          // Update local with cloud data (server wins)
          await _saveProgressLocal(_ProgressUpdate(
            learningObjectId: learningObjectId,
            positionMs: cloudProgress.currentPositionMs,
            isCompleted: cloudProgress.isCompleted,
            isInProgress: cloudProgress.isInProgress,
            userId: userId,
            fontSizeIndex: cloudProgress.fontSizeIndex,
            playbackSpeed: cloudProgress.playbackSpeed,
          ));
          return cloudProgress;
        }
      }

      // Fall back to local
      return _loadProgressLocal(learningObjectId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading progress: $e');
      }
      return _loadProgressLocal(learningObjectId);
    }
  }

  /// Load progress from local storage
  ProgressState? _loadProgressLocal(String learningObjectId) {
    final key = '$_progressPrefix$learningObjectId';
    final dataString = _prefs.getString(key);

    if (dataString == null) return null;

    try {
      // Parse stored data
      final dataMap = <String, dynamic>{};
      for (final pair in dataString.split(',')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final key = parts[0];
          final value = parts[1];

          // Parse based on key type
          if (key == 'position_ms' || key == 'font_size_index') {
            dataMap[key] = int.tryParse(value) ?? 0;
          } else if (key == 'playback_speed') {
            dataMap[key] = double.tryParse(value) ?? 1.0;
          } else if (key == 'is_completed' || key == 'is_in_progress') {
            dataMap[key] = value == 'true';
          } else {
            dataMap[key] = value;
          }
        }
      }

      return ProgressState(
        id: dataMap['id'] ?? '',
        userId: dataMap['user_id'] ?? '',
        learningObjectId: learningObjectId,
        currentPositionMs: dataMap['position_ms'] ?? 0,
        isCompleted: dataMap['is_completed'] ?? false,
        isInProgress: dataMap['is_in_progress'] ?? false,
        fontSizeIndex: dataMap['font_size_index'] ?? defaultFontSizeIndex,
        playbackSpeed: dataMap['playback_speed'] ?? 1.0,
        lastAccessedAt:
            DateTime.tryParse(dataMap['updated_at'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error parsing local progress: $e');
      }
      return null;
    }
  }

  /// Load progress from Supabase
  Future<ProgressState?> _loadProgressCloud(
      String learningObjectId, String userId) async {
    try {
      final response = await _supabase
          .from('progress')
          .select()
          .eq('user_id', userId)
          .eq('learning_object_id', learningObjectId)
          .single();

      if (response == null) return null;

      return ProgressState(
        id: response['id'] ?? '',
        userId: userId,
        learningObjectId: learningObjectId,
        currentPositionMs: response['position_ms'] ?? 0,
        isCompleted: response['is_completed'] ?? false,
        isInProgress: response['is_in_progress'] ?? false,
        fontSizeIndex: response['font_size_index'] ?? defaultFontSizeIndex,
        playbackSpeed: response['playback_speed'] ?? 1.0,
        lastAccessedAt:
            DateTime.tryParse(response['updated_at'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading from Supabase: $e');
      }
      return null;
    }
  }

  /// Set font size index
  Future<void> setFontSizeIndex(int index) async {
    if (index < 0 || index >= fontSizeValues.length) return;

    _fontSizeIndexSubject.add(index);
    await _prefs.setInt(_fontSizeKey, index);
    if (kDebugMode) {
      debugPrint('Font size index saved: $index');
    }
  }

  /// Cycle to next font size
  Future<void> cycleFontSize() async {
    final currentIndex = _fontSizeIndexSubject.value;
    final nextIndex = (currentIndex + 1) % fontSizeValues.length;
    await setFontSizeIndex(nextIndex);
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeedSubject.add(speed);
    await _prefs.setDouble(_playbackSpeedKey, speed);
    if (kDebugMode) {
      debugPrint('Playback speed saved: $speed');
    }
  }

  /// Clear all progress (for logout)
  Future<void> clearAllProgress() async {
    final keys = _prefs
        .getKeys()
        .where((key) => key.startsWith(_progressPrefix))
        .toList();

    for (final key in keys) {
      await _prefs.remove(key);
      // Also remove from cache
      final cacheKey = key.substring(_progressPrefix.length);
      await _cacheService.remove(cacheKey);
    }

    if (kDebugMode) {
      debugPrint('Cleared ${keys.length} progress entries');
    }
  }

  /// Set up background sync for preferences
  void _setupBackgroundSync() {
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        // Online - sync preferences with cloud
        await _syncPreferencesWithCloud();
      }
    });

    // Periodic sync every 30 seconds when online
    Timer.periodic(const Duration(seconds: 30), (timer) async {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await _syncPreferencesWithCloud();
      }
    });
  }

  /// Sync preferences with cloud
  Future<void> _syncPreferencesWithCloud() async {
    try {
      // Get current user
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Sync font size and playback speed
      final cloudPrefs = {
        'user_id': user.id,
        'font_size_index': _fontSizeIndexSubject.value,
        'playback_speed': _playbackSpeedSubject.value,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert to preferences table (create if needed)
      await _supabase
          .from('user_preferences')
          .upsert(cloudPrefs, onConflict: 'user_id')
          .timeout(const Duration(seconds: 5));

      if (kDebugMode) {
        debugPrint('Preferences synced to cloud');
      }
    } catch (e) {
      // Silently fail - local is sufficient
      if (kDebugMode) {
        debugPrint('Cloud sync failed (will retry): $e');
      }
    }
  }

  /// Clean old progress entries (cache management)
  Future<void> _cleanOldProgressEntries() async {
    try {
      final keys = _prefs
          .getKeys()
          .where((key) => key.startsWith(_progressPrefix))
          .toList();

      // Keep only 50 most recent entries
      if (keys.length <= 50) return;

      // Get entries with their last access times
      final entriesWithTime = <MapEntry<String, int>>[];

      for (final key in keys) {
        final dataString = _prefs.getString(key);
        if (dataString != null) {
          // Parse to get updated_at
          DateTime? updatedAt;
          for (final pair in dataString.split(',')) {
            final parts = pair.split(':');
            if (parts.length == 2 && parts[0] == 'updated_at') {
              updatedAt = DateTime.tryParse(parts[1]);
              break;
            }
          }

          if (updatedAt != null) {
            entriesWithTime.add(MapEntry(key, updatedAt.millisecondsSinceEpoch));
          }
        }
      }

      // Sort by time (newest first)
      entriesWithTime.sort((a, b) => b.value.compareTo(a.value));

      // Remove oldest entries beyond 50
      if (entriesWithTime.length > 50) {
        for (int i = 50; i < entriesWithTime.length; i++) {
          await _prefs.remove(entriesWithTime[i].key);
          // Also remove from cache
          final cacheKey = entriesWithTime[i].key.substring(_progressPrefix.length);
          await _cacheService.remove(cacheKey);
        }

        if (kDebugMode) {
          debugPrint('Cleaned ${entriesWithTime.length - 50} old progress entries');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cleaning old entries: $e');
      }
    }
  }

  /// Get cache statistics for progress data
  Future<Map<String, dynamic>> getCacheStatistics() async {
    final progressKeys = _prefs
        .getKeys()
        .where((key) => key.startsWith(_progressPrefix))
        .length;

    final cacheStats = _cacheService.getStatistics();

    return {
      'progressEntries': progressKeys,
      'maxEntries': 50,
      ...cacheStats,
    };
  }

  // Stream getters
  Stream<int> get fontSizeIndexStream => _fontSizeIndexSubject.stream;
  Stream<double> get playbackSpeedStream => _playbackSpeedSubject.stream;

  // Current value getters
  int get fontSizeIndex => _fontSizeIndexSubject.value;
  double get playbackSpeed => _playbackSpeedSubject.value;
  double get currentFontSize => fontSizeValues[fontSizeIndex];
  String get currentFontSizeName => fontSizeNames[fontSizeIndex];

  /// Clean up resources
  void dispose() {
    _saveTimer?.cancel();
    _progressUpdateSubscription?.cancel();
    _fontSizeIndexSubject.close();
    _playbackSpeedSubject.close();
    _progressUpdateSubject.close();
    _instance = null;
  }
}

/// Internal class for progress updates
class _ProgressUpdate {
  final String learningObjectId;
  final int positionMs;
  final bool isCompleted;
  final bool isInProgress;
  final String? userId;
  final int fontSizeIndex;
  final double playbackSpeed;

  _ProgressUpdate({
    required this.learningObjectId,
    required this.positionMs,
    required this.isCompleted,
    required this.isInProgress,
    this.userId,
    required this.fontSizeIndex,
    required this.playbackSpeed,
  });
}

/// Validation function for ProgressService
Future<void> validateProgressService() async {
  if (kDebugMode) {
    debugPrint('=== ProgressService Validation ===');
  }

  // Test 1: Service initialization
  final service = await ProgressService.getInstance();
  assert(service != null, 'Service must initialize');
  if (kDebugMode) {
    debugPrint('✓ Service initialization verified');
  }

  // Test 2: Font size configuration
  assert(ProgressService.fontSizeNames.length == 4, 'Must have 4 font sizes');
  assert(ProgressService.fontSizeValues.length == 4,
      'Must have 4 font size values');
  assert(ProgressService.defaultFontSizeIndex == 1, 'Default must be Medium');
  if (kDebugMode) {
    debugPrint('✓ Font size configuration verified');
  }

  // Test 3: Debounce duration
  assert(ProgressService._debounceDuration == const Duration(seconds: 5),
      'Debounce must be 5 seconds');
  if (kDebugMode) {
    debugPrint('✓ Debounce configuration verified');
  }

  // Test 4: Initial state
  assert(service.fontSizeIndex >= 0 && service.fontSizeIndex < 4,
      'Font size index must be valid');
  assert(service.playbackSpeed > 0, 'Playback speed must be positive');
  if (kDebugMode) {
    debugPrint('✓ Initial state verified');
  }

  // Test 5: Font size cycling
  final initialIndex = service.fontSizeIndex;
  await service.cycleFontSize();
  final newIndex = service.fontSizeIndex;
  assert(newIndex == (initialIndex + 1) % 4, 'Font size must cycle correctly');
  if (kDebugMode) {
    debugPrint('✓ Font size cycling verified');
  }

  if (kDebugMode) {
    debugPrint('=== All ProgressService validations passed ===');
  }
}
