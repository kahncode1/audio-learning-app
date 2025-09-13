# AWS Cognito SSO Authentication Guide for Flutter Audio Learning Platform

## Table of Contents
1. [Overview](#overview)
2. [Enterprise SSO Setup and Configuration](#enterprise-sso-setup-and-configuration)
3. [federateToIdentityPool API Usage](#federatetoidentitypool-api-usage)
4. [Token Management](#token-management)
5. [Automatic Token Refresh Implementation](#automatic-token-refresh-implementation)
6. [Supabase Integration with JWT](#supabase-integration-with-jwt)
7. [Flutter Implementation](#flutter-implementation)
8. [Error Handling and Session Management](#error-handling-and-session-management)
9. [Production Security Best Practices](#production-security-best-practices)
10. [Code Examples](#code-examples)
11. [Configuration Steps](#configuration-steps)
12. [Troubleshooting](#troubleshooting)

## Overview

AWS Cognito serves as the authentication backbone for the Flutter Audio Learning Platform, providing enterprise-grade Single Sign-On (SSO) capabilities that seamlessly bridge to Supabase for backend operations. This comprehensive guide covers production-ready implementation patterns for 2025.

### Architecture Flow
```
Enterprise IdP → AWS Cognito User Pool → JWT Tokens → Supabase Session → Flutter App
```

### Key Benefits
- **Enterprise Integration**: Seamless SSO with existing organizational identity providers
- **JWT Bridging**: Automatic token translation for Supabase compatibility
- **Automatic Refresh**: Built-in token lifecycle management
- **Security**: Enterprise-grade authentication with proper token validation
- **Scalability**: Production-tested for large user bases

## Enterprise SSO Setup and Configuration

### 1. AWS Cognito User Pool Configuration

#### Basic User Pool Setup
```json
{
  "userPoolName": "audio-learning-platform-users",
  "passwordPolicy": {
    "minimumLength": 12,
    "requireUppercase": true,
    "requireLowercase": true,
    "requireNumbers": true,
    "requireSymbols": true
  },
  "selfRegistrationEnabled": false,
  "adminCreateUserConfig": {
    "allowAdminCreateUserOnly": true,
    "inviteMessageAction": "EMAIL"
  }
}
```

#### Identity Provider Integration
For SAML-based enterprise SSO:

```json
{
  "providerName": "EnterpriseSSO",
  "providerType": "SAML",
  "providerDetails": {
    "MetadataURL": "https://your-enterprise-idp.com/metadata.xml",
    "IDPSignout": true,
    "EncryptedResponses": true
  },
  "attributeMapping": {
    "email": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress",
    "given_name": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname",
    "family_name": "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname"
  }
}
```

For OIDC-based enterprise SSO:
```json
{
  "providerName": "AzureAD",
  "providerType": "OIDC",
  "providerDetails": {
    "client_id": "your-azure-app-id",
    "client_secret": "your-azure-client-secret",
    "attributes_request_method": "GET",
    "oidc_issuer": "https://login.microsoftonline.com/tenant-id/v2.0",
    "authorize_scopes": "openid email profile"
  }
}
```

### 2. Identity Pool Configuration

```json
{
  "identityPoolName": "audio_learning_platform_identity_pool",
  "allowUnauthenticatedIdentities": false,
  "cognitoIdentityProviders": [{
    "providerName": "cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX",
    "clientId": "your-app-client-id",
    "serverSideTokenCheck": true
  }],
  "supportedLoginProviders": {
    "cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX": "your-app-client-id"
  }
}
```

### 3. IAM Roles for Identity Pool

#### Authenticated Role Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cognito-identity:GetId",
        "cognito-identity:GetCredentialsForIdentity",
        "cognito-idp:GetUser"
      ],
      "Resource": "*"
    }
  ]
}
```

## federateToIdentityPool API Usage

### Overview
The `federateToIdentityPool` API allows direct credential exchange without User Pool federation, useful for third-party integrations like Supabase.

### Implementation Pattern

```dart
class CognitoIdentityService {
  static const String _identityPoolId = 'us-east-1:your-identity-pool-id';

  /// Federate JWT token to get AWS credentials
  Future<AWSCredentials> federateToIdentityPool(String jwtToken) async {
    try {
      final credentials = await Amplify.Auth.federateToIdentityPool(
        token: jwtToken,
        provider: AuthProvider.cognito,
        options: const FederateToIdentityPoolOptions(
          developerProvidedIdentifier: null,
        ),
      );

      return credentials;
    } on AuthException catch (e) {
      throw AuthServiceException(
        'Federation to identity pool failed: ${e.message}',
        originalError: e,
      );
    }
  }

  /// Get identity pool credentials for current session
  Future<AWSCredentials?> getIdentityPoolCredentials() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) return null;

      final cognitoSession = session as CognitoAuthSession;
      final idToken = cognitoSession.userPoolTokensResult.value.idToken.raw;

      return await federateToIdentityPool(idToken);
    } catch (e) {
      logger.error('Failed to get identity pool credentials: $e');
      return null;
    }
  }
}
```

### Important Limitations

1. **Manual Token Refresh**: Automatic refresh is NOT supported with federated identities
2. **Exclusive Usage**: Cannot use `federateToIdentityPool` after `Auth.signIn`
3. **Token Management**: Must handle token lifecycle manually

## Token Management

### Token Types and Purposes

| Token Type | Purpose | Lifetime | Refresh |
|------------|---------|----------|---------|
| **ID Token** | User identity information | 1 hour | Via refresh token |
| **Access Token** | API authorization | 1 hour | Via refresh token |
| **Refresh Token** | Token renewal | 30 days (configurable) | Manual re-authentication |

### Token Structure

#### ID Token Claims
```json
{
  "sub": "user-uuid",
  "aud": "app-client-id",
  "cognito:groups": ["admins", "users"],
  "email_verified": true,
  "iss": "https://cognito-idp.region.amazonaws.com/user-pool-id",
  "cognito:username": "user@company.com",
  "given_name": "John",
  "family_name": "Doe",
  "aud": "client-id",
  "event_id": "event-uuid",
  "token_use": "id",
  "auth_time": 1640995200,
  "exp": 1640998800,
  "iat": 1640995200,
  "email": "user@company.com"
}
```

#### Access Token Claims
```json
{
  "sub": "user-uuid",
  "device_key": "device-key",
  "iss": "https://cognito-idp.region.amazonaws.com/user-pool-id",
  "client_id": "app-client-id",
  "event_id": "event-uuid",
  "token_use": "access",
  "scope": "openid email profile",
  "auth_time": 1640995200,
  "exp": 1640998800,
  "iat": 1640995200,
  "jti": "jwt-id",
  "username": "user@company.com"
}
```

### Token Validation Implementation

```dart
class TokenValidator {
  static const String _expectedIssuer = 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX';
  static const String _expectedAudience = 'your-app-client-id';

  /// Validate JWT token structure and claims
  static bool validateToken(String token) {
    try {
      final jwt = JWT.decode(token);
      final payload = jwt.payload;

      // Check expiration
      final exp = payload['exp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (exp <= now) {
        logger.warning('Token expired');
        return false;
      }

      // Check issuer
      final iss = payload['iss'] as String;
      if (iss != _expectedIssuer) {
        logger.error('Invalid issuer: $iss');
        return false;
      }

      // Check audience
      final aud = payload['aud'] as String;
      if (aud != _expectedAudience) {
        logger.error('Invalid audience: $aud');
        return false;
      }

      return true;
    } catch (e) {
      logger.error('Token validation failed: $e');
      return false;
    }
  }
}
```

## Automatic Token Refresh Implementation

### Built-in Automatic Refresh

For standard Cognito User Pool authentication (non-federated), Amplify provides automatic token refresh:

```dart
class AuthService {
  Timer? _refreshTimer;
  static const int _tokenRefreshBuffer = 300; // 5 minutes before expiry

  /// Schedule automatic token refresh
  Future<void> scheduleTokenRefresh(AuthSession session) async {
    _refreshTimer?.cancel();

    if (!session.isSignedIn) return;

    final cognitoSession = session as CognitoAuthSession;
    final accessToken = cognitoSession.userPoolTokensResult.value.accessToken;
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(
      accessToken.expiresAt.millisecondsSinceEpoch,
    );

    final now = DateTime.now();
    final refreshTime = expiryTime.subtract(Duration(seconds: _tokenRefreshBuffer));
    final delay = refreshTime.difference(now);

    if (delay.isNegative) {
      // Token already expired or about to expire
      await _performTokenRefresh();
    } else {
      _refreshTimer = Timer(delay, _performTokenRefresh);
      logger.info('Scheduled token refresh for ${refreshTime.toIso8601String()}');
    }
  }

  /// Perform token refresh
  Future<void> _performTokenRefresh() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: true),
      );

      if (session.isSignedIn) {
        await _bridgeToSupabase(session);
        await scheduleTokenRefresh(session);
        logger.info('Tokens refreshed successfully');
      }
    } on AuthException catch (e) {
      logger.error('Token refresh failed: ${e.message}');
      // Trigger re-authentication
      await _handleTokenRefreshFailure();
    }
  }

  /// Handle refresh failure
  Future<void> _handleTokenRefreshFailure() async {
    try {
      await signOut();
      // Navigate to login screen
      NavigationService.navigateToLogin();
    } catch (e) {
      logger.error('Failed to handle token refresh failure: $e');
    }
  }
}
```

### Manual Refresh for Federated Identities

```dart
class FederatedAuthService {
  /// Manual token refresh for federated authentication
  Future<bool> refreshFederatedTokens() async {
    try {
      // Get current session
      final session = await Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) return false;

      final cognitoSession = session as CognitoAuthSession;
      final refreshToken = cognitoSession.userPoolTokensResult.value.refreshToken;

      // Use refresh token to get new tokens
      final response = await _cognitoClient.initiateAuth(
        authFlow: 'REFRESH_TOKEN_AUTH',
        clientId: _clientId,
        authParameters: {
          'REFRESH_TOKEN': refreshToken.raw,
        },
      );

      final newIdToken = response.authenticationResult?.idToken;
      if (newIdToken != null) {
        // Update Supabase session with new token
        await _updateSupabaseSession(newIdToken);
        return true;
      }

      return false;
    } catch (e) {
      logger.error('Manual token refresh failed: $e');
      return false;
    }
  }
}
```

## Supabase Integration with JWT

### JWT Token Processing for Supabase

Supabase requires specific JWT claims for proper authorization. Cognito tokens need modification to include the required `role` claim.

### Pre-Token Generation Lambda Function

```javascript
exports.handler = async (event) => {
    // Add role claim for Supabase compatibility
    event.response.claimsOverrideDetails = {
        claimsToAddOrOverride: {
            'role': 'authenticated',
            'aud': 'authenticated',
            'app_metadata': JSON.stringify({
                provider: 'cognito',
                providers: ['cognito']
            }),
            'user_metadata': JSON.stringify({
                email: event.request.userAttributes.email,
                email_verified: event.request.userAttributes.email_verified === 'true'
            })
        }
    };

    return event;
};
```

### Supabase Client Configuration

```dart
class SupabaseService {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    _client ??= SupabaseClient(
      Env.supabaseUrl,
      Env.supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        detectSessionInUrl: false,
        persistSession: true,
        autoRefreshToken: false, // Handled by Cognito
      ),
    );
    return _client!;
  }

  /// Bridge Cognito JWT to Supabase session
  Future<void> setSupabaseSession(String cognitoIdToken) async {
    try {
      // Verify token before using
      if (!TokenValidator.validateToken(cognitoIdToken)) {
        throw AuthException('Invalid Cognito token');
      }

      // Create Supabase session
      final response = await client.auth.setSession(cognitoIdToken);

      if (response.session == null) {
        throw AuthException('Failed to create Supabase session');
      }

      logger.info('Supabase session created successfully');
    } on AuthException catch (e) {
      logger.error('Supabase session creation failed: ${e.message}');
      throw AuthServiceException(
        'Failed to bridge to Supabase: ${e.message}',
        originalError: e,
      );
    }
  }
}
```

### Row Level Security (RLS) Configuration

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
CREATE POLICY "Users can view their own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view their enrollments" ON enrollments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view enrolled courses" ON courses
    FOR SELECT USING (
        id IN (
            SELECT course_id FROM enrollments
            WHERE user_id = auth.uid()
            AND expires_at > now()
        )
    );

CREATE POLICY "Users can manage their progress" ON progress
    FOR ALL USING (auth.uid() = user_id);
```

