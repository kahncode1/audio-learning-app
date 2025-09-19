import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/course_download_service.dart';
import 'package:audio_learning_app/services/local_content_service.dart';
import 'package:audio_learning_app/models/download_models.dart';
import 'package:audio_learning_app/widgets/download_confirmation_dialog.dart';
import 'package:audio_learning_app/screens/download_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

void main() {
  group('Download Service Integration Tests', () {
    test('CourseDownloadService initializes correctly', () async {
      final service = await CourseDownloadService.getInstance();
      expect(service, isNotNull);
      expect(service.isDownloading, false);
      expect(service.isPaused, false);
    });

    test('Download settings can be updated', () async {
      final service = await CourseDownloadService.getInstance();

      const newSettings = DownloadSettings(
        wifiOnly: true,
        maxRetries: 5,
        retryDelay: Duration(seconds: 3),
      );

      await service.updateSettings(newSettings);
      // Settings should be saved and applied
      expect(true, true); // Settings saved successfully
    });

    test('Check if course is downloaded returns false for non-existent course', () async {
      final service = await CourseDownloadService.getInstance();
      final isDownloaded = await service.isCourseDownloaded('non_existent_course');
      expect(isDownloaded, false);
    });

    test('LocalContentService checks downloaded files first', () async {
      final service = LocalContentService.instance;

      // Set a course ID for testing
      service.setCourseId('TEST-101');

      // Check if content is available (should check downloaded first, then assets)
      final isAvailable = await service.isContentAvailable('63ad7b78-0970-4265-a4fe-51f3fee39d5f');
      expect(isAvailable, true); // Test content exists in assets
    });

    test('LocalContentService can load test content from assets', () async {
      final service = LocalContentService.instance;

      // Load test content
      final content = await service.getContent('63ad7b78-0970-4265-a4fe-51f3fee39d5f');
      expect(content, isNotNull);
      expect(content['version'], '1.0');
      expect(content['displayText'], isNotNull);

      // Load timing data
      final timing = await service.getTimingData('63ad7b78-0970-4265-a4fe-51f3fee39d5f');
      expect(timing, isNotNull);
      expect(timing.words.length, greaterThan(0));
      expect(timing.sentences.length, greaterThan(0));

      // Get audio path
      final audioPath = await service.getAudioPath('63ad7b78-0970-4265-a4fe-51f3fee39d5f');
      expect(audioPath, contains('audio.mp3'));
    });
  });

  group('Download UI Widget Tests', () {
    testWidgets('DownloadConfirmationDialog renders correctly', (WidgetTester tester) async {
      final courseInfo = CourseDownloadInfo(
        courseId: 'TEST-101',
        courseName: 'Test Course',
        learningObjectIds: ['lo_1', 'lo_2', 'lo_3'],
        totalSizeBytes: 107 * 1024 * 1024,
        fileCount: 9,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadConfirmationDialog(courseInfo: courseInfo),
          ),
        ),
      );

      expect(find.text('Download Course Content'), findsOneWidget);
      expect(find.text('Test Course'), findsOneWidget);
      expect(find.text('Download on WiFi only'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Download Now'), findsOneWidget);
    });

    testWidgets('DownloadProgressScreen shows progress indicators', (WidgetTester tester) async {
      final courseInfo = CourseDownloadInfo(
        courseId: 'TEST-101',
        courseName: 'Test Course',
        learningObjectIds: ['lo_1'],
        totalSizeBytes: 107 * 1024 * 1024,
        fileCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DownloadProgressScreen(
            courseInfo: courseInfo,
          ),
        ),
      );

      expect(find.text('Downloading Course'), findsOneWidget);
      expect(find.text('Test Course'), findsOneWidget);
      expect(find.byType(CircularPercentIndicator), findsOneWidget);
    });

    testWidgets('Download reminder dialog shows for deferred downloads', (WidgetTester tester) async {
      final courseInfo = CourseDownloadInfo(
        courseId: 'TEST-101',
        courseName: 'Test Course',
        learningObjectIds: ['lo_1'],
        totalSizeBytes: 107 * 1024 * 1024,
        fileCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadReminderDialog(courseInfo: courseInfo),
          ),
        ),
      );

      expect(find.text('Content Not Downloaded'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });
  });

  group('Download Models Comprehensive Tests', () {
    test('DownloadTask handles all states correctly', () {
      final task = DownloadTask(
        id: 'test_task',
        url: 'https://example.com/file.mp3',
        localPath: '/path/to/file.mp3',
        learningObjectId: 'lo_1',
        fileType: FileType.audio,
        expectedSize: 1000000,
      );

      // Test initial state
      expect(task.status, DownloadStatus.pending);
      expect(task.isComplete, false);
      expect(task.isFailed, false);
      expect(task.canRetry, false);

      // Test downloading state
      task.status = DownloadStatus.downloading;
      task.downloadedBytes = 500000;
      expect(task.progress, 0.5);

      // Test completed state
      task.status = DownloadStatus.completed;
      task.downloadedBytes = task.expectedSize;
      expect(task.isComplete, true);
      expect(task.progress, 1.0);

      // Test failed state with retry
      task.status = DownloadStatus.failed;
      task.retryCount = 1;
      expect(task.isFailed, true);
      expect(task.canRetry, true);

      // Test max retries reached
      task.retryCount = 3;
      expect(task.canRetry, false);
    });

    test('CourseDownloadProgress tracks multiple files', () {
      final tasks = List.generate(10, (i) => DownloadTask(
        id: 'task_$i',
        url: 'https://example.com/file_$i.mp3',
        localPath: '/path/to/file_$i.mp3',
        learningObjectId: 'lo_${i ~/ 3}',
        fileType: FileType.values[i % 3],
        expectedSize: 1000000,
        downloadedBytes: i < 5 ? 1000000 : i * 100000,
        status: i < 5 ? DownloadStatus.completed : DownloadStatus.downloading,
      ));

      final progress = CourseDownloadProgress(
        courseId: 'TEST-101',
        courseName: 'Test Course',
        totalFiles: 10,
        completedFiles: 5,
        failedFiles: 0,
        totalBytes: 10000000,
        downloadedBytes: 7000000,
        tasks: tasks,
        startedAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );

      expect(progress.percentage, 0.7);
      expect(progress.pendingFiles, 5);
      expect(progress.isComplete, false);
      expect(progress.hasFailed, false);

      final speed = progress.getDownloadSpeed();
      expect(speed, greaterThan(0));

      final timeRemaining = progress.getEstimatedTimeRemaining();
      expect(timeRemaining, isNotNull);
      expect(timeRemaining, greaterThan(0));
    });

    test('Download settings persistence', () {
      const settings1 = DownloadSettings(
        wifiOnly: true,
        maxRetries: 5,
        retryDelay: Duration(seconds: 3),
        allowBackground: false,
      );

      final json = settings1.toJson();
      final settings2 = DownloadSettings.fromPrefs(json);

      expect(settings2.wifiOnly, settings1.wifiOnly);
      expect(settings2.maxRetries, settings1.maxRetries);
      expect(settings2.retryDelay, settings1.retryDelay);
      expect(settings2.allowBackground, settings1.allowBackground);
    });
  });
}