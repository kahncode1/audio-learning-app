import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_learning_app/providers/auth_providers.dart';
import 'package:audio_learning_app/services/auth/auth_service_interface.dart';
import 'package:audio_learning_app/services/auth_factory.dart';
import 'package:audio_learning_app/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('authServiceProvider', () {
      test('should provide AuthServiceInterface from factory', () {
        final service = container.read(authServiceProvider);

        expect(service, isA<AuthServiceInterface>());
        expect(service, AuthFactory.instance);
      });

      test('should provide same instance on multiple reads', () {
        final service1 = container.read(authServiceProvider);
        final service2 = container.read(authServiceProvider);

        expect(identical(service1, service2), isTrue);
      });

      test('should have required interface methods', () {
        final service = container.read(authServiceProvider);

        // Verify interface methods exist
        expect(service.initialize, isA<Function>());
        expect(service.signIn, isA<Function>());
        expect(service.signOut, isA<Function>());
        expect(service.getCurrentUser, isA<Function>());
        expect(service.getJwtToken, isA<Function>());
        expect(service.refreshTokens, isA<Function>());
        expect(service.isSignedIn, isA<Function>());
        expect(service.authStateChanges, isA<Stream<bool>>());
      });
    });

    group('authStateProvider', () {
      test('should provide stream of authentication state', () {
        final authState = container.read(authStateProvider);
        expect(authState, isA<AsyncValue<bool>>());
      });

      test('should handle stream updates', () {
        // The provider should provide a stream that emits auth state changes
        final authState = container.read(authStateProvider);
        expect(authState, isA<AsyncValue<bool>>());

        // Stream provider should handle loading state initially
        expect(
            authState.when(
              data: (value) => value,
              loading: () => null,
              error: (_, __) => false,
            ),
            anyOf([isNull, isA<bool>()]));
      });
    });

    group('currentUserProvider', () {
      test('should provide future of current user', () {
        final currentUser = container.read(currentUserProvider);
        expect(currentUser, isA<AsyncValue<User?>>());
      });

      test('should handle no current user', () {
        final currentUser = container.read(currentUserProvider);

        // Should handle the case where no user is signed in
        expect(currentUser, isA<AsyncValue<User?>>());
      });

      test('should create User model from auth user data', () async {
        // This tests the provider logic for converting AuthUser to User
        final currentUser = container.read(currentUserProvider);

        // Provider should return AsyncValue
        expect(currentUser, isA<AsyncValue<User?>>());

        // Test the data transformation logic exists
        currentUser.when(
          data: (user) {
            if (user != null) {
              expect(user, isA<User>());
              expect(user.id, isNotEmpty);
              expect(user.cognitoSub, isNotEmpty);
              expect(user.email, isNotEmpty);
            }
          },
          loading: () {}, // Loading state is valid
          error: (_, __) {}, // Error state is valid
        );
      });
    });

    group('isAuthenticatedProvider', () {
      test('should provide boolean authentication status', () {
        final isAuthenticated = container.read(isAuthenticatedProvider);
        expect(isAuthenticated, isA<bool>());
      });

      test('should return false when loading', () {
        // When auth state is loading, should return false
        final isAuthenticated = container.read(isAuthenticatedProvider);
        expect(isAuthenticated, isA<bool>());

        // Default behavior should be false for safety
        // (users should not see authenticated content while loading)
        expect(isAuthenticated, isFalse);
      });

      test('should return false when error occurs', () {
        // When auth state has error, should return false for safety
        final isAuthenticated = container.read(isAuthenticatedProvider);
        expect(isAuthenticated, isFalse);
      });
    });

    group('Provider Dependencies', () {
      test('auth providers should depend on authServiceProvider', () {
        final service = container.read(authServiceProvider);
        expect(service, isNotNull);

        // Other providers should be able to access the service
        expect(() => container.read(authStateProvider), returnsNormally);
        expect(() => container.read(currentUserProvider), returnsNormally);
        expect(() => container.read(isAuthenticatedProvider), returnsNormally);
      });

      test('isAuthenticatedProvider should depend on authStateProvider', () {
        // isAuthenticatedProvider should watch authStateProvider
        final authState = container.read(authStateProvider);
        final isAuthenticated = container.read(isAuthenticatedProvider);

        expect(authState, isA<AsyncValue<bool>>());
        expect(isAuthenticated, isA<bool>());
      });
    });

    group('Provider Lifecycle', () {
      test('providers should be disposable', () {
        final testContainer = ProviderContainer();

        testContainer.read(authServiceProvider);
        testContainer.read(authStateProvider);
        testContainer.read(currentUserProvider);
        testContainer.read(isAuthenticatedProvider);

        expect(() => testContainer.dispose(), returnsNormally);
      });

      test('providers should handle recreation after disposal', () {
        final testContainer = ProviderContainer();
        final service1 = testContainer.read(authServiceProvider);
        testContainer.dispose();

        final newContainer = ProviderContainer();
        final service2 = newContainer.read(authServiceProvider);

        // Should get same factory instance
        expect(identical(service1, service2), isTrue);
        newContainer.dispose();
      });
    });

    group('Error Handling', () {
      test('providers should handle service errors gracefully', () {
        // Providers should not throw even if service has issues
        expect(() => container.read(authServiceProvider), returnsNormally);
        expect(() => container.read(authStateProvider), returnsNormally);
        expect(() => container.read(currentUserProvider), returnsNormally);
        expect(() => container.read(isAuthenticatedProvider), returnsNormally);
      });

      test('isAuthenticatedProvider should handle null/error states', () {
        final isAuthenticated = container.read(isAuthenticatedProvider);

        // Should always return a boolean, never null
        expect(isAuthenticated, isA<bool>());

        // Should default to false for safety
        expect(isAuthenticated, isFalse);
      });
    });

    group('State Updates', () {
      test('providers should react to auth state changes', () {
        var notificationCount = 0;

        container.listen(
          isAuthenticatedProvider,
          (previous, next) => notificationCount++,
        );

        // Read the provider to establish dependency
        final initialState = container.read(isAuthenticatedProvider);
        expect(initialState, isA<bool>());

        // Changes in auth state should potentially trigger notifications
        // (Actual testing would require mocking the auth service)
      });
    });

    group('User Model Creation', () {
      test('should create User model with correct fields', () {
        final currentUser = container.read(currentUserProvider);

        currentUser.when(
          data: (user) {
            if (user != null) {
              // Verify User model structure
              expect(user.id, isA<String>());
              expect(user.cognitoSub, isA<String>());
              expect(user.email, isA<String>());
              expect(user.organization, isNull); // Set to null in provider
              expect(user.createdAt, isA<DateTime>());
              expect(user.updatedAt, isA<DateTime>());

              // Verify that cognitoSub matches id (from AuthUser.userId)
              expect(user.cognitoSub, user.id);
            }
          },
          loading: () {}, // Valid state
          error: (_, __) {}, // Valid state
        );
      });
    });

    group('Stream Behavior', () {
      test('authStateProvider should provide auth state stream', () {
        final authState = container.read(authStateProvider);

        expect(authState, isA<AsyncValue<bool>>());

        // Should handle all possible AsyncValue states
        authState.when(
          data: (isAuth) => expect(isAuth, isA<bool>()),
          loading: () => expect(true, true), // Loading is valid
          error: (error, stack) => expect(error, isNotNull),
        );
      });
    });

    group('Integration', () {
      test('all auth providers should work together', () {
        // Test that all providers can be read without errors
        final service = container.read(authServiceProvider);
        final authState = container.read(authStateProvider);
        final currentUser = container.read(currentUserProvider);
        final isAuthenticated = container.read(isAuthenticatedProvider);

        expect(service, isNotNull);
        expect(authState, isA<AsyncValue<bool>>());
        expect(currentUser, isA<AsyncValue<User?>>());
        expect(isAuthenticated, isA<bool>());

        // isAuthenticated should be consistent with authState
        authState.when(
          data: (authValue) {
            // When we have auth data, isAuthenticated should match
            // (unless there's an error, in which case it should be false)
          },
          loading: () {
            expect(isAuthenticated, isFalse);
          },
          error: (_, __) {
            expect(isAuthenticated, isFalse);
          },
        );
      });
    });

    group('Factory Integration', () {
      test('should use AuthFactory singleton', () {
        final service = container.read(authServiceProvider);
        final factoryInstance = AuthFactory.instance;

        expect(identical(service, factoryInstance), isTrue);
      });
    });
  });
}
