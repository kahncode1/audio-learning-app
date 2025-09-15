# Mock Authentication Removal Guide

## ⚠️ TEMPORARY DEVELOPMENT SOLUTION
This document describes the mock authentication system created to allow development to continue while waiting for AWS Cognito setup by IT. Follow this guide to cleanly remove the mock authentication when the real authentication is ready.

---

## Architecture Overview

### Core Design: Interface-Based Authentication

The mock authentication system uses an interface pattern to ensure clean separation between mock and production code.

```
lib/
├── services/
│   ├── auth/
│   │   ├── auth_service_interface.dart    # Abstract interface (KEEP)
│   │   ├── cognito_auth_service.dart      # Real implementation (KEEP)
│   │   └── mock_auth_service.dart         # Mock implementation (REMOVE)
│   └── auth_factory.dart                  # Factory pattern (MODIFY)
```

### Key Files Created for Mock Authentication

| File | Purpose | Action When Removing |
|------|---------|---------------------|
| `lib/services/auth/mock_auth_service.dart` | Mock authentication service | DELETE |
| `lib/services/auth/auth_service_interface.dart` | Common interface | KEEP |
| `lib/services/auth/cognito_auth_service.dart` | Real Cognito service | KEEP |
| `lib/services/auth_factory.dart` | Service factory | MODIFY |
| `lib/config/environment.dart` | Environment detection | KEEP/MODIFY |
| `test/mock_auth_test.dart` | Mock auth tests | DELETE or KEEP for testing |

---

## Removal Instructions

### Step 1: Obtain AWS Cognito Credentials

Ensure you have the following from IT:
- [ ] Cognito User Pool ID
- [ ] Cognito App Client ID
- [ ] Cognito Identity Pool ID
- [ ] AWS Region
- [ ] Cognito Domain (if using hosted UI)

### Step 2: Update Configuration Files

#### Update `lib/config/app_config.dart`:
```dart
// Replace these placeholder values:
static const String cognitoUserPoolId = 'us-east-1_ACTUAL_ID';
static const String cognitoClientId = 'YOUR_ACTUAL_CLIENT_ID';
static const String cognitoIdentityPoolId = 'us-east-1:ACTUAL_IDENTITY_POOL';
```

#### Update `.env`:
```env
# Change from development to production
ENVIRONMENT=production

# Add Cognito credentials
COGNITO_USER_POOL_ID=us-east-1_ACTUAL_ID
COGNITO_CLIENT_ID=YOUR_ACTUAL_CLIENT_ID
COGNITO_IDENTITY_POOL_ID=us-east-1:ACTUAL_IDENTITY_POOL
COGNITO_REGION=us-east-1
```

### Step 3: Configure Supabase JWT Validation

1. Go to Supabase Dashboard → Settings → Authentication → Providers
2. Enable "Custom Token (JWT)"
3. Configure JWT secret with Cognito's JWKS:
   ```
   https://cognito-idp.{region}.amazonaws.com/{userPoolId}/.well-known/jwks.json
   ```
4. Set JWT settings:
   - Issuer: `https://cognito-idp.{region}.amazonaws.com/{userPoolId}`
   - Audience: Your App Client ID

### Step 4: Clean Up Mock Authentication Code

#### Option A: Complete Removal (Recommended for Production)

```bash
# Delete mock-specific files
rm lib/services/auth/mock_auth_service.dart
rm lib/config/environment.dart  # If only used for mock
rm test/mock_auth_test.dart

# Update auth factory to always return real service
```

Update `lib/services/auth_factory.dart`:
```dart
class AuthFactory {
  static IAuthService create() {
    return CognitoAuthService();  // Always return real service
  }
}
```

#### Option B: Keep for Testing (Recommended for Development)

Keep mock files but ensure production always uses real auth:

Update `lib/services/auth_factory.dart`:
```dart
class AuthFactory {
  static IAuthService create() {
    // Force production in release builds
    if (kReleaseMode) {
      return CognitoAuthService();
    }

    // Allow mock in debug/profile modes
    const environment = String.fromEnvironment('ENVIRONMENT');
    if (environment == 'development') {
      return MockAuthService();
    }

    return CognitoAuthService();
  }
}
```

### Step 5: Remove Temporary Test Access Policies

