/// Cognito Authentication Service Implementation
///
/// Provides AWS Cognito OAuth authentication with PKCE flow
/// and JWT token bridging to Supabase for backend integration.
///
/// Configuration:
/// - Uses hosted UI for enterprise SSO authentication
/// - Implements Authorization Code + PKCE flow
/// - Bridges Cognito JWT tokens to Supabase sessions

import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' as amplify;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../../config/amplifyconfiguration.dart';
import '../../utils/app_logger.dart';
import 'auth_service_interface.dart';

class CognitoAuthService implements AuthServiceInterface {
  static CognitoAuthService? _instance;
  StreamController<bool>? _authStateController;
  Timer? _refreshTimer;

  CognitoAuthService._internal();

  factory CognitoAuthService() {
    _instance ??= CognitoAuthService._internal();
    return _instance!;
  }

  @override
  Stream<bool> get authStateChanges =>
      _authStateController?.stream ?? const Stream.empty();

  @override
  Future<void> initialize() async {
    try {
      // Initialize auth state stream
      _authStateController = StreamController<bool>.broadcast();

      // Configure Amplify if not already configured
      if (!Amplify.isConfigured) {
        final authPlugin = amplify.AmplifyAuthCognito();
        await Amplify.addPlugin(authPlugin);
        await Amplify.configure(amplifyconfig);

        // Set up auth hub listener
        Amplify.Hub.listen(HubChannel.Auth, (event) {
          switch (event.eventName) {
            case 'SIGNED_IN':
              _authStateController?.add(true);
              _bridgeToSupabase();
              break;
            case 'SIGNED_OUT':
            case 'SESSION_EXPIRED':
              _authStateController?.add(false);
              _clearSupabaseSession();
              break;
          }
        });
      }

      // Check current auth status
      final session = await Amplify.Auth.fetchAuthSession();
      _authStateController?.add(session.isSignedIn);

      if (session.isSignedIn) {
        await _bridgeToSupabase();
        _scheduleTokenRefresh();
      }

      AppLogger.info('CognitoAuthService initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize CognitoAuthService', error: e);
      throw Exception('Authentication initialization failed: $e');
    }
  }

  @override
  Future<amplify.SignInResult> signIn(String email, String password) async {
    try {
      // For OAuth flow, we use the hosted UI instead of direct sign-in
      // This method triggers the OAuth flow with PKCE
      final result = await Amplify.Auth.signInWithWebUI(
        provider: amplify.AuthProvider.cognito,
        options: const amplify.SignInWithWebUIOptions(
          pluginOptions: amplify.CognitoSignInWithWebUIPluginOptions(
            isPreferPrivateSession: false,
          ),
        ),
      );

      if (result.isSignedIn) {
        await _bridgeToSupabase();
        _scheduleTokenRefresh();
      }

      return result;
    } on amplify.AuthException catch (e) {
      AppLogger.error('Sign in failed: ${e.message}', error: e);
      throw e;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      _refreshTimer?.cancel();

      // Sign out from Amplify (will trigger OAuth logout redirect)
      await Amplify.Auth.signOut();

      // Clear Supabase session
      await _clearSupabaseSession();

      _authStateController?.add(false);
      AppLogger.info('User signed out successfully');
    } catch (e) {
      AppLogger.error('Sign out failed', error: e);
      throw Exception('Sign out failed: $e');
    }
  }

  @override
  Future<amplify.AuthUser?> getCurrentUser() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user;
    } catch (e) {
      // No current user - this is expected when not logged in
      return null;
    }
  }

  @override
  Future<bool> isSignedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      AppLogger.warning('Failed to check sign-in status');
      return false;
    }
  }

  @override
  Future<amplify.AuthSession?> getCurrentSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session;
    } catch (e) {
      AppLogger.warning('Failed to get current session');
      return null;
    }
  }

  @override
  Future<String?> getJwtToken() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as amplify.CognitoAuthSession;
      if (!session.isSignedIn) return null;

      final idToken = session.userPoolTokensResult.value.idToken.raw;
      return idToken;
    } catch (e) {
      AppLogger.warning('Failed to get JWT token');
      return null;
    }
  }

  @override
  Future<void> refreshTokens() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: const amplify.FetchAuthSessionOptions(forceRefresh: true),
      );

      if (session.isSignedIn) {
        await _bridgeToSupabase();
        _scheduleTokenRefresh();
        AppLogger.info('Tokens refreshed successfully');
      }
    } on amplify.AuthException catch (e) {
      AppLogger.error('Token refresh failed: ${e.message}', error: e);
      // If refresh fails, user needs to re-authenticate
      await signOut();
      throw e;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _authStateController?.close();
    _instance = null;
  }

  /// Bridge Cognito JWT token to Supabase session
  Future<void> _bridgeToSupabase() async {
    try {
      final idToken = await getJwtToken();
      if (idToken == null) {
        AppLogger.warning('No JWT token available for Supabase bridge');
        return;
      }

      // Set the Authorization header for Supabase client
      // This approach works with Supabase's JWT settings configured for Cognito
      // The JWT will be validated using the JWKS endpoint we configured
      supa.Supabase.instance.client.headers['Authorization'] =
          'Bearer $idToken';

      // Test the JWT by making a simple query to verify it works
      try {
        // Try to query user profile to verify JWT is working
        await supa.Supabase.instance.client
            .from('user_profiles')
            .select('id')
            .limit(1)
            .maybeSingle();

        AppLogger.info('Successfully bridged to Supabase with JWT');

        // Sync user profile data
        await _syncUserProfile();
      } catch (e) {
        AppLogger.warning('JWT validation failed: $e');
        // Clear the header if validation fails
        supa.Supabase.instance.client.headers.remove('Authorization');
        throw e;
      }
    } catch (e) {
      AppLogger.warning('Supabase bridge failed: $e');
      // Don't throw - allow app to work even if Supabase bridge fails
    }
  }

  /// Clear Supabase session
  Future<void> _clearSupabaseSession() async {
    try {
      // Remove the Authorization header when signing out
      supa.Supabase.instance.client.headers.remove('Authorization');
      AppLogger.info('Supabase session cleared');
    } catch (e) {
      AppLogger.warning('Failed to clear Supabase session: $e');
    }
  }

  /// Sync user profile to Supabase
  Future<void> _syncUserProfile() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return;

      // Get user attributes
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final email = attributes
          .firstWhere((attr) => attr.userAttributeKey.key == 'email')
          .value;
      final name = attributes
          .firstWhere(
            (attr) => attr.userAttributeKey.key == 'name',
            orElse: () => const amplify.AuthUserAttribute(
              userAttributeKey: amplify.AuthUserAttributeKey.name,
              value: 'Unknown User',
            ),
          )
          .value;

      // Upsert user profile in Supabase
      await supa.Supabase.instance.client.from('user_profiles').upsert({
        'id': user.userId,
        'email': email,
        'full_name': name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger.info('User profile synced to Supabase');
    } catch (e) {
      AppLogger.warning('Failed to sync user profile: $e');
      // Don't throw - this is not critical for app functionality
    }
  }

  /// Schedule automatic token refresh
  void _scheduleTokenRefresh() {
    _refreshTimer?.cancel();

    // Refresh tokens 5 minutes before expiry (tokens typically last 1 hour)
    const refreshInterval = Duration(minutes: 55);

    _refreshTimer = Timer.periodic(refreshInterval, (timer) async {
      try {
        await refreshTokens();
      } catch (e) {
        AppLogger.error('Scheduled token refresh failed', error: e);
        timer.cancel();
      }
    });

    AppLogger.info('Token refresh scheduled for every 55 minutes');
  }
}
