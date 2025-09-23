/// Download Queue Manager
///
/// Purpose: Manages download queue operations and task prioritization
/// Handles queue state, task ordering, and retry logic
///
/// Responsibilities:
/// - Queue management and task ordering
/// - Priority handling for download tasks
/// - Retry count management
/// - Queue state persistence
///
import 'dart:collection';
import '../../models/download_models.dart';
import '../../models/learning_object.dart';
import '../../utils/app_logger.dart';

class DownloadQueueManager {
  final List<DownloadTask> _queue = [];
  int _currentQueueIndex = 0;

  /// Get current queue
  List<DownloadTask> get queue => List.unmodifiable(_queue);

  /// Get current queue index
  int get currentQueueIndex => _currentQueueIndex;

  /// Get current task
  DownloadTask? get currentTask {
    if (_currentQueueIndex >= 0 && _currentQueueIndex < _queue.length) {
      return _queue[_currentQueueIndex];
    }
    return null;
  }

  /// Check if queue is complete
  bool get isQueueComplete => _currentQueueIndex >= _queue.length;

  /// Clear queue
  void clearQueue() {
    _queue.clear();
    _currentQueueIndex = 0;
    AppLogger.info('Download queue cleared');
  }

  /// Build queue from learning objects
  Future<void> buildQueue(String courseId, List<LearningObject> learningObjects) async {
    clearQueue();

    for (final lo in learningObjects) {
      final tasks = await _createDownloadTasksForLearningObject(courseId, lo);
      _queue.addAll(tasks);
    }

    AppLogger.info('Download queue built', {
      'courseId': courseId,
      'totalTasks': _queue.length,
      'totalLearningObjects': learningObjects.length,
    });
  }

  /// Restore queue from saved progress
  void restoreQueue(List<DownloadTask> tasks) {
    _queue.clear();
    _queue.addAll(tasks);

    // Find first incomplete task
    _currentQueueIndex = _queue.indexWhere((task) => !task.isComplete);
    if (_currentQueueIndex == -1) {
      _currentQueueIndex = 0;
    }

    AppLogger.info('Queue restored from progress', {
      'totalTasks': _queue.length,
      'currentIndex': _currentQueueIndex,
      'completedTasks': _queue.where((t) => t.isComplete).length,
    });
  }

  /// Move to next task in queue
  void moveToNextTask() {
    if (_currentQueueIndex < _queue.length) {
      _currentQueueIndex++;
    }
  }

  /// Skip current task (on failure)
  void skipCurrentTask() {
    if (currentTask != null) {
      currentTask!.status = DownloadStatus.failed;
    }
    moveToNextTask();
  }

  /// Mark current task as complete
  void markCurrentTaskComplete() {
    if (currentTask != null) {
      currentTask!.status = DownloadStatus.completed;
      currentTask!.downloadedBytes = currentTask!.expectedSize;
    }
  }

  /// Handle retry for current task
  bool shouldRetryCurrentTask(DownloadSettings settings) {
    final task = currentTask;
    if (task == null) return false;

    task.retryCount++;
    task.lastAttemptAt = DateTime.now();

    return task.canRetry;
  }

  /// Calculate retry delay for current task
  Duration getRetryDelay(DownloadSettings settings) {
    final task = currentTask;
    if (task == null) return settings.retryDelay;

    // Exponential backoff
    return settings.retryDelay * (1 << task.retryCount);
  }

  /// Get failed tasks
  List<DownloadTask> getFailedTasks() {
    return _queue.where((task) => task.status == DownloadStatus.failed).toList();
  }

  /// Reset failed tasks for retry
  void resetFailedTasks() {
    for (final task in _queue) {
      if (task.status == DownloadStatus.failed) {
        task.status = DownloadStatus.pending;
        task.retryCount = 0;
        task.errorMessage = null;
        task.downloadedBytes = 0;
      }
    }

    // Reset to first failed task
    _currentQueueIndex = _queue.indexWhere((task) => task.status == DownloadStatus.pending);
    if (_currentQueueIndex == -1) {
      _currentQueueIndex = 0;
    }
  }

