import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/auth_factory.dart';
import 'package:audio_learning_app/services/auth/mock_auth_service.dart';
import 'package:audio_learning_app/services/auth/mock_auth_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Mock Auth Integration Tests', () {
    setUpAll(() async {
      // Initialize Supabase if not already initialized
      try {
        await Supabase.initialize(
          url: 'https://placeholder.supabase.co',
          anonKey: 'placeholder-key',
        );
      } catch (e) {
        // Already initialized or failed, continue with tests
      }
    });

    test('Complete authentication flow with initialized Supabase', () async {
      // Reset factory to get fresh instance
      AuthFactory.reset();

      final authService = AuthFactory.instance;
      expect(authService, isA<MockAuthService>());

      // Initialize
      await authService.initialize();

      // Test sign in
      final signInResult = await authService.signIn(
        'test@example.com',
        'password123',
      );
      expect(signInResult.isSignedIn, isTrue);

      // Get current user
      final user = await authService.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.username, equals('test'));

      // Check signed in status
      final isSignedIn = await authService.isSignedIn();
      expect(isSignedIn, isTrue);

      // Get JWT token
      final token = await authService.getJwtToken();
      expect(token, isNotNull);
      expect(token, contains('mock-jwt-token'));

      // Refresh tokens
      await authService.refreshTokens();
      final newToken = await authService.getJwtToken();
      expect(newToken, isNotNull);

      // Test auth state stream
      final states = <bool>[];
      final subscription = authService.authStateChanges.listen(
        (state) => states.add(state),
      );

      // Sign out
      await authService.signOut();
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify signed out
      final isSignedOut = await authService.isSignedIn();
      expect(isSignedOut, isFalse);

      final userAfterSignOut = await authService.getCurrentUser();
      expect(userAfterSignOut, isNull);

      await subscription.cancel();
      authService.dispose();
    });

    test('Mock auth handles all test users correctly', () async {
      final authService = MockAuthService();
      await authService.initialize();

      // Test all predefined users
      final testUsers = [
        ('test@example.com', 'password123'),
        ('admin@example.com', 'admin123'),
        ('user@example.com', 'user123'),
      ];

      for (final (email, password) in testUsers) {
        // Sign in
        final result = await authService.signIn(email, password);
        expect(result.isSignedIn, isTrue);

        // Verify user
        final user = await authService.getCurrentUser();
        expect(user, isNotNull);
        expect(user!.username, equals(email.split('@')[0]));

        // Sign out
        await authService.signOut();
        final signedOut = await authService.isSignedIn();
        expect(signedOut, isFalse);
      }

      authService.dispose();
    });

    test('Mock auth correctly rejects invalid credentials', () async {
      final authService = MockAuthService();
      await authService.initialize();

      // Test invalid password
      expect(
        () => authService.signIn('test@example.com', 'wrongpassword'),
        throwsA(isA<MockAuthException>()),
      );

      // Test non-existent user
      expect(
        () => authService.signIn('nonexistent@example.com', 'password'),
        throwsA(isA<MockAuthException>()),
      );

      // Verify still not signed in
      final isSignedIn = await authService.isSignedIn();
      expect(isSignedIn, isFalse);

      authService.dispose();
    });

    test('Mock auth maintains session across operations', () async {
      final authService = MockAuthService();
      await authService.initialize();

      // Sign in
      await authService.signIn('test@example.com', 'password123');

      // Perform multiple operations that require auth
      for (int i = 0; i < 5; i++) {
        final user = await authService.getCurrentUser();
        expect(user, isNotNull);

        final token = await authService.getJwtToken();
        expect(token, isNotNull);

        final isSignedIn = await authService.isSignedIn();
        expect(isSignedIn, isTrue);
      }

      // Token should persist
      final token1 = await authService.getJwtToken();
      final token2 = await authService.getJwtToken();
      expect(token1, equals(token2));

      authService.dispose();
    });

    test('Factory pattern works correctly', () async {
      // Reset and get instance
      AuthFactory.reset();
      final instance1 = AuthFactory.instance;

      // Should be mock by default
      expect(instance1, isA<MockAuthService>());

      // Should return same instance
      final instance2 = AuthFactory.instance;
      expect(identical(instance1, instance2), isTrue);

      // Can be reset
      AuthFactory.reset();
      final instance3 = AuthFactory.instance;
      expect(identical(instance1, instance3), isFalse);

      // Clean up
      instance1.dispose();
      instance3.dispose();
    });
  });
}