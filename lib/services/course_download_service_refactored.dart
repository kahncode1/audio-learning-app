/// Course Download Service (Refactored)
///
/// Purpose: Coordinates downloading of course content for offline use
/// Now uses extracted services for better maintainability
///
/// Dependencies:
/// - DownloadQueueManager: Manages download queue
/// - DownloadProgressTracker: Tracks progress state
/// - FileSystemManager: Handles file operations
/// - NetworkDownloader: Performs network operations
///
/// Usage:
/// ```dart
/// final service = await CourseDownloadService.getInstance();
/// await service.downloadCourse(courseId, courseName, learningObjects);
/// service.progressStream.listen((progress) {
///   print('Downloaded: ${progress.getProgressString()}');
/// });
/// ```
///
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_models.dart';
import '../models/learning_object_v2.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';
import 'download/download_queue_manager.dart';
import 'download/download_progress_tracker.dart';
import 'download/file_system_manager.dart';
import 'download/network_downloader.dart';
import 'download/course_download_api_service.dart';
import 'database/local_database_service.dart';
import 'sync/data_sync_service.dart';

class CourseDownloadService {
  static CourseDownloadService? _instance;

  // Extracted services
  final DownloadQueueManager _queueManager = DownloadQueueManager();
  final DownloadProgressTracker _progressTracker = DownloadProgressTracker();
  final FileSystemManager _fileSystemManager = FileSystemManager();
  final NetworkDownloader _networkDownloader = NetworkDownloader();

  // Phase 5 database services
  final CourseDownloadApiService _apiService = CourseDownloadApiService();
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;
  final DataSyncService _syncService = DataSyncService();

  // State
  DownloadSettings _settings = const DownloadSettings();
  bool _isPaused = false;
  bool _isDownloading = false;

  // Constants
  static const String _settingsKey = 'download_settings';

  // Private constructor
  CourseDownloadService._();

  /// Get singleton instance
  static Future<CourseDownloadService> getInstance() async {
    if (_instance == null) {
      _instance = CourseDownloadService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize service
  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Initialize extracted services
    await _fileSystemManager.initialize();
    await _progressTracker.initialize(prefs);
    _networkDownloader.initialize(wifiOnly: _settings.wifiOnly);

    // Load settings
    final settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      _settings = DownloadSettings.fromPrefs(jsonDecode(settingsJson));
      _networkDownloader.updateWiFiOnly(_settings.wifiOnly);
    }

    // Clean up old temp files on startup
    await _fileSystemManager.cleanupTempFiles();

    AppLogger.info('CourseDownloadService initialized');
  }

  /// Get progress stream
  Stream<CourseDownloadProgress?> get progressStream => _progressTracker.progressStream;

  /// Get current progress
  CourseDownloadProgress? get currentProgress => _progressTracker.currentProgress;

  /// Check if currently downloading
  bool get isDownloading => _isDownloading;

  /// Check if paused
  bool get isPaused => _isPaused;

  /// Main download method for a course (updated for new architecture)
  Future<void> downloadCourse(
    String courseId,
    String courseName,
    String userId,
  ) async {
    if (_isDownloading) {
      AppLogger.warning('Download already in progress');
      return;
    }

    try {
      _isDownloading = true;
      _isPaused = false;

      // Use the new CourseDownloadApiService to download course
      // This handles all the database operations and queue building
      await _apiService.downloadCourse(
        courseId: courseId,
        userId: userId,
      );

      // Listen to progress from API service
      _apiService.progressStream.listen((apiProgress) {
        AppLogger.info('Download progress', {
          'courseId': apiProgress.courseId,
          'status': apiProgress.status,
          'percentage': apiProgress.percentage,
          'message': apiProgress.message,
        });
      });

      // After download completes, sync with local database
      await _syncService.performFullSync(userId);

      AppLogger.info('Course download completed and synced', {
        'courseId': courseId,
        'userId': userId,
      });

    } catch (e) {
      AppLogger.error('Download failed', error: e);
      _progressTracker.markFailed(e.toString());
      rethrow;
    } finally {
      _isDownloading = false;
    }
  }

