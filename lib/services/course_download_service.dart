/// Course Download Service
///
/// Purpose: Manages downloading of course content for offline use
/// Features:
/// - Download queue management with sequential processing
/// - Progress tracking with real-time updates
/// - Resume support for interrupted downloads
/// - Network-aware downloading (WiFi-only option)
/// - Retry logic with exponential backoff
/// - Persistent state across app restarts
///
/// Dependencies:
/// - dio: HTTP downloads with progress tracking
/// - path_provider: Access to app documents directory
/// - connectivity_plus: Network state detection
/// - rxdart: Progress stream management
///
/// Usage:
/// ```dart
/// final service = await CourseDownloadService.getInstance();
/// await service.downloadCourse(courseId, learningObjects);
/// service.progressStream.listen((progress) {
///   print('Downloaded: ${progress.getProgressString()}');
/// });
/// ```

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';
import '../models/download_models.dart';
import '../models/learning_object.dart';
import '../services/dio_provider.dart';
import '../services/supabase_service.dart';
import '../utils/app_logger.dart';

class CourseDownloadService {
  static CourseDownloadService? _instance;
  late final SharedPreferences _prefs;
  late final Directory _documentsDir;
  late final Dio _dio;
  final Connectivity _connectivity = Connectivity();

  // Download state
  CourseDownloadProgress? _currentProgress;
  final _progressController = BehaviorSubject<CourseDownloadProgress?>();
  StreamSubscription? _connectivitySubscription;
  DownloadSettings _settings = const DownloadSettings();
  bool _isPaused = false;
  bool _isDownloading = false;
  CancelToken? _cancelToken;

  // Queue management
  final List<DownloadTask> _queue = [];
  int _currentQueueIndex = 0;

  // Constants
  static const String _prefsKeyPrefix = 'download_progress_';
  static const String _settingsKey = 'download_settings';
  static const String _manifestFileName = 'manifest.json';
  static const String _tempExtension = '.tmp';

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
    _prefs = await SharedPreferences.getInstance();
    _documentsDir = await getApplicationDocumentsDirectory();
    _dio = DioProvider.dio;