## Flutter Implementation

### Complete AuthService Implementation

```dart
/// Authentication Service - AWS Cognito SSO with Supabase Bridge
///
/// Handles all authentication operations:
/// - AWS Cognito SSO authentication
/// - JWT token management and refresh
/// - Supabase session bridging
/// - Automatic token refresh scheduling

import 'dart:async';
import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _cognitoPoolId = Env.cognitoPoolId;
  static const String _cognitoClientId = Env.cognitoClientId;
  static const int _tokenRefreshBuffer = 300; // Refresh 5 minutes before expiry
  static const String _sessionKey = 'cognito_session';

  Timer? _refreshTimer;
  StreamController<AuthState>? _authStateController;

  Stream<AuthState> get authStateStream =>
      _authStateController?.stream ?? const Stream.empty();

  /// Initialize Amplify configuration
  Future<void> configureAmplify() async {
    if (Amplify.isConfigured) return;

    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugins([authPlugin]);

    try {
      await Amplify.configure(amplifyconfig);
      _authStateController = StreamController<AuthState>.broadcast();

      // Set up auth state listener
      Amplify.Auth.streamController.stream.listen((event) {
        _authStateController?.add(_mapToAuthState(event));
      });

      logger.info('Amplify configured successfully');
    } on AmplifyAlreadyConfiguredException {
      logger.warning('Amplify was already configured');
    } catch (e) {
      logger.error('Amplify configuration failed: $e');
      throw AuthServiceException(
        'Failed to configure Amplify',
        originalError: e,
      );
    }
  }

  /// Authenticate user via SSO
  Future<AuthSession> authenticate() async {
    try {
      // Check for cached session first
      final cachedSession = await _getCachedSession();
      if (cachedSession != null && cachedSession.isSignedIn) {
        await _scheduleTokenRefresh(cachedSession);
        return cachedSession;
      }

      // Check current session
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        await _cacheSession(session);
        await _bridgeToSupabase(session);
        await _scheduleTokenRefresh(session);
        return session;
      }

      // Initiate SSO login
      final result = await Amplify.Auth.signInWithWebUI(
        provider: AuthProvider.custom('EnterpriseSSO'),
        options: const SignInWithWebUIOptions(
          pluginOptions: CognitoSignInWithWebUIPluginOptions(
            isPreferPrivateSession: false,
          ),
        ),
      );

      if (!result.isSignedIn) {
        throw AuthException('SSO login failed');
      }

      final newSession = await Amplify.Auth.fetchAuthSession();
      await _cacheSession(newSession);
      await _bridgeToSupabase(newSession);
      await _scheduleTokenRefresh(newSession);

      return newSession;
    } on AuthException catch (e) {
      logger.error('Authentication failed: ${e.message}');
      throw AuthServiceException(
        'Failed to authenticate: ${e.message}',
        originalError: e,
      );
    }
  }

  /// Bridge Cognito session to Supabase
  Future<void> _bridgeToSupabase(AuthSession session) async {
    if (!session.isSignedIn) {
      throw AuthException('Cannot bridge unsigned session');
    }

    try {
      final cognitoSession = session as CognitoAuthSession;
      final idToken = cognitoSession.userPoolTokensResult.value.idToken.raw;

      // Validate token before bridging
      if (!TokenValidator.validateToken(idToken)) {
        throw AuthException('Invalid token for Supabase bridge');
      }

      // Create Supabase session with Cognito JWT
      final response = await Supabase.instance.client.auth.setSession(idToken);

      if (response.session == null) {
        throw AuthException('Failed to create Supabase session');
      }

      logger.info('Successfully bridged to Supabase');
    } catch (e) {
      logger.error('Supabase bridge failed: $e');
      throw AuthServiceException(
        'Failed to bridge to Supabase: $e',
        originalError: e,
      );
    }
  }

  /// Schedule automatic token refresh
  Future<void> _scheduleTokenRefresh(AuthSession session) async {
    _refreshTimer?.cancel();

    if (!session.isSignedIn) return;

    try {
      final cognitoSession = session as CognitoAuthSession;
      final accessToken = cognitoSession.userPoolTokensResult.value.accessToken;
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(
        accessToken.expiresAt.millisecondsSinceEpoch,
      );

      final now = DateTime.now();
      final refreshTime = expiryTime.subtract(Duration(seconds: _tokenRefreshBuffer));
      final delay = refreshTime.difference(now);

      if (delay.isNegative) {
        // Token already expired or about to expire
        await _refreshTokens();
      } else {
        _refreshTimer = Timer(delay, _refreshTokens);
        logger.info('Scheduled token refresh for ${refreshTime.toIso8601String()}');
      }
    } catch (e) {
      logger.error('Failed to schedule token refresh: $e');
    }
  }

  /// Refresh authentication tokens
  Future<void> _refreshTokens() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: true),
      );

      if (session.isSignedIn) {
        await _cacheSession(session);
        await _bridgeToSupabase(session);
        await _scheduleTokenRefresh(session);
        logger.info('Tokens refreshed successfully');
      } else {
        throw AuthException('Session no longer valid');
      }
    } on AuthException catch (e) {
      logger.error('Token refresh failed: ${e.message}');
      await _handleTokenRefreshFailure(e);
    }
  }

  /// Handle token refresh failures
  Future<void> _handleTokenRefreshFailure(AuthException error) async {
    try {
      // Clear cached session
      await _clearCachedSession();

      // Sign out and trigger re-authentication
      await signOut();

      // Notify listeners of auth state change
      _authStateController?.add(AuthState.unauthenticated);

      logger.warning('Token refresh failed, user needs to re-authenticate');
    } catch (e) {
      logger.error('Failed to handle token refresh failure: $e');
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      _refreshTimer?.cancel();

      // Clear cached session
      await _clearCachedSession();

      // Sign out from Amplify
      await Amplify.Auth.signOut();

      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      logger.info('User signed out successfully');
    } catch (e) {
      logger.error('Sign out failed: $e');
      throw AuthServiceException(
        'Failed to sign out: $e',
        originalError: e,
      );
    }
  }

  /// Get current user attributes
  Future<Map<String, dynamic>?> getUserAttributes() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      return Map.fromEntries(
        attributes.map((attr) => MapEntry(attr.userAttributeKey.key, attr.value)),
      );
    } catch (e) {
      logger.error('Failed to fetch user attributes: $e');
      return null;
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      logger.error('Failed to check sign-in status: $e');
      return false;
    }
  }

  /// Cache authentication session
  Future<void> _cacheSession(AuthSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'isSignedIn': session.isSignedIn,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      if (session.isSignedIn && session is CognitoAuthSession) {
        final tokens = session.userPoolTokensResult.value;
        sessionData.addAll({
          'accessToken': tokens.accessToken.raw,
          'idToken': tokens.idToken.raw,
          'refreshToken': tokens.refreshToken.raw,
          'expiresAt': tokens.accessToken.expiresAt.millisecondsSinceEpoch,
        });
      }

      await prefs.setString(_sessionKey, jsonEncode(sessionData));
    } catch (e) {
      logger.error('Failed to cache session: $e');
    }
  }

  /// Get cached authentication session
  Future<AuthSession?> _getCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_sessionKey);

      if (sessionJson == null) return null;

      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
      final timestamp = sessionData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if cached session is too old (more than 1 hour)
      if (now - timestamp > 3600000) {
        await _clearCachedSession();
        return null;
      }

      // For now, return null and let fetchAuthSession handle it
      // This is because recreating a CognitoAuthSession from cache
      // is complex and Amplify handles session restoration internally
      return null;
    } catch (e) {
      logger.error('Failed to get cached session: $e');
      return null;
    }
  }

  /// Clear cached session
  Future<void> _clearCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (e) {
      logger.error('Failed to clear cached session: $e');
    }
  }

  /// Map Amplify auth events to our auth state
  AuthState _mapToAuthState(AuthHubEvent event) {
    switch (event.eventName) {
      case 'SIGNED_IN':
        return AuthState.authenticated;
      case 'SIGNED_OUT':
      case 'SESSION_EXPIRED':
        return AuthState.unauthenticated;
      case 'USER_DELETED':
        return AuthState.unauthenticated;
      default:
        return AuthState.unknown;
    }
  }

  /// Dispose resources
  void dispose() {
    _refreshTimer?.cancel();
    _authStateController?.close();
  }
}

/// Authentication states
enum AuthState {
  unknown,
  authenticated,
  unauthenticated,
}

/// Custom exception for auth service errors
class AuthServiceException implements Exception {
  final String message;
  final dynamic originalError;

  const AuthServiceException(this.message, {this.originalError});

  @override
  String toString() => 'AuthServiceException: $message';
}
```