Remove the temporary RLS policy created for testing:

```sql
-- Remove the temporary public access policy for test data
DROP POLICY IF EXISTS "Public read access for test data" ON learning_objects;
```

This policy was created to allow unauthenticated access to the test learning object (ID: `94096d75-7125-49be-b11c-49a9d5b5660d`) during development.

### Step 6: Update Supabase Service

Remove or comment out development-specific code in `lib/services/supabase_service.dart`:

```dart
// Remove or comment out:
Future<bool> initializeForDevelopment() async {
  // This entire method can be removed
}

Future<void> _createDevUser() async {
  // This entire method can be removed
}
```

### Step 7: Test the Migration

1. **Run verification script:**
   ```bash
   dart scripts/setup_verification.dart
   ```

2. **Test authentication flow:**
   ```bash
   flutter test test/auth_test.dart
   ```

3. **Manual testing:**
   - Sign in with a real Cognito user
   - Verify JWT bridging to Supabase
   - Check that data operations work with RLS

### Step 8: Update Documentation

Remove or update references to mock authentication in:
- [ ] README.md
- [ ] SETUP_GUIDE.md
- [ ] Code comments mentioning mock auth
- [ ] This file (MOCK_AUTH_REMOVAL_GUIDE.md) can be deleted

---

## Files to Review

### Files That Should NOT Change
These files were designed to work with both mock and real authentication:
- `lib/providers/providers.dart` - Uses interface
- `lib/screens/*` - All screens use interface
- `lib/models/*` - Data models are independent
- `lib/widgets/*` - UI components are independent

### Files That May Need Updates
- `lib/services/auth_factory.dart` - Remove mock logic
- `lib/main.dart` - Remove any dev-specific initialization
- `pubspec.yaml` - No changes needed

---

## Verification Checklist

After removing mock authentication:

- [ ] App builds successfully
- [ ] No references to `MockAuthService` in production code
- [ ] Real authentication works end-to-end
- [ ] JWT tokens bridge to Supabase correctly
- [ ] RLS policies work with real user tokens
- [ ] No hardcoded test credentials remain
- [ ] Environment is set to "production"
- [ ] All tests pass with real auth service

---

## Rollback Plan

If you need to temporarily revert to mock authentication:

1. Set `ENVIRONMENT=development` in `.env`
2. Ensure mock files are still present
3. Restart the application

The factory pattern will automatically switch back to mock authentication.

---

## Mock Authentication Details (For Reference)

### Test Users Created by Mock System
```dart
Email: test@example.com
Password: Test123!
Role: user

Email: admin@test.com
Password: Admin123!
Role: admin
```

### Mock Token Structure
The mock system generates simplified tokens that mimic JWT structure:
```json
{
  "sub": "mock-user-001",
  "email": "test@example.com",
  "exp": 1234567890,
  "name": "Test User",
  "organization": "Test Corp"
}
```

### Database Test Data
Mock system and testing setup created this data in Supabase:

#### Test User:
```sql
INSERT INTO users (id, cognito_sub, email, full_name, organization)
VALUES (
  'dev-user-001',
  'mock-user-001',
  'test@example.com',
  'Test User',
  'Test Corp'
);
```

#### Test Course and Learning Object:
- **Course**: "Insurance Case Management" (ID: INS-101)
- **Assignment**: "Establishing a Case Reserve"
- **Learning Object**: ID `94096d75-7125-49be-b11c-49a9d5b5660d`
  - Contains SSML content for audio narration testing
  - Has temporary public access policy for unauthenticated testing

#### Test Button in HomePage:
- **"Test with Database"** button in `lib/screens/home_screen.dart`
  - Directly fetches the test learning object using Supabase anon key
  - Bypasses authentication for testing purposes
  - Should be removed in production

---

## Support

If you encounter issues during removal:

1. Check `scripts/setup_verification.dart` output
2. Review Supabase logs for JWT validation errors
3. Verify Cognito credentials are correct
4. Ensure environment variables are updated
5. Check that all mock files are properly removed/updated

---

## Timeline

- **Mock Authentication Created**: 2025-09-13
- **Planned Removal**: When IT provides Cognito credentials
- **Keep Until**: Production deployment confirmed working

---

*This document should be deleted after successful migration to production authentication.*