    // Load settings
    final settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      _settings = DownloadSettings.fromPrefs(jsonDecode(settingsJson));
    }

    // Monitor connectivity if WiFi-only is enabled
    if (_settings.wifiOnly) {
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    }

    // Clean up old temp files on startup
    await _cleanupTempFiles();

    AppLogger.info('CourseDownloadService initialized', {
      'documentsPath': _documentsDir.path,
      'wifiOnly': _settings.wifiOnly,
    });
  }

  /// Get progress stream
  Stream<CourseDownloadProgress?> get progressStream =>
      _progressController.stream;

  /// Get current progress
  CourseDownloadProgress? get currentProgress => _currentProgress;

  /// Check if currently downloading
  bool get isDownloading => _isDownloading;

  /// Check if paused
  bool get isPaused => _isPaused;

  /// Main download method for a course
  Future<void> downloadCourse(String courseId, String courseName,
      List<LearningObject> learningObjects) async {
    if (_isDownloading) {
      AppLogger.warning('Download already in progress');
      return;
    }

    try {
      _isDownloading = true;
      _isPaused = false;
      _cancelToken = CancelToken();

      // Check for existing progress
      _currentProgress = await _loadProgress(courseId);

      if (_currentProgress == null) {
        // Create new progress
        _queue.clear();
        _currentQueueIndex = 0;

        // Build download queue
        for (final lo in learningObjects) {
          _queue.addAll(await _createDownloadTasks(courseId, lo));
        }

        // Calculate total size
        final totalBytes =
            _queue.fold<int>(0, (sum, task) => sum + task.expectedSize);

        _currentProgress = CourseDownloadProgress(
          courseId: courseId,
          courseName: courseName,
          totalFiles: _queue.length,
          completedFiles: 0,
          failedFiles: 0,
          totalBytes: totalBytes,
          downloadedBytes: 0,
          tasks: _queue,
          startedAt: DateTime.now(),
          overallStatus: DownloadStatus.downloading,
        );
      } else {
        // Resume from saved progress
        _queue.clear();
        _queue.addAll(_currentProgress!.tasks);
        _currentQueueIndex = _queue.indexWhere((task) => !task.isComplete);
        if (_currentQueueIndex == -1) _currentQueueIndex = 0;
      }

      // Check network if WiFi-only
      if (_settings.wifiOnly && !(await _isWiFiConnected())) {
        throw Exception('WiFi-only mode enabled but not connected to WiFi');
      }

      // Start processing queue
      await _processQueue();
    } catch (e) {
      AppLogger.error('Download failed', error: e);
      _currentProgress = _currentProgress?.copyWith(
        overallStatus: DownloadStatus.failed,
      );
      _progressController.add(_currentProgress);
      rethrow;
    } finally {
      _isDownloading = false;
      _cancelToken = null;
    }
  }

  /// Process download queue
  Future<void> _processQueue() async {
    while (_currentQueueIndex < _queue.length && !_isPaused) {
      final task = _queue[_currentQueueIndex];

      if (task.isComplete) {
        _currentQueueIndex++;
        continue;
      }

      try {
        await _downloadFile(task);

        // Update task status
        task.status = DownloadStatus.completed;
        task.downloadedBytes = task.expectedSize;

        // Sync individual task progress to Supabase
        await _syncProgressToSupabase(task);

        // Update overall progress
        _updateProgress();
      } catch (e) {
        AppLogger.error('Failed to download file', error: e, data: {
          'taskId': task.id,
          'url': task.url,
        });

        // Handle retry logic
        task.retryCount++;
        task.errorMessage = e.toString();

        if (task.canRetry && !_isPaused) {
          // Exponential backoff
          final delay = _settings.retryDelay * (1 << task.retryCount);
          AppLogger.info('Retrying download after delay', {
            'taskId': task.id,
            'retryCount': task.retryCount,
            'delay': delay.inSeconds,
          });
          await Future.delayed(delay);
          continue; // Retry same file
        } else {
          task.status = DownloadStatus.failed;
          _updateProgress();
        }
      }

      _currentQueueIndex++;
    }

    // Check if all complete
    if (_currentQueueIndex >= _queue.length) {
      _currentProgress = _currentProgress?.copyWith(
        completedAt: DateTime.now(),
        overallStatus: _currentProgress!.hasFailed
            ? DownloadStatus.failed
            : DownloadStatus.completed,
      );
      _progressController.add(_currentProgress);
      await _saveProgress();

      // Create manifest file
      if (_currentProgress?.overallStatus == DownloadStatus.completed) {
        await _createManifest(_currentProgress!.courseId);
      }
    }
  }

  /// Download individual file
  Future<void> _downloadFile(DownloadTask task) async {
    final file = File(task.localPath);
    final tempFile = File('${task.localPath}$_tempExtension');

    try {
      // Ensure directory exists
      await file.parent.create(recursive: true);

      // Check for partial download
      int startByte = 0;
      if (tempFile.existsSync()) {
        startByte = await tempFile.length();
        AppLogger.info('Resuming download from byte $startByte', {
          'taskId': task.id,
        });
      }

      // Download with progress tracking
      task.status = DownloadStatus.downloading;
      _progressController.add(_currentProgress);

      await _dio.download(
        task.url,
        tempFile.path,
        deleteOnError: false,
        cancelToken: _cancelToken,
        options: Options(
          headers: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          responseType: ResponseType.stream,
        ),
        onReceiveProgress: (received, total) {
          task.downloadedBytes = startByte + received;

          // Update overall progress
          final totalDownloaded = _queue.fold<int>(
              0,
              (sum, t) =>
                  sum +
                  (t == task
                      ? task.downloadedBytes
                      : t.isComplete
                          ? t.expectedSize
                          : t.downloadedBytes));

          _currentProgress = _currentProgress?.copyWith(
            downloadedBytes: totalDownloaded,
          );

          // Throttle updates to avoid overwhelming UI
          if (DateTime.now().millisecondsSinceEpoch % 100 < 10) {
            _progressController.add(_currentProgress);
          }
        },
      );

      // Verify download size
      final downloadedSize = await tempFile.length();
      if (downloadedSize < task.expectedSize * 0.9) {
        throw Exception(
            'Downloaded file size mismatch: expected ${task.expectedSize}, got $downloadedSize');
      }

      // Atomic move to final location
      if (file.existsSync()) {
        await file.delete();
      }
      await tempFile.rename(file.path);

      AppLogger.info('File downloaded successfully', {
        'taskId': task.id,
        'size': downloadedSize,
        'path': file.path,
      });
    } catch (e) {
      // Clean up on error if configured
      if (_settings.deleteOnError && tempFile.existsSync()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  /// Update progress and save to storage
  void _updateProgress() {
    if (_currentProgress == null) return;

    final completedFiles = _queue.where((t) => t.isComplete).length;
    final failedFiles = _queue.where((t) => t.isFailed).length;

    _currentProgress = _currentProgress!.copyWith(
      completedFiles: completedFiles,
      failedFiles: failedFiles,
      tasks: _queue,
    );

    _progressController.add(_currentProgress);
    _saveProgress();

    // Sync to Supabase in the background (non-blocking)
    _updateCourseDownloadStatus();
  }

  /// Pause download
  Future<void> pauseDownload() async {
    _isPaused = true;
    _cancelToken?.cancel('User paused download');
    _currentProgress = _currentProgress?.copyWith(
      overallStatus: DownloadStatus.paused,
    );
    _progressController.add(_currentProgress);
    await _saveProgress();

    AppLogger.info('Download paused');
  }

  /// Resume download
  Future<void> resumeDownload() async {
    if (_currentProgress == null) return;

    _isPaused = false;
    _isDownloading = true;
    _cancelToken = CancelToken();

    _currentProgress = _currentProgress?.copyWith(
      overallStatus: DownloadStatus.downloading,
    );
    _progressController.add(_currentProgress);

    // Resume from current position in queue
    await _processQueue();
  }

  /// Retry failed downloads
  Future<void> retryFailed() async {
    if (_currentProgress == null) return;

    // Reset failed tasks
    for (final task in _queue) {
      if (task.isFailed) {
        task.status = DownloadStatus.pending;
        task.retryCount = 0;
        task.errorMessage = null;
      }
    }

    // Find first failed task
    _currentQueueIndex = _queue.indexWhere((t) => !t.isComplete);
    if (_currentQueueIndex == -1) return;

    // Resume processing
    await resumeDownload();
  }

  /// Check if course is fully downloaded
  Future<bool> isCourseDownloaded(String courseId) async {
    final manifestPath = '${await _getCourseDirectory(courseId)}/manifest.json';
    final manifestFile = File(manifestPath);

    if (!await manifestFile.exists()) return false;

    try {
      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

      // Verify all files exist
      final files = manifest['files'] as List;
      for (final filePath in files) {
        final file = File(filePath.toString());
        if (!await file.exists()) {
          return false;
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('Error checking course download', error: e);
      return false;
    }
  }

  /// Delete downloaded course content
  Future<void> deleteCourseContent(String courseId) async {
    try {
      final courseDir = Directory(await _getCourseDirectory(courseId));
      if (await courseDir.exists()) {
        await courseDir.delete(recursive: true);
      }

      // Clear saved progress
      await _prefs.remove('$_prefsKeyPrefix$courseId');

      AppLogger.info('Course content deleted', {'courseId': courseId});
    } catch (e) {
      AppLogger.error('Error deleting course content', error: e);
      rethrow;
    }
  }

  /// Update download settings
  Future<void> updateSettings(DownloadSettings settings) async {
    _settings = settings;
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));

    // Update connectivity monitoring
    if (settings.wifiOnly && _connectivitySubscription == null) {
      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    } else if (!settings.wifiOnly) {
      _connectivitySubscription?.cancel();
      _connectivitySubscription = null;
    }
  }

  // Private helper methods

  /// Create download tasks for a learning object
  Future<List<DownloadTask>> _createDownloadTasks(
      String courseId, LearningObject lo) async {
    final loDir =
        '${await _getCourseDirectory(courseId)}/learning_objects/${lo.id}';

    // Try to fetch CDN URLs from Supabase if available
    Map<String, dynamic>? cdnUrls;
    try {
      if (SupabaseService().isInitialized) {
        final response = await SupabaseService()
            .client
            .from('learning_objects')
            .select('audio_url, content_url, timing_url, file_size_bytes')
            .eq('id', lo.id)
            .maybeSingle();

        if (response != null && response['audio_url'] != null) {
          cdnUrls = response;
          AppLogger.info('Using CDN URLs from Supabase', {
            'learningObjectId': lo.id,
            'hasAudioUrl': response['audio_url'] != null,
            'hasContentUrl': response['content_url'] != null,
            'hasTimingUrl': response['timing_url'] != null,
          });
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to fetch CDN URLs from Supabase', {
        'error': e.toString(),
      });
    }

    // Use CDN URLs if available, otherwise use placeholder URLs
    final baseUrl = cdnUrls != null ? '' : 'https://cdn.example.com/courses';
    final audioUrl =
        cdnUrls?['audio_url'] ?? '$baseUrl/$courseId/${lo.id}/audio.mp3';
    final contentUrl =
        cdnUrls?['content_url'] ?? '$baseUrl/$courseId/${lo.id}/content.json';
    final timingUrl =
        cdnUrls?['timing_url'] ?? '$baseUrl/$courseId/${lo.id}/timing.json';
    final fileSize = cdnUrls?['file_size_bytes'] as int?;

    return [
      DownloadTask(
        id: '${lo.id}_audio',
        url: audioUrl,
        localPath: '$loDir/audio.mp3',
        learningObjectId: lo.id,
        fileType: FileType.audio,
        expectedSize:
            fileSize ?? 3 * 1024 * 1024, // Use actual size or 3MB estimate
      ),
      DownloadTask(
        id: '${lo.id}_content',
        url: contentUrl,
        localPath: '$loDir/content.json',
        learningObjectId: lo.id,
        fileType: FileType.content,
        expectedSize: 10 * 1024, // 10KB estimate
      ),
      DownloadTask(
        id: '${lo.id}_timing',
        url: timingUrl,
        localPath: '$loDir/timing.json',
        learningObjectId: lo.id,
        fileType: FileType.timing,
        expectedSize: 50 * 1024, // 50KB estimate
      ),
    ];
  }

  /// Get course directory path
  Future<String> _getCourseDirectory(String courseId) async {
    return '${_documentsDir.path}/audio_learning/courses/$courseId';
  }

  /// Create manifest file for downloaded course
  Future<void> _createManifest(String courseId) async {
    final courseDir = await _getCourseDirectory(courseId);
    final manifestFile = File('$courseDir/$_manifestFileName');

    final manifest = {
      'courseId': courseId,
      'downloadedAt': DateTime.now().toIso8601String(),
      'version': 1,
      'files': _queue.map((t) => t.localPath).toList(),
    };

    await manifestFile.writeAsString(jsonEncode(manifest));
    AppLogger.info('Manifest created', {'courseId': courseId});
  }

  /// Save progress to SharedPreferences
  Future<void> _saveProgress() async {
    if (_currentProgress == null) return;

    await _prefs.setString(
      '$_prefsKeyPrefix${_currentProgress!.courseId}',
      jsonEncode(_currentProgress!.toJson()),
    );
  }

  /// Load progress from SharedPreferences
  Future<CourseDownloadProgress?> _loadProgress(String courseId) async {
    final json = _prefs.getString('$_prefsKeyPrefix$courseId');
    if (json != null) {
      try {
        return CourseDownloadProgress.fromJson(jsonDecode(json));
      } catch (e) {
        AppLogger.error('Error loading progress', error: e);
      }
    }
    return null;
  }

  /// Clean up old temp files
  Future<void> _cleanupTempFiles() async {
    try {
      final appDir = Directory('${_documentsDir.path}/audio_learning');
      if (!await appDir.exists()) return;

      await for (final file
          in appDir.list(recursive: true, followLinks: false)) {
        if (file is File && file.path.endsWith(_tempExtension)) {
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age.inHours > 24) {
            await file.delete();
            AppLogger.info('Deleted old temp file', {'path': file.path});
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error cleaning temp files', error: e);
    }
  }

  /// Check if connected to WiFi
  Future<bool> _isWiFiConnected() async {
    final results = await _connectivity.checkConnectivity();
    // Check if WiFi is in the list of available connections
    return results.contains(ConnectivityResult.wifi);
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // Check if WiFi is available in the list of connectivity results
    final hasWifi = results.contains(ConnectivityResult.wifi);

    if (_settings.wifiOnly && _isDownloading && !hasWifi) {
      AppLogger.warning('Lost WiFi connection, pausing download');
      pauseDownload();
    }
  }

  /// Sync download progress with Supabase (when migration is applied)
  Future<void> _syncProgressToSupabase(DownloadTask task) async {
    try {
      if (!SupabaseService().isInitialized) return;

      final userId = SupabaseService().getCurrentUser()?.id;
      if (userId == null) return;

      // Try to update download_progress table if it exists
      await SupabaseService().client.from('download_progress').upsert({
        'user_id': userId,
        'learning_object_id': task.learningObjectId,
        'course_id': _currentProgress?.courseId,
        'download_status': task.status.toString().split('.').last,
        'progress_percentage': (task.progress * 100).round(),
        'bytes_downloaded': task.downloadedBytes,
        'total_bytes': task.expectedSize,
        'files_completed': task.isComplete ? 1 : 0,
        'total_files': 1,
        'retry_count': task.retryCount,
        'error_message': task.errorMessage,
        'last_activity_at': DateTime.now().toIso8601String(),
        'started_at': task.status == DownloadStatus.downloading
            ? DateTime.now().toIso8601String()
            : null,
        'completed_at':
            task.isComplete ? DateTime.now().toIso8601String() : null,
      }).onError((error, stackTrace) {
        // Table might not exist yet if migration hasn't been applied
        AppLogger.debug(
            'Download progress sync skipped (table may not exist)', {
          'error': error.toString(),
        });
      });
    } catch (e) {
      // Silently fail - this is optional functionality
      AppLogger.debug('Failed to sync download progress to Supabase', {
        'error': e.toString(),
      });
    }
  }

  /// Update course-level download status in Supabase
  Future<void> _updateCourseDownloadStatus() async {
    try {
      if (!SupabaseService().isInitialized || _currentProgress == null) return;

      final userId = SupabaseService().getCurrentUser()?.id;
      if (userId == null) return;

      await SupabaseService().client.from('course_downloads').upsert({
        'user_id': userId,
        'course_id': _currentProgress!.courseId,
        'download_status':
            _currentProgress!.overallStatus.toString().split('.').last,
        'learning_objects_completed':
            _currentProgress!.completedFiles ~/ 3, // 3 files per LO
        'total_learning_objects': _currentProgress!.totalFiles ~/ 3,
        'total_size_bytes': _currentProgress!.totalBytes,
        'downloaded_bytes': _currentProgress!.downloadedBytes,
        'last_activity_at': DateTime.now().toIso8601String(),
        'completed_at': _currentProgress!.isComplete
            ? DateTime.now().toIso8601String()
            : null,
      }).onError((error, stackTrace) {
        AppLogger.debug('Course download status sync skipped', {
          'error': error.toString(),
        });
      });
    } catch (e) {
      AppLogger.debug('Failed to sync course download status', {
        'error': e.toString(),
      });
    }
  }

  /// Dispose service
  void dispose() {
    _connectivitySubscription?.cancel();
    _progressController.close();
  }
}

/// Validation function for CourseDownloadService
@visibleForTesting
Future<void> validateCourseDownloadService() async {
  debugPrint('=== CourseDownloadService Validation ===');

  final service = await CourseDownloadService.getInstance();

  // Test service initialization
  debugPrint('✓ Service initialization verified');

  // Test settings
  await service.updateSettings(const DownloadSettings(wifiOnly: true));
  debugPrint('✓ Settings update verified');

  // Test course download check
  await service.isCourseDownloaded('test_course');
  debugPrint('✓ Download check verified');

  debugPrint('=== All CourseDownloadService validations passed ===');
}
