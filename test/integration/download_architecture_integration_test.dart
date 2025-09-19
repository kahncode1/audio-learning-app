import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/course_download_service.dart';
import 'package:audio_learning_app/services/local_content_service.dart';
import 'package:audio_learning_app/services/supabase_service.dart';
import 'package:audio_learning_app/models/download_models.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() {
  group('Download Architecture Integration Tests', () {
    late CourseDownloadService downloadService;
    late LocalContentService localContentService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Load environment variables
      await dotenv.load(fileName: '.env');

      // Initialize Supabase
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );

      // Initialize services
      downloadService = CourseDownloadService();
      localContentService = LocalContentService();
    });

    tearDownAll(() async {
      await downloadService.dispose();
      await localContentService.dispose();
    });

    test('should fetch CDN URLs from Supabase for test learning object', () async {
      // Our test learning object ID
      const testLearningObjectId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';

      try {
        // Fetch learning object from Supabase
        final response = await SupabaseService().client
            .from('learning_objects')
            .select('id, title, audio_url, content_url, timing_url, download_status, file_version')
            .eq('id', testLearningObjectId)
            .single();

        print('\n=== CDN URLs from Database ===');
        print('Title: ${response['title']}');
        print('Audio URL: ${response['audio_url']}');
        print('Content URL: ${response['content_url']}');
        print('Timing URL: ${response['timing_url']}');
        print('Download Status: ${response['download_status']}');
        print('File Version: ${response['file_version']}');

        // Verify CDN URLs are present
        expect(response['audio_url'], isNotNull);
        expect(response['content_url'], isNotNull);
        expect(response['timing_url'], isNotNull);
        expect(response['download_status'], equals('pending'));
        expect(response['file_version'], equals(1));

        // Verify the URLs are properly formatted
        expect(response['audio_url'], contains('establishing_case_reserve.mp3'));
        expect(response['content_url'], contains('establishing_case_reserve.json'));
        expect(response['timing_url'], contains('establishing_case_reserve.json'));

      } catch (e) {
        print('Error fetching from Supabase: $e');
        // If we can't connect to Supabase, skip this test
        if (e.toString().contains('SocketException')) {
          print('Skipping test - cannot connect to Supabase');
          return;
        }
        rethrow;
      }
    });

    test('should create download tasks from learning objects', () async {
      // Create mock learning object data
      final mockLearningObject = {
        'id': 'test-lo-1',
        'title': 'Test Learning Object',
        'audio_url': 'https://example.com/audio.mp3',
        'content_url': 'https://example.com/content.json',
        'timing_url': 'https://example.com/timing.json',
        'file_size_bytes': 1024 * 1024, // 1MB
      };

      // Create download info
      final downloadInfo = CourseDownloadInfo(
        courseId: 'test-course',
        courseTitle: 'Test Course',
        learningObjects: [
          LearningObjectInfo(
            id: mockLearningObject['id'] as String,
            title: mockLearningObject['title'] as String,
            audioUrl: mockLearningObject['audio_url'] as String?,
            contentUrl: mockLearningObject['content_url'] as String?,
            timingUrl: mockLearningObject['timing_url'] as String?,
            estimatedSize: mockLearningObject['file_size_bytes'] as int?,
          ),
        ],
      );

      // Queue download
      await downloadService.queueCourseDownload(downloadInfo);

      // Get progress
      final progress = downloadService.getCourseProgress(downloadInfo.courseId);

      // Verify download was queued
      expect(progress, isNotNull);
      expect(progress!.courseId, equals('test-course'));
      expect(progress.status, equals(DownloadStatus.queued));
      expect(progress.totalTasks, equals(3)); // audio, content, timing

      print('\n=== Download Queue Status ===');
      print('Course: ${progress.courseTitle}');
      print('Status: ${progress.status}');
      print('Tasks: ${progress.completedTasks}/${progress.totalTasks}');
      print('Progress: ${progress.progressPercentage}%');
    });

    test('should handle download errors gracefully', () async {
      // Create download info with invalid URLs
      final downloadInfo = CourseDownloadInfo(
        courseId: 'test-error-course',
        courseTitle: 'Error Test Course',
        learningObjects: [
          LearningObjectInfo(
            id: 'error-lo-1',
            title: 'Error Test LO',
            audioUrl: 'https://invalid-url-that-does-not-exist.com/audio.mp3',
            contentUrl: null,
            timingUrl: null,
            estimatedSize: 0,
          ),
        ],
      );

      // Queue download
      await downloadService.queueCourseDownload(downloadInfo);

      // Try to process (will fail due to invalid URLs)
      await downloadService.processNextDownload();

      // Get progress
      final progress = downloadService.getCourseProgress(downloadInfo.courseId);

      // Should handle error gracefully
      expect(progress, isNotNull);
      expect(progress!.failedTasks, greaterThan(0));

      print('\n=== Error Handling Test ===');
      print('Failed tasks: ${progress.failedTasks}');
      print('Last error: ${progress.lastError}');
    });

    test('should track download progress correctly', () async {
      // Create multiple learning objects
      final downloadInfo = CourseDownloadInfo(
        courseId: 'progress-test-course',
        courseTitle: 'Progress Test Course',
        learningObjects: [
          LearningObjectInfo(
            id: 'lo-1',
            title: 'LO 1',
            audioUrl: 'https://example.com/lo1.mp3',
            contentUrl: 'https://example.com/lo1.json',
            timingUrl: 'https://example.com/lo1-timing.json',
            estimatedSize: 500000,
          ),
          LearningObjectInfo(
            id: 'lo-2',
            title: 'LO 2',
            audioUrl: 'https://example.com/lo2.mp3',
            contentUrl: null,
            timingUrl: null,
            estimatedSize: 300000,
          ),
        ],
      );

      // Queue download
      await downloadService.queueCourseDownload(downloadInfo);

      // Get initial progress
      var progress = downloadService.getCourseProgress(downloadInfo.courseId);
      expect(progress!.totalTasks, equals(4)); // 3 files for lo-1, 1 for lo-2
      expect(progress.progressPercentage, equals(0));

      // Simulate completing some tasks
      downloadService.updateTaskProgress('lo-1-audio',
        status: DownloadStatus.completed,
        bytesDownloaded: 500000);

      // Check updated progress
      progress = downloadService.getCourseProgress(downloadInfo.courseId);
      expect(progress!.completedTasks, equals(1));
      expect(progress.progressPercentage, greaterThan(0));

      print('\n=== Progress Tracking Test ===');
      print('Total bytes: ${progress.formatBytes(progress.totalBytes)}');
      print('Downloaded: ${progress.formatBytes(progress.downloadedBytes)}');
      print('Progress: ${progress.progressPercentage}%');
      print('Tasks: ${progress.completedTasks}/${progress.totalTasks}');
    });

    test('should verify local file paths are correct', () async {
      const testLearningObjectId = 'test-lo-123';

      // Get expected file paths
      final audioPath = await localContentService.getAudioFilePath(testLearningObjectId);
      final contentPath = localContentService.getContentFilePath(testLearningObjectId);
      final timingPath = localContentService.getTimingFilePath(testLearningObjectId);

      print('\n=== Local File Paths ===');
      print('Audio: $audioPath');
      print('Content: $contentPath');
      print('Timing: $timingPath');

      // Verify paths are properly formatted
      expect(audioPath, contains('test-lo-123'));
      expect(audioPath, endsWith('.mp3'));
      expect(contentPath, contains('test-lo-123'));
      expect(contentPath, endsWith('_content.json'));
      expect(timingPath, contains('test-lo-123'));
      expect(timingPath, endsWith('_timing.json'));

      // Verify directory structure
      final audioDir = Directory(audioPath).parent;
      expect(audioDir.path, contains('audio_learning_content'));
      expect(audioDir.path, contains('audio'));
    });

    test('should handle offline mode correctly', () async {
      // Check if we have any downloaded content
      final hasContent = await localContentService.hasDownloadedContent('test-lo');

      print('\n=== Offline Mode Test ===');
      print('Has downloaded content: $hasContent');

      // Test should pass regardless of actual content
      expect(hasContent, isA<bool>());

      // Verify service can check for specific files
      final hasAudio = await localContentService.hasAudioFile('test-lo');
      expect(hasAudio, isFalse); // Should be false since we haven't downloaded anything
    });

    test('should validate download models', () {
      // Test DownloadTask
      final task = DownloadTask(
        id: 'task-1',
        learningObjectId: 'lo-1',
        fileType: FileType.audio,
        url: 'https://example.com/audio.mp3',
        localPath: '/path/to/audio.mp3',
        status: DownloadStatus.pending,
        totalBytes: 1000000,
        downloadedBytes: 500000,
        retryCount: 0,
      );

      expect(task.progress, equals(0.5));
      expect(task.isComplete, isFalse);
      expect(task.canRetry, isTrue);

      // Test to/from JSON
      final json = task.toJson();
      final restored = DownloadTask.fromJson(json);
      expect(restored.id, equals(task.id));
      expect(restored.progress, equals(task.progress));

      // Test CourseDownloadProgress
      final progress = CourseDownloadProgress(
        courseId: 'course-1',
        courseTitle: 'Test Course',
        status: DownloadStatus.downloading,
        totalTasks: 10,
        completedTasks: 3,
        failedTasks: 1,
        totalBytes: 10000000,
        downloadedBytes: 3500000,
      );

      expect(progress.progressPercentage, equals(35));
      expect(progress.remainingTasks, equals(6));
      expect(progress.formatBytes(1048576), equals('1.0 MB'));
      expect(progress.formatDuration(const Duration(minutes: 1, seconds: 30)),
             equals('1:30'));

      print('\n=== Model Validation ===');
      print('✓ DownloadTask model validated');
      print('✓ CourseDownloadProgress model validated');
      print('✓ JSON serialization working');
    });
  });
}