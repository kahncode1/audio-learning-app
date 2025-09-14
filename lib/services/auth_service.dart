/// AWS Cognito Authentication Service
///
/// Purpose: Manages authentication with AWS Cognito SSO
/// Dependencies:
///   - amplify_flutter: AWS SDK
///   - amplify_auth_cognito: Cognito authentication
///   - shared_preferences: Session caching
///
/// Usage:
///   final authService = AuthService();
///   await authService.configureAmplify();
///   final user = await authService.authenticate();
///
/// Expected behavior:
///   - Configures Amplify with Cognito settings
///   - Handles SSO authentication flow
///   - Manages token refresh and session persistence
///   - Bridges to Supabase via JWT tokens

import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' as amplify;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../config/app_config.dart';
import 'auth/auth_service_interface.dart';

class AuthService implements AuthServiceInterface {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isConfigured = false;
  Timer? _refreshTimer;
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();

  /// Stream of authentication state changes (internal)
  Stream<AuthState> get _authStateStream => _authStateController.stream;

  /// Check if Amplify is configured
  bool get isConfigured => _isConfigured;

  @override
  Future<void> initialize() async {
    await configureAmplify();
  }

  /// Configure Amplify with Cognito
  Future<void> configureAmplify() async {
    if (_isConfigured) {
      safePrint('Amplify already configured');
      return;
    }

    try {
      // Create Cognito plugin
      final authPlugin = AmplifyAuthCognito();

      // Add plugin to Amplify
      await Amplify.addPlugins([authPlugin]);

      // Configure Amplify with app configuration
      final config = AppConfig();
      await Amplify.configure(config.amplifyConfig);

      _isConfigured = true;
      safePrint('Amplify configured successfully');

      // Set up auth state listener
      _setupAuthStateListener();

      // Set up token refresh
      _setupTokenRefresh();
    } catch (e) {
      safePrint('Error configuring Amplify: $e');
      rethrow;
    }
  }

