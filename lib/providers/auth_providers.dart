/// Authentication State Management Providers
///
/// Purpose: Manages authentication state and user session
/// Dependencies:
///   - flutter_riverpod: State management
///   - auth services: Authentication implementation
///   - models: User model
///
/// Critical: These providers are used throughout the app for auth checks

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_factory.dart';
import '../services/auth/auth_service_interface.dart';
import '../models/models.dart';

/// Auth service provider using factory pattern
final authServiceProvider = Provider<AuthServiceInterface>((ref) {
  return AuthFactory.instance;
});

/// Current authentication state stream
final authStateProvider = StreamProvider<bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current user provider
final currentUserProvider = FutureProvider<User?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final authUser = await authService.getCurrentUser();
  if (authUser == null) return null;

  // Create User model from AuthUser
  return User(
    id: authUser.userId,
    cognitoSub: authUser.userId,
    email: authUser.username,
    organization: null,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
});

/// Is authenticated provider - simplified access to auth state
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (isAuthenticated) => isAuthenticated,
    loading: () => false,
    error: (_, __) => false,
  );
});