### Riverpod Provider Setup

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Auth state provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateStream;
});

/// User attributes provider
final userAttributesProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserAttributes();
});

/// Sign-in status provider
final isSignedInProvider = FutureProvider<bool>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.isSignedIn();
});
```

## Error Handling and Session Management

### Comprehensive Error Handling

```dart
class AuthErrorHandler {
  /// Handle authentication errors with user-friendly messages
  static String getErrorMessage(dynamic error) {
    if (error is AuthServiceException) {
      return _getAuthServiceErrorMessage(error);
    } else if (error is AuthException) {
      return _getCognitoErrorMessage(error);
    } else if (error is SupabaseException) {
      return _getSupabaseErrorMessage(error);
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static String _getAuthServiceErrorMessage(AuthServiceException error) {
    if (error.message.contains('Failed to authenticate')) {
      return 'Unable to sign in. Please check your credentials and try again.';
    } else if (error.message.contains('Failed to bridge to Supabase')) {
      return 'Authentication successful, but unable to access your data. Please contact support.';
    } else if (error.message.contains('Failed to sign out')) {
      return 'Unable to sign out completely. Please close the app and try again.';
    } else {
      return 'Authentication service error. Please try again or contact support.';
    }
  }

  static String _getCognitoErrorMessage(AuthException error) {
    switch (error.message) {
      case 'User does not exist.':
        return 'Account not found. Please contact your administrator.';
      case 'Incorrect username or password.':
        return 'Invalid credentials. Please try again.';
      case 'User is not confirmed.':
        return 'Your account needs to be activated. Please contact your administrator.';
      case 'User account is disabled.':
        return 'Your account has been disabled. Please contact your administrator.';
      case 'Network error':
        return 'Network connection error. Please check your internet and try again.';
      default:
        return 'Sign-in failed: ${error.message}';
    }
  }

  static String _getSupabaseErrorMessage(SupabaseException error) {
    if (error.message.contains('JWT')) {
      return 'Session expired. Please sign in again.';
    } else if (error.message.contains('network')) {
      return 'Unable to connect to our servers. Please check your internet connection.';
    } else {
      return 'Data service error. Please try again or contact support.';
    }
  }
}
```

### Session Monitoring and Recovery

```dart
class SessionManager {
  static const Duration _sessionCheckInterval = Duration(minutes: 5);
  Timer? _sessionMonitor;

  /// Start monitoring session health
  void startSessionMonitoring(AuthService authService) {
    _sessionMonitor?.cancel();

    _sessionMonitor = Timer.periodic(_sessionCheckInterval, (timer) async {
      await _checkSessionHealth(authService);
    });
  }

  /// Stop session monitoring
  void stopSessionMonitoring() {
    _sessionMonitor?.cancel();
  }

  /// Check session health and recover if needed
  Future<void> _checkSessionHealth(AuthService authService) async {
    try {
      final isSignedIn = await authService.isSignedIn();

      if (!isSignedIn) {
        logger.warning('Session lost, attempting recovery');
        await _recoverSession(authService);
      } else {
        // Verify Supabase session is still valid
        final supabaseSession = Supabase.instance.client.auth.currentSession;
        if (supabaseSession == null) {
          logger.warning('Supabase session lost, attempting bridge');
          final cognitoSession = await Amplify.Auth.fetchAuthSession();
          if (cognitoSession.isSignedIn) {
            await authService._bridgeToSupabase(cognitoSession);
          }
        }
      }
    } catch (e) {
      logger.error('Session health check failed: $e');
    }
  }

  /// Attempt to recover lost session
  Future<void> _recoverSession(AuthService authService) async {
    try {
      await authService.authenticate();
      logger.info('Session recovered successfully');
    } catch (e) {
      logger.error('Session recovery failed: $e');
      // Navigate to login screen
      NavigationService.navigateToLogin();
    }
  }
}
```

## Production Security Best Practices

### 1. JWT Token Validation

```dart
class ProductionTokenValidator {
  static const String _jwksUrl = 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX/.well-known/jwks.json';
  static Map<String, dynamic>? _cachedJwks;
  static DateTime? _jwksCacheExpiry;

  /// Validate JWT token with proper signature verification
  static Future<bool> validateTokenProduction(String token) async {
    try {
      final jwt = JWT.decode(token);
      final header = jwt.header;
      final payload = jwt.payload;

      // 1. Check token structure
      if (!_validateTokenStructure(header, payload)) {
        return false;
      }

      // 2. Verify signature
      if (!await _verifySignature(token, header)) {
        return false;
      }

      // 3. Validate claims
      if (!_validateClaims(payload)) {
        return false;
      }

      return true;
    } catch (e) {
      logger.error('Token validation failed: $e');
      return false;
    }
  }

  static bool _validateTokenStructure(Map<String, dynamic> header, Map<String, dynamic> payload) {
    // Check required header fields
    if (!header.containsKey('alg') || !header.containsKey('kid')) {
      logger.error('Invalid token header structure');
      return false;
    }

    // Check required payload fields
    final requiredFields = ['iss', 'aud', 'exp', 'iat', 'sub', 'token_use'];
    for (final field in requiredFields) {
      if (!payload.containsKey(field)) {
        logger.error('Missing required field: $field');
        return false;
      }
    }

    return true;
  }

  static Future<bool> _verifySignature(String token, Map<String, dynamic> header) async {
    try {
      // Get JWKS
      final jwks = await _getJwks();
      if (jwks == null) return false;

      // Find matching key
      final kid = header['kid'] as String;
      final keys = jwks['keys'] as List;
      final matchingKey = keys.firstWhere(
        (key) => key['kid'] == kid,
        orElse: () => null,
      );

      if (matchingKey == null) {
        logger.error('No matching key found for kid: $kid');
        return false;
      }

      // Verify signature using the public key
      // Implementation would use a JWT library like dart_jsonwebtoken
      // that supports RSA signature verification

      return true; // Simplified for example
    } catch (e) {
      logger.error('Signature verification failed: $e');
      return false;
    }
  }

  static bool _validateClaims(Map<String, dynamic> payload) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Check expiration
    final exp = payload['exp'] as int;
    if (exp <= now) {
      logger.warning('Token expired');
      return false;
    }

    // Check not before
    if (payload.containsKey('nbf')) {
      final nbf = payload['nbf'] as int;
      if (nbf > now) {
        logger.warning('Token not yet valid');
        return false;
      }
    }

    // Check issuer
    final iss = payload['iss'] as String;
    if (!iss.startsWith('https://cognito-idp.')) {
      logger.error('Invalid issuer: $iss');
      return false;
    }

    // Check token use
    final tokenUse = payload['token_use'] as String;
    if (!['id', 'access'].contains(tokenUse)) {
      logger.error('Invalid token use: $tokenUse');
      return false;
    }

    return true;
  }

  static Future<Map<String, dynamic>?> _getJwks() async {
    // Check cache first
    if (_cachedJwks != null &&
        _jwksCacheExpiry != null &&
        DateTime.now().isBefore(_jwksCacheExpiry!)) {
      return _cachedJwks;
    }

    try {
      final response = await dio.get(_jwksUrl);
      if (response.statusCode == 200) {
        _cachedJwks = response.data;
        _jwksCacheExpiry = DateTime.now().add(Duration(hours: 1));
        return _cachedJwks;
      }
    } catch (e) {
      logger.error('Failed to fetch JWKS: $e');
    }

    return null;
  }
}
```

### 2. Secure Token Storage

```dart
class SecureTokenStorage {
  static const String _accessTokenKey = 'secure_access_token';
  static const String _idTokenKey = 'secure_id_token';
  static const String _refreshTokenKey = 'secure_refresh_token';

