/// Data Synchronization Service
///
/// Purpose: Manages bidirectional sync between local SQLite database
/// and remote Supabase database for offline/online functionality.
///
/// Dependencies:
/// - Supabase: Remote data source
/// - LocalDatabaseService: Local data storage
/// - ConnectivityPlus: Network status monitoring
///
/// Usage:
/// ```dart
/// final syncService = DataSyncService();
/// await syncService.syncUserProgress(userId);
/// ```
///
/// Expected behavior:
/// - Syncs user progress when network available
/// - Handles conflict resolution (last-write-wins)
/// - Queues changes made offline
/// - Auto-syncs on network reconnection

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';
import '../database/local_database_service.dart';

class DataSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LocalDatabaseService _localDb = LocalDatabaseService.instance;
  final Connectivity _connectivity = Connectivity();

  // Sync status tracking
  bool _isSyncing = false;
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  // Network monitoring
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _wasOffline = false;

  /// Initialize sync service and start monitoring
  Future<void> initialize(String userId) async {
    // Monitor network status
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results, userId);
    });

    // Check initial network status
    final initialStatus = await _connectivity.checkConnectivity();
    _handleConnectivityChange(initialStatus, userId);
  }

  /// Handle network connectivity changes
  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
    String userId,
  ) async {
    final isConnected =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (isConnected && _wasOffline) {
      // Network restored - trigger sync
      print('📡 Network restored - starting sync...');
      await performFullSync(userId);
    }

    _wasOffline = !isConnected;
  }

  /// Perform full synchronization
  Future<void> performFullSync(String userId) async {
    if (_isSyncing) {
      print('⏳ Sync already in progress');
      return;
    }

    try {
      _isSyncing = true;
      _emitStatus(SyncStatus(
        status: 'syncing',
        message: 'Starting synchronization...',
      ));

      // 1. Sync user progress (local → remote)
      await _syncUserProgressToRemote(userId);

      // 2. Sync user progress (remote → local)
      await _syncUserProgressFromRemote(userId);

      // 3. Sync course progress
      await _syncCourseProgress(userId);

      // 4. Check for course updates
      await _checkCourseUpdates(userId);

      _emitStatus(SyncStatus(
        status: 'completed',
        message: 'Synchronization complete',
      ));
    } catch (e) {
      _emitStatus(SyncStatus(
        status: 'failed',
        message: 'Sync failed: ${e.toString()}',
      ));
      print('❌ Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync local user progress to remote
  Future<void> _syncUserProgressToRemote(String userId) async {
    _emitStatus(SyncStatus(
      status: 'syncing',
      message: 'Uploading progress...',
    ));

    final db = await _localDb.database;
    final localProgress = await db.query(
      'user_progress',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    for (final progress in localProgress) {
      try {
        // Convert SQLite boolean integers to actual booleans
        final progressData = Map<String, dynamic>.from(progress);
        progressData['is_completed'] = progress['is_completed'] == 1;
        progressData['is_in_progress'] = progress['is_in_progress'] == 1;

        // Upload to Supabase
        await _supabase.from('user_progress').upsert(
              progressData,
              onConflict: 'user_id,learning_object_id',
            );
      } catch (e) {
        print(
            '⚠️ Failed to sync progress for ${progress['learning_object_id']}: $e');
      }
    }
  }

  /// Sync remote user progress to local
  Future<void> _syncUserProgressFromRemote(String userId) async {
    _emitStatus(SyncStatus(
      status: 'syncing',
      message: 'Downloading progress...',
    ));

    final remoteProgress =
        await _supabase.from('user_progress').select().eq('user_id', userId);

    for (final progress in remoteProgress as List) {
      final localProgress = await _localDb.getUserProgress(
        userId,
        progress['learning_object_id'],
      );

      // Conflict resolution: Use the most recently updated version
      if (localProgress != null) {
        final localUpdated =
            DateTime.tryParse(localProgress['updated_at'] as String? ?? '');
        final remoteUpdated =
            DateTime.tryParse(progress['updated_at'] as String? ?? '');

        if (localUpdated != null && remoteUpdated != null) {
          if (localUpdated.isAfter(remoteUpdated)) {
            // Local is newer, skip remote update
            continue;
          }
        }
      }

      // Convert boolean values for SQLite
      final progressData = Map<String, dynamic>.from(progress);
      progressData['is_completed'] = progress['is_completed'] == true ? 1 : 0;
      progressData['is_in_progress'] =
          progress['is_in_progress'] == true ? 1 : 0;

      await _localDb.upsertUserProgress(progressData);
    }
  }

  /// Sync course progress
  Future<void> _syncCourseProgress(String userId) async {
    _emitStatus(SyncStatus(
      status: 'syncing',
      message: 'Syncing course progress...',
    ));

    // Get local course progress
    final db = await _localDb.database;
    final localCourseProgress = await db.query(
      'user_course_progress',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // Upload to remote
    for (final progress in localCourseProgress) {
      try {
        await _supabase.from('user_course_progress').upsert(
              progress,
              onConflict: 'user_id,course_id',
            );
      } catch (e) {
        print(
            '⚠️ Failed to sync course progress for ${progress['course_id']}: $e');
      }
    }

    // Download from remote
    final remoteCourseProgress = await _supabase
        .from('user_course_progress')
        .select()
        .eq('user_id', userId);

    for (final progress in remoteCourseProgress as List) {
      await db.insert(
        'user_course_progress',
        progress,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Check for course updates
  Future<void> _checkCourseUpdates(String userId) async {
    _emitStatus(SyncStatus(
      status: 'syncing',
      message: 'Checking for course updates...',
    ));

    final localCourses = await _localDb.getCourses();

    for (final localCourse in localCourses) {
      try {
        // Get remote course data
        final remoteCourse = await _supabase
            .from('courses')
            .select()
            .eq('id', localCourse['id'])
            .maybeSingle();

        if (remoteCourse != null) {
          final localUpdated =
              DateTime.tryParse(localCourse['updated_at'] as String? ?? '');
          final remoteUpdated =
              DateTime.tryParse(remoteCourse['updated_at'] as String? ?? '');

          if (localUpdated != null && remoteUpdated != null) {
            if (remoteUpdated.isAfter(localUpdated)) {
              // Course has been updated - mark for re-download
              await _markCourseForUpdate(localCourse['id'], userId);
            }
          }
        }
      } catch (e) {
        print('⚠️ Failed to check updates for course ${localCourse['id']}: $e');
      }
    }
  }

  /// Mark course as needing update
  Future<void> _markCourseForUpdate(String courseId, String userId) async {
    final db = await _localDb.database;
    await db.update(
      'download_cache',
      {'needs_update': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'user_id = ? AND course_id = ?',
      whereArgs: [userId, courseId],
    );
  }

  /// Save user progress (with offline support)
  Future<void> saveUserProgress({
    required String userId,
    required String learningObjectId,
    required Map<String, dynamic> progressData,
  }) async {
    // Always save locally first
    progressData['user_id'] = userId;
    progressData['learning_object_id'] = learningObjectId;
    progressData['updated_at'] = DateTime.now().toIso8601String();

    // Convert booleans for SQLite
    if (progressData['is_completed'] != null) {
      progressData['is_completed'] =
          progressData['is_completed'] == true ? 1 : 0;
    }
    if (progressData['is_in_progress'] != null) {
      progressData['is_in_progress'] =
          progressData['is_in_progress'] == true ? 1 : 0;
    }

    await _localDb.upsertUserProgress(progressData);

    // Try to sync to remote if online
    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.isNotEmpty &&
        !connectivity.contains(ConnectivityResult.none)) {
      try {
        // Convert back for Supabase
        final remoteData = Map<String, dynamic>.from(progressData);
        remoteData['is_completed'] = progressData['is_completed'] == 1;
        remoteData['is_in_progress'] = progressData['is_in_progress'] == 1;

        await _supabase.from('user_progress').upsert(
              remoteData,
              onConflict: 'user_id,learning_object_id',
            );
      } catch (e) {
        // Failed to sync remotely, but local save succeeded
        print('⚠️ Failed to sync progress remotely (will retry later): $e');
      }
    }
  }

  /// Get user progress (with offline support)
  Future<Map<String, dynamic>?> getUserProgress({
    required String userId,
    required String learningObjectId,
  }) async {
    // Try to get from local first
    final localProgress =
        await _localDb.getUserProgress(userId, learningObjectId);

    // If offline or we have local data, return it
    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none) ||
        localProgress != null) {
      return localProgress;
    }

    // Try to get from remote if online and no local data
    try {
      final remoteProgress = await _supabase
          .from('user_progress')
          .select()
          .eq('user_id', userId)
          .eq('learning_object_id', learningObjectId)
          .maybeSingle();

      if (remoteProgress != null) {
        // Save to local for offline access
        final progressData = Map<String, dynamic>.from(remoteProgress);
        progressData['is_completed'] =
            remoteProgress['is_completed'] == true ? 1 : 0;
        progressData['is_in_progress'] =
            remoteProgress['is_in_progress'] == true ? 1 : 0;
        await _localDb.upsertUserProgress(progressData);
      }

      return remoteProgress;
    } catch (e) {
      print('⚠️ Failed to get remote progress: $e');
      return localProgress;
    }
  }

  /// Clear all local data (for logout)
  Future<void> clearAllData() async {
    await _localDb.clearAllData();
    _emitStatus(SyncStatus(
      status: 'cleared',
      message: 'Local data cleared',
    ));
  }

  /// Emit sync status
  void _emitStatus(SyncStatus status) {
    if (!_syncStatusController.isClosed) {
      _syncStatusController.add(status);
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
  }

  /// Validation function
  static Future<void> validateDataSyncService() async {
    print('🔍 Validating DataSyncService...');

    final service = DataSyncService();

    // Test connectivity monitoring
    final connectivity = await Connectivity().checkConnectivity();
    print('✓ Current connectivity: $connectivity');

    // Test sync status stream
    final statusSubscription = service.syncStatusStream.listen((status) {
      print('  Sync status: ${status.status} - ${status.message}');
    });

    // Test offline progress save (doesn't require network)
    final testProgress = {
      'current_position_ms': 5000,
      'last_word_index': 42,
      'last_sentence_index': 3,
      'is_in_progress': true,
      'completion_percentage': 25,
    };

    await service.saveUserProgress(
      userId: 'test-user',
      learningObjectId: 'test-lo',
      progressData: testProgress,
    );
    print('✓ Offline progress save working');

    // Retrieve saved progress
    final retrieved = await service.getUserProgress(
      userId: 'test-user',
      learningObjectId: 'test-lo',
    );
    assert(retrieved != null, 'Failed to retrieve progress');
    print('✓ Progress retrieval working');

    // Clean up test data
    final db = await LocalDatabaseService.instance.database;
    await db.delete(
      'user_progress',
      where: 'user_id = ? AND learning_object_id = ?',
      whereArgs: ['test-user', 'test-lo'],
    );

    await statusSubscription.cancel();
    service.dispose();

    print('✅ DataSyncService validation complete!');
  }
}

/// Sync status model
class SyncStatus {
  final String status; // 'idle', 'syncing', 'completed', 'failed', 'cleared'
  final String message;
  final DateTime timestamp;

  SyncStatus({
    required this.status,
    required this.message,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => {
        'status': status,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };
}
