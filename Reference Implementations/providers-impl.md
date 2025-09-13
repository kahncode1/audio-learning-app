# /implementations/providers.dart

```dart
/// State Management Providers - Riverpod Implementation
/// 
/// Provides all state management including:
/// - Authentication state
/// - Course and assignment data
/// - Player state (playback speed, font size, position)
/// - Progress tracking
/// - Service providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Player state providers
final playbackSpeedProvider = StateProvider<double>((ref) => 1.5);
final fontSizeIndexProvider = StateProvider<int>((ref) => 1); // Medium default
final isPlayingProvider = StateProvider<bool>((ref) => false);
final positionProvider = StateProvider<double>((ref) => 0.0);
final currentSentenceIndexProvider = StateProvider<int>((ref) => -1);
final currentWordIndexProvider = StateProvider<int>((ref) => -1);

// Audio player provider
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

// Dio provider for HTTP requests
final dioProvider = Provider<Dio>((ref) {
  return DioProvider.instance;
});

// SharedPreferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  
  AuthState({
    this.isAuthenticated = false,
    this.isLoading = true,
    this.error,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  
  AuthNotifier(this.ref) : super(AuthState()) {
    _checkAuthStatus();
  }
  
  Future<void> _checkAuthStatus() async {
    try {
      final authService = ref.read(authServiceProvider);
      final isSignedIn = await authService.isSignedIn();
      
      state = AuthState(
        isAuthenticated: isSignedIn,
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> signIn() async {
    state = AuthState(isLoading: true);
    
    try {
      final authService = ref.read(authServiceProvider);
      await authService.authenticate();
      
      state = AuthState(
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> signOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    
    state = AuthState(
      isAuthenticated: false,
      isLoading: false,
    );
  }
}

// Courses provider
final coursesProvider = FutureProvider<List<Course>>((ref) async {
  final supabase = ref.read(supabaseClientProvider);
  
  final response = await supabase
      .from('enrolled_courses')
      .select('''
        course_id,
        courses (
          course_id,
          course_number,
          course_title,
          gradient_start,
          gradient_end
        )
      ''')
      .gte('expiration_date', DateTime.now().toIso8601String());
  
  return (response as List)
      .map((json) => Course.fromJson(json['courses']))
      .toList();
});

// Assignments provider
final assignmentsProvider = FutureProvider.family<List<Assignment>, String>(
  (ref, courseId) async {
    final supabase = ref.read(supabaseClientProvider);
    
    final response = await supabase
        .from('assignments')
        .select('''
          id,
          assignment_number,
          assignment_name,
          order_index,
          learning_objects (
            loid,
            title,
            ssml_content,
            estimated_duration,
            word_timings
          )
        ''')
        .eq('course_id', courseId)
        .order('order_index', ascending: true);
    
    return (response as List)
        .map((json) => Assignment.fromJson(json))
        .toList();
  },
);

// Progress management provider with font size persistence
final progressProvider = StateNotifierProvider<ProgressNotifier, Map<String, ProgressState>>((ref) {
  return ProgressNotifier(ref);
});

class ProgressNotifier extends StateNotifier<Map<String, ProgressState>> {
  final Ref ref;
  
  ProgressNotifier(this.ref) : super({});
  
  Future<void> saveProgress(
    String loid, 
    Duration position,
    double playbackSpeed,
    int fontSizeIndex,
  ) async {
    final progressState = ProgressState(
      loid: loid,
      userId: ref.read(currentUserIdProvider),
      position: position,
      playbackSpeed: playbackSpeed,
      fontSizeIndex: fontSizeIndex,
      lastUpdated: DateTime.now(),
    );
    
    state = {...state, loid: progressState};
    
    // Save to Supabase
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('progress').upsert({
      'loid': loid,
      'user_id': progressState.userId,
      'position': position.inMilliseconds,
      'playback_speed': playbackSpeed,
      'font_size_index': fontSizeIndex,
      'is_in_progress': true,
      'last_updated': DateTime.now().toIso8601String(),
    });
    
    // Save preferences to SharedPreferences
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setDouble('playback_speed', playbackSpeed);
    await prefs.setInt('font_size_index', fontSizeIndex);
  }
  
  Future<ProgressState?> getProgress(String loid) async {
    if (state.containsKey(loid)) {
      return state[loid];
    }
    
    final supabase = ref.read(supabaseClientProvider);
    
    // Try to load from Supabase
    final result = await supabase
        .from('progress')
        .select()
        .eq('loid', loid)
        .eq('user_id', ref.read(currentUserIdProvider))
        .single();
    
    if (result != null) {
      // Load preferences
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final fontSizeIndex = prefs.getInt('font_size_index') ?? 1;
      final playbackSpeed = prefs.getDouble('playback_speed') ?? 1.5;
      
      final progressState = ProgressState(
        loid: loid,
        userId: result['user_id'],
        position: Duration(milliseconds: result['position']),
        playbackSpeed: playbackSpeed,
        fontSizeIndex: fontSizeIndex,
        lastUpdated: DateTime.parse(result['last_updated']),
      );
      
      state = {...state, loid: progressState};
      return progressState;
    }
    
    return null;
  }
  
  Future<void> markCompleted(String loid) async {
    final supabase = ref.read(supabaseClientProvider);
    
    await supabase
        .from('progress')
        .update({
          'is_completed': true,
          'is_in_progress': false,
          'completion_date': DateTime.now().toIso8601String(),
        })
        .eq('loid', loid)
        .eq('user_id', ref.read(currentUserIdProvider));
    
    // Update local state
    if (state.containsKey(loid)) {
      state = {
        ...state,
        loid: state[loid]!.copyWith(completed: true),
      };
    }
  }
}

// Service providers
final authServiceProvider = Provider((ref) => AuthService());
final speechifyServiceProvider = Provider((ref) => SpeechifyService());
final progressServiceProvider = Provider((ref) {
  return ProgressService(
    supabase: ref.read(supabaseClientProvider),
    prefs: ref.read(sharedPreferencesProvider).asData?.value ?? 
           throw Exception('SharedPreferences not initialized'),
  );
});

// Current user ID provider
final currentUserIdProvider = Provider<String>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return supabase.auth.currentUser?.id ?? '';
});

// Word timing service provider
final wordTimingServiceProvider = Provider((ref) {
  return WordTimingService();
});

// Audio player service provider
final audioPlayerServiceProvider = Provider((ref) {
  final service = AudioPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});
```