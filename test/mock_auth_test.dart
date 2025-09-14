import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/auth/mock_auth_service.dart';
import 'package:audio_learning_app/services/auth/mock_auth_models.dart';
import 'package:audio_learning_app/services/auth_factory.dart';

void main() {
  group('Mock Authentication Tests', () {
    late MockAuthService mockAuth;

    setUp(() {
      mockAuth = MockAuthService();
    });

    tearDown(() {
      mockAuth.dispose();
    });

    test('Initialize mock auth service', () async {
      await mockAuth.initialize();
      // Should complete without errors
      expect(true, isTrue);
    });

    test('Sign in with valid test credentials', () async {
      await mockAuth.initialize();
      
      final result = await mockAuth.signIn(
        'test@example.com',
        'password123',
      );
      
      expect(result.isSignedIn, isTrue);
    });

    test('Sign in fails with invalid credentials', () async {
      await mockAuth.initialize();

      expect(
        () => mockAuth.signIn('test@example.com', 'wrongpassword'),
        throwsA(isA<MockAuthException>()),
      );
    });

    test('Get current user after sign in', () async {
      await mockAuth.initialize();
      await mockAuth.signIn('test@example.com', 'password123');
      
      final user = await mockAuth.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.username, equals('test'));
    });

    test('Check if signed in', () async {
      await mockAuth.initialize();
      
      // Initially not signed in
      expect(await mockAuth.isSignedIn(), isFalse);
      
      // Sign in
      await mockAuth.signIn('test@example.com', 'password123');
      
      // Now signed in
      expect(await mockAuth.isSignedIn(), isTrue);
    });

    test('Get JWT token after sign in', () async {
      await mockAuth.initialize();
      await mockAuth.signIn('test@example.com', 'password123');
      
      final token = await mockAuth.getJwtToken();
      expect(token, isNotNull);
      expect(token, isA<String>());
    });

    test('Sign out clears user session', () async {
      await mockAuth.initialize();
      await mockAuth.signIn('test@example.com', 'password123');
      
      // Verify signed in
      expect(await mockAuth.isSignedIn(), isTrue);
      
      // Sign out
      await mockAuth.signOut();
      
      // Verify signed out
      expect(await mockAuth.isSignedIn(), isFalse);
      expect(await mockAuth.getCurrentUser(), isNull);
      expect(await mockAuth.getJwtToken(), isNull);
    });

    test('Auth state stream emits changes', () async {
      await mockAuth.initialize();
      
      final states = <bool>[];
      final subscription = mockAuth.authStateChanges.listen(
        (state) => states.add(state),
      );
      
      // Sign in
      await mockAuth.signIn('test@example.com', 'password123');
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Sign out
      await mockAuth.signOut();
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Verify state changes
      expect(states, contains(true)); // Signed in
      expect(states, contains(false)); // Signed out
      
      await subscription.cancel();
    });

    test('Refresh tokens works when signed in', () async {
      await mockAuth.initialize();
      await mockAuth.signIn('test@example.com', 'password123');
      
      await mockAuth.getJwtToken();
      await mockAuth.refreshTokens();
      final newToken = await mockAuth.getJwtToken();
      
      expect(newToken, isNotNull);
      // For mock, tokens might be different after refresh
    });

    test('Refresh tokens fails when not signed in', () async {
      await mockAuth.initialize();

      expect(
        () => mockAuth.refreshTokens(),
        throwsA(isA<MockAuthException>()),
      );
    });
  });

  group('Auth Factory Tests', () {
    test('Factory returns singleton instance', () {
      final instance1 = AuthFactory.instance;
      final instance2 = AuthFactory.instance;
      
      expect(identical(instance1, instance2), isTrue);
    });

    test('Factory uses mock auth by default', () {
      // Reset to ensure clean state
      AuthFactory.reset();
      
      final instance = AuthFactory.instance;
      expect(instance, isA<MockAuthService>());
    });

    test('Factory can be reset', () {
      final instance1 = AuthFactory.instance;
      AuthFactory.reset();
      final instance2 = AuthFactory.instance;
      
      expect(identical(instance1, instance2), isFalse);
    });
  });
}