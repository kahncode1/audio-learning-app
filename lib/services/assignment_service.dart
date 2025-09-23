/// Assignment Service
///
/// Purpose: Manages assignment data operations with Supabase
/// Dependencies:
///   - supabase_service.dart: Database client
///   - models/assignment.dart: Assignment model
///
/// Status: ✅ Created for DATA_ARCHITECTURE_PLAN (Phase 4)
///   - Supports new database schema with snake_case fields
///   - Handles assignment fetching with metrics
///
/// Usage:
///   final assignmentService = AssignmentService();
///   final assignments = await assignmentService.fetchAssignments(courseId);
///
/// Expected behavior:
///   - Fetches assignments from Supabase with proper field mapping
///   - Returns assignments with learning object counts and duration

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../models/assignment.dart';

class AssignmentService {
  static final AssignmentService _instance = AssignmentService._internal();
  factory AssignmentService() => _instance;
  AssignmentService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  /// Fetch all assignments for a course
  Future<List<Assignment>> fetchAssignments(String courseId) async {
    try {
      final response = await _supabaseService.client
          .from('assignments')
          .select()
          .eq('course_id', courseId)
          .order('order_index');

      return (response as List)
          .map((json) => Assignment.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching assignments: $e');
      rethrow;
    }
  }

  /// Fetch a single assignment by ID
  Future<Assignment?> fetchAssignment(String assignmentId) async {
    try {
      final response = await _supabaseService.client
          .from('assignments')
          .select()
          .eq('id', assignmentId)
          .maybeSingle();

      if (response != null) {
        return Assignment.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching assignment: $e');
      return null;
    }
  }

  /// Fetch assignments with progress for a user
  Future<List<Map<String, dynamic>>> fetchAssignmentsWithProgress(
    String courseId,
  ) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Fetch assignments
      final assignments = await fetchAssignments(courseId);

      // Fetch user progress for this course
      final progressResponse = await _supabaseService.client
          .from('user_progress')
          .select('assignment_id, learning_object_id, is_completed')
          .eq('user_id', userId)
          .eq('course_id', courseId);

      final progressList = progressResponse as List;

      // Calculate completion for each assignment
      final assignmentsWithProgress = assignments.map((assignment) {
        final assignmentProgress = progressList
            .where((p) => p['assignment_id'] == assignment.id)
            .toList();

        final completedCount = assignmentProgress
            .where((p) => p['is_completed'] == true)
            .length;

        return {
          'assignment': assignment,
          'completed_count': completedCount,
          'progress_percentage': assignment.learningObjectCount > 0
              ? (completedCount / assignment.learningObjectCount * 100)
              : 0.0,
        };
      }).toList();

      return assignmentsWithProgress;
    } catch (e) {
      debugPrint('Error fetching assignments with progress: $e');
      rethrow;
    }
  }

  /// Get the next assignment to work on
  Future<Assignment?> getNextAssignment(String courseId) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return null;

      // Fetch all assignments for the course
      final assignments = await fetchAssignments(courseId);
      if (assignments.isEmpty) return null;

      // Check progress for each assignment
      for (final assignment in assignments) {
        final response = await _supabaseService.client
            .from('user_progress')
            .select('is_completed')
            .eq('user_id', userId)
            .eq('assignment_id', assignment.id);

        final progressList = response as List;

        // If any learning object is not completed, this is the next assignment
        final hasIncomplete = progressList.isEmpty ||
            progressList.any((p) => p['is_completed'] != true);

        if (hasIncomplete) {
          return assignment;
        }
      }

      // All assignments completed
      return null;
    } catch (e) {
      debugPrint('Error getting next assignment: $e');
      return null;
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

/// Validation function to verify AssignmentService implementation
void validateAssignmentService() {
  final assignmentService = AssignmentService();

  // Test singleton pattern
  final assignmentService2 = AssignmentService();
  assert(identical(assignmentService, assignmentService2));

  debugPrint('AssignmentService validation passed');
}