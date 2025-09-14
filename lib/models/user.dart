/// User Model
///
/// Purpose: Represents a user profile with Cognito integration
/// Dependencies: None
///
/// Usage:
///   final user = User.fromJson(jsonData);
///   final displayName = user.displayName;
///
/// Expected behavior:
///   - Maps Cognito sub to user profile
///   - Stores user organization and details
///   - Supports profile updates

class User {
  final String id;
  final String cognitoSub;
  final String email;
  final String? fullName;
  final String? organization;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.cognitoSub,
    required this.email,
    this.fullName,
    this.organization,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get display name (full name or email)
  String get displayName => fullName ?? email.split('@').first;

  /// Get initials for avatar
  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      }
      return fullName!.substring(0, 1).toUpperCase();
    }
    return email.substring(0, 1).toUpperCase();
  }

  /// Check if profile is complete
  bool get isProfileComplete => fullName != null && organization != null;

  /// Creates User from JSON map
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      cognitoSub: json['cognito_sub'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      organization: json['organization'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Creates User from Cognito attributes
  factory User.fromCognitoAttributes({
    required String sub,
    required String email,
    String? name,
    String? organization,
  }) {
    final now = DateTime.now();
    return User(
      id: '', // Will be assigned by database
      cognitoSub: sub,
      email: email,
      fullName: name,
      organization: organization,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Converts User to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cognito_sub': cognitoSub,
      'email': email,
      'full_name': fullName,
      'organization': organization,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts to JSON for Supabase insert/update
  Map<String, dynamic> toSupabaseJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'cognito_sub': cognitoSub,
      'email': email,
      'full_name': fullName,
      'organization': organization,
      // Let database handle timestamps
    };
  }

  /// Creates a copy with updated fields
  User copyWith({
    String? id,
    String? cognitoSub,
    String? email,
    String? fullName,
    String? organization,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      cognitoSub: cognitoSub ?? this.cognitoSub,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      organization: organization ?? this.organization,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify User model implementation
void validateUserModel() {

  // Test JSON parsing
  final testJson = {
    'id': 'user-123',
    'cognito_sub': 'cognito-sub-456',
    'email': 'john.doe@example.com',
    'full_name': 'John Doe',
    'organization': 'Insurance Corp',
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
  };

  final user = User.fromJson(testJson);
  assert(user.id == 'user-123');
  assert(user.cognitoSub == 'cognito-sub-456');
  assert(user.email == 'john.doe@example.com');
  assert(user.displayName == 'John Doe');
  assert(user.initials == 'JD');
  assert(user.isProfileComplete == true);

  // Test user without full name
  final minimalJson = {
    'id': 'user-789',
    'cognito_sub': 'cognito-sub-999',
    'email': 'jane@example.com',
    'full_name': null,
    'organization': null,
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
  };

  final minimalUser = User.fromJson(minimalJson);
  assert(minimalUser.displayName == 'jane');
  assert(minimalUser.initials == 'J');
  assert(minimalUser.isProfileComplete == false);

  // Test Cognito attributes factory
  final cognitoUser = User.fromCognitoAttributes(
    sub: 'cognito-123',
    email: 'test@example.com',
    name: 'Test User',
    organization: 'Test Org',
  );
  assert(cognitoUser.cognitoSub == 'cognito-123');
  assert(cognitoUser.email == 'test@example.com');
  assert(cognitoUser.fullName == 'Test User');

  // Test initials with single name
  final singleName = user.copyWith(fullName: 'Madonna');
  assert(singleName.initials == 'M');

  // Test serialization
  final json = user.toJson();
  assert(json['id'] == 'user-123');
  assert(json['full_name'] == 'John Doe');

  // Test Supabase JSON
  final supabaseJson = user.toSupabaseJson();
  assert(supabaseJson['cognito_sub'] == 'cognito-sub-456');
  assert(!supabaseJson.containsKey('created_at')); // Database handles timestamps

}