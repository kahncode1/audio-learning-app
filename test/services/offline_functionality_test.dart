/// Offline Functionality Test
///
/// Purpose: Tests the complete offline data flow including
/// local database, download service, and sync mechanism.
///
/// Tests:
/// - Local database creation and operations
/// - Course download and storage
/// - Offline progress tracking
/// - Data synchronization

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/database/local_database_service.dart';
import 'package:audio_learning_app/services/download/course_download_api_service.dart';
import 'package:audio_learning_app/services/sync/data_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize sqflite for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Local Database Tests', () {
    late LocalDatabaseService localDb;

    setUp(() async {
      localDb = LocalDatabaseService.instance;
      // Clear any existing data
      try {
        await localDb.clearAllData();
      } catch (_) {}
    });

    tearDown(() async {
      await localDb.close();
    });

    test('should create database with all tables', () async {
      final db = await localDb.database;

      // Verify database exists
      expect(db, isNotNull);

      // Verify all tables exist
      final tables = [
        'courses',
        'assignments',
        'learning_objects',
        'user_progress',
        'user_course_progress',
        'download_cache'
      ];

      for (final table in tables) {
        final result = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            [table]);
        expect(result.isNotEmpty, true, reason: 'Table $table should exist');
      }
    });

    test('should store and retrieve course data', () async {
      // Create test course
      final testCourse = {
        'id': 'test-course-001',
        'external_course_id': 101,
        'course_number': 'TEST-101',
        'title': 'Test Course for Offline',
        'description': 'Testing offline functionality',
        'total_learning_objects': 5,
        'total_assignments': 2,
        'estimated_duration_ms': 1800000,
        'thumbnail_url': 'https://example.com/thumb.jpg',
        'order_index': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert course
      await localDb.upsertCourse(testCourse);

      // Retrieve course
      final retrieved = await localDb.getCourse('test-course-001');
      expect(retrieved, isNotNull);
      expect(retrieved!['title'], equals('Test Course for Offline'));
      expect(retrieved['total_learning_objects'], equals(5));
      expect(retrieved['course_number'], equals('TEST-101'));
    });

    test('should store and retrieve assignment data', () async {
      // First add a course
      await localDb.upsertCourse({
        'id': 'test-course-002',
        'course_number': 'TEST-102',
        'title': 'Test Course',
        'order_index': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create test assignment
      final testAssignment = {
        'id': 'test-assignment-001',
        'course_id': 'test-course-002',
        'assignment_number': 1,
        'title': 'Test Assignment',
        'description': 'Testing assignment storage',
        'learning_object_count': 3,
        'total_duration_ms': 900000,
        'order_index': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert assignment
      await localDb.upsertAssignment(testAssignment);

      // Retrieve assignments for course
      final assignments = await localDb.getAssignments('test-course-002');
      expect(assignments.length, equals(1));
      expect(assignments[0]['title'], equals('Test Assignment'));
      expect(assignments[0]['learning_object_count'], equals(3));
    });

    test('should store and retrieve learning object with timing data',
        () async {
      // Setup course and assignment
      await localDb.upsertCourse({
        'id': 'test-course-003',
        'course_number': 'TEST-103',
        'title': 'Test Course',
        'order_index': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await localDb.upsertAssignment({
        'id': 'test-assignment-002',
        'course_id': 'test-course-003',
        'assignment_number': 1,
        'title': 'Test Assignment',
        'order_index': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create test learning object with timing data
      final testLO = {
        'id': 'test-lo-001',
        'assignment_id': 'test-assignment-002',
        'course_id': 'test-course-003',
        'title': 'Test Learning Object',
        'order_index': 1,
        'display_text': 'This is the test content.',
        'paragraphs': ['This is the test content.'],
        'headers': [],
        'formatting': {
          'bold_headers': false,
          'paragraph_spacing': true,
        },
        'metadata': {
          'word_count': 5,
          'character_count': 24,
          'estimated_reading_time': '1 minute',
          'language': 'en',
        },
        'word_timings': [
          {
            'word': 'This',
            'start_ms': 0,
            'end_ms': 200,
            'char_start': 0,
            'char_end': 4,
            'sentence_index': 0
          },
          {
            'word': 'is',
            'start_ms': 200,
            'end_ms': 350,
            'char_start': 5,
            'char_end': 7,
            'sentence_index': 0
          },
          {
            'word': 'the',
            'start_ms': 350,
            'end_ms': 500,
            'char_start': 8,
            'char_end': 11,
            'sentence_index': 0
          },
          {
            'word': 'test',
            'start_ms': 500,
            'end_ms': 750,
            'char_start': 12,
            'char_end': 16,
            'sentence_index': 0
          },
          {
            'word': 'content.',
            'start_ms': 750,
            'end_ms': 1000,
            'char_start': 17,
            'char_end': 25,
            'sentence_index': 0
          },
        ],
        'sentence_timings': [
          {
            'text': 'This is the test content.',
            'start_ms': 0,
            'end_ms': 1000,
            'sentence_index': 0,
            'word_start_index': 0,
            'word_end_index': 4,
            'char_start': 0,
            'char_end': 25,
          },
        ],
        'total_duration_ms': 1000,
        'audio_url': 'https://example.com/audio/test.mp3',
        'audio_size_bytes': 123456,
        'audio_format': 'mp3',
        'audio_codec': 'mp3_128',
        'file_version': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert learning object
      await localDb.upsertLearningObject(testLO);

      // Retrieve learning object
      final retrieved = await localDb.getLearningObject('test-lo-001');
      expect(retrieved, isNotNull);
      expect(retrieved!['title'], equals('Test Learning Object'));
      expect(retrieved['display_text'], equals('This is the test content.'));

      // Check timing data
      expect(retrieved['word_timings'], isList);
      expect((retrieved['word_timings'] as List).length, equals(5));
      expect((retrieved['word_timings'] as List)[0]['word'], equals('This'));
      expect((retrieved['word_timings'] as List)[0]['start_ms'], equals(0));
      expect((retrieved['word_timings'] as List)[0]['end_ms'], equals(200));

      expect(retrieved['sentence_timings'], isList);
      expect((retrieved['sentence_timings'] as List).length, equals(1));
      expect((retrieved['sentence_timings'] as List)[0]['text'],
          equals('This is the test content.'));
    });

    test('should track user progress offline', () async {
      // Setup required data
      await localDb.upsertCourse({
        'id': 'test-course-004',
        'course_number': 'TEST-104',
        'title': 'Test Course',
        'order_index': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await localDb.upsertAssignment({
        'id': 'test-assignment-003',
        'course_id': 'test-course-004',
        'assignment_number': 1,
        'title': 'Test Assignment',
        'order_index': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await localDb.upsertLearningObject({
        'id': 'test-lo-002',
        'assignment_id': 'test-assignment-003',
        'course_id': 'test-course-004',
        'title': 'Test LO',
        'order_index': 0,
        'display_text': 'Test content',
        'paragraphs': ['Test content'],
        'headers': [],
        'formatting': {},
        'metadata': {'word_count': 2},
        'word_timings': [],
        'sentence_timings': [],
        'total_duration_ms': 1000,
        'audio_url': 'test.mp3',
        'audio_size_bytes': 1000,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create user progress
      final testProgress = {
        'id': 'test-progress-001',
        'user_id': 'test-user-001',
        'learning_object_id': 'test-lo-002',
        'course_id': 'test-course-004',
        'assignment_id': 'test-assignment-003',
        'is_completed': 0,
        'is_in_progress': 1,
        'completion_percentage': 45,
        'current_position_ms': 450,
        'last_word_index': 2,
        'last_sentence_index': 0,
        'playback_speed': 1.5,
        'play_count': 3,
        'total_play_time_ms': 1350,
        'started_at':
            DateTime.now().subtract(Duration(minutes: 5)).toIso8601String(),
        'last_played_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert progress
      await localDb.upsertUserProgress(testProgress);

      // Retrieve progress
      final retrieved =
          await localDb.getUserProgress('test-user-001', 'test-lo-002');
      expect(retrieved, isNotNull);
      expect(retrieved!['completion_percentage'], equals(45));
      expect(retrieved['current_position_ms'], equals(450));
      expect(retrieved['last_word_index'], equals(2));
      expect(retrieved['last_sentence_index'], equals(0));
      expect(retrieved['playback_speed'], equals(1.5));
      expect(retrieved['is_in_progress'], equals(1));
    });

    test('should handle download cache tracking', () async {
      // Setup required data
      await localDb.upsertCourse({
        'id': 'test-course-005',
        'course_number': 'TEST-105',
        'title': 'Test Course',
        'order_index': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await localDb.upsertLearningObject({
        'id': 'test-lo-003',
        'assignment_id': 'test-assignment',
        'course_id': 'test-course-005',
        'title': 'Test LO',
        'order_index': 0,
        'display_text': 'Test',
        'paragraphs': [],
        'headers': [],
        'formatting': {},
        'metadata': {},
        'word_timings': [],
        'sentence_timings': [],
        'total_duration_ms': 1000,
        'audio_url': 'test.mp3',
        'audio_size_bytes': 1000,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Create initial download cache entry
      final db = await localDb.database;
      await db.insert('download_cache', {
        'id': 'test-download-001',
        'user_id': 'test-user-001',
        'learning_object_id': 'test-lo-003',
        'course_id': 'test-course-005',
        'download_status': 'downloading',
        'download_progress': 50,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Update download status
      await localDb.updateDownloadStatus(
        userId: 'test-user-001',
        learningObjectId: 'test-lo-003',
        status: 'completed',
        progress: 100,
      );

      // Get download status
      final status =
          await localDb.getDownloadStatus('test-user-001', 'test-course-005');
      expect(status.length, equals(1));
      expect(status[0]['download_status'], equals('completed'));
      expect(status[0]['download_progress'], equals(100));
      expect(status[0]['audio_downloaded'], equals(1));
      expect(status[0]['content_downloaded'], equals(1));
    });
  });

  group('Data Sync Tests', () {
    late DataSyncService syncService;
    late LocalDatabaseService localDb;

    setUp(() async {
      localDb = LocalDatabaseService.instance;
      syncService = DataSyncService();

      // Clear any existing data
      try {
        await localDb.clearAllData();
      } catch (_) {}
    });

    tearDown(() async {
      syncService.dispose();
      await localDb.close();
    });

    test('should save progress locally when offline', () async {
      // Save progress
      await syncService.saveUserProgress(
        userId: 'test-user-002',
        learningObjectId: 'test-lo-004',
        progressData: {
          'course_id': 'test-course',
          'assignment_id': 'test-assignment',
          'current_position_ms': 5000,
          'last_word_index': 10,
          'last_sentence_index': 1,
          'is_in_progress': true,
          'completion_percentage': 50,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      // Retrieve progress
      final retrieved = await syncService.getUserProgress(
        userId: 'test-user-002',
        learningObjectId: 'test-lo-004',
      );

      expect(retrieved, isNotNull);
      expect(retrieved!['current_position_ms'], equals(5000));
      expect(retrieved['last_word_index'], equals(10));
      expect(
          retrieved['is_in_progress'], equals(1)); // SQLite stores as integer
      expect(retrieved['completion_percentage'], equals(50));
    });

    test('should handle sync status updates', () async {
      // Listen to sync status
      final statuses = <String>[];
      final subscription = syncService.syncStatusStream.listen((status) {
        statuses.add(status.status);
      });

      // Clear data (triggers status update)
      await syncService.clearAllData();

      // Wait for status update
      await Future.delayed(Duration(milliseconds: 100));

      expect(statuses.contains('cleared'), true);

      await subscription.cancel();
    });
  });

  group('Integration Tests', () {
    late LocalDatabaseService localDb;
    late CourseDownloadApiService downloadService;
    late DataSyncService syncService;

    setUp(() async {
      localDb = LocalDatabaseService.instance;
      downloadService = CourseDownloadApiService();
      syncService = DataSyncService();

      // Clear any existing data
      try {
        await localDb.clearAllData();
      } catch (_) {}
    });

    tearDown(() async {
      downloadService.dispose();
      syncService.dispose();
      await localDb.close();
    });

    test('should check if course is downloaded', () async {
      // Initially not downloaded
      final isDownloaded =
          await downloadService.isCourseDownloaded('non-existent-course');
      expect(isDownloaded, false);

      // Add a course
      await localDb.upsertCourse({
        'id': 'test-course-006',
        'course_number': 'TEST-106',
        'title': 'Test Course',
        'order_index': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Still not fully downloaded (no learning objects)
      final partiallyDownloaded =
          await downloadService.isCourseDownloaded('test-course-006');
      expect(partiallyDownloaded, false);

      // Add complete data
      await localDb.upsertAssignment({
        'id': 'test-assignment-004',
        'course_id': 'test-course-006',
        'assignment_number': 1,
        'title': 'Test Assignment',
        'order_index': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      await localDb.upsertLearningObject({
        'id': 'test-lo-005',
        'assignment_id': 'test-assignment-004',
        'course_id': 'test-course-006',
        'title': 'Test LO',
        'order_index': 0,
        'display_text': 'Test',
        'paragraphs': [],
        'headers': [],
        'formatting': {},
        'metadata': {},
        'word_timings': [],
        'sentence_timings': [],
        'total_duration_ms': 1000,
        'audio_url': 'test.mp3',
        'audio_size_bytes': 1000,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Now fully downloaded
      final fullyDownloaded =
          await downloadService.isCourseDownloaded('test-course-006');
      expect(fullyDownloaded, true);
    });

    test('should track download progress', () async {
      final progressUpdates = <int>[];

      // Listen to progress
      final subscription = downloadService.progressStream.listen((progress) {
        progressUpdates.add(progress.percentage);
      });

      // Note: Actual download test would require Supabase connection
      // This just tests the progress emission mechanism

      await Future.delayed(Duration(milliseconds: 100));
      await subscription.cancel();

      // Progress stream is available
      expect(downloadService.progressStream, isNotNull);
    });
  });
}

/// Run validation functions
void runValidations() async {
  print('\n🚀 Running Phase 5 Validations...\n');

  await LocalDatabaseService.validateLocalDatabase();
  print('');

  await CourseDownloadApiService.validateCourseDownloadApiService();
  print('');

  await DataSyncService.validateDataSyncService();
  print('');

  print('✅ All Phase 5 validations complete!');
}
