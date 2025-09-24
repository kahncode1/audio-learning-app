/// Local SQLite database service for offline functionality
///
/// Purpose: Manages local SQLite database for caching course content
/// and user progress data to enable offline learning.
///
/// Dependencies:
/// - sqflite: Local database management
/// - path: Database file path management
/// - Models: Course, Assignment, LearningObject, UserProgress
///
/// Usage:
/// ```dart
/// final db = await LocalDatabaseService.instance.database;
/// ```
///
/// Expected behavior:
/// - Creates local database on first launch
/// - Mirrors Supabase schema for offline support
/// - Provides CRUD operations for all entities
/// - Handles versioning and migrations

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../utils/app_logger.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => instance;
  LocalDatabaseService._internal();

  static Database? _database;
  static const String _dbName = 'audio_learning_app.db';
  static const int _dbVersion = 1;

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// Create database schema
  Future<void> _createDatabase(Database db, int version) async {
    // Create courses table
    await db.execute('''
      CREATE TABLE courses (
        id TEXT PRIMARY KEY,
        external_course_id INTEGER UNIQUE,
        course_number TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        description TEXT,
        total_learning_objects INTEGER DEFAULT 0,
        total_assignments INTEGER DEFAULT 0,
        estimated_duration_ms INTEGER DEFAULT 0,
        thumbnail_url TEXT,
        order_index INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create assignments table
    await db.execute('''
      CREATE TABLE assignments (
        id TEXT PRIMARY KEY,
        course_id TEXT NOT NULL,
        assignment_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        learning_object_count INTEGER DEFAULT 0,
        total_duration_ms INTEGER DEFAULT 0,
        order_index INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE,
        UNIQUE(course_id, assignment_number)
      )
    ''');

    // Create learning_objects table
    await db.execute('''
      CREATE TABLE learning_objects (
        id TEXT PRIMARY KEY,
        assignment_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        title TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        display_text TEXT NOT NULL,
        paragraphs TEXT NOT NULL,
        headers TEXT DEFAULT '[]',
        formatting TEXT DEFAULT '{"bold_headers": false, "paragraph_spacing": true}',
        metadata TEXT NOT NULL,
        word_timings TEXT NOT NULL,
        sentence_timings TEXT NOT NULL,
        total_duration_ms INTEGER NOT NULL,
        audio_url TEXT NOT NULL,
        audio_size_bytes INTEGER NOT NULL,
        audio_format TEXT DEFAULT 'mp3',
        audio_codec TEXT DEFAULT 'mp3_128',
        local_file_path TEXT,
        file_version INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (assignment_id) REFERENCES assignments (id) ON DELETE CASCADE,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');

    // Create user_progress table
    await db.execute('''
      CREATE TABLE user_progress (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        learning_object_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        assignment_id TEXT NOT NULL,
        is_completed INTEGER DEFAULT 0,
        is_in_progress INTEGER DEFAULT 0,
        completion_percentage INTEGER DEFAULT 0,
        current_position_ms INTEGER DEFAULT 0,
        last_word_index INTEGER DEFAULT -1,
        last_sentence_index INTEGER DEFAULT -1,
        started_at TEXT,
        last_played_at TEXT,
        completed_at TEXT,
        play_count INTEGER DEFAULT 0,
        total_play_time_ms INTEGER DEFAULT 0,
        playback_speed REAL DEFAULT 1.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (learning_object_id) REFERENCES learning_objects (id) ON DELETE CASCADE,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE,
        FOREIGN KEY (assignment_id) REFERENCES assignments (id) ON DELETE CASCADE,
        UNIQUE(user_id, learning_object_id),
        CHECK (completion_percentage >= 0 AND completion_percentage <= 100),
        CHECK (playback_speed >= 0.5 AND playback_speed <= 3.0)
      )
    ''');

    // Create user_course_progress table
    await db.execute('''
      CREATE TABLE user_course_progress (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        completed_learning_objects INTEGER DEFAULT 0,
        total_learning_objects INTEGER NOT NULL,
        completion_percentage INTEGER DEFAULT 0,
        total_time_spent_ms INTEGER DEFAULT 0,
        last_accessed_at TEXT,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        last_learning_object_id TEXT,
        last_assignment_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE,
        FOREIGN KEY (last_learning_object_id) REFERENCES learning_objects (id),
        FOREIGN KEY (last_assignment_id) REFERENCES assignments (id),
        UNIQUE(user_id, course_id),
        CHECK (completion_percentage >= 0 AND completion_percentage <= 100)
      )
    ''');

    // Create download_cache table
    await db.execute('''
      CREATE TABLE download_cache (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        learning_object_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        download_status TEXT DEFAULT 'pending',
        download_progress INTEGER DEFAULT 0,
        downloaded_version INTEGER,
        needs_update INTEGER DEFAULT 0,
        audio_downloaded INTEGER DEFAULT 0,
        content_downloaded INTEGER DEFAULT 0,
        audio_file_size INTEGER,
        download_started_at TEXT,
        download_completed_at TEXT,
        error_message TEXT,
        retry_count INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (learning_object_id) REFERENCES learning_objects (id) ON DELETE CASCADE,
        FOREIGN KEY (course_id) REFERENCES courses (id) ON DELETE CASCADE,
        UNIQUE(user_id, learning_object_id),
        CHECK (download_status IN ('pending', 'downloading', 'completed', 'failed', 'cancelled'))
      )
    ''');

    // Create indexes for performance
    await db.execute(
        'CREATE INDEX idx_courses_course_number ON courses(course_number)');
    await db.execute(
        'CREATE INDEX idx_courses_external_id ON courses(external_course_id)');
    await db.execute(
        'CREATE INDEX idx_courses_order_index ON courses(order_index)');

    await db.execute(
        'CREATE INDEX idx_assignments_course_id ON assignments(course_id)');
    await db.execute(
        'CREATE INDEX idx_assignments_order_index ON assignments(course_id, order_index)');

    await db.execute(
        'CREATE INDEX idx_learning_objects_assignment_id ON learning_objects(assignment_id)');
    await db.execute(
        'CREATE INDEX idx_learning_objects_course_id ON learning_objects(course_id)');
    await db.execute(
        'CREATE INDEX idx_learning_objects_order_index ON learning_objects(assignment_id, order_index)');

    await db.execute(
        'CREATE INDEX idx_user_progress_user_id ON user_progress(user_id)');
    await db.execute(
        'CREATE INDEX idx_user_progress_learning_object_id ON user_progress(learning_object_id)');
    await db.execute(
        'CREATE INDEX idx_user_progress_user_course ON user_progress(user_id, course_id)');
    await db.execute(
        'CREATE INDEX idx_user_progress_user_assignment ON user_progress(user_id, assignment_id)');
    await db.execute(
        'CREATE INDEX idx_user_progress_completion ON user_progress(user_id, is_completed)');

    await db.execute(
        'CREATE INDEX idx_user_course_progress_user_id ON user_course_progress(user_id)');
    await db.execute(
        'CREATE INDEX idx_user_course_progress_course_id ON user_course_progress(course_id)');

    await db.execute(
        'CREATE INDEX idx_download_cache_user_id ON download_cache(user_id)');
    await db.execute(
        'CREATE INDEX idx_download_cache_course_id ON download_cache(course_id)');
    await db.execute(
        'CREATE INDEX idx_download_cache_status ON download_cache(download_status)');
    await db.execute(
        'CREATE INDEX idx_download_cache_needs_update ON download_cache(needs_update)');
  }

  /// Handle database upgrades
  Future<void> _upgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE courses ADD COLUMN new_field TEXT');
    // }
  }

  /// Insert or update a course
  Future<int> upsertCourse(Map<String, dynamic> course) async {
    final db = await database;
    course['updated_at'] = DateTime.now().toIso8601String();

    return await db.insert(
      'courses',
      course,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert or update an assignment
  Future<int> upsertAssignment(Map<String, dynamic> assignment) async {
    final db = await database;
    assignment['updated_at'] = DateTime.now().toIso8601String();

    return await db.insert(
      'assignments',
      assignment,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert or update a learning object
  Future<int> upsertLearningObject(Map<String, dynamic> learningObject) async {
    final db = await database;
    learningObject['updated_at'] = DateTime.now().toIso8601String();

    // Convert JSONB fields to strings
    if (learningObject['paragraphs'] is List) {
      learningObject['paragraphs'] = jsonEncode(learningObject['paragraphs']);
    }
    if (learningObject['headers'] is List) {
      learningObject['headers'] = jsonEncode(learningObject['headers']);
    }
    if (learningObject['formatting'] is Map) {
      learningObject['formatting'] = jsonEncode(learningObject['formatting']);
    }
    if (learningObject['metadata'] is Map) {
      learningObject['metadata'] = jsonEncode(learningObject['metadata']);
    }
    if (learningObject['word_timings'] is List) {
      learningObject['word_timings'] =
          jsonEncode(learningObject['word_timings']);
    }
    if (learningObject['sentence_timings'] is List) {
      learningObject['sentence_timings'] =
          jsonEncode(learningObject['sentence_timings']);
    }

    return await db.insert(
      'learning_objects',
      learningObject,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all courses
  Future<List<Map<String, dynamic>>> getCourses() async {
    final db = await database;
    return await db.query('courses', orderBy: 'order_index ASC');
  }

  /// Get course by ID
  Future<Map<String, dynamic>?> getCourse(String courseId) async {
    final db = await database;
    final results = await db.query(
      'courses',
      where: 'id = ?',
      whereArgs: [courseId],
    );
    return results.isEmpty ? null : results.first;
  }

  /// Delete all courses and related data from the database
  Future<void> deleteAllCourses() async {
    final db = await database;
    await db.delete('user_progress');
    await db.delete('download_cache');
    await db.delete('learning_objects');
    await db.delete('assignments');
    await db.delete('courses');
    AppLogger.info('Deleted all courses and related data from local database');
  }

  /// Get assignments for a course
  Future<List<Map<String, dynamic>>> getAssignments(String courseId) async {
    final db = await database;
    return await db.query(
      'assignments',
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'order_index ASC',
    );
  }

  /// Get learning objects for an assignment
  Future<List<Map<String, dynamic>>> getLearningObjects(
      String assignmentId) async {
    final db = await database;
    final results = await db.query(
      'learning_objects',
      where: 'assignment_id = ?',
      whereArgs: [assignmentId],
      orderBy: 'order_index ASC',
    );

    // Parse JSON strings back to objects
    // Create mutable copies of the results to avoid read-only error
    final mutableResults =
        results.map((r) => Map<String, dynamic>.from(r)).toList();

    for (final result in mutableResults) {
      if (result['paragraphs'] is String) {
        result['paragraphs'] = jsonDecode(result['paragraphs'] as String);
      }
      if (result['headers'] is String) {
        result['headers'] = jsonDecode(result['headers'] as String);
      }
      if (result['formatting'] is String) {
        result['formatting'] = jsonDecode(result['formatting'] as String);
      }
      if (result['metadata'] is String) {
        result['metadata'] = jsonDecode(result['metadata'] as String);
      }
      if (result['word_timings'] is String) {
        result['word_timings'] = jsonDecode(result['word_timings'] as String);
      }
      if (result['sentence_timings'] is String) {
        result['sentence_timings'] =
            jsonDecode(result['sentence_timings'] as String);
      }
    }

    return mutableResults;
  }

  /// Get a specific learning object
  Future<Map<String, dynamic>?> getLearningObject(
      String learningObjectId) async {
    final db = await database;
    final results = await db.query(
      'learning_objects',
      where: 'id = ?',
      whereArgs: [learningObjectId],
    );

    if (results.isEmpty) return null;

    final result = Map<String, dynamic>.from(results.first);

    // Parse JSON strings back to objects
    if (result['paragraphs'] is String) {
      result['paragraphs'] = jsonDecode(result['paragraphs'] as String);
    }
    if (result['headers'] is String) {
      result['headers'] = jsonDecode(result['headers'] as String);
    }
    if (result['formatting'] is String) {
      result['formatting'] = jsonDecode(result['formatting'] as String);
    }
    if (result['metadata'] is String) {
      result['metadata'] = jsonDecode(result['metadata'] as String);
    }
    if (result['word_timings'] is String) {
      result['word_timings'] = jsonDecode(result['word_timings'] as String);
    }
    if (result['sentence_timings'] is String) {
      result['sentence_timings'] =
          jsonDecode(result['sentence_timings'] as String);
    }

    return result;
  }

  /// Update user progress
  Future<int> upsertUserProgress(Map<String, dynamic> progress) async {
    final db = await database;
    progress['updated_at'] = DateTime.now().toIso8601String();

    return await db.insert(
      'user_progress',
      progress,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get user progress for a learning object
  Future<Map<String, dynamic>?> getUserProgress(
      String userId, String learningObjectId) async {
    final db = await database;
    final results = await db.query(
      'user_progress',
      where: 'user_id = ? AND learning_object_id = ?',
      whereArgs: [userId, learningObjectId],
    );
    return results.isEmpty ? null : results.first;
  }

  /// Update download cache status
  Future<int> updateDownloadStatus({
    required String userId,
    required String learningObjectId,
    required String status,
    int? progress,
    String? errorMessage,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'download_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (progress != null) updates['download_progress'] = progress;
    if (errorMessage != null) updates['error_message'] = errorMessage;
    if (status == 'completed') {
      updates['download_completed_at'] = DateTime.now().toIso8601String();
      updates['audio_downloaded'] = 1;
      updates['content_downloaded'] = 1;
    }

    return await db.update(
      'download_cache',
      updates,
      where: 'user_id = ? AND learning_object_id = ?',
      whereArgs: [userId, learningObjectId],
    );
  }

  /// Get download status for a course
  Future<List<Map<String, dynamic>>> getDownloadStatus(
      String userId, String courseId) async {
    final db = await database;
    return await db.query(
      'download_cache',
      where: 'user_id = ? AND course_id = ?',
      whereArgs: [userId, courseId],
    );
  }

  /// Clear all data (for logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('user_progress');
    await db.delete('user_course_progress');
    await db.delete('download_cache');
    await db.delete('learning_objects');
    await db.delete('assignments');
    await db.delete('courses');
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Validation function
  static Future<void> validateLocalDatabase() async {
    print('🔍 Validating LocalDatabaseService...');

    final service = LocalDatabaseService.instance;
    final db = await service.database;

    // Verify database version
    final version = await db.getVersion();
    assert(version == _dbVersion, 'Database version mismatch');
    print('✓ Database version: $version');

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
      assert(result.isNotEmpty, 'Table $table does not exist');
      print('✓ Table exists: $table');
    }

    // Test CRUD operations
    final testCourse = {
      'id': 'test-course-id',
      'course_number': 'TEST-101',
      'title': 'Test Course',
      'total_learning_objects': 10,
      'total_assignments': 3,
      'estimated_duration_ms': 3600000,
      'order_index': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    await service.upsertCourse(testCourse);
    final retrievedCourse = await service.getCourse('test-course-id');
    assert(retrievedCourse != null, 'Failed to retrieve course');
    assert(retrievedCourse!['title'] == 'Test Course', 'Course data mismatch');
    print('✓ CRUD operations working');

    // Clean up test data
    await db.delete('courses', where: 'id = ?', whereArgs: ['test-course-id']);

    print('✅ LocalDatabaseService validation complete!');
  }
}
