/// Riverpod State Management Providers
///
/// Purpose: Central state management for the application
/// Dependencies:
///   - flutter_riverpod: State management
///   - services: Authentication and database services
///   - models: Data models
///
/// Usage:
///   final courses = ref.watch(enrolledCoursesProvider);
///   final authState = ref.watch(authStateProvider);
///
/// Expected behavior:
///   - Manages authentication state
///   - Caches and provides data access
///   - Handles user preferences
///   - Supports real-time updates

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_factory.dart';
import '../services/auth/auth_service_interface.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

// Service Providers

/// Auth service provider using factory pattern
final authServiceProvider = Provider<AuthServiceInterface>((ref) {
  return AuthFactory.instance;
});

/// Supabase service provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

// Authentication State Providers

/// Current authentication state
final authStateProvider = StreamProvider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current user provider
final currentUserProvider = FutureProvider<User?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final authUser = await authService.getCurrentUser();
  if (authUser == null) return null;

  // Create User model from AuthUser
  return User(
    id: authUser.userId,
    cognitoSub: authUser.userId,
    email: authUser.username ?? '',
    organization: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (isAuthenticated) => isAuthenticated,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Data Providers

/// Enrolled courses provider
final enrolledCoursesProvider =
    FutureProvider<List<EnrolledCourse>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);

  // Only fetch if authenticated
  if (!supabaseService.isAuthenticated) {
    return [];
  }

  return await supabaseService.fetchEnrolledCourses();
});

/// Assignments provider for a specific course
final assignmentsProvider =
    FutureProvider.family<List<Assignment>, String>((ref, courseId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);

  // Allow test course ID to bypass authentication
  if (!supabaseService.isAuthenticated &&
      courseId != '14350bfb-5e84-4479-b7a2-09ce7a2fdd48') {
    return [];
  }

  return await supabaseService.fetchAssignments(courseId);
});

/// Learning objects provider for a specific assignment
final learningObjectsProvider =
    FutureProvider.family<List<LearningObject>, String>(
        (ref, assignmentId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);

  // Allow test assignment ID to bypass authentication
  if (!supabaseService.isAuthenticated &&
      assignmentId != 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11') {
    return [];
  }

  return await supabaseService.fetchLearningObjects(assignmentId);
});

/// Progress provider for a specific learning object
final progressProvider = FutureProvider.family<ProgressState?, String>(
    (ref, learningObjectId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);

  if (!supabaseService.isAuthenticated) {
    return null;
  }

  return await supabaseService.fetchProgress(learningObjectId);
});

// User Preference Providers

/// Font size index provider (0-3: Small, Medium, Large, X-Large)
final fontSizeIndexProvider =
    StateNotifierProvider<FontSizeNotifier, int>((ref) {
  return FontSizeNotifier();
});

class FontSizeNotifier extends StateNotifier<int> {
  FontSizeNotifier() : super(1); // Default to Medium (index 1)

  void setFontSize(int index) {
    if (index >= 0 && index < ProgressState.fontSizeNames.length) {
      state = index;
    }
  }

  void cycleToNext() {
    state = (state + 1) % ProgressState.fontSizeNames.length;
  }

  String get fontSizeName => ProgressState.fontSizeNames[state];
  double get fontSizeValue => ProgressState.fontSizeValues[state];
}

/// Playback speed provider
final playbackSpeedProvider =
    StateNotifierProvider<PlaybackSpeedNotifier, double>((ref) {
  return PlaybackSpeedNotifier();
});

class PlaybackSpeedNotifier extends StateNotifier<double> {
  static const List<double> speeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];

  PlaybackSpeedNotifier() : super(1.0); // Default to 1.0x

  void setSpeed(double speed) {
    if (speeds.contains(speed)) {
      state = speed;
    }
  }

  void cycleToNext() {
    final currentIndex = speeds.indexOf(state);
    final nextIndex = (currentIndex + 1) % speeds.length;
    state = speeds[nextIndex];
  }

  String get formattedSpeed => '${state}x';
}

