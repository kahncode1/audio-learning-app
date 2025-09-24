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
import '../../models/download_models.dart';
import '../../models/learning_object_v2.dart';
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
  Future<void> buildQueue(
      String courseId, List<LearningObjectV2> learningObjects) async {
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
    return _queue
        .where((task) => task.status == DownloadStatus.failed)
        .toList();
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
    _currentQueueIndex =
        _queue.indexWhere((task) => task.status == DownloadStatus.pending);
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
    LearningObjectV2 lo,
  ) async {
    final tasks = <DownloadTask>[];

    // Audio file task - using new audioUrl field
    if (lo.audioUrl.isNotEmpty) {
      tasks.add(DownloadTask(
        id: '${lo.id}_audio_v${lo.fileVersion}',
        courseId: courseId,
        learningObjectId: lo.id,
        url: lo.audioUrl,
        localPath:
            'courses/$courseId/learning_objects/${lo.id}/audio.${lo.audioFormat}',
        fileType: DownloadFileType.audio,
        expectedSize: lo.audioSizeBytes, // Use actual size from database
        status: DownloadStatus.pending,
        version: lo.fileVersion, // Track version for updates
      ));
    }

    // Word timings JSON task - save separately for offline access
    tasks.add(DownloadTask(
      id: '${lo.id}_word_timings_v${lo.fileVersion}',
      courseId: courseId,
      learningObjectId: lo.id,
      url: '', // Will be saved directly from memory
      localPath:
          'courses/$courseId/learning_objects/${lo.id}/word_timings.json',
      fileType: DownloadFileType.timing,
      expectedSize: lo.wordTimings.length * 100, // Estimate based on word count
      status: DownloadStatus.pending,
      version: lo.fileVersion,
      jsonData:
          lo.wordTimings.map((w) => w.toJson()).toList(), // Store timing data
    ));

    // Sentence timings JSON task - save separately for offline access
    tasks.add(DownloadTask(
      id: '${lo.id}_sentence_timings_v${lo.fileVersion}',
      courseId: courseId,
      learningObjectId: lo.id,
      url: '', // Will be saved directly from memory
      localPath:
          'courses/$courseId/learning_objects/${lo.id}/sentence_timings.json',
      fileType: DownloadFileType.timing,
      expectedSize:
          lo.sentenceTimings.length * 200, // Estimate based on sentence count
      status: DownloadStatus.pending,
      version: lo.fileVersion,
      jsonData: lo.sentenceTimings
          .map((s) => s.toJson())
          .toList(), // Store timing data
    ));

    // Content metadata JSON task - save for offline access
    tasks.add(DownloadTask(
      id: '${lo.id}_content_v${lo.fileVersion}',
      courseId: courseId,
      learningObjectId: lo.id,
      url: '', // Will be saved directly from memory
      localPath: 'courses/$courseId/learning_objects/${lo.id}/content.json',
      fileType: DownloadFileType.content,
      expectedSize: 10 * 1024, // Estimate 10KB for metadata
      status: DownloadStatus.pending,
      version: lo.fileVersion,
      jsonData: {
        'display_text': lo.displayText,
        'paragraphs': lo.paragraphs,
        'headers': lo.headers,
        'formatting': lo.formatting.toJson(),
        'metadata': lo.metadata.toJson(),
      },
    ));

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
