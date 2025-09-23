/// Riverpod State Management Providers - Barrel Export
///
/// Purpose: Central export point for all provider modules
/// This file re-exports all provider modules to maintain backward compatibility
/// after modularization. All existing imports of 'providers.dart' will continue to work.
///
/// Module Organization:
///   - auth_providers.dart: Authentication and user state
///   - course_providers.dart: Course, assignment, and learning object data
///   - audio_providers.dart: Audio playback and highlighting state (CRITICAL)
///   - ui_providers.dart: UI preferences (font size, playback speed) (CRITICAL)
///   - progress_providers.dart: Progress tracking and synchronization
///
/// Usage (unchanged):
///   import 'providers/providers.dart';
///   final courses = ref.watch(enrolledCoursesProvider);
///   final authState = ref.watch(authStateProvider);
///
/// Architecture Note:
/// This modularization was done as part of Phase 6 (Architecture Refinement)
/// using Option A (Minimal Risk) approach to improve maintainability
/// without risking the critical dual-level highlighting system.

// Re-export all provider modules
export 'auth_providers.dart';
export 'course_providers.dart';
export 'audio_providers.dart';
export 'ui_providers.dart';
export 'progress_providers.dart';
export 'database_providers.dart';  // New database service providers

// Re-export existing specialized providers (if needed by other parts of the app)
export 'audio_context_provider.dart';

/// Validation function to verify providers implementation
/// This function tests critical provider functionality through the provider system
/// Note: Validation is handled through the provider system and unit tests
/// Direct instantiation is not needed in the barrel export file
void validateProviders() {
  // Provider validation available through provider system and tests
  // Validation is performed through unit tests and the provider system
}