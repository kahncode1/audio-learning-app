/// Download Models for Course Content
///
/// Purpose: Data models for managing course content downloads
/// Features:
/// - Track individual file downloads
/// - Monitor overall course download progress
/// - Handle download states and errors
/// - Support resume functionality
///
/// Usage:
/// ```dart
/// final task = DownloadTask(
///   id: 'unique_id',
///   url: 'https://example.com/file.mp3',
///   localPath: '/path/to/local/file.mp3',
///   expectedSize: 1024000,
/// );
/// ```

import 'package:flutter/foundation.dart';

/// Represents the download status of a file
enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  paused,
}

/// Types of files being downloaded
enum FileType {
  audio,
  content,
  timing,
}

/// Alias for FileType to match usage in download services
typedef DownloadFileType = FileType;

/// Individual download task for a single file
class DownloadTask {
  final String id;
  final String url;
  final String localPath;
  final String learningObjectId;
  final String? courseId;
  final FileType fileType;
  final int expectedSize;
  int downloadedBytes;
  DownloadStatus status;
  int retryCount;
  String? errorMessage;
  DateTime? lastModified;
  DateTime? lastAttemptAt;
  final int? version; // File version for cache invalidation
  final dynamic jsonData; // For saving JSON directly from memory

  DownloadTask({
    required this.id,
    required this.url,
    required this.localPath,
    required this.learningObjectId,
    this.courseId,
    required this.fileType,
    required this.expectedSize,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    this.lastModified,
    this.lastAttemptAt,
    this.version,
    this.jsonData,
  });

  /// Progress as a percentage (0.0 to 1.0)
  double get progress => expectedSize > 0 ? downloadedBytes / expectedSize : 0.0;

  /// Whether this task is complete
  bool get isComplete => status == DownloadStatus.completed;

  /// Whether this task has failed
  bool get isFailed => status == DownloadStatus.failed;

  /// Whether this task can be retried
  bool get canRetry => isFailed && retryCount < 3;

  /// Create a copy with updated fields
  DownloadTask copyWith({
    int? downloadedBytes,
    DownloadStatus? status,
    int? retryCount,
    String? errorMessage,
    DateTime? lastModified,
    DateTime? lastAttemptAt,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      localPath: localPath,
      learningObjectId: learningObjectId,
      courseId: courseId,
      fileType: fileType,
      expectedSize: expectedSize,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      lastModified: lastModified ?? this.lastModified,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      version: version,
      jsonData: jsonData,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'localPath': localPath,
      'learningObjectId': learningObjectId,
      'courseId': courseId,
      'fileType': fileType.name,
      'expectedSize': expectedSize,
      'downloadedBytes': downloadedBytes,
      'status': status.name,
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'lastModified': lastModified?.toIso8601String(),
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'version': version,
      'jsonData': jsonData,
    };
  }

  /// Create from JSON
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      url: json['url'] as String? ?? '',
      localPath: json['localPath'] as String,
      learningObjectId: json['learningObjectId'] as String,
      courseId: json['courseId'] as String?,
      fileType: FileType.values.byName(json['fileType'] as String),
      expectedSize: json['expectedSize'] as int,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      status: DownloadStatus.values.byName(json['status'] as String? ?? 'pending'),
      retryCount: json['retryCount'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : null,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      version: json['version'] as int?,
      jsonData: json['jsonData'],
    );
  }
}

/// Overall progress for downloading an entire course
class CourseDownloadProgress {
  final String courseId;
  final String courseName;
  final int totalFiles;
  final int completedFiles;
  final int failedFiles;
  final int totalBytes;
  final int downloadedBytes;
  final List<DownloadTask> tasks;
  final DateTime startedAt;
  DateTime? completedAt;
  DownloadStatus overallStatus;

  CourseDownloadProgress({
    required this.courseId,
    required this.courseName,
    required this.totalFiles,
    required this.completedFiles,
    required this.failedFiles,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.tasks,
    required this.startedAt,
    this.completedAt,
    this.overallStatus = DownloadStatus.pending,
  });

  /// Overall progress as a percentage (0.0 to 1.0)
  double get percentage => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  /// Whether all files have been downloaded
  bool get isComplete => completedFiles == totalFiles;