  /// Authenticate user via SSO
  Future<AuthUser?> authenticate() async {
    try {
      // Check if already signed in
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        return await getCurrentUser();
      }

      // Start SSO sign in flow
      final result = await Amplify.Auth.signInWithWebUI(
        provider: const AuthProvider.saml('YourSSOProvider'),
      );

      if (result.isSignedIn) {
        final user = await getCurrentUser();
        await _cacheUserSession();
        _authStateController.add(AuthState.authenticated);
        return user;
      }

      return null;
    } catch (e) {
      safePrint('Authentication error: $e');
      _authStateController.add(AuthState.unauthenticated);
      rethrow;
    }
  }

  @override
  Future<amplify.SignInResult> signIn(String email, String password) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        await _cacheUserSession();
        _authStateController.add(AuthState.authenticated);
        return const amplify.SignInResult(
          isSignedIn: true,
          nextStep: amplify.AuthNextSignInStep(
            signInStep: amplify.AuthSignInStep.done,
          ),
        );
      }

      return const amplify.SignInResult(
        isSignedIn: false,
        nextStep: amplify.AuthNextSignInStep(
          signInStep: amplify.AuthSignInStep.done,
        ),
      );
    } on AuthException catch (e) {
      safePrint('Sign in error: ${e.message}');
      _authStateController.add(AuthState.unauthenticated);
      rethrow;
    }
  }

  /// Sign in with username and password (for testing)
  Future<AuthUser?> signInWithCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final result = await signIn(email, password);
      if (result.isSignedIn) {
        return await getCurrentUser();
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<amplify.AuthUser?> getCurrentUser() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user;
    } catch (e) {
      safePrint('Error getting current user: $e');
      return null;
    }
  }

  /// Get user attributes
  Future<Map<String, String>> getUserAttributes() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final Map<String, String> attributeMap = {};

      for (final attribute in attributes) {
        attributeMap[attribute.userAttributeKey.key] = attribute.value;
      }

      return attributeMap;
    } catch (e) {
      safePrint('Error fetching user attributes: $e');
      return {};
    }
  }

  /// Get current session with tokens
  Future<CognitoAuthSession?> getSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      if (session.isSignedIn) {
        return session;
      }

      return null;
    } catch (e) {
      safePrint('Error fetching session: $e');
      return null;
    }
  }

  @override
  Future<String?> getJwtToken() async {
    return await getIdToken();
  }

  /// Get ID token for Supabase bridging
  Future<String?> getIdToken() async {
    try {
      final session = await getSession();
      if (session != null && session.userPoolTokensResult.value != null) {
        return session.userPoolTokensResult.value!.idToken.raw;
      }
      return null;
    } catch (e) {
      safePrint('Error getting ID token: $e');
      return null;
    }
  }

  /// Get access token
  Future<String?> getAccessToken() async {
    try {
      final session = await getSession();
      if (session != null && session.userPoolTokensResult.value != null) {
        return session.userPoolTokensResult.value!.accessToken.raw;
      }
      return null;
    } catch (e) {
      safePrint('Error getting access token: $e');
      return null;
    }
  }

  @override
  Future<void> refreshTokens() async {
    await refreshSession();
  }

  /// Refresh session tokens
  Future<bool> refreshSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: true),
      );

      if (session.isSignedIn) {
        await _cacheUserSession();
        return true;
      }

      return false;
    } catch (e) {
      safePrint('Error refreshing session: $e');
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      await _clearCachedSession();
      _authStateController.add(AuthState.unauthenticated);
      _refreshTimer?.cancel();
      safePrint('User signed out successfully');
    } catch (e) {
      safePrint('Error signing out: $e');
    }
  }

  @override
  Future<bool> isSignedIn() async {
    return await isAuthenticated();
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      return false;
    }
  }

  /// Create User model from Cognito data
  Future<User?> createUserFromCognito() async {
    try {
      final cognitoUser = await getCurrentUser();
      if (cognitoUser == null) return null;

      final attributes = await getUserAttributes();

      return User.fromCognitoAttributes(
        sub: cognitoUser.userId,
        email: attributes['email'] ?? '',
        name: attributes['name'],
        organization: attributes['custom:organization'],
      );
    } catch (e) {
      safePrint('Error creating user from Cognito: $e');
      return null;
    }
  }

  // Private helper methods

  void _setupAuthStateListener() {
    Amplify.Hub.listen(HubChannel.Auth, (event) {
      switch (event.eventName) {
        case 'SIGNED_IN':
          _authStateController.add(AuthState.authenticated);
          break;
        case 'SIGNED_OUT':
        case 'SESSION_EXPIRED':
          _authStateController.add(AuthState.unauthenticated);
          break;
        case 'USER_DELETED':
          _authStateController.add(AuthState.unauthenticated);
          break;
      }
    });
  }

  void _setupTokenRefresh() {
    // Refresh tokens every 50 minutes (for 1-hour tokens)
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 50), (timer) async {
      if (await isAuthenticated()) {
        await refreshSession();
      }
    });
  }

  Future<void> _cacheUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final session = await getSession();

      if (session != null) {
        await prefs.setString('cached_user_id', session.identityIdResult.value ?? '');
        await prefs.setInt('session_cached_at', DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      safePrint('Error caching session: $e');
    }
  }

  Future<void> _clearCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_id');
      await prefs.remove('session_cached_at');
    } catch (e) {
      safePrint('Error clearing cached session: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _authStateController.close();
  }

  @override
  Stream<bool> get authStateChanges => _authStateStream.map(
    (state) => state == AuthState.authenticated
  );
}

/// Authentication state enum
enum AuthState {
  authenticated,
  unauthenticated,
  unknown,
}

/// Validation function to verify AuthService implementation
void validateAuthService() {

  final authService = AuthService();

  // Test singleton pattern
  final authService2 = AuthService();
  assert(identical(authService, authService2));

  // Test initial state
  assert(authService.isConfigured == false);

}