// Audio Playback Providers

/// Current word index for highlighting
final currentWordIndexProvider = StateProvider<int>((ref) => -1);

/// Current sentence index for highlighting
final currentSentenceIndexProvider = StateProvider<int>((ref) => -1);

/// Audio playback position in milliseconds
final playbackPositionProvider = StateProvider<int>((ref) => 0);

/// Audio playback state (playing/paused)
final isPlayingProvider = StateProvider<bool>((ref) => false);

// Selected Content Providers

/// Currently selected course
final selectedCourseProvider = StateProvider<Course?>((ref) => null);

/// Currently selected assignment
final selectedAssignmentProvider = StateProvider<Assignment?>((ref) => null);

/// Currently selected learning object
final selectedLearningObjectProvider =
    StateProvider<LearningObject?>((ref) => null);

// Progress Management

/// Progress update notifier
final progressUpdateProvider =
    StateNotifierProvider<ProgressUpdateNotifier, AsyncValue<void>>((ref) {
  return ProgressUpdateNotifier(ref);
});

class ProgressUpdateNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  ProgressUpdateNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> updateProgress({
    required String learningObjectId,
    required int positionMs,
    bool? isCompleted,
    bool? isInProgress,
  }) async {
    state = const AsyncValue.loading();

    try {
      final supabaseService = ref.read(supabaseServiceProvider);

      // Get or create progress
      var progress = await supabaseService.fetchProgress(learningObjectId);

      if (progress == null) {
        // Create new progress
        final user = await ref.read(currentUserProvider.future);
        if (user == null) throw Exception('User not authenticated');

        progress = ProgressState(
          id: '', // Will be generated by database
          userId: user.id,
          learningObjectId: learningObjectId,
          currentPositionMs: positionMs,
          isCompleted: isCompleted ?? false,
          isInProgress: isInProgress ?? true,
          playbackSpeed: ref.read(playbackSpeedProvider),
          fontSizeIndex: ref.read(fontSizeIndexProvider),
          lastAccessedAt: DateTime.now(),
        );
      } else {
        // Update existing progress
        progress = progress.copyWith(
          currentPositionMs: positionMs,
          isCompleted: isCompleted ?? progress.isCompleted,
          isInProgress: isInProgress ?? progress.isInProgress,
          playbackSpeed: ref.read(playbackSpeedProvider),
          fontSizeIndex: ref.read(fontSizeIndexProvider),
          lastAccessedAt: DateTime.now(),
        );
      }

      await supabaseService.saveProgress(progress);

      // Invalidate progress cache
      ref.invalidate(progressProvider(learningObjectId));

      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Initialization Provider

/// App initialization provider
final appInitializationProvider = FutureProvider<bool>((ref) async {
  try {
    // Initialize auth service
    final authService = ref.read(authServiceProvider);
    await authService.initialize();

    // Initialize Supabase
    final supabaseService = ref.read(supabaseServiceProvider);
    await supabaseService.initialize();

    // Check if user is already authenticated
    if (await authService.isSignedIn()) {
      // Bridge to Supabase if using real auth
      final token = await authService.getJwtToken();
      if (token != null && !token.startsWith('mock-')) {
        await supabaseService.bridgeFromCognito();
      }
    }

    return true;
  } catch (e) {
    return false;
  }
});

/// Validation function to verify providers implementation
void validateProviders() {
  // Test font size notifier
  final fontSizeNotifier = FontSizeNotifier();
  assert(fontSizeNotifier.fontSizeName == 'Medium');

  fontSizeNotifier.cycleToNext();
  assert(fontSizeNotifier.fontSizeName == 'Large');

  // Test playback speed notifier
  final speedNotifier = PlaybackSpeedNotifier();
  assert(speedNotifier.formattedSpeed == '1.0x');

  speedNotifier.cycleToNext();
  assert(speedNotifier.formattedSpeed == '1.25x');
}
