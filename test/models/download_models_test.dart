import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/download_models.dart';

void main() {
  group('Download Models', () {
    group('DownloadStatus Enum', () {
      test('should have all required statuses', () {
        expect(DownloadStatus.pending, isNotNull);
        expect(DownloadStatus.downloading, isNotNull);
        expect(DownloadStatus.completed, isNotNull);
        expect(DownloadStatus.failed, isNotNull);
        expect(DownloadStatus.paused, isNotNull);
      });
    });

    group('FileType Enum', () {
      test('should have all file types', () {
        expect(FileType.audio, isNotNull);
        expect(FileType.content, isNotNull);
        expect(FileType.timing, isNotNull);
      });
    });

    group('DownloadTask', () {
      late DownloadTask task;

      setUp(() {
        task = DownloadTask(
          id: 'task-123',
          url: 'https://example.com/test.mp3',
          localPath: '/local/test.mp3',
          learningObjectId: 'lo-456',
          fileType: FileType.audio,
          expectedSize: 2048000, // 2MB
        );
      });

      group('Constructor', () {
        test('should create task with all required fields', () {
          expect(task.id, 'task-123');
          expect(task.url, 'https://example.com/test.mp3');
          expect(task.localPath, '/local/test.mp3');
          expect(task.learningObjectId, 'lo-456');
          expect(task.fileType, FileType.audio);
          expect(task.expectedSize, 2048000);
          expect(task.downloadedBytes, 0);
          expect(task.status, DownloadStatus.pending);
          expect(task.retryCount, 0);
          expect(task.errorMessage, isNull);
          expect(task.lastModified, isNull);
        });

        test('should create task with optional fields', () {
          final taskWithOptionals = DownloadTask(
            id: 'task-456',
            url: 'https://example.com/content.json',
            localPath: '/local/content.json',
            learningObjectId: 'lo-789',
            fileType: FileType.content,
            expectedSize: 10240,
            downloadedBytes: 5120,
            status: DownloadStatus.downloading,
            retryCount: 2,
            errorMessage: 'Network error',
            lastModified: DateTime.now(),
          );

          expect(taskWithOptionals.downloadedBytes, 5120);
          expect(taskWithOptionals.status, DownloadStatus.downloading);
          expect(taskWithOptionals.retryCount, 2);
          expect(taskWithOptionals.errorMessage, 'Network error');
          expect(taskWithOptionals.lastModified, isNotNull);
        });
      });

      group('Progress Calculation', () {
        test('should calculate progress correctly', () {
          task.downloadedBytes = 1024000; // 1MB
          expect(task.progress, 0.5);
        });

        test('should handle zero expected size', () {
          final zeroSizeTask = DownloadTask(
            id: 'zero',
            url: 'url',
            localPath: 'path',
            learningObjectId: 'lo',
            fileType: FileType.content,
            expectedSize: 0,
          );
          expect(zeroSizeTask.progress, 0.0);
        });

        test('should handle complete download', () {
          task.downloadedBytes = 2048000; // Full size
          expect(task.progress, 1.0);
        });
      });

      group('Status Properties', () {
        test('isComplete should return true when completed', () {
          task.status = DownloadStatus.completed;
          expect(task.isComplete, true);
        });

        test('isComplete should return false when not completed', () {
          task.status = DownloadStatus.downloading;
          expect(task.isComplete, false);
        });

        test('isFailed should return true when failed', () {
          task.status = DownloadStatus.failed;
          expect(task.isFailed, true);
        });

        test('isFailed should return false when not failed', () {
          task.status = DownloadStatus.completed;
          expect(task.isFailed, false);
        });
      });

      group('Retry Logic', () {
        test('canRetry should be true for failed task with low retry count', () {
          task.status = DownloadStatus.failed;
          task.retryCount = 1;
          expect(task.canRetry, true);
        });

        test('canRetry should be false for failed task with high retry count', () {
          task.status = DownloadStatus.failed;
          task.retryCount = 3;
          expect(task.canRetry, false);
        });

        test('canRetry should be false for non-failed task', () {
          task.status = DownloadStatus.completed;
          task.retryCount = 0;
          expect(task.canRetry, false);
        });
      });

      group('copyWith', () {
        test('should create copy with updated fields', () {
          final updated = task.copyWith(
            downloadedBytes: 1024000,
            status: DownloadStatus.downloading,
            retryCount: 1,
            errorMessage: 'Test error',
            lastModified: DateTime.now(),
          );

          expect(updated.downloadedBytes, 1024000);
          expect(updated.status, DownloadStatus.downloading);
          expect(updated.retryCount, 1);
          expect(updated.errorMessage, 'Test error');
          expect(updated.lastModified, isNotNull);
          
          // Original fields should be preserved
          expect(updated.id, task.id);
          expect(updated.url, task.url);
          expect(updated.expectedSize, task.expectedSize);
        });
      });

      group('JSON Serialization', () {
        test('should serialize to JSON correctly', () {
          task.downloadedBytes = 512000;
          task.status = DownloadStatus.downloading;
          task.retryCount = 1;
          task.errorMessage = 'Network timeout';
          task.lastModified = DateTime.parse('2024-01-15T10:30:00Z');

          final json = task.toJson();

          expect(json['id'], 'task-123');
          expect(json['url'], 'https://example.com/test.mp3');
          expect(json['fileType'], 'audio');
          expect(json['downloadedBytes'], 512000);
          expect(json['status'], 'downloading');
          expect(json['retryCount'], 1);
          expect(json['errorMessage'], 'Network timeout');
          expect(json['lastModified'], '2024-01-15T10:30:00.000Z');
        });

        test('should deserialize from JSON correctly', () {
          final json = {
            'id': 'task-789',
            'url': 'https://example.com/timing.json',
            'localPath': '/local/timing.json',
            'learningObjectId': 'lo-123',
            'fileType': 'timing',
            'expectedSize': 51200,
            'downloadedBytes': 25600,
            'status': 'failed',
            'retryCount': 2,
            'errorMessage': 'Server error',
            'lastModified': '2024-02-01T15:45:00Z',
          };

          final restored = DownloadTask.fromJson(json);

          expect(restored.id, 'task-789');
          expect(restored.fileType, FileType.timing);
          expect(restored.downloadedBytes, 25600);
          expect(restored.status, DownloadStatus.failed);
          expect(restored.retryCount, 2);
          expect(restored.errorMessage, 'Server error');
          expect(restored.lastModified, DateTime.parse('2024-02-01T15:45:00Z'));
        });

        test('should handle missing optional fields in JSON', () {
          final minimalJson = {
            'id': 'minimal',
            'url': 'url',
            'localPath': 'path',
            'learningObjectId': 'lo',
            'fileType': 'content',
            'expectedSize': 1024,
          };

          final task = DownloadTask.fromJson(minimalJson);

          expect(task.downloadedBytes, 0);
          expect(task.status, DownloadStatus.pending);
          expect(task.retryCount, 0);
          expect(task.errorMessage, isNull);
          expect(task.lastModified, isNull);
        });

        test('round-trip serialization should preserve data', () {
          task.downloadedBytes = 100000;
          task.status = DownloadStatus.completed;
          task.lastModified = DateTime.now();

          final json = task.toJson();
          final restored = DownloadTask.fromJson(json);

          expect(restored.id, task.id);
          expect(restored.downloadedBytes, task.downloadedBytes);
          expect(restored.status, task.status);
          expect(restored.lastModified, task.lastModified);
        });
      });
    });

    group('CourseDownloadProgress', () {
      late CourseDownloadProgress progress;
      late List<DownloadTask> tasks;

      setUp(() {
        tasks = [
          DownloadTask(
            id: 'task1',
            url: 'url1',
            localPath: 'path1',
            learningObjectId: 'lo1',
            fileType: FileType.audio,
            expectedSize: 1024000,
          ),
          DownloadTask(
            id: 'task2',
            url: 'url2',
            localPath: 'path2',
            learningObjectId: 'lo2',
            fileType: FileType.content,
            expectedSize: 10240,
          ),
        ];

        progress = CourseDownloadProgress(
          courseId: 'course-123',
          courseName: 'Test Course',
          totalFiles: 10,
          completedFiles: 3,
          failedFiles: 1,
          totalBytes: 104857600, // 100MB
          downloadedBytes: 52428800, // 50MB
          tasks: tasks,
          startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
      });

      group('Constructor', () {
        test('should create progress with all required fields', () {
          expect(progress.courseId, 'course-123');
          expect(progress.courseName, 'Test Course');
          expect(progress.totalFiles, 10);
          expect(progress.completedFiles, 3);
          expect(progress.failedFiles, 1);
          expect(progress.totalBytes, 104857600);
          expect(progress.downloadedBytes, 52428800);
          expect(progress.tasks, tasks);
          expect(progress.overallStatus, DownloadStatus.pending);
        });
      });

      group('Progress Calculations', () {
        test('should calculate percentage correctly', () {
          expect(progress.percentage, 0.5);
        });

        test('should handle zero total bytes', () {
          final zeroProgress = progress.copyWith();
          final zeroBytesProgress = CourseDownloadProgress(
            courseId: progress.courseId,
            courseName: progress.courseName,
            totalFiles: progress.totalFiles,
            completedFiles: progress.completedFiles,
            failedFiles: progress.failedFiles,
            totalBytes: 0,
            downloadedBytes: 0,
            tasks: tasks,
            startedAt: progress.startedAt,
          );
          expect(zeroBytesProgress.percentage, 0.0);
        });

        test('should determine completion status', () {
          expect(progress.isComplete, false);
          
          final completed = progress.copyWith(completedFiles: 10);
          expect(completed.isComplete, true);
        });

        test('should detect failed files', () {
          expect(progress.hasFailed, true);
          
          final noFails = progress.copyWith(failedFiles: 0);
          expect(noFails.hasFailed, false);
        });

        test('should calculate pending files', () {
          expect(progress.pendingFiles, 6); // 10 - 3 - 1
        });
      });

      group('Speed and Time Estimation', () {
        test('should calculate download speed', () {
          final speed = progress.getDownloadSpeed();
          expect(speed, greaterThan(0));
        });

        test('should estimate time remaining', () {
          final timeRemaining = progress.getEstimatedTimeRemaining();
          expect(timeRemaining, isA<int?>());
          if (timeRemaining != null) {
            expect(timeRemaining, greaterThanOrEqualTo(0));
          }
        });
      });

      group('Formatting', () {
        test('should format bytes correctly', () {
          expect(CourseDownloadProgress.formatBytes(1024), '1.0 KB');
          expect(CourseDownloadProgress.formatBytes(1048576), '1.0 MB');
          expect(CourseDownloadProgress.formatBytes(1073741824), '1.00 GB');
          expect(CourseDownloadProgress.formatBytes(512), '512 B');
        });

        test('should format duration correctly', () {
          expect(CourseDownloadProgress.formatDuration(30), '30 sec');
          expect(CourseDownloadProgress.formatDuration(90), '2 min');
          expect(CourseDownloadProgress.formatDuration(3661), '1 hr 1 min');
        });

        test('should format progress string', () {
          final progressStr = progress.getProgressString();
          expect(progressStr, contains('MB'));
          expect(progressStr, contains('50%'));
        });
      });

      group('JSON Serialization', () {
        test('should serialize to JSON correctly', () {
          final json = progress.toJson();

          expect(json['courseId'], 'course-123');
          expect(json['totalFiles'], 10);
          expect(json['tasks'], hasLength(2));
          expect(json['overallStatus'], 'pending');
        });

        test('should deserialize from JSON correctly', () {
          final json = progress.toJson();
          final restored = CourseDownloadProgress.fromJson(json);

          expect(restored.courseId, progress.courseId);
          expect(restored.totalFiles, progress.totalFiles);
          expect(restored.tasks.length, progress.tasks.length);
          expect(restored.overallStatus, progress.overallStatus);
        });
      });
    });

    group('CourseDownloadInfo', () {
      test('should create from learning objects', () {
        final info = CourseDownloadInfo.fromLearningObjects(
          courseId: 'course-456',
          courseName: 'Large Course',
          learningObjectIds: List.generate(20, (i) => 'lo-$i'),
        );

        expect(info.courseId, 'course-456');
        expect(info.courseName, 'Large Course');
        expect(info.learningObjectIds.length, 20);
        expect(info.fileCount, 60); // 20 * 3 files per object
        expect(info.totalSizeBytes, greaterThan(0));
      });

      test('should format size correctly', () {
        final info = CourseDownloadInfo.fromLearningObjects(
          courseId: 'course',
          courseName: 'Course',
          learningObjectIds: ['lo1', 'lo2'],
        );

        expect(info.formattedSize, contains('MB'));
      });
    });

    group('DownloadSettings', () {
      test('should create with defaults', () {
        const settings = DownloadSettings();

        expect(settings.wifiOnly, false);
        expect(settings.maxRetries, 3);
        expect(settings.retryDelay, const Duration(seconds: 2));
        expect(settings.allowBackground, true);
        expect(settings.deleteOnError, true);
      });

      test('should create with custom values', () {
        const settings = DownloadSettings(
          wifiOnly: true,
          maxRetries: 5,
          retryDelay: Duration(seconds: 10),
          allowBackground: false,
          deleteOnError: false,
        );

        expect(settings.wifiOnly, true);
        expect(settings.maxRetries, 5);
        expect(settings.retryDelay, const Duration(seconds: 10));
        expect(settings.allowBackground, false);
        expect(settings.deleteOnError, false);
      });

      test('should serialize to JSON for preferences', () {
        const settings = DownloadSettings(
          wifiOnly: true,
          maxRetries: 2,
          retryDelay: Duration(seconds: 5),
        );

        final json = settings.toJson();

        expect(json['wifiOnly'], true);
        expect(json['maxRetries'], 2);
        expect(json['retryDelaySeconds'], 5);
      });

      test('should create from preferences map', () {
        final prefs = {
          'wifiOnly': true,
          'maxRetries': 4,
          'retryDelaySeconds': 8,
          'allowBackground': false,
        };

        final settings = DownloadSettings.fromPrefs(prefs);

        expect(settings.wifiOnly, true);
        expect(settings.maxRetries, 4);
        expect(settings.retryDelay, const Duration(seconds: 8));
        expect(settings.allowBackground, false);
      });

      test('should use defaults for missing preference values', () {
        final prefs = <String, dynamic>{};
        final settings = DownloadSettings.fromPrefs(prefs);

        expect(settings.wifiOnly, false);
        expect(settings.maxRetries, 3);
        expect(settings.retryDelay, const Duration(seconds: 2));
      });
    });

    group('Validation Function', () {
      test('validateDownloadModels should not throw', () {
        expect(() => validateDownloadModels(), returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle very large file sizes', () {
        final task = DownloadTask(
          id: 'large',
          url: 'url',
          localPath: 'path',
          learningObjectId: 'lo',
          fileType: FileType.audio,
          expectedSize: 5 * 1024 * 1024 * 1024, // 5GB
        );

        task.downloadedBytes = 2 * 1024 * 1024 * 1024; // 2GB
        expect(task.progress, closeTo(0.4, 0.01));

        final formattedSize = CourseDownloadProgress.formatBytes(task.expectedSize);
        expect(formattedSize, contains('GB'));
      });

      test('should handle zero-size downloads', () {
        final task = DownloadTask(
          id: 'zero',
          url: 'url',
          localPath: 'path',
          learningObjectId: 'lo',
          fileType: FileType.content,
          expectedSize: 0,
        );

        expect(task.progress, 0.0);
        expect(task.isComplete, false);
      });

      test('should handle negative values gracefully', () {
        final progress = CourseDownloadProgress(
          courseId: 'test',
          courseName: 'Test',
          totalFiles: 5,
          completedFiles: 3,
          failedFiles: 0,
          totalBytes: 1000,
          downloadedBytes: -100, // Negative (invalid)
          tasks: [],
          startedAt: DateTime.now(),
        );

        expect(progress.percentage, lessThan(0)); // Will be negative but won't crash
      });
    });
  });
}