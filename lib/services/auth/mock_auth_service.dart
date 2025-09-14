import 'dart:async';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'auth_service_interface.dart';
import 'mock_auth_models.dart';

/// Mock authentication service for development.
/// Uses Supabase directly with test users until Cognito is configured.
class MockAuthService implements AuthServiceInterface {
  final _authStateController = StreamController<bool>.broadcast();
  MockAuthUser? _currentMockUser;
  String? _mockJwtToken;

  // Test users for development
  static const _testUsers = {
    'test@example.com': 'password123',
    'admin@example.com': 'admin123',
    'user@example.com': 'user123',
  };

  @override
  Future<void> initialize() async {
    // Test users initialized
  }

  @override
  Future<SignInResult> signIn(String email, String password) async {
    await Future.delayed(
        const Duration(milliseconds: 500)); // Simulate network delay

    // Check against test users
    if (_testUsers[email] != password) {
      throw MockAuthException(
        'Invalid credentials',
        underlyingException: 'Mock auth: Invalid email or password',
      );
    }

    // Sign in to Supabase with the test account
    try {
      final response =
          await supabase.Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _currentMockUser = MockAuthUser(
          userId: response.user!.id,
          username: email.split('@')[0],
          email: email,
        );
        _mockJwtToken = response.session?.accessToken ??
            'mock-jwt-token-${DateTime.now().millisecondsSinceEpoch}';
        _authStateController.add(true);

        return const SignInResult(
          isSignedIn: true,
          nextStep: AuthNextSignInStep(
            signInStep: AuthSignInStep.done,
          ),
        );
      }
    } catch (e) {
      // Supabase not initialized, using pure mock
      // Fall back to pure mock if Supabase isn't configured
      _currentMockUser = MockAuthUser(
        userId: 'mock-user-${email.hashCode}',
        username: email.split('@')[0],
        email: email,
      );
      _mockJwtToken = 'mock-jwt-token-${DateTime.now().millisecondsSinceEpoch}';
      _authStateController.add(true);
      return const SignInResult(
        isSignedIn: true,
        nextStep: AuthNextSignInStep(
          signInStep: AuthSignInStep.done,
        ),
      );
    }

    throw MockAuthException(
      'Sign in failed',
      underlyingException: 'Unknown error in mock auth',
    );
  }

  @override
  Future<void> signOut() async {
    await Future.delayed(
        const Duration(milliseconds: 200)); // Simulate network delay

    try {
      await supabase.Supabase.instance.client.auth.signOut();
    } catch (e) {
      // Supabase not initialized or sign out failed, continue
    }

    _currentMockUser = null;
    _mockJwtToken = null;
    _authStateController.add(false);
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    if (_currentMockUser == null) {
      // Try to check Supabase session if initialized
      try {
        final supabaseUser = supabase.Supabase.instance.client.auth.currentUser;
        if (supabaseUser != null) {
          _currentMockUser = MockAuthUser(
            userId: supabaseUser.id,
            username: supabaseUser.email?.split('@')[0] ?? 'user',
            email: supabaseUser.email ?? '',
          );
        }
      } catch (e) {
        // Supabase not initialized, continue with mock user
      }
    }

    // Convert MockAuthUser to AuthUser
    if (_currentMockUser != null) {
      return AuthUser(
        userId: _currentMockUser!.userId,
        username: _currentMockUser!.username,
        signInDetails: const CognitoSignInDetailsApiBased(
          username: 'mock',
        ),
      );
    }

    return null;
  }

  @override
  Future<bool> isSignedIn() async {
    final user = await getCurrentUser();
    return user != null;
  }

  @override
  Future<String?> getJwtToken() async {
    if (_currentMockUser == null) return null;

    // Try to get real token from Supabase if initialized
    try {
      final session = supabase.Supabase.instance.client.auth.currentSession;
      if (session != null) {
        _mockJwtToken = session.accessToken;
      }
    } catch (e) {
      // Supabase not initialized, use mock token
    }

    return _mockJwtToken;
  }

  @override
  Future<void> refreshTokens() async {
    if (_currentMockUser == null) {
      throw MockAuthException(
        'No user signed in',
        underlyingException: 'Cannot refresh tokens without active session',
      );
    }

    try {
      // Try to refresh Supabase session if initialized
      final response =
          await supabase.Supabase.instance.client.auth.refreshSession();
      if (response.session != null) {
        _mockJwtToken = response.session!.accessToken;
        return;
      }
    } catch (e) {
      // Supabase not initialized, continue with mock
    }

    // Fall back to generating new mock token
    _mockJwtToken =
        'mock-jwt-token-refreshed-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  void dispose() {
    _authStateController.close();
  }
}
