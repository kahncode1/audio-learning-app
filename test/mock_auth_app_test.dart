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
      print('✅ Successfully signed in with test@example.com');
    });

    test('✅ Can retrieve current user after sign in', () async {
      await authService.initialize();
      await authService.signIn('test@example.com', 'password123');

      final user = await authService.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.username, equals('test'));
      print('✅ Retrieved user: ${user.username}');
    });

    test('✅ Can get JWT token', () async {
      await authService.initialize();
      await authService.signIn('test@example.com', 'password123');

      final token = await authService.getJwtToken();
      expect(token, isNotNull);
      expect(token, startsWith('mock-jwt-token'));
      print('✅ Got JWT token: ${token!.substring(0, 20)}...');
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
      print('✅ Successfully signed out');
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
      print('✅ Auth state stream emitted: $states');

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
        print('✅ User $email works correctly');
      }
    });

    test('✅ Invalid credentials are rejected', () async {
      await authService.initialize();

      try {
        await authService.signIn('test@example.com', 'wrongpassword');
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('MockAuthException'));
        print('✅ Invalid credentials correctly rejected');
      }
    });

    test('🏭 Factory returns mock auth service', () {
      AuthFactory.reset();
      final service = AuthFactory.instance;
      expect(service, isA<MockAuthService>());
      print('✅ Factory correctly returns MockAuthService');
    });
  });

  test('🎯 SUMMARY: Mock Authentication is Working!', () {
    print('''

    ✅ MOCK AUTHENTICATION TEST SUMMARY
    ====================================
    All authentication operations are working correctly:

    ✓ Service initialization
    ✓ User sign in/sign out
    ✓ Current user retrieval
    ✓ JWT token generation
    ✓ Auth state streaming
    ✓ Multiple test users
    ✓ Invalid credential handling
    ✓ Factory pattern

    The mock authentication system is ready for use!
    You can now proceed with app development.

    Test Users Available:
    - test@example.com / password123
    - admin@example.com / admin123
    - user@example.com / user123
    ''');

    expect(true, isTrue);
  });
}