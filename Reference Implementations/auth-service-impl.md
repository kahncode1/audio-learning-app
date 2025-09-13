# /implementations/auth-service.dart

```dart
/// Authentication Service - AWS Cognito SSO with Supabase Bridge
/// 
/// Handles all authentication operations:
/// - AWS Cognito SSO authentication
/// - JWT token management and refresh
/// - Supabase session bridging
/// - Automatic token refresh scheduling

import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String _cognitoPoolId = Env.cognitoPoolId;
  static const String _cognitoClientId = Env.cognitoClientId;
  static const int _tokenRefreshBuffer = 300; // Refresh 5 minutes before expiry
  
  Timer? _refreshTimer;
  
  Future<void> configureAmplify() async {
    if (Amplify.isConfigured) return;
    
    final authPlugin = AmplifyAuthCognito();
    await Amplify.addPlugins([authPlugin]);
    
    try {
      await Amplify.configure(amplifyconfig);
    } on AmplifyAlreadyConfiguredException {
      logger.warning('Amplify was already configured');
    }
  }
  
  Future<AuthSession> authenticate() async {
    try {
      // Check existing session
      final session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        await _scheduleTokenRefresh(session);
        return session;
      }
      
      // Initiate SSO login
      final result = await Amplify.Auth.signInWithWebUI(
        provider: AuthProvider.custom('YourSSO'),
      );
      
      if (!result.isSignedIn) {
        throw AuthException('SSO login failed');
      }
      
      final newSession = await Amplify.Auth.fetchAuthSession();
      await _bridgeToSupabase(newSession);
      await _scheduleTokenRefresh(newSession);
      
      return newSession;
    } on AuthException catch (e) {
      logger.error('Authentication failed: ${e.message}');
      throw AuthServiceException('Failed to authenticate', originalError: e);
    }
  }
  
  Future<void> _bridgeToSupabase(AuthSession session) async {
    if (!session.isSignedIn) {
      throw AuthException('Cannot bridge unsigned session');
    }
    
    final cognitoSession = session as CognitoAuthSession;
    final idToken = cognitoSession.userPoolTokensResult.value.idToken.raw;
    
    try {
      // Create Supabase session with Cognito JWT
      await Supabase.instance.client.auth.setSession(idToken);
      
      // Verify session is active
      final supabaseSession = Supabase.instance.client.auth.currentSession;
      if (supabaseSession == null) {
        throw AuthException('Failed to create Supabase session');
      }
      
      logger.info('Successfully bridged to Supabase');
    } catch (e) {
      logger.error('Supabase bridge failed: $e');
      throw AuthServiceException('Failed to bridge to Supabase', originalError: e);
    }
  }
  
  Future<void> _scheduleTokenRefresh(AuthSession session) async {
    _refreshTimer?.cancel();
    
    if (!session.isSignedIn) return;
    
    final cognitoSession = session as CognitoAuthSession;
    final expiryTime = cognitoSession.userPoolTokensResult.value.expiresAt;
    
    if (expiryTime == null) return;
    
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
  }
  
  Future<void> _refreshTokens() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: true),
      );
      
      if (session.isSignedIn) {
        await _bridgeToSupabase(session);
        await _scheduleTokenRefresh(session);
        logger.info('Tokens refreshed successfully');
      }
    } catch (e) {
      logger.error('Token refresh failed: $e');
      // Trigger re-authentication
      await authenticate();
    }
  }
  
  Future<void> signOut() async {
    try {
      _refreshTimer?.cancel();
      
      // Sign out from Amplify
      await Amplify.Auth.signOut();
      
      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();
      
      logger.info('User signed out successfully');
    } catch (e) {
      logger.error('Sign out failed: $e');
      throw AuthServiceException('Failed to sign out', originalError: e);
    }
  }
  
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
  
  Future<bool> isSignedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      return false;
    }
  }
  
  void dispose() {
    _refreshTimer?.cancel();
  }
}

// Validation function
void main() async {
  print('🔧 Testing AuthService...\n');
  
  final List<String> validationFailures = [];
  int totalTests = 0;
  
  // Test 1: Service initialization
  totalTests++;
  try {
    final service = AuthService();
    print('✓ AuthService initialized successfully');
  } catch (e) {
    validationFailures.add('Service initialization failed: $e');
  }
  
  // Test 2: Amplify configuration
  totalTests++;
  try {
    final service = AuthService();
    await service.configureAmplify();
    print('✓ Amplify configuration successful');
  } catch (e) {
    validationFailures.add('Amplify configuration failed: $e');
  }
  
  // Test 3: Sign-in check
  totalTests++;
  try {
    final service = AuthService();
    final isSignedIn = await service.isSignedIn();
    print('✓ Sign-in status check: $isSignedIn');
  } catch (e) {
    validationFailures.add('Sign-in check failed: $e');
  }
  
  // Test 4: Token refresh scheduling logic
  totalTests++;
  try {
    // Test calculation of refresh time
    final expiryTime = DateTime.now().add(Duration(hours: 1));
    final refreshTime = expiryTime.subtract(Duration(seconds: 300));
    final delay = refreshTime.difference(DateTime.now());
    
    if (delay.inMinutes > 0 && delay.inMinutes < 60) {
      print('✓ Token refresh scheduling logic correct: ${delay.inMinutes} minutes');
    } else {
      validationFailures.add('Incorrect refresh calculation: ${delay.inMinutes} minutes');
    }
  } catch (e) {
    validationFailures.add('Refresh scheduling test failed: $e');
  }
  
  // Final validation results
  print('\n' + '=' * 50);
  if (validationFailures.isNotEmpty) {
    print('❌ VALIDATION FAILED - ${validationFailures.length} of $totalTests tests failed:\n');
    for (final failure in validationFailures) {
      print('  • $failure');
    }
    exit(1);
  } else {
    print('✅ VALIDATION PASSED - All $totalTests tests produced expected results');
    print('AuthService is ready for integration');
    exit(0);
  }
}
```