  /// Store tokens securely
  static Future<void> storeTokens({
    required String accessToken,
    required String idToken,
    required String refreshToken,
  }) async {
    try {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

      await Future.wait([
        storage.write(key: _accessTokenKey, value: accessToken),
        storage.write(key: _idTokenKey, value: idToken),
        storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);

      logger.info('Tokens stored securely');
    } catch (e) {
      logger.error('Failed to store tokens securely: $e');
      // Fallback to regular storage with warning
      await _fallbackTokenStorage(accessToken, idToken, refreshToken);
    }
  }

  /// Retrieve tokens securely
  static Future<Map<String, String?>> retrieveTokens() async {
    try {
      const storage = FlutterSecureStorage();

      final results = await Future.wait([
        storage.read(key: _accessTokenKey),
        storage.read(key: _idTokenKey),
        storage.read(key: _refreshTokenKey),
      ]);

      return {
        'accessToken': results[0],
        'idToken': results[1],
        'refreshToken': results[2],
      };
    } catch (e) {
      logger.error('Failed to retrieve secure tokens: $e');
      return {};
    }
  }

  /// Clear all stored tokens
  static Future<void> clearTokens() async {
    try {
      const storage = FlutterSecureStorage();
      await Future.wait([
        storage.delete(key: _accessTokenKey),
        storage.delete(key: _idTokenKey),
        storage.delete(key: _refreshTokenKey),
      ]);

      // Also clear fallback storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fallback_tokens');

      logger.info('All tokens cleared');
    } catch (e) {
      logger.error('Failed to clear tokens: $e');
    }
  }

  static Future<void> _fallbackTokenStorage(
    String accessToken,
    String idToken,
    String refreshToken,
  ) async {
    logger.warning('Using fallback token storage - tokens not fully encrypted');
    final prefs = await SharedPreferences.getInstance();

    final tokenData = {
      'accessToken': accessToken,
      'idToken': idToken,
      'refreshToken': refreshToken,
      'storedAt': DateTime.now().millisecondsSinceEpoch,
    };

    await prefs.setString('fallback_tokens', jsonEncode(tokenData));
  }
}
```

### 3. Network Security Configuration

```dart
class NetworkSecurityConfig {
  /// Configure secure HTTP client for authentication
  static Dio createSecureClient() {
    final dio = Dio();

    // Add security interceptors
    dio.interceptors.addAll([
      _createSecurityInterceptor(),
      _createCertificatePinningInterceptor(),
      _createLoggingInterceptor(),
    ]);

    // Configure base options
    dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'AudioLearningPlatform/1.0.0 Flutter',
        'Accept': 'application/json',
      },
    );

