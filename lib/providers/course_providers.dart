/// Course Data Management Providers
///
/// Purpose: Manages course, assignment, and learning object data
/// Dependencies:
///   - flutter_riverpod: State management
///   - supabase_service: Data fetching
///   - models: Course, Assignment, LearningObject models
///
/// Note: Includes test data bypass for development

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';

/// Supabase service provider
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Enrolled courses provider
final enrolledCoursesProvider =
    FutureProvider<List<EnrolledCourse>>((ref) async {
  final supabaseService = ref.watch(supabaseServiceProvider);

  // Only fetch if authenticated
  if (!supabaseService.isAuthenticated) {
    return [];
  }

  return await supabaseService.fetchEnrolledCourses();
});

/// Assignments provider for a specific course
final assignmentsProvider =
    FutureProvider.family<List<Assignment>, String>((ref, courseId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);

  // Allow test course ID to bypass authentication
  if (!supabaseService.isAuthenticated &&
      courseId != '14350bfb-5e84-4479-b7a2-09ce7a2fdd48') {
    return [];
  }

  return await supabaseService.fetchAssignments(courseId);
});

/// Learning objects provider for a specific assignment
final learningObjectsProvider =
    FutureProvider.family<List<LearningObject>, String>(
        (ref, assignmentId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);

  // Allow test assignment ID to bypass authentication
  if (!supabaseService.isAuthenticated &&
      assignmentId != 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11') {
    return [];
  }

  return await supabaseService.fetchLearningObjects(assignmentId);
});

/// Progress provider for a specific learning object (fetch only)
final progressProvider = FutureProvider.family<ProgressState?, String>(
    (ref, learningObjectId) async {
  final supabaseService = ref.watch(supabaseServiceProvider);

  if (!supabaseService.isAuthenticated) {
    return null;
  }

  return await supabaseService.fetchProgress(learningObjectId);
});

/// Currently selected course
final selectedCourseProvider = StateProvider<Course?>((ref) => null);

/// Currently selected assignment
final selectedAssignmentProvider = StateProvider<Assignment?>((ref) => null);

/// Currently selected learning object
final selectedLearningObjectProvider =
    StateProvider<LearningObject?>((ref) => null);
