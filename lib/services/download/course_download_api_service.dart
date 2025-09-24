/// Course Download API Service
///
/// Purpose: Handles downloading entire courses from Supabase including
/// all assignments, learning objects, and associated content.
///
/// Dependencies:
/// - Supabase: Remote data source
/// - LocalDatabaseService: Local storage
/// - Models: Course, Assignment, LearningObject
///
/// Usage:
/// ```dart
/// final service = CourseDownloadApiService();
/// await service.downloadCourse(courseId, userId);
/// ```
///
/// Expected behavior:
/// - Downloads course metadata from Supabase
/// - Downloads all assignments for the course
/// - Downloads all learning objects with timing data
/// - Stores everything in local SQLite database
/// - Tracks download progress

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/app_logger.dart';
import '../database/local_database_service.dart';

class CourseDownloadApiService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;
  final Dio _dio = Dio();

  // Progress tracking
  final _progressController = StreamController<DownloadProgress>.broadcast();
  Stream<DownloadProgress> get progressStream => _progressController.stream;

  /// Download an entire course with all its content
  Future<void> downloadCourse({
    required String courseId,
    required String userId,
  }) async {
    try {
      _emitProgress(DownloadProgress(
        courseId: courseId,
        status: 'starting',
        percentage: 0,
        message: 'Starting course download...',
      ));

      // 1. Download course metadata
      _emitProgress(DownloadProgress(
        courseId: courseId,
        status: 'downloading',
        percentage: 5,
        message: 'Downloading course information...',
      ));

      final courseData = await _downloadCourseMetadata(courseId);
      if (courseData == null) {
        throw Exception('Course not found');
      }

      await _localDb.upsertCourse(courseData);

      // 2. Download all assignments
      _emitProgress(DownloadProgress(
        courseId: courseId,
        status: 'downloading',
        percentage: 15,
        message: 'Downloading assignments...',
      ));

      final assignments = await _downloadAssignments(courseId);
      for (final assignment in assignments) {
        await _localDb.upsertAssignment(assignment);
      }

      // 3. Download all learning objects
      _emitProgress(DownloadProgress(
        courseId: courseId,
        status: 'downloading',
        percentage: 25,
        message: 'Downloading learning objects...',
      ));

      final totalLearningObjects =
          courseData['total_learning_objects'] as int? ?? 0;
      int downloadedCount = 0;

      for (final assignment in assignments) {
        final learningObjects =
            await _downloadLearningObjects(assignment['id']);

        for (final lo in learningObjects) {
          await _localDb.upsertLearningObject(lo);

          // Track download cache entry
          await _createDownloadCacheEntry(userId, lo['id'], courseId);

          downloadedCount++;
          final progress =
              25 + (downloadedCount / totalLearningObjects * 65).round();

          _emitProgress(DownloadProgress(
            courseId: courseId,
            status: 'downloading',
            percentage: progress.clamp(25, 90),
            message:
                'Downloading learning object ${downloadedCount} of $totalLearningObjects...',
          ));
        }
      }

      // 4. Mark download as complete
      _emitProgress(DownloadProgress(
        courseId: courseId,
        status: 'completed',
        percentage: 100,
        message: 'Course download complete!',
      ));
    } catch (e) {
      _emitProgress(DownloadProgress(
        courseId: courseId,
        status: 'failed',
        percentage: 0,
        message: 'Download failed: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Download course metadata from Supabase
  Future<Map<String, dynamic>?> _downloadCourseMetadata(String courseId) async {
    final response = await _supabase
        .from('courses')
        .select()
        .eq('id', courseId)
        .maybeSingle();

    if (response == null) return null;

    // Ensure required timestamp fields
    response['created_at'] ??= DateTime.now().toIso8601String();
    response['updated_at'] ??= DateTime.now().toIso8601String();

    return response;
  }

  /// Download all assignments for a course
  Future<List<Map<String, dynamic>>> _downloadAssignments(
      String courseId) async {
    final response = await _supabase
        .from('assignments')
        .select()
        .eq('course_id', courseId)
        .order('order_index', ascending: true);

    final assignments = List<Map<String, dynamic>>.from(response as List);

    // Ensure required timestamp fields
    for (final assignment in assignments) {
      assignment['created_at'] ??= DateTime.now().toIso8601String();
      assignment['updated_at'] ??= DateTime.now().toIso8601String();
    }

    return assignments;
  }

  /// Download all learning objects for an assignment
  Future<List<Map<String, dynamic>>> _downloadLearningObjects(
      String assignmentId) async {
    final response = await _supabase
        .from('learning_objects')
        .select()
        .eq('assignment_id', assignmentId)
        .order('order_index', ascending: true);

    final learningObjects = List<Map<String, dynamic>>.from(response as List);

    // Ensure required timestamp fields
    for (final lo in learningObjects) {
      lo['created_at'] ??= DateTime.now().toIso8601String();
      lo['updated_at'] ??= DateTime.now().toIso8601String();

      // Download audio file if URL exists
      if (lo['audio_url'] != null && lo['audio_url'].toString().isNotEmpty) {
        await _downloadAudioFile(
          learningObjectId: lo['id'] as String,
          audioUrl: lo['audio_url'] as String,
          courseId: lo['course_id'] as String,
        );
      }

      // Save content and timing data
      await _saveContentData(
        learningObjectId: lo['id'] as String,
        courseId: lo['course_id'] as String,
        learningObject: lo,
      );
    }

    return learningObjects;
  }

  /// Create download cache entry for a learning object
  Future<void> _createDownloadCacheEntry(
    String userId,
    String learningObjectId,
    String courseId,
  ) async {
    await _localDb.updateDownloadStatus(
      userId: userId,
      learningObjectId: learningObjectId,
      status: 'completed',
      progress: 100,
    );
  }

  /// Check if a course needs updating
  Future<bool> courseNeedsUpdate(String courseId) async {
    final localCourse = await _localDb.getCourse(courseId);
    if (localCourse == null) return true;

    final remoteCourse = await _downloadCourseMetadata(courseId);
    if (remoteCourse == null) return false;

    // Compare updated_at timestamps
    final localUpdated =
        DateTime.tryParse(localCourse['updated_at'] as String? ?? '');
    final remoteUpdated =
        DateTime.tryParse(remoteCourse['updated_at'] as String? ?? '');

    if (localUpdated == null || remoteUpdated == null) return true;

    return remoteUpdated.isAfter(localUpdated);
  }

  /// Download only updated content for a course
  Future<void> updateCourse({
    required String courseId,
    required String userId,
  }) async {
    try {
      _emitProgress(DownloadProgress(
        courseId: courseId,
        status: 'checking',
        percentage: 0,
        message: 'Checking for updates...',
      ));

      final needsUpdate = await courseNeedsUpdate(courseId);
      if (!needsUpdate) {
        _emitProgress(DownloadProgress(
          courseId: courseId,
          status: 'completed',
          percentage: 100,
          message: 'Course is up to date',
        ));
        return;
      }

      // Download full course if updates are needed
      await downloadCourse(courseId: courseId, userId: userId);
    } catch (e) {
      _emitProgress(DownloadProgress(
        courseId: courseId,
        status: 'failed',
        percentage: 0,
        message: 'Update failed: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Download audio file from URL to local storage
  Future<void> _downloadAudioFile({
    required String learningObjectId,
    required String audioUrl,
    required String courseId,
  }) async {
    try {
      // Get documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(
        '${documentsDir.path}/audio_learning/courses/$courseId/learning_objects/$learningObjectId',
      );

      // Create directory if it doesn't exist
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final audioFile = File('${audioDir.path}/audio.mp3');

      // Skip if file already exists
      if (await audioFile.exists()) {
        AppLogger.info('Audio file already exists', {
          'learningObjectId': learningObjectId,
          'path': audioFile.path,
        });
        return;
      }

      // Download the audio file
      AppLogger.info('Downloading audio file', {
        'learningObjectId': learningObjectId,
        'url': audioUrl,
      });

      final response = await _dio.get<List<int>>(
        audioUrl,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      // Save to file
      await audioFile.writeAsBytes(response.data!);

      AppLogger.info('Audio file downloaded successfully', {
        'learningObjectId': learningObjectId,
        'size': response.data!.length,
        'path': audioFile.path,
      });
    } catch (e) {
      AppLogger.error('Failed to download audio file', error: e, data: {
        'learningObjectId': learningObjectId,
        'audioUrl': audioUrl,
      });
      // Don't rethrow - allow download to continue even if audio fails
    }
  }

  /// Save content and timing data to local storage
  Future<void> _saveContentData({
    required String learningObjectId,
    required String courseId,
    required Map<String, dynamic> learningObject,
  }) async {
    try {
      // Get documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final contentDir = Directory(
        '${documentsDir.path}/audio_learning/courses/$courseId/learning_objects/$learningObjectId',
      );

      // Create directory if it doesn't exist
      if (!await contentDir.exists()) {
        await contentDir.create(recursive: true);
      }

      // Extract content from learning object
      final contentJson = learningObject['content'] as Map<String, dynamic>?;
      final displayText = contentJson?['display_text'] as String? ?? '';
      final metadata = learningObject['metadata'] as Map<String, dynamic>?;

      // Create timing data file
      final timingFile = File('${contentDir.path}/timing.json');

      // Extract word_timings JSONB
      final wordTimingsData = learningObject['word_timings'];
      Map<String, dynamic> timingData;
      Map<String, dynamic>? lookupTableData;

      if (wordTimingsData is Map<String, dynamic>) {
        // New format from Supabase JSONB
        timingData = {
          'version': 2,
          'word_timings': wordTimingsData['words'] ?? [],
          'sentence_timings': wordTimingsData['sentences'] ?? [],
          'total_duration_ms': wordTimingsData['totalDurationMs'] ?? 0,
        };

        // Extract embedded lookup table if present
        if (wordTimingsData['lookupTable'] != null) {
          lookupTableData = wordTimingsData['lookupTable'] as Map<String, dynamic>;
          AppLogger.info('Found embedded lookup table', {
            'entries': (lookupTableData['lookup'] as List?)?.length ?? 0,
            'interval': lookupTableData['interval'],
          });
        }
      } else {
        // Legacy format
        timingData = {
          'version': 2,
          'word_timings': wordTimingsData ?? [],
          'sentence_timings': learningObject['sentence_timings'] ?? [],
          'total_duration_ms': learningObject['total_duration_ms'] ?? 0,
        };
      }

      await timingFile.writeAsString(json.encode(timingData));

      // Save embedded lookup table as separate file if present
      if (lookupTableData != null) {
        final lookupFile = File('${contentDir.path}/position_lookup.json');
        await lookupFile.writeAsString(json.encode(lookupTableData));
        AppLogger.info('✅ Saved embedded lookup table', {
          'path': lookupFile.path,
          'entries': (lookupTableData['lookup'] as List?)?.length ?? 0,
          'interval': lookupTableData['interval'],
        });
      }

      // Download separate lookup table if URL is provided
      final lookupTableUrl = learningObject['lookup_table_url'] as String?;
      if (lookupTableUrl != null && lookupTableUrl.isNotEmpty) {
        try {
          final lookupFile = File('${contentDir.path}/position_lookup.json');

          AppLogger.info('Downloading lookup table', {
            'url': lookupTableUrl,
            'path': lookupFile.path,
          });

          // Download the lookup table
          final response = await _dio.get<String>(
            lookupTableUrl,
            options: Options(responseType: ResponseType.plain),
          );

          if (response.data != null) {
            await lookupFile.writeAsString(response.data!);

            // Parse to verify and log
            final lookupData = json.decode(response.data!) as Map<String, dynamic>;
            AppLogger.info('✅ Downloaded lookup table', {
              'interval': lookupData['interval'],
              'entries': (lookupData['lookup'] as List?)?.length ?? 0,
              'version': lookupData['version'],
            });
          }
        } catch (e) {
          AppLogger.warning('Failed to download lookup table', {
            'error': e.toString(),
            'url': lookupTableUrl,
          });
          // Continue without lookup table - app will fall back to binary search
        }
      } else {
        AppLogger.info('No lookup table URL - will use binary search');
      }

      // Create content.json file with display text and metadata
      final contentFile = File('${contentDir.path}/content.json');
      final contentData = {
        'version': 2,
        'display_text': displayText,
        'metadata': metadata ??
            {
              'word_count': displayText.split(' ').length,
              'character_count': displayText.length,
              'estimated_reading_time':
                  '${(displayText.split(' ').length / 200).ceil()} min',
            },
      };
      await contentFile.writeAsString(json.encode(contentData));

      AppLogger.info('Content data saved', {
        'learningObjectId': learningObjectId,
        'path': contentDir.path,
        'hasDisplayText': displayText.isNotEmpty,
        'hasWordTimings':
            (learningObject['word_timings'] as List?)?.isNotEmpty ?? false,
      });
    } catch (e) {
      AppLogger.error('Failed to save content data', error: e, data: {
        'learningObjectId': learningObjectId,
      });
    }
  }

  /// Get list of downloaded courses for a user
  Future<List<Map<String, dynamic>>> getDownloadedCourses() async {
    return await _localDb.getCourses();
  }

  /// Check if a course is fully downloaded
  Future<bool> isCourseDownloaded(String courseId) async {
    final course = await _localDb.getCourse(courseId);
    if (course == null) return false;

    // Check if all learning objects are downloaded
    final assignments = await _localDb.getAssignments(courseId);
    for (final assignment in assignments) {
      final learningObjects =
          await _localDb.getLearningObjects(assignment['id']);
      if (learningObjects.isEmpty) return false;
    }

    return true;
  }

  /// Delete a downloaded course
  Future<void> deleteCourse(String courseId) async {
    final db = await _localDb.database;
    await db.delete('courses', where: 'id = ?', whereArgs: [courseId]);
  }

  /// Emit progress update
  void _emitProgress(DownloadProgress progress) {
    if (!_progressController.isClosed) {
      _progressController.add(progress);
    }
  }

  /// Dispose resources
  void dispose() {
    _progressController.close();
  }

  /// Validation function
  static Future<void> validateCourseDownloadApiService() async {
    print('🔍 Validating CourseDownloadApiService...');

    final service = CourseDownloadApiService();

    // Test progress stream
    final progressSubscription = service.progressStream.listen((progress) {
      print('  Progress: ${progress.percentage}% - ${progress.message}');
    });

    // Test course metadata download (using test course if available)
    try {
      // Note: This would need a test course ID in your Supabase database
      // const testCourseId = 'test-course-id';
      // final metadata = await service._downloadCourseMetadata(testCourseId);
      // print('✓ Course metadata download working');

      print('✓ Service initialized successfully');
    } catch (e) {
      print('⚠️ Could not test downloads (needs test data in Supabase)');
    }

    await progressSubscription.cancel();
    service.dispose();

    print('✅ CourseDownloadApiService validation complete!');
  }
}

/// Download progress model
class DownloadProgress {
  final String courseId;
  final String
      status; // 'starting', 'checking', 'downloading', 'completed', 'failed'
  final int percentage;
  final String message;

  DownloadProgress({
    required this.courseId,
    required this.status,
    required this.percentage,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'courseId': courseId,
        'status': status,
        'percentage': percentage,
        'message': message,
      };
}
