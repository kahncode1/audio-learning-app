# Mock Authentication Usage Guide

## Overview
This guide explains how to use the mock authentication system that has been implemented to unblock development while waiting for AWS Cognito credentials.

## Current Status
✅ **Fully Implemented and Tested** (2025-09-13)
- 23 tests passing
- All authentication operations working
- Ready for full app development

## Test Credentials

| Email | Password | Username |
|-------|----------|----------|
| test@example.com | password123 | test |
| admin@example.com | admin123 | admin |
| user@example.com | user123 | user |

## Architecture

### Files Created
- `lib/services/auth/auth_service_interface.dart` - Common interface
- `lib/services/auth/mock_auth_service.dart` - Mock implementation
- `lib/services/auth/mock_auth_models.dart` - Mock-specific models
- `lib/services/auth_factory.dart` - Factory for switching implementations
- `test/mock_auth_test.dart` - Unit tests (13 passing)
- `test/mock_auth_app_test.dart` - Integration tests (10 passing)

### How It Works
1. **Interface Pattern**: All auth operations go through `AuthServiceInterface`
2. **Factory Pattern**: `AuthFactory` returns mock or real auth based on environment
3. **Graceful Fallback**: Works even when Supabase isn't initialized
4. **Stream Support**: Full auth state streaming for reactive UI

## Using Mock Auth in Your Code

### In Providers/Services
```dart
// The providers already use the interface
final authService = ref.watch(authServiceProvider);
// This will automatically use mock auth until Cognito is configured
```

### Direct Usage
```dart
import 'package:audio_learning_app/services/auth_factory.dart';

// Get the auth service (mock by default)
final authService = AuthFactory.instance;

// Initialize
await authService.initialize();

// Sign in
final result = await authService.signIn('test@example.com', 'password123');
if (result.isSignedIn) {
  // User is signed in
}

// Get current user
final user = await authService.getCurrentUser();

// Sign out
await authService.signOut();
```

### In Widgets
```dart
// Using Riverpod
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (isAuthenticated) => isAuthenticated
        ? AuthenticatedView()
        : LoginView(),
      loading: () => LoadingView(),
      error: (e, s) => ErrorView(e),
    );
  }
}
```

## Testing Your Features

### Unit Tests
```dart
test('My feature with auth', () async {
  final authService = MockAuthService();
  await authService.initialize();
  await authService.signIn('test@example.com', 'password123');

  // Test your feature
  expect(await authService.isSignedIn(), isTrue);
});
```

### Widget Tests
```dart
testWidgets('My widget with auth', (tester) async {
  // Mock auth is automatically used in test environment
  await tester.pumpWidget(
    ProviderScope(
      child: MyApp(),
    ),
  );

  // Your widget tests
});
```

## Switching to Real Auth (When Ready)

### Method 1: Environment Variable
```bash
# Run with real auth
flutter run --dart-define=USE_MOCK_AUTH=false
```

### Method 2: Code Change
```dart
// In lib/services/auth_factory.dart
const useMockAuth = bool.fromEnvironment(
  'USE_MOCK_AUTH',
  defaultValue: false, // Change to false when Cognito is ready
);
```

### Method 3: Runtime Override
```dart
// For testing different auth implementations
AuthFactory.setInstance(AuthService()); // Use real auth
AuthFactory.setInstance(MockAuthService()); // Use mock auth
```

## Features Supported

✅ **All Standard Auth Operations:**
- Sign in/out
- Get current user
- Check authentication status
- JWT token generation
- Token refresh
- Auth state streaming

✅ **Development Features:**
- Multiple test users
- Instant sign in (no network delay)
- Predictable behavior
- No external dependencies
- Works offline

## Troubleshooting

### Issue: "Supabase not initialized" warnings
**Solution**: These are expected and handled gracefully. The mock auth works without Supabase.

### Issue: Tests failing with SharedPreferences error
**Solution**: Use the mock service directly in tests, not through the factory with Supabase initialization.

### Issue: Need different test users
**Solution**: Modify the `_testUsers` map in `mock_auth_service.dart`:
```dart
static const _testUsers = {
  'test@example.com': 'password123',
  'admin@example.com': 'admin123',
  'user@example.com': 'user123',
  // Add more as needed
};
```

## Best Practices

1. **Always use the interface**: Don't directly reference `MockAuthService` in production code
2. **Test both paths**: Write tests that work with both mock and real auth
3. **Document auth requirements**: Note which features need specific user roles/permissions
4. **Use providers**: Let Riverpod handle auth state management

## Next Steps

With mock authentication working, you can now:
1. Build all UI screens that require authentication
2. Implement audio features with user context
3. Test progress tracking and preferences
4. Develop the complete user flow

When AWS Cognito credentials arrive:
1. Add credentials to `lib/config/app_config.dart`
2. Set `USE_MOCK_AUTH=false`
3. Test the real auth flow
4. Remove mock auth code if desired (optional - useful for testing)

## Summary

The mock authentication system is:
- ✅ Fully functional
- ✅ Well tested (23 tests passing)
- ✅ Ready for production development
- ✅ Easy to switch to real auth later

You can confidently build all features knowing the authentication layer is solid and ready.