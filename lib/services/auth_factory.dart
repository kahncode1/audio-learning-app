import 'auth/auth_service_interface.dart';
import 'auth/cognito_auth_service.dart';

/// Factory for creating the authentication service.
/// ONLY uses Cognito authentication - no more mock auth!
class AuthFactory {
  static AuthServiceInterface? _instance;

  /// Get the authentication service instance.
  /// Always returns CognitoAuthService.
  static AuthServiceInterface get instance {
    if (_instance != null) return _instance!;

    _instance = CognitoAuthService();
    print('🔐 Using AWS Cognito Authentication Service');

    return _instance!;
  }

  /// Reset the instance (useful for testing)
  static void reset() {
    _instance?.dispose();
    _instance = null;
  }

  /// Manually set the implementation (useful for testing)
  static void setInstance(AuthServiceInterface service) {
    _instance?.dispose();
    _instance = service;
  }
}