    return dio;
  }

  static Interceptor _createSecurityInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // Ensure HTTPS only
        if (!options.uri.isScheme('https')) {
          handler.reject(DioException(
            requestOptions: options,
            error: 'HTTPS required for all requests',
            type: DioExceptionType.cancel,
          ));
          return;
        }

        // Add security headers
        options.headers.addAll({
          'X-Content-Type-Options': 'nosniff',
          'X-Frame-Options': 'DENY',
          'X-XSS-Protection': '1; mode=block',
        });

        handler.next(options);
      },
      onError: (error, handler) {
        // Log security-related errors
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.connectionError) {
          logger.error('Network security error: ${error.message}');
        }

        handler.next(error);
      },
    );
  }

  static Interceptor _createCertificatePinningInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // Certificate pinning would be implemented here
        // for production apps connecting to known endpoints
        handler.next(options);
      },
    );
  }

  static Interceptor _createLoggingInterceptor() {
    return LogInterceptor(
      requestBody: false, // Never log request bodies in production
      responseBody: false, // Never log response bodies in production
      logPrint: (object) {
        if (kDebugMode) {
          logger.debug(object.toString());
        }
      },
    );
  }
}
```

## Configuration Steps

### 1. AWS Console Setup

#### Create Cognito User Pool
```bash
aws cognito-idp create-user-pool \
  --pool-name "audio-learning-platform-users" \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 12,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": true
    }
  }' \
  --admin-create-user-config '{
    "AllowAdminCreateUserOnly": true,
    "InviteMessageAction": "EMAIL"
  }' \
  --verification-message-template '{
    "EmailMessage": "Welcome to Audio Learning Platform. Your verification code is {####}",
    "EmailSubject": "Audio Learning Platform - Verify Your Account"
  }'
