import 'auth/auth_service_interface.dart';
import 'auth/mock_auth_service.dart';
import 'auth_service.dart';

/// Factory for creating the appropriate authentication service.
/// This allows easy switching between mock and real implementations.
class AuthFactory {
  static AuthServiceInterface? _instance;
  
  /// Get the authentication service instance.
  /// Uses environment variable to determine which implementation.
  static AuthServiceInterface get instance {
    if (_instance != null) return _instance!;
    
    // Check environment variable or app config
    const useMockAuth = bool.fromEnvironment(
      'USE_MOCK_AUTH',
      defaultValue: true, // Default to mock until Cognito is ready
    );
    
    if (useMockAuth) {
      print('🎭 Using Mock Authentication Service');
      print('🔄 To switch to real auth, set USE_MOCK_AUTH=false');
      _instance = MockAuthService();
    } else {
      print('🔐 Using AWS Cognito Authentication Service');
      _instance = AuthService();
    }
    
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