# Supabase JWT Configuration for Cognito Integration

## Overview
This guide explains how to configure Supabase to accept and validate JWT tokens from AWS Cognito.

## Configuration Steps

### 1. Access Supabase Dashboard
Navigate to your Supabase project dashboard:
- Go to `Authentication` → `Providers`
- Look for "Custom Token (JWT)" section

### 2. Configure JWT Settings

#### JWT Secret Configuration
Since Cognito uses RSA key pairs, you'll need to use the JWKS endpoint:

```
https://cognito-idp.us-east-1.amazonaws.com/us-east-1_vAMMFcpew/.well-known/jwks.json
```

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

### 5. Lambda Function for Custom Claims

If you need to add custom claims to Cognito tokens for Supabase compatibility, create a Pre-Token Generation Lambda:

```javascript
exports.handler = async (event) => {
    // Add custom claims for Supabase
    event.response.claimsOverrideDetails = {
        claimsToAddOrOverride: {
            'role': 'authenticated',
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

### 6. Remove Temporary Test Policies

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

### 7. Test JWT Validation

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

1. **"Invalid JWT" Error:**
   - Verify JWKS URL is correct
   - Check that token hasn't expired
   - Ensure issuer and audience match exactly

2. **RLS Policy Violations:**
   - Check that JWT contains expected claims
   - Verify claim names match policy expectations
   - Test with `auth.jwt()` function directly

3. **Token Refresh Issues:**
   - Ensure Cognito refresh token is valid
   - Check that new tokens are bridged to Supabase
   - Monitor token expiration times

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