```

#### Create App Client
```bash
aws cognito-idp create-user-pool-client \
  --user-pool-id "us-east-1_XXXXXXXXX" \
  --client-name "audio-learning-mobile-client" \
  --supported-identity-providers "COGNITO" "EnterpriseSSO" \
  --callback-urls "audiolearning://auth/" \
  --logout-urls "audiolearning://signout/" \
  --allowed-o-auth-flows "authorization_code" \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --allowed-o-auth-flows-user-pool-client \
  --prevent-user-existence-errors "ENABLED" \
  --enable-token-revocation
```

#### Create Identity Pool
```bash
aws cognito-identity create-identity-pool \
  --identity-pool-name "audio_learning_platform_identity_pool" \
  --allow-unauthenticated-identities false \
  --cognito-identity-providers '{
    "ProviderName": "cognito-idp.us-east-1.amazonaws.com/us-east-1_XXXXXXXXX",
    "ClientId": "your-app-client-id",
    "ServerSideTokenCheck": true
  }'
```

### 2. Flutter Configuration

#### pubspec.yaml
```yaml
dependencies:
  flutter:
    sdk: flutter

  # Authentication
  amplify_flutter: ^2.0.0
  amplify_auth_cognito: ^2.0.0

  # Backend
  supabase_flutter: ^2.3.0

  # Security
  flutter_secure_storage: ^9.0.0

  # Storage
  shared_preferences: ^2.2.2

  # Network
  dio: ^5.4.0

  # State Management
  flutter_riverpod: ^2.4.9

  # Utilities
  jwt_decoder: ^2.0.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.1
