/// Database Service Providers
///
/// Purpose: Provides access to Phase 5 database services through Riverpod
/// Dependencies:
///   - LocalDatabaseService: Local SQLite database
///   - CourseService: Course data management
///   - AssignmentService: Assignment data management
///   - LearningObjectService: Learning object data management
///   - UserProgressService: User progress tracking
///   - DataSyncService: Offline/online synchronization
///
/// Usage:
///   final courses = await ref.watch(localCoursesProvider.future);
///   final progress = ref.watch(userProgressProvider(learningObjectId));

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database/local_database_service.dart';
import '../services/course_service.dart';
import '../services/assignment_service.dart';
import '../services/learning_object_service.dart';
import '../services/user_progress_service.dart';
import '../services/user_settings_service.dart';
import '../services/sync/data_sync_service.dart';
import '../services/download/course_download_api_service.dart';
export '../services/download/course_download_api_service.dart' show DownloadProgress;
import '../models/course.dart';
import '../models/assignment.dart';
import '../models/learning_object_v2.dart';
import '../models/user_progress.dart';

/// Local database service provider
final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return LocalDatabaseService.instance;
});

/// Course service provider
final courseServiceProvider = Provider<CourseService>((ref) {
  return CourseService();
});

/// Assignment service provider
final assignmentServiceProvider = Provider<AssignmentService>((ref) {
  return AssignmentService();
});

/// Learning object service provider
final learningObjectServiceProvider = Provider<LearningObjectService>((ref) {
  return LearningObjectService();
});

/// User progress service provider
final userProgressServiceProvider = Provider<UserProgressService>((ref) {
  return UserProgressService();
});

/// User settings service provider
final userSettingsServiceProvider = Provider<UserSettingsService>((ref) {
  return UserSettingsService();
});

/// Data sync service provider
final dataSyncServiceProvider = Provider<DataSyncService>((ref) {
  return DataSyncService();
});

/// Course download API service provider
final courseDownloadApiServiceProvider = Provider<CourseDownloadApiService>((ref) {
  return CourseDownloadApiService();
});

/// Provider for courses from local database
final localCoursesProvider = FutureProvider<List<Course>>((ref) async {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final coursesData = await localDb.getCourses();

  // Convert database rows to Course models
  return coursesData.map((data) => Course.fromJson(data)).toList();
});

/// Provider for assignments of a specific course
final courseAssignmentsProvider = FutureProvider.family<List<Assignment>, String>((ref, courseId) async {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final assignmentsData = await localDb.getAssignments(courseId);

  // Convert database rows to Assignment models
  return assignmentsData.map((data) => Assignment.fromJson(data)).toList();
});

/// Provider for learning objects of a specific assignment
final assignmentLearningObjectsProvider = FutureProvider.family<List<LearningObjectV2>, String>((ref, assignmentId) async {
  final localDb = ref.watch(localDatabaseServiceProvider);
  final learningObjectsData = await localDb.getLearningObjects(assignmentId);

  // Convert database rows to LearningObjectV2 models
  return learningObjectsData.map((data) => LearningObjectV2.fromJson(data)).toList();
});

/// Provider for user progress on a specific learning object
final userProgressProvider = FutureProvider.family<UserProgress?, String>((ref, learningObjectId) async {
  final userProgressService = ref.watch(userProgressServiceProvider);

  // Fetch progress directly using the service
  return await userProgressService.fetchProgress(learningObjectId);
});

/// Provider for course completion percentage
final courseCompletionProvider = FutureProvider.family<double, String>((ref, courseId) async {
  final localDb = ref.watch(localDatabaseServiceProvider);

  // Get the current user ID (you'll need to get this from auth)
  const userId = 'current-user-id';

  // Get all learning objects for the course
  final assignments = await localDb.getAssignments(courseId);
  int totalLearningObjects = 0;
  int completedLearningObjects = 0;

  for (final assignment in assignments) {
    final learningObjects = await localDb.getLearningObjects(assignment['id']);
    totalLearningObjects += learningObjects.length;

    for (final lo in learningObjects) {
      final progress = await localDb.getUserProgress(userId, lo['id']);
      if (progress != null && progress['is_completed'] == 1) {
        completedLearningObjects++;
      }
    }
  }

  if (totalLearningObjects == 0) return 0.0;
  return (completedLearningObjects / totalLearningObjects) * 100.0;
});

/// Provider for downloading a course
final downloadCourseProvider = FutureProvider.family<void, String>((ref, courseId) async {
  final downloadService = ref.watch(courseDownloadApiServiceProvider);

  // Get the current user ID (you'll need to get this from auth)
  const userId = 'current-user-id';

  await downloadService.downloadCourse(
    courseId: courseId,
    userId: userId,
  );
});

/// Provider for download progress stream
final downloadProgressProvider = StreamProvider<DownloadProgress?>((ref) {
  final downloadService = ref.watch(courseDownloadApiServiceProvider);
  return downloadService.progressStream;
});

/// Provider for syncing data
final syncDataProvider = FutureProvider<void>((ref) async {
  final syncService = ref.watch(dataSyncServiceProvider);

  // Get the current user ID (you'll need to get this from auth)
  const userId = 'current-user-id';

  await syncService.performFullSync(userId);
});

/// Provider for current user settings
final userSettingsProvider = StateNotifierProvider<UserSettingsNotifier, UserSettingsState>((ref) {
  return UserSettingsNotifier(ref.watch(userSettingsServiceProvider));
});

/// User settings notifier
class UserSettingsNotifier extends StateNotifier<UserSettingsState> {
  final UserSettingsService _service;

  UserSettingsNotifier(this._service) : super(UserSettingsState.defaults()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _service.fetchSettings();
    state = UserSettingsState(
      fontSize: settings.getFontSize(),
      playbackSpeed: settings.getDefaultPlaybackSpeed(),
      theme: settings.themeName,
      highlightColor: settings.getWordHighlightColor(),
    );
  }

  Future<void> updateFontSize(double fontSize) async {
    state = state.copyWith(fontSize: fontSize);
    await _service.updateFontSize(fontSize);
  }

  Future<void> updatePlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _service.updatePlaybackSpeed(speed);
  }
}

/// User settings state model for UI
class UserSettingsState {
  final double fontSize;
  final double playbackSpeed;
  final String theme;
  final String highlightColor;

  UserSettingsState({
    required this.fontSize,
    required this.playbackSpeed,
    required this.theme,
    required this.highlightColor,
  });

  factory UserSettingsState.defaults() {
    return UserSettingsState(
      fontSize: 18.0,
      playbackSpeed: 1.0,
      theme: 'light',
      highlightColor: '#FFEB3B',
    );
  }

  factory UserSettingsState.fromJson(Map<String, dynamic> json) {
    return UserSettingsState(
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 18.0,
      playbackSpeed: (json['playback_speed'] as num?)?.toDouble() ?? 1.0,
      theme: json['theme'] as String? ?? 'light',
      highlightColor: json['highlight_color'] as String? ?? '#FFEB3B',
    );
  }

  UserSettingsState copyWith({
    double? fontSize,
    double? playbackSpeed,
    String? theme,
    String? highlightColor,
  }) {
    return UserSettingsState(
      fontSize: fontSize ?? this.fontSize,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      theme: theme ?? this.theme,
      highlightColor: highlightColor ?? this.highlightColor,
    );
  }
}