  /// Whether any files have failed
  bool get hasFailed => failedFiles > 0;

  /// Get count of pending files
  int get pendingFiles => totalFiles - completedFiles - failedFiles;

  /// Get current download speed estimate (bytes per second)
  int getDownloadSpeed() {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    if (elapsed <= 0) return 0;
    return (downloadedBytes / elapsed).round();
  }

  /// Estimate time remaining in seconds
  int? getEstimatedTimeRemaining() {
    final speed = getDownloadSpeed();
    if (speed <= 0) return null;
    final remainingBytes = totalBytes - downloadedBytes;
    return (remainingBytes / speed).round();
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Format duration to human-readable string
  static String formatDuration(int seconds) {
    if (seconds < 60) return '$seconds sec';
    if (seconds < 3600) return '${(seconds / 60).round()} min';
    return '${(seconds / 3600).round()} hr ${((seconds % 3600) / 60).round()} min';
  }

  /// Get human-readable progress string
  String getProgressString() {
    return '${formatBytes(downloadedBytes)} / ${formatBytes(totalBytes)} (${(percentage * 100).toStringAsFixed(0)}%)';
  }

  /// Create a copy with updated fields
  CourseDownloadProgress copyWith({
    int? completedFiles,
    int? failedFiles,
    int? downloadedBytes,
    List<DownloadTask>? tasks,
    DateTime? completedAt,
    DownloadStatus? overallStatus,
  }) {
    return CourseDownloadProgress(
      courseId: courseId,
      courseName: courseName,
      totalFiles: totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
      failedFiles: failedFiles ?? this.failedFiles,
      totalBytes: totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      tasks: tasks ?? this.tasks,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      overallStatus: overallStatus ?? this.overallStatus,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'courseId': courseId,
      'courseName': courseName,
      'totalFiles': totalFiles,
      'completedFiles': completedFiles,
      'failedFiles': failedFiles,
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'overallStatus': overallStatus.name,
    };
  }

  /// Create from JSON
  factory CourseDownloadProgress.fromJson(Map<String, dynamic> json) {
    return CourseDownloadProgress(
      courseId: json['courseId'] as String,
      courseName: json['courseName'] as String,
      totalFiles: json['totalFiles'] as int,
      completedFiles: json['completedFiles'] as int,
      failedFiles: json['failedFiles'] as int,
      totalBytes: json['totalBytes'] as int,
      downloadedBytes: json['downloadedBytes'] as int,
      tasks: (json['tasks'] as List)
          .map((t) => DownloadTask.fromJson(t as Map<String, dynamic>))
          .toList(),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      overallStatus: DownloadStatus.values.byName(
        json['overallStatus'] as String? ?? 'pending',
      ),
    );
  }
}

/// Information about what needs to be downloaded for a course
class CourseDownloadInfo {
  final String courseId;
  final String courseName;
  final List<String> learningObjectIds;
  final int totalSizeBytes;
  final int fileCount;

  CourseDownloadInfo({
    required this.courseId,
    required this.courseName,
    required this.learningObjectIds,
    required this.totalSizeBytes,
    required this.fileCount,
  });

  /// Get human-readable size
  String get formattedSize => CourseDownloadProgress.formatBytes(totalSizeBytes);

  /// Create from learning objects
  factory CourseDownloadInfo.fromLearningObjects({
    required String courseId,
    required String courseName,
    required List<String> learningObjectIds,
  }) {
    // Estimate sizes: ~3MB audio, ~10KB content, ~50KB timing per object
    const audioSize = 3 * 1024 * 1024; // 3MB
    const contentSize = 10 * 1024; // 10KB
    const timingSize = 50 * 1024; // 50KB
    const filesPerObject = 3;

    final totalSize = learningObjectIds.length * (audioSize + contentSize + timingSize);
    final fileCount = learningObjectIds.length * filesPerObject;

    return CourseDownloadInfo(
      courseId: courseId,
      courseName: courseName,
      learningObjectIds: learningObjectIds,
      totalSizeBytes: totalSize,
      fileCount: fileCount,
    );
  }
}

/// Settings for download behavior
class DownloadSettings {
  final bool wifiOnly;
  final int maxRetries;
  final Duration retryDelay;
  final bool allowBackground;
  final bool deleteOnError;