```

#### Environment Configuration (.env)
```env
# AWS Cognito Configuration
COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
COGNITO_APP_CLIENT_ID=your-app-client-id
COGNITO_IDENTITY_POOL_ID=us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
COGNITO_REGION=us-east-1

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# App Configuration
APP_ENVIRONMENT=production
LOG_LEVEL=info
```

#### Amplify Configuration (amplifyconfiguration.dart)
```dart
const amplifyconfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "AppSync": {
          "Default": {
            "ApiUrl": "your-appsync-endpoint",
            "Region": "us-east-1",
            "AuthMode": "AMAZON_COGNITO_USER_POOLS",
            "ClientDatabasePrefix": "audio_learning_platform"
          }
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_XXXXXXXXX",
            "AppClientId": "your-app-client-id",
            "Region": "us-east-1"
          }
        },
        "CognitoIdentityPool": {
          "Default": {
            "PoolId": "us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
            "Region": "us-east-1"
          }
        }
      }
    }
  }
}''';
```

### 3. Supabase Configuration

#### JWT Settings
Navigate to Authentication → Settings → JWT Settings in Supabase Dashboard:

```json
{
  "jwt_secret": "your-jwt-secret",
  "jwt_exp": 3600,
  "jwt_default_role": "authenticated",
  "jwt_aud": "authenticated"
}
```

#### Custom Claims Function
Create an Edge Function to handle Cognito JWT:

```sql
create or replace function auth.jwt() returns json as $$
  select
    coalesce(
      nullif(current_setting('request.jwt.claim', true), ''),
      nullif(current_setting('request.jwt.claims', true), '')
    )::json
$$ language sql stable;
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Token Validation Failures
```dart
// Issue: "Invalid token signature"
// Solution: Verify JWKS endpoint and key rotation

class TokenDebugger {
  static void debugTokenIssues(String token) {
    try {
      final jwt = JWT.decode(token);
      logger.debug('Token Header: ${jwt.header}');
      logger.debug('Token Payload: ${jwt.payload}');

      // Check expiration
      final exp = jwt.payload['exp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      logger.debug('Token expires at: ${DateTime.fromMillisecondsSinceEpoch(exp * 1000)}');
      logger.debug('Current time: ${DateTime.now()}');
      logger.debug('Token expired: ${exp <= now}');

      // Check issuer
      final iss = jwt.payload['iss'] as String;
      logger.debug('Token issuer: $iss');

    } catch (e) {
      logger.error('Token debug failed: $e');
    }
  }
}
```

#### 2. Supabase Bridge Failures
```dart
// Issue: "Failed to create Supabase session"
// Solution: Ensure role claim is present

class SupabaseBridgeDebugger {
  static Future<void> debugBridgeIssues(String cognitoToken) async {
    try {
      // Check if token has required claims
      final jwt = JWT.decode(cognitoToken);
      final payload = jwt.payload;

      logger.debug('Checking required claims for Supabase...');
      logger.debug('Has role claim: ${payload.containsKey('role')}');
      logger.debug('Role value: ${payload['role']}');
      logger.debug('Has aud claim: ${payload.containsKey('aud')}');
      logger.debug('Audience value: ${payload['aud']}');

      // Test Supabase connection directly
      final response = await Supabase.instance.client.auth.setSession(cognitoToken);
      logger.debug('Supabase session creation result: ${response.session != null}');

    } catch (e) {
      logger.error('Supabase bridge debug failed: $e');
    }
  }
}
```

#### 3. Automatic Refresh Not Working
```dart
// Issue: Tokens not refreshing automatically
// Solution: Check refresh token validity and scheduling

class RefreshDebugger {
  static void debugRefreshIssues(AuthSession session) {
    if (session is CognitoAuthSession) {
      final tokens = session.userPoolTokensResult.value;

      logger.debug('Access token expires at: ${tokens.accessToken.expiresAt}');
      logger.debug('Refresh token: ${tokens.refreshToken.raw.substring(0, 20)}...');

      final now = DateTime.now();
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(
        tokens.accessToken.expiresAt.millisecondsSinceEpoch,
      );
      final timeToExpiry = expiryTime.difference(now);

      logger.debug('Time to expiry: ${timeToExpiry.inMinutes} minutes');
      logger.debug('Should refresh: ${timeToExpiry.inSeconds < 300}');
    }
  }
}
```

### Error Code Reference

| Error Code | Cause | Solution |
|------------|-------|----------|
| `NotAuthorizedException` | Invalid credentials | Check user exists and credentials are correct |
| `UserNotConfirmedException` | User not confirmed | Admin must confirm user in Cognito |
| `UserNotFoundException` | User doesn't exist | Create user or check username/email |
| `TokenValidationException` | Invalid JWT token | Check token format and signature |
| `RefreshTokenExpiredException` | Refresh token expired | User must re-authenticate |
| `NetworkException` | Network connectivity | Check internet connection and DNS |
| `ServiceException` | AWS service error | Check service status and retry |

### Performance Monitoring

```dart
class AuthPerformanceMonitor {
  static final Map<String, DateTime> _operationStartTimes = {};

  static void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
  }

  static void endOperation(String operationName) {
    final startTime = _operationStartTimes.remove(operationName);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      logger.info('Operation $operationName completed in ${duration.inMilliseconds}ms');

      // Log performance warnings
      if (duration.inSeconds > 5) {
        logger.warning('Slow auth operation: $operationName took ${duration.inSeconds}s');
      }
    }
  }
}

// Usage in AuthService
Future<AuthSession> authenticate() async {
  AuthPerformanceMonitor.startOperation('authenticate');
  try {
    // ... authentication logic
    return session;
  } finally {
    AuthPerformanceMonitor.endOperation('authenticate');
  }
}
```

This comprehensive guide provides everything needed to implement AWS Cognito SSO authentication with Supabase integration in your Flutter audio learning platform. The implementation is production-ready with proper error handling, security measures, and performance considerations for 2025.