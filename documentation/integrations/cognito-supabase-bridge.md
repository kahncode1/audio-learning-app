# AWS Cognito to Supabase JWT Bridge Implementation

## Overview

This guide provides a complete implementation for bridging AWS Cognito JWT tokens to Supabase authentication, enabling seamless SSO integration for your Flutter audio learning platform.

## Architecture Flow

```
Enterprise SSO → AWS Cognito → JWT Token → Supabase Session → Flutter App
```

## Implementation Steps

### 1. AWS Cognito Configuration

Configure your Cognito User Pool to include required claims:

```json
{
  "cognito:username": "user123",
  "email": "user@company.com",
  "custom:role": "learner",
  "custom:organization": "company-id",
  "sub": "uuid-here",
  "aud": "your-client-id"
}
```

### 2. Supabase JWT Configuration

In your Supabase project settings, configure JWT validation:

```sql
-- Enable JWT validation in Supabase
SELECT auth.jwt() ->> 'sub' AS user_id;
SELECT auth.jwt() ->> 'email' AS user_email;
SELECT auth.jwt() ->> 'custom:role' AS user_role;
```

### 3. Flutter Integration

```dart
class AuthService {
  static final _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResult> bridgeToSupabase(String cognitoIdToken) async {
    try {
      // Create Supabase session using Cognito JWT
      final response = await _supabase.auth.setSession(
        RefreshSession(
          accessToken: cognitoIdToken,
          refreshToken: '', // Not used for JWT bridge
        ),
      );

      if (response.session != null) {
        return AuthResult.success(response.session!);
      } else {
        throw AuthException('Failed to create Supabase session');
      }
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  Future<void> syncUserProfile(User cognitoUser) async {
    final userProfile = {
      'id': cognitoUser.sub,
      'email': cognitoUser.email,
      'full_name': cognitoUser.attributes?['name'],
      'organization_id': cognitoUser.attributes?['custom:organization'],
      'role': cognitoUser.attributes?['custom:role'] ?? 'learner',
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase
        .from('user_profiles')
        .upsert(userProfile)
        .eq('id', cognitoUser.sub);
  }
}
```

### 4. Error Handling

```dart
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => 'AuthException: $message';
}

enum AuthResult {
  success(Session session),
  failure(String error);

  const AuthResult.success(this.session) : error = null;
  const AuthResult.failure(this.error) : session = null;

  final Session? session;
  final String? error;
}
```

### 5. Row Level Security Policies

```sql
-- RLS policy for user_profiles
CREATE POLICY "Users can only access their own profile"
ON user_profiles FOR ALL
USING (auth.jwt() ->> 'sub' = id::text);

-- RLS policy for courses with organization filtering
CREATE POLICY "Users see courses for their organization"
ON courses FOR SELECT
USING (
  organization_id = (auth.jwt() ->> 'custom:organization')
);

-- RLS policy for progress tracking
CREATE POLICY "Users can only access their own progress"
ON progress FOR ALL
USING (user_id = (auth.jwt() ->> 'sub')::uuid);
```

### 6. Token Refresh Handling

```dart
class TokenManager {
  Timer? _refreshTimer;

  void scheduleTokenRefresh(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return;

    final refreshTime = expiresAt - Duration(minutes: 5);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (refreshTime > now) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(
        Duration(seconds: refreshTime - now),
        () => refreshSession(),
      );
    }
  }

  Future<void> refreshSession() async {
    try {
      // Get fresh Cognito token
      final cognitoUser = await Amplify.Auth.getCurrentUser();
      final session = await Amplify.Auth.fetchAuthSession();

      if (session.isSignedIn && session.userPoolTokens != null) {
        final idToken = session.userPoolTokens!.idToken.raw;
        await AuthService().bridgeToSupabase(idToken);
      }
    } catch (e) {
      print('Token refresh failed: $e');
      // Handle refresh failure - possibly redirect to login
    }
  }
}
```

## Testing the Bridge

```dart
void validateCognitoSupabaseBridge() async {
  // Test 1: Successful authentication
  final cognitoSession = await Amplify.Auth.fetchAuthSession();
  assert(cognitoSession.isSignedIn);

  final idToken = cognitoSession.userPoolTokens?.idToken.raw;
  assert(idToken != null);

  // Test 2: Bridge to Supabase
  final authResult = await AuthService().bridgeToSupabase(idToken!);
  assert(authResult.session != null);

  // Test 3: Supabase RLS works
  final courses = await Supabase.instance.client
      .from('courses')
      .select()
      .limit(1);
  assert(courses.isNotEmpty); // Should return organization-filtered results

  print('✅ Cognito-Supabase bridge validation complete');
}
```

## Security Considerations

1. **JWT Signature Validation**: Supabase automatically validates JWT signatures
2. **Token Expiration**: Implement proper token refresh before expiration
3. **Claim Validation**: Validate required claims are present
4. **RLS Policies**: Ensure all sensitive tables have proper RLS policies
5. **HTTPS Only**: All token transmission must be over HTTPS

## Troubleshooting

### Common Issues

1. **Invalid JWT Error**: Check Supabase JWT secret matches Cognito
2. **RLS Violations**: Verify JWT claims match RLS policy expectations
3. **Token Expiration**: Implement automatic refresh 5 minutes before expiry
4. **Missing Claims**: Ensure Cognito includes all required custom attributes

### Debug Logging

```dart
void debugAuthBridge(String idToken) {
  final parts = idToken.split('.');
  final payload = base64.normalize(parts[1]);
  final decoded = json.decode(utf8.decode(base64.decode(payload)));

  print('JWT Claims: $decoded');
  print('User ID: ${decoded['sub']}');
  print('Organization: ${decoded['custom:organization']}');
  print('Role: ${decoded['custom:role']}');
  print('Expires: ${decoded['exp']}');
}
```

This implementation provides a secure, production-ready bridge between AWS Cognito and Supabase that supports your audio learning platform's enterprise authentication requirements.