  /// Calculate total bytes for all tasks
  int calculateTotalBytes() {
    return _queue.fold<int>(0, (sum, task) => sum + task.expectedSize);
  }

  /// Calculate downloaded bytes
  int calculateDownloadedBytes() {
    return _queue.fold<int>(0, (sum, task) {
      if (task.isComplete) {
        return sum + task.expectedSize;
      } else {
        return sum + task.downloadedBytes;
      }
    });
  }

  /// Get queue statistics
  QueueStatistics getStatistics() {
    int completed = 0;
    int failed = 0;
    int pending = 0;
    int downloading = 0;

    for (final task in _queue) {
      switch (task.status) {
        case DownloadStatus.completed:
          completed++;
          break;
        case DownloadStatus.failed:
          failed++;
          break;
        case DownloadStatus.downloading:
          downloading++;
          break;
        case DownloadStatus.pending:
        default:
          pending++;
          break;
      }
    }

    return QueueStatistics(
      totalTasks: _queue.length,
      completedTasks: completed,
      failedTasks: failed,
      pendingTasks: pending,
      downloadingTasks: downloading,
      totalBytes: calculateTotalBytes(),
      downloadedBytes: calculateDownloadedBytes(),
    );
  }

  /// Create download tasks for a learning object
  Future<List<DownloadTask>> _createDownloadTasksForLearningObject(
    String courseId,
    LearningObject lo,
  ) async {
    final tasks = <DownloadTask>[];

    // Audio file task
    if (lo.audioUrl != null && lo.audioUrl!.isNotEmpty) {
      tasks.add(DownloadTask(
        id: '${lo.id}_audio',
        courseId: courseId,
        learningObjectId: lo.id,
        url: lo.audioUrl!,
        localPath: 'courses/$courseId/learning_objects/${lo.id}/audio.mp3',
        fileType: DownloadFileType.audio,
        expectedSize: 5 * 1024 * 1024, // Estimate 5MB
        status: DownloadStatus.pending,
      ));
    }

    // Content JSON task
    if (lo.contentUrl != null && lo.contentUrl!.isNotEmpty) {
      tasks.add(DownloadTask(
        id: '${lo.id}_content',
        courseId: courseId,
        learningObjectId: lo.id,
        url: lo.contentUrl!,
        localPath: 'courses/$courseId/learning_objects/${lo.id}/content.json',
        fileType: DownloadFileType.content,
        expectedSize: 50 * 1024, // Estimate 50KB
        status: DownloadStatus.pending,
      ));
    }

    // Timing JSON task
    if (lo.timingUrl != null && lo.timingUrl!.isNotEmpty) {
      tasks.add(DownloadTask(
        id: '${lo.id}_timing',
        courseId: courseId,
        learningObjectId: lo.id,
        url: lo.timingUrl!,
        localPath: 'courses/$courseId/learning_objects/${lo.id}/timing.json',
        fileType: DownloadFileType.timing,
        expectedSize: 100 * 1024, // Estimate 100KB
        status: DownloadStatus.pending,
      ));
    }

    return tasks;
  }
}

/// Queue statistics model
class QueueStatistics {
  final int totalTasks;
  final int completedTasks;
  final int failedTasks;
  final int pendingTasks;
  final int downloadingTasks;
  final int totalBytes;
  final int downloadedBytes;

  QueueStatistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.failedTasks,
    required this.pendingTasks,
    required this.downloadingTasks,
    required this.totalBytes,
    required this.downloadedBytes,
  });

  double get progressPercentage {
    if (totalTasks == 0) return 0;
    return completedTasks / totalTasks;
  }

  double get bytesPercentage {
    if (totalBytes == 0) return 0;
    return downloadedBytes / totalBytes;
  }

  bool get hasFailures => failedTasks > 0;
  bool get isComplete => completedTasks == totalTasks;
}