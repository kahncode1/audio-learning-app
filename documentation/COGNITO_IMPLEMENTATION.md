# AWS Cognito OAuth Implementation

## Status: ✅ COMPLETED (January 22, 2025)

This document describes the successful implementation of AWS Cognito OAuth authentication with PKCE flow for the Audio Learning App.

## Configuration

### AWS Cognito Settings
- **User Pool ID:** `us-east-1_vAMMFcpew`
- **Client ID:** `7n2o5r6em0latepiui4rfg6vmi`
- **Region:** `us-east-1`
- **Hosted UI Domain:** `users.login-test.theinstitutes.org`
- **OAuth Flow:** Authorization Code + PKCE (no client secret)
- **OAuth Redirect URIs:**
  - Callback: `audiocourses://oauth/callback`
  - Logout: `audiocourses://oauth/logout`

### Environment Variables (.env)
```env
COGNITO_USER_POOL_ID=us-east-1_vAMMFcpew
COGNITO_CLIENT_ID=7n2o5r6em0latepiui4rfg6vmi
COGNITO_APP_CLIENT_ID=7n2o5r6em0latepiui4rfg6vmi
COGNITO_REGION=us-east-1
COGNITO_DOMAIN=users.login-test.theinstitutes.org
```

## Implementation Details

### 1. Deep Linking Configuration

#### iOS (Info.plist)
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.industria.audiocourses</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>audiocourses</string>
        </array>
    </dict>
</array>
```

#### Android (AndroidManifest.xml)
```xml
<intent-filter android:autoVerify="false">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="audiocourses"
          android:host="oauth"
          android:path="/callback"/>
</intent-filter>
```

### 2. Authentication Service Architecture

#### Service Factory Pattern
- **AuthFactory** (`lib/services/auth_factory.dart`) - Returns only CognitoAuthService
- **CognitoAuthService** (`lib/services/auth/cognito_auth_service.dart`) - Implements OAuth flow
- **AuthServiceInterface** - Common interface for authentication methods

#### Key Features
- OAuth 2.0 with PKCE flow
- JWT token bridging to Supabase
- Automatic token refresh (55-minute intervals)
- User profile synchronization
- Hub event listeners for auth state changes

### 3. Supabase Integration

#### JWT Bridging
The Cognito JWT token is automatically bridged to Supabase after successful authentication:
```dart
await Supabase.instance.client.auth.setSession(idToken);
```

#### RLS Policies
All Supabase tables use Cognito JWT claims for authorization:
```sql
CREATE POLICY "policy_name" ON table_name
FOR SELECT USING (auth.jwt() ->> 'sub' IS NOT NULL);
```

#### Helper Functions
- `cognito_user_id()` - Extracts Cognito user ID from JWT
- `is_cognito_authenticated()` - Checks if valid Cognito JWT exists

### 4. Testing

#### Auth Test Screen
Located at: `lib/screens/auth_test_screen.dart`

Access via: Settings > Developer Tools > Cognito OAuth Test

Features:
- Sign in with Cognito hosted UI
- View authentication status
- Check JWT token
- Verify Supabase connection
- Test token refresh
- Sign out functionality

## File Changes Summary

### New Files
- `/lib/config/amplifyconfiguration.dart` - Amplify configuration
- `/lib/services/auth/cognito_auth_service.dart` - Cognito OAuth implementation
- `/lib/screens/auth_test_screen.dart` - Testing interface
- `/documentation/supabase/SUPABASE_JWT_CONFIGURATION.md` - Supabase setup guide

### Modified Files
- `/lib/services/auth_factory.dart` - Removed mock auth, only returns Cognito
- `/lib/screens/settings_screen.dart` - Added Auth Test to Developer Tools
- `/ios/Runner/Info.plist` - Added OAuth deep linking
- `/android/app/src/main/AndroidManifest.xml` - Added OAuth intent filters
- `/.env` - Added Cognito configuration

### Removed Files
- All mock authentication files (as per MOCK_AUTH_REMOVAL_GUIDE.md)

## Known Issues Resolved

1. **"Auth plugin has not been added" error**
   - Solution: Call `initialize()` on CognitoAuthService before use
   - Fixed in: `auth_test_screen.dart` with `_initializeAuth()` method

2. **Import conflicts between Amplify and Supabase**
   - Solution: Use namespace aliases (`amplify` and `supa`)
   - Applied in: `cognito_auth_service.dart`

## Security Considerations

1. **PKCE Flow** - No client secret stored in mobile app
2. **JWT Validation** - Supabase validates tokens using JWKS endpoint
3. **Token Refresh** - Automatic refresh before expiry
4. **Secure Storage** - Tokens stored in platform secure storage
5. **RLS Policies** - All database access requires valid Cognito JWT

## Next Steps

1. Remove temporary Supabase test data access policies
2. Implement proper error handling for network failures
3. Add user profile management UI
4. Implement logout redirect handling
5. Add production Cognito configuration

## Testing Instructions

1. Launch the app
2. Navigate to Settings > Developer Tools > Cognito OAuth Test
3. Click "Sign In with Cognito"
4. Authenticate with enterprise credentials
5. Verify successful authentication and Supabase connection
6. Test token refresh functionality
7. Test sign out

## Support

For issues or questions regarding the Cognito implementation:
- Review `/documentation/apis/aws-cognito-sso.md`
- Check `/documentation/integrations/cognito-supabase-bridge.md`
- Contact IT for Cognito configuration changes