# Supabase JWT Configuration for Cognito Integration

## Overview
This guide explains how to configure Supabase to accept and validate JWT tokens from AWS Cognito.

## Configuration Steps

### 1. Option A: Third-Party Auth Integration (Recommended)
Navigate to your Supabase project dashboard:
- Go to `Authentication` → `Providers`
- Look for "Third-party Auth Integrations" section
- Add AWS Cognito integration with:
  - **Pool ID:** `us-east-1_vAMMFcpew`
  - **Region:** `us-east-1`

### 2. Option B: Manual JWT Settings (Alternative)
If third-party integration is not available, configure manual JWT settings:
- Go to `Authentication` → `Settings` → `JWT Settings`

#### JWT Configuration Fields:
- **JWT Secret:** `https://cognito-idp.us-east-1.amazonaws.com/us-east-1_vAMMFcpew/.well-known/jwks.json`
- **JWT Issuer:** `https://cognito-idp.us-east-1.amazonaws.com/us-east-1_vAMMFcpew`
- **JWT Audience:** `7n2o5r6em0latepiui4rfg6vmi` (the App Client ID)

### 3. Database Setup

#### Create User Profiles Table
```sql
-- Create user_profiles table to store Cognito user data
CREATE TABLE IF NOT EXISTS user_profiles (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  organization TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for users to access their own profile
CREATE POLICY "Users can view their own profile"
  ON user_profiles FOR SELECT
  USING (auth.jwt() ->> 'sub' = id);

CREATE POLICY "Users can update their own profile"
  ON user_profiles FOR UPDATE
  USING (auth.jwt() ->> 'sub' = id);
```

### 4. Update Existing RLS Policies

Update your existing RLS policies to use Cognito JWT claims:

```sql
-- Example: Update courses access policy
DROP POLICY IF EXISTS "Users see courses for their organization" ON courses;

CREATE POLICY "Users see courses for their organization"
  ON courses FOR SELECT
  USING (
    organization_id = (auth.jwt() ->> 'custom:organization')
    OR
    organization_id IS NULL  -- Allow access to public courses
  );

-- Example: Update progress tracking policy
DROP POLICY IF EXISTS "Users can only access their own progress" ON progress;

CREATE POLICY "Users can only access their own progress"
  ON progress FOR ALL
  USING (user_id = (auth.jwt() ->> 'sub'));
```

### 5. Lambda Function for Custom Claims (Required)

You MUST create a Pre-Token Generation Lambda to add the required 'role' claim:

```javascript
exports.handler = async (event) => {
    // Add required role claim for Supabase RLS
    event.response.claimsOverrideDetails = {
        claimsToAddOrOverride: {
            'role': 'authenticated', // Required for RLS policies
            'aud': 'authenticated',
            'app_metadata': JSON.stringify({
                provider: 'cognito',
                providers: ['cognito']
            }),
            'user_metadata': JSON.stringify({
                email: event.request.userAttributes.email,
                email_verified: event.request.userAttributes.email_verified === 'true'
            })
        }
    };

    return event;
};
```

### 6. Flutter Implementation Approach

Due to limitations in the Supabase Flutter SDK, use the Authorization header approach:

```dart
// Set JWT in Authorization header
final idToken = await getJwtToken();
Supabase.instance.client.headers['Authorization'] = 'Bearer $idToken';

// Clear on sign out
Supabase.instance.client.headers.remove('Authorization');
```

**Important**: Do NOT use `setSession(idToken)` as it expects both access and refresh tokens.

### 7. Remove Temporary Test Policies

Remove the temporary public access policy that was created for testing:

```sql
-- Remove temporary test access
DROP POLICY IF EXISTS "Public read access for test data" ON learning_objects;

-- Ensure all tables have proper RLS
ALTER TABLE learning_objects ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE progress ENABLE ROW LEVEL SECURITY;
```

### 8. Test JWT Validation

You can test JWT validation using Supabase's SQL editor:

```sql
-- Test that JWT claims are accessible
SELECT auth.jwt() ->> 'sub' AS user_id,
       auth.jwt() ->> 'email' AS user_email,
       auth.jwt() ->> 'custom:organization' AS organization;
```

## Verification Steps

1. **Test Authentication Flow:**
   - User signs in via Cognito hosted UI
   - App receives JWT token
   - Token is sent to Supabase
   - Supabase validates and accepts token

2. **Test RLS Policies:**
   - Authenticated user can only see their own data
   - Organization-based filtering works correctly
   - No unauthorized access to other users' data

3. **Monitor for Issues:**
   - Check Supabase logs for JWT validation errors
   - Verify token expiration is handled correctly
   - Ensure refresh flow works as expected

## Troubleshooting

### Common Issues:

1. **"refresh_token_not_found" Error:**
   - **Cause:** Using `setSession(idToken)` which expects access + refresh tokens
   - **Solution:** Use Authorization header approach instead: `client.headers['Authorization'] = 'Bearer $idToken'`

2. **"Invalid JWT" Error:**
   - Verify JWKS URL is correct in Supabase settings
   - Check that token hasn't expired (1 hour default)
   - Ensure issuer and audience match exactly
   - Verify Lambda function is adding required 'role' claim

3. **RLS Policy Violations:**
   - Check that JWT contains 'role': 'authenticated' claim
   - Verify JWT contains 'sub' claim for user identification
   - Test with `auth.jwt()` function directly in SQL editor
   - Ensure Lambda Pre-Token Generation trigger is active

4. **Token Refresh Issues:**
   - Cognito refresh tokens expire after 30 days
   - New ID tokens must be re-bridged to Supabase
   - Monitor token expiration times and implement refresh logic

## Security Notes

- Never expose JWT tokens in logs or error messages
- Always use HTTPS for token transmission
- Regularly rotate Cognito signing keys
- Monitor for suspicious authentication patterns
- Keep RLS policies strict and well-tested

## Next Steps

Once Supabase is configured:
1. Test the complete authentication flow
2. Remove all mock authentication code
3. Update documentation to reflect production setup
4. Train users on the new authentication process