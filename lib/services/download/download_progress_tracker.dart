/// Download Progress Tracker
///
/// Purpose: Tracks and manages download progress state
/// Handles progress calculations, notifications, and persistence
///
/// Responsibilities:
/// - Progress state management
/// - Progress calculations and metrics
/// - Progress persistence to SharedPreferences
/// - Progress stream notifications
///
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/download_models.dart';
import '../../utils/app_logger.dart';

class DownloadProgressTracker {
  static const String _prefsKeyPrefix = 'download_progress_';

  CourseDownloadProgress? _currentProgress;
  final _progressController = BehaviorSubject<CourseDownloadProgress?>();
  late final SharedPreferences _prefs;

  /// Get progress stream
  Stream<CourseDownloadProgress?> get progressStream => _progressController.stream;

  /// Get current progress
  CourseDownloadProgress? get currentProgress => _currentProgress;

  /// Initialize tracker with SharedPreferences
  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  /// Create new progress for course
  CourseDownloadProgress createProgress({
    required String courseId,
    required String courseName,
    required int totalFiles,
    required int totalBytes,
    required List<DownloadTask> tasks,
  }) {
    _currentProgress = CourseDownloadProgress(
      courseId: courseId,
      courseName: courseName,
      totalFiles: totalFiles,
      completedFiles: 0,
      failedFiles: 0,
      totalBytes: totalBytes,
      downloadedBytes: 0,
      tasks: tasks,
      startedAt: DateTime.now(),
      overallStatus: DownloadStatus.downloading,
    );

    _progressController.add(_currentProgress);
    AppLogger.info('Created new download progress', {
      'courseId': courseId,
      'totalFiles': totalFiles,
      'totalBytes': totalBytes,
    });

    return _currentProgress!;
  }

  /// Load saved progress for course
  Future<CourseDownloadProgress?> loadProgress(String courseId) async {
    final key = '$_prefsKeyPrefix$courseId';
    final json = _prefs.getString(key);

    if (json != null) {
      try {
        _currentProgress = CourseDownloadProgress.fromJson(jsonDecode(json));
        _progressController.add(_currentProgress);

        AppLogger.info('Loaded saved progress', {
          'courseId': courseId,
          'completedFiles': _currentProgress?.completedFiles,
          'totalFiles': _currentProgress?.totalFiles,
        });

        return _currentProgress;
      } catch (e) {
        AppLogger.error('Failed to load progress', error: e);
        // Remove corrupted data
        await _prefs.remove(key);
      }
    }

    return null;
  }

  /// Save current progress
  Future<void> saveProgress() async {
    if (_currentProgress == null) return;

    final key = '$_prefsKeyPrefix${_currentProgress!.courseId}';
    try {
      await _prefs.setString(key, jsonEncode(_currentProgress!.toJson()));
      AppLogger.info('Progress saved', {
        'courseId': _currentProgress!.courseId,
      });
    } catch (e) {
      AppLogger.error('Failed to save progress', error: e);
    }
  }

  /// Delete saved progress
  Future<void> deleteProgress(String courseId) async {
    final key = '$_prefsKeyPrefix$courseId';
    await _prefs.remove(key);

    if (_currentProgress?.courseId == courseId) {
      _currentProgress = null;
      _progressController.add(null);
    }

    AppLogger.info('Progress deleted', {'courseId': courseId});
  }

  /// Update progress from tasks
  void updateProgressFromTasks(List<DownloadTask> tasks) {
    if (_currentProgress == null) return;

    int completedFiles = 0;
    int failedFiles = 0;
    int downloadedBytes = 0;

    for (final task in tasks) {
      switch (task.status) {
        case DownloadStatus.completed:
          completedFiles++;
          downloadedBytes += task.expectedSize;
          break;
        case DownloadStatus.failed:
          failedFiles++;
          break;
        case DownloadStatus.downloading:
        case DownloadStatus.pending:
          downloadedBytes += task.downloadedBytes;
          break;
      }
    }

    _currentProgress = _currentProgress!.copyWith(
      completedFiles: completedFiles,
      failedFiles: failedFiles,
      downloadedBytes: downloadedBytes,
      tasks: tasks,
    );

    _progressController.add(_currentProgress);
  }

