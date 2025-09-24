/// Course Service
///
/// Purpose: Manages course data operations with Supabase
/// Dependencies:
///   - supabase_service.dart: Database client
///   - models/course.dart: Course model
///
/// Status: ✅ Created for DATA_ARCHITECTURE_PLAN (Phase 4)
///   - Supports new database schema with snake_case fields
///   - Handles course fetching and enrollment operations
///
/// Usage:
///   final courseService = CourseService();
///   final courses = await courseService.fetchAvailableCourses();
///
/// Expected behavior:
///   - Fetches courses from Supabase with proper field mapping
///   - Handles user enrollments
///   - Manages course-level operations

import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../models/course.dart';

class CourseService {
  static final CourseService _instance = CourseService._internal();
  factory CourseService() => _instance;
  CourseService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  /// Fetch all available courses
  Future<List<Course>> fetchAvailableCourses() async {
    try {
      final response = await _supabaseService.client
          .from('courses')
          .select()
          .order('order_index');

      return (response as List).map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching available courses: $e');
      rethrow;
    }
  }

  /// Fetch user's enrolled courses
  Future<List<Course>> fetchEnrolledCourses() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabaseService.client
          .from('user_course_enrollments')
          .select('*, courses(*)')
          .eq('user_id', userId)
          .order('enrolled_at', ascending: false);

      return (response as List)
          .map((json) => Course.fromJson(json['courses']))
          .toList();
    } catch (e) {
      debugPrint('Error fetching enrolled courses: $e');
      rethrow;
    }
  }

  /// Fetch a single course by ID
  Future<Course?> fetchCourse(String courseId) async {
    try {
      final response = await _supabaseService.client
          .from('courses')
          .select()
          .eq('id', courseId)
          .maybeSingle();

      if (response != null) {
        return Course.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching course: $e');
      return null;
    }
  }

  /// Enroll user in a course
  Future<bool> enrollInCourse(String courseId) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabaseService.client.from('user_course_enrollments').insert({
        'user_id': userId,
        'course_id': courseId,
        'enrolled_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Successfully enrolled in course: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error enrolling in course: $e');
      return false;
    }
  }

  /// Unenroll user from a course
  Future<bool> unenrollFromCourse(String courseId) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabaseService.client
          .from('user_course_enrollments')
          .delete()
          .eq('user_id', userId)
          .eq('course_id', courseId);

      debugPrint('Successfully unenrolled from course: $courseId');
      return true;
    } catch (e) {
      debugPrint('Error unenrolling from course: $e');
      return false;
    }
  }

  /// Check if user is enrolled in a course
  Future<bool> isEnrolled(String courseId) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return false;

      final response = await _supabaseService.client
          .from('user_course_enrollments')
          .select('id')
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking enrollment: $e');
      return false;
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

/// Validation function to verify CourseService implementation
void validateCourseService() {
  final courseService = CourseService();

  // Test singleton pattern
  final courseService2 = CourseService();
  assert(identical(courseService, courseService2));

  debugPrint('CourseService validation passed');
}
