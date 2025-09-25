import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' as amplify;

/// Common interface for authentication services.
/// This allows us to switch between mock and real implementations.
abstract class AuthServiceInterface {
  /// Initialize the authentication service
  Future<void> initialize();

  /// Sign in with email and password
  Future<amplify.SignInResult> signIn(String email, String password);

  /// Sign out the current user
  Future<void> signOut();

  /// Get the current authenticated user
  Future<amplify.AuthUser?> getCurrentUser();

  /// Check if user is signed in
  Future<bool> isSignedIn();

  /// Get the current user's JWT token
  Future<String?> getJwtToken();

  /// Refresh the current user's tokens
  Future<void> refreshTokens();

  /// Get current auth session
  Future<amplify.AuthSession?> getCurrentSession();

  /// Stream of authentication state changes
  Stream<bool> get authStateChanges;

  /// Dispose of resources
  void dispose();
}