  const DownloadSettings({
    this.wifiOnly = false,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
    this.allowBackground = true,
    this.deleteOnError = true,
  });

  /// Create from SharedPreferences
  factory DownloadSettings.fromPrefs(Map<String, dynamic> prefs) {
    return DownloadSettings(
      wifiOnly: prefs['wifiOnly'] as bool? ?? false,
      maxRetries: prefs['maxRetries'] as int? ?? 3,
      retryDelay: Duration(
        seconds: prefs['retryDelaySeconds'] as int? ?? 2,
      ),
      allowBackground: prefs['allowBackground'] as bool? ?? true,
      deleteOnError: prefs['deleteOnError'] as bool? ?? true,
    );
  }

  /// Convert to map for SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'wifiOnly': wifiOnly,
      'maxRetries': maxRetries,
      'retryDelaySeconds': retryDelay.inSeconds,
      'allowBackground': allowBackground,
      'deleteOnError': deleteOnError,
    };
  }
}

/// Validation function for download models
@visibleForTesting
void validateDownloadModels() {
  debugPrint('=== Download Models Validation ===');

  // Test DownloadTask
  final task = DownloadTask(
    id: 'test_task_1',
    url: 'https://example.com/audio.mp3',
    localPath: '/path/to/audio.mp3',
    learningObjectId: 'test_lo_1',
    fileType: FileType.audio,
    expectedSize: 3145728, // 3MB
    downloadedBytes: 1572864, // 1.5MB
  );

  assert(task.progress == 0.5, 'Progress should be 50%');
  assert(!task.isComplete, 'Task should not be complete');
  assert(!task.canRetry, 'Task should not be retriable when not failed');

  // Test failed state
  task.status = DownloadStatus.failed;
  assert(task.isFailed, 'Task should be marked as failed');
  assert(task.canRetry, 'Failed task should be retriable');

  // Reset for JSON test
  task.status = DownloadStatus.pending;

  // Test JSON serialization
  final taskJson = task.toJson();
  final taskFromJson = DownloadTask.fromJson(taskJson);
  assert(taskFromJson.id == task.id, 'Task should survive JSON round trip');

  // Test CourseDownloadProgress
  final progress = CourseDownloadProgress(
    courseId: 'course_1',
    courseName: 'Test Course',
    totalFiles: 10,
    completedFiles: 5,
    failedFiles: 1,
    totalBytes: 107 * 1024 * 1024, // 107MB
    downloadedBytes: 53 * 1024 * 1024, // 53MB
    tasks: [task],
    startedAt: DateTime.now(),
  );

  assert(progress.percentage >= 0.49 && progress.percentage <= 0.51,
      'Progress percentage should be ~50%');
  assert(progress.pendingFiles == 4, 'Should have 4 pending files');
  assert(progress.hasFailed, 'Should have failed files');
  assert(progress.getProgressString().contains('MB'), 'Progress string should contain MB');

  // Test JSON serialization
  final progressJson = progress.toJson();
  final progressFromJson = CourseDownloadProgress.fromJson(progressJson);
  assert(progressFromJson.courseId == progress.courseId,
      'Progress should survive JSON round trip');

  // Test CourseDownloadInfo
  final info = CourseDownloadInfo.fromLearningObjects(
    courseId: 'course_1',
    courseName: 'Test Course',
    learningObjectIds: List.generate(35, (i) => 'lo_$i'),
  );

  assert(info.fileCount == 105, 'Should have 105 files (35 * 3)');
  assert(info.formattedSize.contains('MB'), 'Size should be in MB');

  // Test DownloadSettings
  const settings = DownloadSettings(wifiOnly: true);
  final settingsJson = settings.toJson();
  final settingsFromPrefs = DownloadSettings.fromPrefs(settingsJson);
  assert(settingsFromPrefs.wifiOnly == true, 'Settings should preserve wifiOnly');

  debugPrint('✓ All download model validations passed');
}