/// Mock models for authentication to avoid conflicts with Amplify/Supabase types

class MockAuthUser {
  final String userId;
  final String username;
  final String email;

  MockAuthUser({
    required this.userId,
    required this.username,
    required this.email,
  });
}

class MockAuthException implements Exception {
  final String message;
  final String? underlyingException;

  MockAuthException(this.message, {this.underlyingException});

  @override
  String toString() => 'MockAuthException: $message';
}
