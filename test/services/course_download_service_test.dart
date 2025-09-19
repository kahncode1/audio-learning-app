import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/download_models.dart';

void main() {
  group('DownloadModels Tests', () {
    test('DownloadTask progress calculation', () {
      final task = DownloadTask(
        id: 'test_1',
        url: 'https://example.com/test.mp3',
        localPath: '/path/to/test.mp3',
        learningObjectId: 'lo_1',
        fileType: FileType.audio,
        expectedSize: 1000,
        downloadedBytes: 500,
      );

      expect(task.progress, 0.5);
      expect(task.isComplete, false);
      expect(task.canRetry, false);

      // Test failed state with retries
      task.status = DownloadStatus.failed;
      task.retryCount = 2;
      expect(task.isFailed, true);
      expect(task.canRetry, true);

      task.retryCount = 3;
      expect(task.canRetry, false);
    });

    test('DownloadTask JSON serialization', () {
      final task = DownloadTask(
        id: 'test_1',
        url: 'https://example.com/test.mp3',
        localPath: '/path/to/test.mp3',
        learningObjectId: 'lo_1',
        fileType: FileType.audio,
        expectedSize: 1000,
      );

      final json = task.toJson();
      final restored = DownloadTask.fromJson(json);

      expect(restored.id, task.id);
      expect(restored.url, task.url);
      expect(restored.localPath, task.localPath);
      expect(restored.learningObjectId, task.learningObjectId);
      expect(restored.fileType, task.fileType);
      expect(restored.expectedSize, task.expectedSize);
    });

    test('CourseDownloadProgress percentage calculation', () {
      final tasks = [
        DownloadTask(
          id: 'task_1',
          url: 'url1',
          localPath: 'path1',
          learningObjectId: 'lo_1',
          fileType: FileType.audio,
          expectedSize: 1000,
          downloadedBytes: 1000,
          status: DownloadStatus.completed,
        ),
        DownloadTask(
          id: 'task_2',
          url: 'url2',
          localPath: 'path2',
          learningObjectId: 'lo_1',
          fileType: FileType.content,
          expectedSize: 500,
          downloadedBytes: 250,
          status: DownloadStatus.downloading,
        ),
      ];

      final progress = CourseDownloadProgress(
        courseId: 'course_1',
        courseName: 'Test Course',
        totalFiles: 2,
        completedFiles: 1,
        failedFiles: 0,
        totalBytes: 1500,
        downloadedBytes: 1250,
        tasks: tasks,
        startedAt: DateTime.now(),
      );

      expect(progress.percentage, closeTo(0.833, 0.001));
      expect(progress.isComplete, false);
      expect(progress.hasFailed, false);
      expect(progress.pendingFiles, 1);
    });

    test('CourseDownloadProgress formatting methods', () {
      final progress = CourseDownloadProgress(
        courseId: 'course_1',
        courseName: 'Test Course',
        totalFiles: 10,
        completedFiles: 5,
        failedFiles: 1,
        totalBytes: 107 * 1024 * 1024, // 107MB
        downloadedBytes: 53 * 1024 * 1024, // 53MB
        tasks: [],
        startedAt: DateTime.now().subtract(const Duration(seconds: 60)),
      );

      final progressString = progress.getProgressString();
      expect(progressString, contains('MB'));
      expect(progressString, contains('%'));

      // Test byte formatting
      expect(CourseDownloadProgress.formatBytes(512), '512 B');
      expect(CourseDownloadProgress.formatBytes(2048), '2.0 KB');
      expect(CourseDownloadProgress.formatBytes(3145728), '3.0 MB');

      // Test duration formatting
      expect(CourseDownloadProgress.formatDuration(30), '30 sec');
      expect(CourseDownloadProgress.formatDuration(90), '2 min');
      expect(CourseDownloadProgress.formatDuration(3700), '1 hr 2 min');
    });

    test('CourseDownloadInfo from learning objects', () {
      final info = CourseDownloadInfo.fromLearningObjects(
        courseId: 'course_1',
        courseName: 'Test Course',
        learningObjectIds: List.generate(35, (i) => 'lo_$i'),
      );

      expect(info.fileCount, 105); // 35 * 3 files
      expect(info.formattedSize, contains('MB'));
      expect(info.totalSizeBytes, greaterThan(100 * 1024 * 1024)); // >100MB
    });

    test('DownloadSettings serialization', () {
      const settings = DownloadSettings(
        wifiOnly: true,
        maxRetries: 5,
        retryDelay: Duration(seconds: 3),
      );

      final json = settings.toJson();
      final restored = DownloadSettings.fromPrefs(json);

      expect(restored.wifiOnly, settings.wifiOnly);
      expect(restored.maxRetries, settings.maxRetries);
      expect(restored.retryDelay, settings.retryDelay);
    });

    test('Download speed calculation', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 10));
      final progress = CourseDownloadProgress(
        courseId: 'course_1',
        courseName: 'Test Course',
        totalFiles: 10,
        completedFiles: 5,
        failedFiles: 0,
        totalBytes: 10 * 1024 * 1024, // 10MB
        downloadedBytes: 1 * 1024 * 1024, // 1MB in 10 seconds
        tasks: [],
        startedAt: startTime,
      );

      final speed = progress.getDownloadSpeed();
      expect(speed, greaterThan(0));
      expect(speed, lessThan(1024 * 1024)); // Less than 1MB/s

      final timeRemaining = progress.getEstimatedTimeRemaining();
      expect(timeRemaining, greaterThan(0));
    });

    test('CourseDownloadProgress JSON round trip', () {
      final tasks = [
        DownloadTask(
          id: 'task_1',
          url: 'url1',
          localPath: 'path1',
          learningObjectId: 'lo_1',
          fileType: FileType.audio,
          expectedSize: 1000,
        ),
      ];

      final progress = CourseDownloadProgress(
        courseId: 'course_1',
        courseName: 'Test Course',
        totalFiles: 1,
        completedFiles: 0,
        failedFiles: 0,
        totalBytes: 1000,
        downloadedBytes: 0,
        tasks: tasks,
        startedAt: DateTime.now(),
        overallStatus: DownloadStatus.pending,
      );

      final json = progress.toJson();
      final restored = CourseDownloadProgress.fromJson(json);

      expect(restored.courseId, progress.courseId);
      expect(restored.courseName, progress.courseName);
      expect(restored.totalFiles, progress.totalFiles);
      expect(restored.totalBytes, progress.totalBytes);
      expect(restored.tasks.length, progress.tasks.length);
      expect(restored.overallStatus, progress.overallStatus);
    });

    test('Learning object conversion for testing', () {
      // Test that we can create download info from learning object IDs
      final learningObjectIds = ['lo_1', 'lo_2', 'lo_3'];

      final info = CourseDownloadInfo.fromLearningObjects(
        courseId: 'test_course',
        courseName: 'Test Course',
        learningObjectIds: learningObjectIds,
      );

      expect(info.learningObjectIds.length, 3);
      expect(info.fileCount, 9); // 3 objects * 3 files each
    });
  });

  group('Validation Functions', () {
    test('Download models validation', () {
      // This test ensures the validation function runs without errors
      validateDownloadModels();
      expect(true, true); // If we get here, validation passed
    });
  });
}