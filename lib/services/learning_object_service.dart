/// Learning Object Service
///
/// Purpose: Manages learning object data operations with Supabase
/// Dependencies:
///   - supabase_service.dart: Database client
///   - models/learning_object_v2.dart: LearningObjectV2 model
///
/// Status: ✅ Created for DATA_ARCHITECTURE_PLAN (Phase 4)
///   - Supports new database schema with JSONB fields
///   - Handles pre-processed content with word/sentence timings
///
/// Usage:
///   final loService = LearningObjectService();
///   final learningObjects = await loService.fetchLearningObjects(assignmentId);
///
/// Expected behavior:
///   - Fetches learning objects with complete timing data
///   - Handles JSONB field parsing for word and sentence timings

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../models/learning_object_v2.dart';

class LearningObjectService {
  static final LearningObjectService _instance =
      LearningObjectService._internal();
  factory LearningObjectService() => _instance;
  LearningObjectService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  /// Fetch all learning objects for an assignment
  Future<List<LearningObjectV2>> fetchLearningObjects(
      String assignmentId) async {
    try {
      final response = await _supabaseService.client
          .from('learning_objects')
          .select()
          .eq('assignment_id', assignmentId)
          .order('order_index');

      return (response as List)
          .map((json) => LearningObjectV2.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching learning objects: $e');
      rethrow;
    }
  }

  /// Fetch a single learning object by ID
  Future<LearningObjectV2?> fetchLearningObject(String learningObjectId) async {
    try {
      final response = await _supabaseService.client
          .from('learning_objects')
          .select()
          .eq('id', learningObjectId)
          .maybeSingle();

      if (response != null) {
        return LearningObjectV2.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching learning object: $e');
      return null;
    }
  }

  /// Fetch learning objects for a course
  Future<List<LearningObjectV2>> fetchLearningObjectsForCourse(
      String courseId) async {
    try {
      final response = await _supabaseService.client
          .from('learning_objects')
          .select()
          .eq('course_id', courseId)
          .order('assignment_id')
          .order('order_index');

      return (response as List)
          .map((json) => LearningObjectV2.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching learning objects for course: $e');
      rethrow;
    }
  }

  /// Fetch learning objects with user progress
  Future<List<Map<String, dynamic>>> fetchLearningObjectsWithProgress(
    String assignmentId,
  ) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch learning objects
      final learningObjects = await fetchLearningObjects(assignmentId);

      // Fetch user progress
      final progressResponse = await _supabaseService.client
          .from('user_progress')
          .select()
          .eq('user_id', userId)
          .eq('assignment_id', assignmentId);

      final progressMap = Map<String, dynamic>.fromEntries(
        (progressResponse as List).map((p) => MapEntry(
              p['learning_object_id'] as String,
              p,
            )),
      );

      // Combine learning objects with progress
      return learningObjects.map((lo) {
        final progress = progressMap[lo.id];
        return {
          'learning_object': lo,
          'progress': progress,
          'is_completed': progress?['is_completed'] ?? false,
          'current_position_ms': progress?['current_position_ms'] ?? 0,
          'last_word_index': progress?['last_word_index'] ?? 0,
          'last_sentence_index': progress?['last_sentence_index'] ?? 0,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching learning objects with progress: $e');
      rethrow;
    }
  }

  /// Get the next learning object to work on
  Future<LearningObjectV2?> getNextLearningObject(String assignmentId) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return null;

      // Fetch all learning objects for the assignment
      final learningObjects = await fetchLearningObjects(assignmentId);
      if (learningObjects.isEmpty) return null;

      // Check progress for each learning object
      for (final lo in learningObjects) {
        final response = await _supabaseService.client
            .from('user_progress')
            .select('is_completed')
            .eq('user_id', userId)
            .eq('learning_object_id', lo.id)
            .maybeSingle();

        // If no progress or not completed, this is the next one
        if (response == null || response['is_completed'] != true) {
          return lo;
        }
      }

      // All learning objects completed
      return null;
    } catch (e) {
      debugPrint('Error getting next learning object: $e');
      return null;
    }
  }

  /// Prefetch learning objects for offline use
  Future<void> prefetchLearningObjects(String courseId) async {
    try {
      // Fetch all learning objects for the course
      final learningObjects = await fetchLearningObjectsForCourse(courseId);

      // Store in local cache (implementation would depend on cache service)
      debugPrint(
          'Prefetched ${learningObjects.length} learning objects for course $courseId');

      // TODO: Implement local storage/caching
    } catch (e) {
      debugPrint('Error prefetching learning objects: $e');
      rethrow;
    }
  }

  /// Get the current user ID from the auth service
  Future<String?> _getCurrentUserId() async {
    try {
      final cognitoUser = await _supabaseService.authService.getCurrentUser();
      if (cognitoUser == null) return null;

      final response = await _supabaseService.client
          .from('users')
          .select('id')
          .eq('cognito_sub', cognitoUser.userId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      debugPrint('Error getting current user ID: $e');
      return null;
    }
  }
}

/// Validation function to verify LearningObjectService implementation
void validateLearningObjectService() {
  final loService = LearningObjectService();

  // Test singleton pattern
  final loService2 = LearningObjectService();
  assert(identical(loService, loService2));

  debugPrint('LearningObjectService validation passed');
}
