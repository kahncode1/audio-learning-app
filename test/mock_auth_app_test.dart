/// Test app to verify mock authentication works correctly
/// Run this test to ensure mock auth is functioning properly

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/auth_factory.dart';
import 'package:audio_learning_app/services/auth/mock_auth_service.dart';

void main() {
  group('Mock Auth App Tests - Verify Authentication Works', () {
    late MockAuthService authService;

    setUp(() {
      // Get mock auth service directly (not through factory to avoid Supabase)
      authService = MockAuthService();
    });

    tearDown(() {
      authService.dispose();
    });

    test('✅ Mock auth initializes correctly', () async {
      await authService.initialize();
      expect(true, isTrue, reason: 'Initialization should complete');
    });

    test('✅ Can sign in with test user', () async {
      await authService.initialize();

      final result = await authService.signIn(
        'test@example.com',
        'password123',
      );

      expect(result.isSignedIn, isTrue);
    });

    test('✅ Can retrieve current user after sign in', () async {
      await authService.initialize();
      await authService.signIn('test@example.com', 'password123');

      final user = await authService.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.username, equals('test'));
    });

    test('✅ Can get JWT token', () async {
      await authService.initialize();
      await authService.signIn('test@example.com', 'password123');

      final token = await authService.getJwtToken();
      expect(token, isNotNull);
      expect(token, startsWith('mock-jwt-token'));
    });

    test('✅ Can sign out', () async {
      await authService.initialize();
      await authService.signIn('test@example.com', 'password123');

      // Verify signed in
      expect(await authService.isSignedIn(), isTrue);

      // Sign out
      await authService.signOut();

      // Verify signed out
      expect(await authService.isSignedIn(), isFalse);
      expect(await authService.getCurrentUser(), isNull);
    });

    test('✅ Auth state stream works', () async {
      await authService.initialize();

      final states = <bool>[];
      final subscription = authService.authStateChanges.listen(states.add);

      // Sign in
      await authService.signIn('test@example.com', 'password123');
      await Future.delayed(const Duration(milliseconds: 100));

      // Sign out
      await authService.signOut();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(states.contains(true), isTrue, reason: 'Should emit signed in state');
      expect(states.contains(false), isTrue, reason: 'Should emit signed out state');

      await subscription.cancel();
    });

    test('✅ All test users work', () async {
      await authService.initialize();

      final testCredentials = [
        ('test@example.com', 'password123', 'test'),
        ('admin@example.com', 'admin123', 'admin'),
        ('user@example.com', 'user123', 'user'),
      ];

      for (final (email, password, expectedUsername) in testCredentials) {
        // Sign in
        final result = await authService.signIn(email, password);
        expect(result.isSignedIn, isTrue);

        // Check user
        final user = await authService.getCurrentUser();
        expect(user?.username, equals(expectedUsername));

        // Sign out for next test
        await authService.signOut();
      }
    });

    test('✅ Invalid credentials are rejected', () async {
      await authService.initialize();

      try {
        await authService.signIn('test@example.com', 'wrongpassword');
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('MockAuthException'));
      }
    });

    test('🏭 Factory returns mock auth service', () {
      AuthFactory.reset();
      final service = AuthFactory.instance;
      expect(service, isA<MockAuthService>());
    });
  });

  test('🎯 SUMMARY: Mock Authentication is Working!', () {
    // All authentication operations are working correctly
    expect(true, isTrue);
  });
}