  /// Update task progress
  void updateTaskProgress(String taskId, int downloadedBytes) {
    if (_currentProgress == null) return;

    final taskIndex = _currentProgress!.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex != -1) {
      _currentProgress!.tasks[taskIndex].downloadedBytes = downloadedBytes;

      // Recalculate total downloaded bytes
      final totalDownloaded = _currentProgress!.tasks.fold<int>(
        0,
        (sum, task) => sum + (task.isComplete ? task.expectedSize : task.downloadedBytes),
      );

      _currentProgress = _currentProgress!.copyWith(
        downloadedBytes: totalDownloaded,
      );

      _progressController.add(_currentProgress);
    }
  }

  /// Mark download as complete
  void markComplete() {
    if (_currentProgress == null) return;

    final hasFailed = _currentProgress!.failedFiles > 0;
    _currentProgress = _currentProgress!.copyWith(
      completedAt: DateTime.now(),
      overallStatus: hasFailed ? DownloadStatus.failed : DownloadStatus.completed,
    );

    _progressController.add(_currentProgress);

    AppLogger.info('Download marked complete', {
      'courseId': _currentProgress!.courseId,
      'status': _currentProgress!.overallStatus.toString(),
      'completedFiles': _currentProgress!.completedFiles,
      'failedFiles': _currentProgress!.failedFiles,
    });
  }

  /// Mark download as paused
  void markPaused() {
    if (_currentProgress == null) return;

    _currentProgress = _currentProgress!.copyWith(
      overallStatus: DownloadStatus.paused,
    );

    _progressController.add(_currentProgress);
  }

  /// Mark download as resuming
  void markResuming() {
    if (_currentProgress == null) return;

    _currentProgress = _currentProgress!.copyWith(
      overallStatus: DownloadStatus.downloading,
    );

    _progressController.add(_currentProgress);
  }

  /// Mark download as failed
  void markFailed(String errorMessage) {
    if (_currentProgress == null) return;

    _currentProgress = _currentProgress!.copyWith(
      overallStatus: DownloadStatus.failed,
    );

    _progressController.add(_currentProgress);

    AppLogger.error('Download marked as failed', error: errorMessage, data: {
      'courseId': _currentProgress!.courseId,
    });
  }

  /// Get progress percentage
  double getProgressPercentage() {
    if (_currentProgress == null || _currentProgress!.totalFiles == 0) {
      return 0.0;
    }
    return _currentProgress!.completedFiles / _currentProgress!.totalFiles;
  }

  /// Get bytes percentage
  double getBytesPercentage() {
    if (_currentProgress == null || _currentProgress!.totalBytes == 0) {
      return 0.0;
    }
    return _currentProgress!.downloadedBytes / _currentProgress!.totalBytes;
  }

  /// Get formatted progress string
  String getProgressString() {
    if (_currentProgress == null) return 'No active download';

    final percentage = (getProgressPercentage() * 100).toStringAsFixed(1);
    final downloadedMB = (_currentProgress!.downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMB = (_currentProgress!.totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return '$percentage% - $downloadedMB MB / $totalMB MB';
  }

  /// Get estimated time remaining
  Duration? getEstimatedTimeRemaining() {
    if (_currentProgress == null || _currentProgress!.downloadSpeed == 0) {
      return null;
    }

    final remainingBytes = _currentProgress!.totalBytes - _currentProgress!.downloadedBytes;
    final secondsRemaining = remainingBytes / _currentProgress!.downloadSpeed;

    return Duration(seconds: secondsRemaining.round());
  }

  /// Clean up resources
  void dispose() {
    _progressController.close();
  }
}