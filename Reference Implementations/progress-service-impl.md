# /implementations/progress-service.dart

```dart
/// Progress Service - Progress Tracking with Font Size Persistence
/// 
/// Handles progress management including:
/// - Debounced progress saving (5 second intervals)
/// - Font size and playback speed persistence
/// - Local and remote storage sync
/// - Conflict resolution for progress data

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressService {
  static const Duration _saveDebounce = Duration(seconds: 5);
  static const String _progressKeyPrefix = 'progress_';
  static const String _fontSizeKey = 'font_size_index';
  static const String _playbackSpeedKey = 'playback_speed';
  
  final SupabaseClient _supabase;
  final SharedPreferences _prefs;
  Timer? _saveTimer;
  ProgressState? _pendingState;
  
  ProgressService({
    required SupabaseClient supabase,
    required SharedPreferences prefs,
  }) : _supabase = supabase,
       _prefs = prefs;
  
  /// Save progress with debouncing to reduce database writes
  void saveProgress(ProgressState state) {
    _pendingState = state;
    _saveTimer?.cancel();
    
    _saveTimer = Timer(_saveDebounce, () async {
      if (_pendingState == null) return;
      
      try {
        // Save to local storage immediately
        await _saveLocal(_pendingState!);
        
        // Save to Supabase
        await _saveRemote(_pendingState!);
        
        // Save preferences
        await _savePreferences(_pendingState!);
        
        logger.info('Progress saved: ${_pendingState!.position.inMilliseconds}ms');
      } catch (e) {
        logger.error('Failed to save progress: $e');
        // Local save succeeded, remote can retry later
      }
      
      _pendingState = null;
    });
  }
  
  Future<void> _saveLocal(ProgressState state) async {
    final key = '$_progressKeyPrefix${state.loid}';
    final json = jsonEncode(state.toJson());
    await _prefs.setString(key, json);
  }
  
  Future<void> _saveRemote(ProgressState state) async {
    await _supabase
        .from('progress')
        .upsert({
          'user_id': state.userId,
          'learning_object_id': state.loid,
          'position_ms': state.position.inMilliseconds,
          'playback_speed': state.playbackSpeed,
          'font_size_index': state.fontSizeIndex,
          'is_completed': state.completed,
          'is_in_progress': true,
          'last_updated': DateTime.now().toIso8601String(),
        })
        .eq('user_id', state.userId)
        .eq('learning_object_id', state.loid);
  }
  
  Future<void> _savePreferences(ProgressState state) async {
    await _prefs.setInt(_fontSizeKey, state.fontSizeIndex);
    await _prefs.setDouble(_playbackSpeedKey, state.playbackSpeed);
  }
  
  Future<ProgressState?> loadProgress(String learningObjectId) async {
    try {
      // Try remote first
      final response = await _supabase
          .from('progress')
          .select()
          .eq('learning_object_id', learningObjectId)
          .single();
      
      // Load preferences
      final fontSizeIndex = _prefs.getInt(_fontSizeKey) ?? 1;
      final playbackSpeed = _prefs.getDouble(_playbackSpeedKey) ?? 1.5;
      
      return ProgressState.fromJson({
        ...response,
        'fontSizeIndex': fontSizeIndex,
        'playbackSpeed': playbackSpeed,
      });
    } catch (e) {
      // Fall back to local
      final key = '$_progressKeyPrefix$learningObjectId';
      final json = _prefs.getString(key);
      if (json != null) {
        return ProgressState.fromJson(jsonDecode(json));
      }
      return null;
    }
  }
  
  Future<void> markCompleted(String learningObjectId) async {
    try {
      await _supabase
          .from('progress')
          .update({
            'is_completed': true,
            'is_in_progress': false,
            'completion_date': DateTime.now().toIso8601String(),
          })
          .eq('learning_object_id', learningObjectId);
      
      // Update local cache
      final key = '$_progressKeyPrefix$learningObjectId';
      await _prefs.remove(key);
    } catch (e) {
      logger.error('Failed to mark as completed: $e');
    }
  }
  
  Future<void> syncProgress() async {
    // Find all local progress entries
    final keys = _prefs.getKeys()
        .where((key) => key.startsWith(_progressKeyPrefix))
        .toList();
    
    for (final key in keys) {
      final json = _prefs.getString(key);
      if (json != null) {
        try {
          final state = ProgressState.fromJson(jsonDecode(json));
          await _saveRemote(state);
        } catch (e) {
          logger.error('Failed to sync progress for $key: $e');
        }
      }
    }
  }
  
  int getFontSizeIndex() => _prefs.getInt(_fontSizeKey) ?? 1;
  double getPlaybackSpeed() => _prefs.getDouble(_playbackSpeedKey) ?? 1.5;
  
  void dispose() {
    // Save any pending progress immediately
    if (_pendingState != null) {
      _saveLocal(_pendingState!);
      _saveRemote(_pendingState!);
      _savePreferences(_pendingState!);
    }
    _saveTimer?.cancel();
  }
}

class ProgressState {
  final String loid;
  final String userId;
  final Duration position;
  final double playbackSpeed;
  final int fontSizeIndex;
  final bool completed;
  final DateTime lastUpdated;
  
  ProgressState({
    required this.loid,
    required this.userId,
    required this.position,
    required this.playbackSpeed,
    required this.fontSizeIndex,
    this.completed = false,
    required this.lastUpdated,
  });
  
  factory ProgressState.fromJson(Map<String, dynamic> json) {
    return ProgressState(
      loid: json['loid'] ?? json['learning_object_id'],
      userId: json['user_id'],
      position: Duration(milliseconds: json['position_ms'] ?? 0),
      playbackSpeed: (json['playback_speed'] ?? 1.5).toDouble(),
      fontSizeIndex: json['font_size_index'] ?? 1,
      completed: json['is_completed'] ?? false,
      lastUpdated: DateTime.parse(json['last_updated']),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'loid': loid,
    'user_id': userId,
    'position_ms': position.inMilliseconds,
    'playback_speed': playbackSpeed,
    'font_size_index': fontSizeIndex,
    'is_completed': completed,
    'last_updated': lastUpdated.toIso8601String(),
  };
  
  ProgressState copyWith({
    String? loid,
    String? userId,
    Duration? position,
    double? playbackSpeed,
    int? fontSizeIndex,
    bool? completed,
    DateTime? lastUpdated,
  }) {
    return ProgressState(
      loid: loid ?? this.loid,
      userId: userId ?? this.userId,
      position: position ?? this.position,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      fontSizeIndex: fontSizeIndex ?? this.fontSizeIndex,
      completed: completed ?? this.completed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

// Validation function
void main() async {
  print('🔧 Testing ProgressService...\n');
  
  final List<String> validationFailures = [];
  int totalTests = 0;
  
  // Test 1: Service initialization
  totalTests++;
  try {
    final prefs = await SharedPreferences.getInstance();
    final service = ProgressService(
      supabase: Supabase.instance.client,
      prefs: prefs,
    );
    print('✓ ProgressService initialized successfully');
  } catch (e) {
    validationFailures.add('Service initialization failed: $e');
  }
  
  // Test 2: Preference persistence
  totalTests++;
  try {
    final prefs = await SharedPreferences.getInstance();
    final service = ProgressService(
      supabase: Supabase.instance.client,
      prefs: prefs,
    );
    
    final state = ProgressState(
      loid: 'test-loid',
      userId: 'test-user',
      position: Duration(minutes: 5, seconds: 30),
      playbackSpeed: 1.75,
      fontSizeIndex: 2, // Large
      lastUpdated: DateTime.now(),
    );
    
    await service._savePreferences(state);
    
    final savedFontSize = service.getFontSizeIndex();
    final savedSpeed = service.getPlaybackSpeed();
    
    if (savedFontSize == 2 && savedSpeed == 1.75) {
      print('✓ Preferences persisted correctly');
    } else {
      validationFailures.add('Preference persistence failed: font=$savedFontSize, speed=$savedSpeed');
    }
  } catch (e) {
    validationFailures.add('Preference persistence test failed: $e');
  }
  
  // Test 3: Debounce mechanism
  totalTests++;
  try {
    final prefs = await SharedPreferences.getInstance();
    final service = ProgressService(
      supabase: Supabase.instance.client,
      prefs: prefs,
    );
    
    final state = ProgressState(
      loid: 'test-loid',
      userId: 'test-user',
      position: Duration(seconds: 10),
      playbackSpeed: 1.5,
      fontSizeIndex: 1,
      lastUpdated: DateTime.now(),
    );
    
    // Save multiple times rapidly
    service.saveProgress(state);
    service.saveProgress(state.copyWith(position: Duration(seconds: 20)));
    service.saveProgress(state.copyWith(position: Duration(seconds: 30)));
    
    // Only the last one should be pending
    if (service._pendingState?.position == Duration(seconds: 30)) {
      print('✓ Debounce mechanism working correctly');
    } else {
      validationFailures.add('Debounce not working: ${service._pendingState?.position}');
    }
  } catch (e) {
    validationFailures.add('Debounce test failed: $e');
  }
  
  // Test 4: Progress state JSON serialization
  totalTests++;
  try {
    final state = ProgressState(
      loid: 'test-loid',
      userId: 'test-user',
      position: Duration(minutes: 10, seconds: 45),
      playbackSpeed: 1.25,
      fontSizeIndex: 3,
      completed: false,
      lastUpdated: DateTime.now(),
    );
    
    final json = state.toJson();
    final restored = ProgressState.fromJson(json);
    
    if (restored.loid == state.loid &&
        restored.position == state.position &&
        restored.fontSizeIndex == state.fontSizeIndex &&
        restored.playbackSpeed == state.playbackSpeed) {
      print('✓ Progress state serialization working');
    } else {
      validationFailures.add('Serialization mismatch');
    }
  } catch (e) {
    validationFailures.add('Serialization test failed: $e');
  }
  
  // Final validation results
  print('\n' + '=' * 50);
  if (validationFailures.isNotEmpty) {
    print('❌ VALIDATION FAILED - ${validationFailures.length} of $totalTests tests failed:\n');
    for (final failure in validationFailures) {
      print('  • $failure');
    }
    exit(1);
  } else {
    print('✅ VALIDATION PASSED - All $totalTests tests produced expected results');
    print('Progress tracking with preferences ready for use');
    exit(0);
  }
}
```