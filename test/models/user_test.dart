import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/user.dart';

void main() {
  group('User Model', () {
    final testJson = {
      'id': 'user-abc123',
      'cognito_sub': 'cognito-def456',
      'email': 'sarah.wilson@company.com',
      'full_name': 'Sarah Wilson',
      'organization': 'Wilson Insurance Group',
      'created_at': '2024-04-01T08:30:00Z',
      'updated_at': '2024-04-05T15:45:00Z',
    };

    group('Constructor', () {
      test('should create User with all required fields', () {
        final user = User(
          id: 'test-id',
          cognitoSub: 'cognito-sub',
          email: 'test@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.id, 'test-id');
        expect(user.cognitoSub, 'cognito-sub');
        expect(user.email, 'test@example.com');
        expect(user.fullName, isNull);
        expect(user.organization, isNull);
      });

      test('should create User with optional fields', () {
        final now = DateTime.now();
        final user = User(
          id: 'test-id',
          cognitoSub: 'cognito-sub',
          email: 'test@example.com',
          fullName: 'Test User',
          organization: 'Test Org',
          createdAt: now,
          updatedAt: now,
        );

        expect(user.fullName, 'Test User');
        expect(user.organization, 'Test Org');
      });
    });

    group('Display Name', () {
      test('should use full name when available', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'john.doe@example.com',
          fullName: 'John Doe',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.displayName, 'John Doe');
      });

      test('should use email prefix when full name is null', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'jane.smith@example.com',
          fullName: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.displayName, 'jane.smith');
      });

      test('should handle empty full name', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'user@test.com',
          fullName: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.displayName, 'user');
      });
    });

    group('Initials', () {
      test('should create initials from full name with first and last', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: 'Alice Johnson',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.initials, 'AJ');
      });

      test('should create initials from full name with middle names', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: 'Alice Marie Johnson Smith',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.initials, 'AS'); // First and last
      });

      test('should create initial from single name', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: 'Madonna',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.initials, 'M');
      });

      test('should use email initial when no full name', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'bob@example.com',
          fullName: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.initials, 'B');
      });

      test('should handle empty full name', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'charlie@example.com',
          fullName: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.initials, 'C');
      });

      test('should handle whitespace in full name', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: '  David   Lee  ',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.initials, 'DL');
      });
    });

    group('Profile Completeness', () {
      test('should be complete when both name and organization exist', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: 'Complete User',
          organization: 'Complete Org',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.isProfileComplete, true);
      });

      test('should be incomplete when missing full name', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: null,
          organization: 'Has Org',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.isProfileComplete, false);
      });

      test('should be incomplete when missing organization', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: 'Has Name',
          organization: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.isProfileComplete, false);
      });

      test('should be incomplete when missing both', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: null,
          organization: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.isProfileComplete, false);
      });
    });

    group('JSON Serialization', () {
      test('fromJson should parse valid JSON correctly', () {
        final user = User.fromJson(testJson);

        expect(user.id, 'user-abc123');
        expect(user.cognitoSub, 'cognito-def456');
        expect(user.email, 'sarah.wilson@company.com');
        expect(user.fullName, 'Sarah Wilson');
        expect(user.organization, 'Wilson Insurance Group');
        expect(user.createdAt, DateTime.parse('2024-04-01T08:30:00Z'));
        expect(user.updatedAt, DateTime.parse('2024-04-05T15:45:00Z'));
      });

      test('fromJson should handle null optional fields', () {
        final minimalJson = {
          'id': 'minimal-user',
          'cognito_sub': 'minimal-sub',
          'email': 'minimal@test.com',
          'full_name': null,
          'organization': null,
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        };

        final user = User.fromJson(minimalJson);

        expect(user.fullName, isNull);
        expect(user.organization, isNull);
        expect(user.isProfileComplete, false);
      });

      test('toJson should serialize all fields correctly', () {
        final user = User.fromJson(testJson);
        final json = user.toJson();

        expect(json['id'], 'user-abc123');
        expect(json['cognito_sub'], 'cognito-def456');
        expect(json['email'], 'sarah.wilson@company.com');
        expect(json['full_name'], 'Sarah Wilson');
        expect(json['organization'], 'Wilson Insurance Group');
        expect(json['created_at'], '2024-04-01T08:30:00.000Z');
        expect(json['updated_at'], '2024-04-05T15:45:00.000Z');
      });

      test('round-trip serialization should preserve data', () {
        final original = User.fromJson(testJson);
        final json = original.toJson();
        final restored = User.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.cognitoSub, original.cognitoSub);
        expect(restored.email, original.email);
        expect(restored.fullName, original.fullName);
        expect(restored.organization, original.organization);
        expect(restored.createdAt, original.createdAt);
        expect(restored.updatedAt, original.updatedAt);
      });
    });

    group('Cognito Factory', () {
      test('fromCognitoAttributes should create user from Cognito data', () {
        final user = User.fromCognitoAttributes(
          sub: 'cognito-abc123',
          email: 'cognito.user@example.com',
          name: 'Cognito User',
          organization: 'Cognito Org',
        );

        expect(user.id, isEmpty); // Will be assigned by database
        expect(user.cognitoSub, 'cognito-abc123');
        expect(user.email, 'cognito.user@example.com');
        expect(user.fullName, 'Cognito User');
        expect(user.organization, 'Cognito Org');
        expect(user.createdAt, isA<DateTime>());
        expect(user.updatedAt, isA<DateTime>());
      });

      test('fromCognitoAttributes should handle optional fields', () {
        final user = User.fromCognitoAttributes(
          sub: 'cognito-minimal',
          email: 'minimal@cognito.com',
        );

        expect(user.cognitoSub, 'cognito-minimal');
        expect(user.email, 'minimal@cognito.com');
        expect(user.fullName, isNull);
        expect(user.organization, isNull);
      });
    });

    group('Supabase JSON', () {
      test('toSupabaseJson should exclude timestamps and empty ID', () {
        final user = User.fromCognitoAttributes(
          sub: 'cognito-123',
          email: 'test@supabase.com',
          name: 'Supabase User',
          organization: 'Supabase Org',
        );

        final json = user.toSupabaseJson();

        expect(json.containsKey('id'), false); // Empty ID excluded
        expect(json.containsKey('created_at'), false); // Database handles
        expect(json.containsKey('updated_at'), false); // Database handles
        expect(json['cognito_sub'], 'cognito-123');
        expect(json['email'], 'test@supabase.com');
        expect(json['full_name'], 'Supabase User');
        expect(json['organization'], 'Supabase Org');
      });

      test('toSupabaseJson should include non-empty ID', () {
        final user = User(
          id: 'existing-user-123',
          cognitoSub: 'cognito-123',
          email: 'existing@example.com',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final json = user.toSupabaseJson();

        expect(json['id'], 'existing-user-123');
        expect(json['cognito_sub'], 'cognito-123');
      });
    });

    group('copyWith', () {
      test('should create copy with updated fields', () {
        final original = User.fromJson(testJson);
        final updated = original.copyWith(
          fullName: 'Updated Name',
          organization: 'New Organization',
          email: 'newemail@example.com',
        );

        expect(updated.id, original.id);
        expect(updated.cognitoSub, original.cognitoSub);
        expect(updated.fullName, 'Updated Name');
        expect(updated.organization, 'New Organization');
        expect(updated.email, 'newemail@example.com');
        expect(updated.createdAt, original.createdAt);
        expect(updated.updatedAt, original.updatedAt);
      });

      test('should preserve original when no fields changed', () {
        final original = User.fromJson(testJson);
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.email, original.email);
        expect(copy.fullName, original.fullName);
        expect(copy.organization, original.organization);
      });

      test('should allow clearing nullable fields', () {
        final original = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: 'Has Name',
          organization: 'Has Org',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final updated = original.copyWith(
          fullName: null,
          organization: null,
        );

        expect(updated.fullName, isNull);
        expect(updated.organization, isNull);
        expect(updated.isProfileComplete, false);
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when IDs match', () {
        final now = DateTime.now();
        final user1 = User(
          id: 'same-id',
          cognitoSub: 'sub-1',
          email: 'user1@example.com',
          fullName: 'User One',
          createdAt: now,
          updatedAt: now,
        );

        final user2 = User(
          id: 'same-id',
          cognitoSub: 'sub-2',
          email: 'user2@example.com',
          fullName: 'User Two',
          createdAt: now.add(const Duration(days: 1)),
          updatedAt: now.add(const Duration(days: 1)),
        );

        expect(user1, equals(user2));
        expect(user1.hashCode, user2.hashCode);
      });

      test('should not be equal when IDs differ', () {
        final now = DateTime.now();
        final user1 = User(
          id: 'id-1',
          cognitoSub: 'same-sub',
          email: 'same@example.com',
          createdAt: now,
          updatedAt: now,
        );

        final user2 = User(
          id: 'id-2',
          cognitoSub: 'same-sub',
          email: 'same@example.com',
          createdAt: now,
          updatedAt: now,
        );

        expect(user1, isNot(equals(user2)));
      });

      test('should be equal to itself', () {
        final user = User.fromJson(testJson);
        expect(user, equals(user));
      });
    });

    group('toString', () {
      test('should return readable string representation', () {
        final user = User(
          id: 'user-123',
          cognitoSub: 'cognito-456',
          email: 'test@example.com',
          fullName: 'Test User',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final str = user.toString();
        expect(str, contains('user-123'));
        expect(str, contains('test@example.com'));
        expect(str, contains('Test User'));
      });
    });

    group('Edge Cases', () {
      test('should handle special characters in names', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName: 'José María García-López',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.displayName, 'José María García-López');
        expect(user.initials, 'JG'); // First and last
      });

      test('should handle very long names', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'test@example.com',
          fullName:
              'Alexander Maximilian Christopher Wellington Blackwood-Smythe',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.initials, 'AB'); // First and last only
      });

      test('should handle emails without @ symbol gracefully', () {
        final user = User(
          id: 'test',
          cognitoSub: 'sub',
          email: 'invalidemail',
          fullName: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(user.displayName, 'invalidemail');
        expect(user.initials, 'I');
      });
    });

    group('Validation Function', () {
      test('validateUserModel should not throw', () {
        expect(() => validateUserModel(), returnsNormally);
      });
    });
  });
}