  /// Process download queue
  Future<void> _processQueue() async {
    while (!_queueManager.isQueueComplete && !_isPaused) {
      final task = _queueManager.currentTask;

      if (task == null || task.isComplete) {
        _queueManager.moveToNextTask();
        continue;
      }

      try {
        // Get file paths
        final savePath = _fileSystemManager.getFilePath(task.courseId, task.localPath);
        final tempPath = _fileSystemManager.getTempFilePath(savePath);

        // Ensure directory exists
        await _fileSystemManager.ensureDirectoryExists(savePath);

        // Download file
        await _networkDownloader.downloadFile(
          url: task.url,
          savePath: savePath,
          tempPath: tempPath,
          onReceiveProgress: (received, total) {
            _progressTracker.updateTaskProgress(task.id, received);
          },
        );

        // Mark task complete
        _queueManager.markCurrentTaskComplete();
        _progressTracker.updateProgressFromTasks(_queueManager.queue);

        // Sync to Supabase
        await _syncProgressToSupabase(task);

      } catch (e) {
        AppLogger.error('Failed to download file', error: e, data: {
          'taskId': task.id,
          'url': task.url,
        });

        // Handle retry logic
        if (_queueManager.shouldRetryCurrentTask(_settings) && !_isPaused) {
          final delay = _queueManager.getRetryDelay(_settings);
          AppLogger.info('Retrying download after delay', {
            'taskId': task.id,
            'delay': delay.inSeconds,
          });
          await Future.delayed(delay);
          continue; // Retry same file
        } else {
          _queueManager.skipCurrentTask();
          _progressTracker.updateProgressFromTasks(_queueManager.queue);
        }
      }

      _queueManager.moveToNextTask();
    }

    // Check if all complete
    if (_queueManager.isQueueComplete) {
      _progressTracker.markComplete();
      await _progressTracker.saveProgress();

      // Create manifest file
      final stats = _queueManager.getStatistics();
      if (stats.isComplete && !stats.hasFailures) {
        final courseId = _progressTracker.currentProgress!.courseId;
        await _createManifest(courseId);
      }
    }
  }

  /// Pause download
  Future<void> pauseDownload() async {
    if (_isDownloading && !_isPaused) {
      _isPaused = true;
      _networkDownloader.cancelDownload();
      _progressTracker.markPaused();
      await _progressTracker.saveProgress();

      AppLogger.info('Download paused');
    }
  }

  /// Resume download
  Future<void> resumeDownload() async {
    if (_isPaused && _progressTracker.currentProgress != null) {
      _isPaused = false;
      _isDownloading = true;
      _progressTracker.markResuming();

      AppLogger.info('Resuming download');
      await _processQueue();
    }
  }

  /// Retry failed downloads
  Future<void> retryFailed() async {
    if (_isDownloading) {
      AppLogger.warning('Cannot retry while downloading');
      return;
    }

    _queueManager.resetFailedTasks();
    _progressTracker.updateProgressFromTasks(_queueManager.queue);

    _isPaused = false;
    _isDownloading = true;

    AppLogger.info('Retrying failed downloads');
    await _processQueue();
  }

  /// Check if course is fully downloaded
  Future<bool> isCourseDownloaded(String courseId) async {
    return await _fileSystemManager.isCourseDownloaded(courseId);
  }

  /// Delete downloaded course content
  Future<void> deleteCourseContent(String courseId) async {
    await _fileSystemManager.deleteCourseContent(courseId);
    await _progressTracker.deleteProgress(courseId);

    AppLogger.info('Course content deleted', {'courseId': courseId});
  }

  /// Update download settings
  Future<void> updateSettings(DownloadSettings settings) async {
    _settings = settings;
    _networkDownloader.updateWiFiOnly(settings.wifiOnly);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

    AppLogger.info('Download settings updated', settings.toJson());
  }

  /// Create manifest file
  Future<void> _createManifest(String courseId) async {
    final files = _queueManager.queue
        .where((task) => task.status == DownloadStatus.completed)
        .map((task) => task.localPath)
        .toList();

    await _fileSystemManager.createManifest(
      courseId,
      files,
      {
        'downloadedAt': DateTime.now().toIso8601String(),
        'totalFiles': files.length,
      },
    );
  }

  /// Sync progress to Supabase
  Future<void> _syncProgressToSupabase(DownloadTask task) async {
    try {
      final supabase = SupabaseService();
      // Sync download progress to Supabase if needed
      // Implementation depends on Supabase schema
    } catch (e) {
      AppLogger.warning('Failed to sync progress to Supabase', data: {
        'error': e.toString(),
      });
    }
  }

  /// Clean up resources
  void dispose() {
    _networkDownloader.dispose();
    _progressTracker.dispose();
  }
}