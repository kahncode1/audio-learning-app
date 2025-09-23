# Audio Learning Platform - Setup Guide

## Prerequisites Checklist

- [ ] AWS Account with admin access
- [ ] Supabase project created (✅ Already done: cmjdciktvfxiyapdseqn)
- [ ] Flutter development environment set up (✅ Already done)
- [ ] Speechify API account (for audio features)

## Part 1: AWS Cognito Setup (30 minutes)

### Step 1: Create User Pool

1. **Navigate to AWS Cognito Console**
   ```
   https://console.aws.amazon.com/cognito/home
   ```

2. **Create User Pool**
   - Click "Create user pool"
   - Choose "Step through settings"

3. **Configure Sign-in Options**
   ```yaml
   Cognito user pool sign-in:
     - ✓ Email address
     - ✓ Username

   Username requirements:
     - Case sensitive: No
   ```

4. **Configure Security**
   ```yaml
   Password policy:
     - Minimum length: 8
     - ✓ Require numbers
     - ✓ Require special character
     - ✓ Require uppercase letters
     - ✓ Require lowercase letters

   MFA:
     - Optional (can enable later)
   ```

5. **Configure Sign-up**
   ```yaml
   Self-registration: Enable

   Required attributes:
     - email (required)

   Custom attributes (Add these):
     - organization (string, mutable)
     - role (string, mutable)
   ```

6. **Configure Messages**
   - Use Cognito default email settings
   - Customize messages later if needed

7. **Add App Client**
   ```yaml
   App client name: flutter-audio-learning

   Generate client secret: NO (public client)

   Auth Flows Configuration:
     - ✓ ALLOW_USER_SRP_AUTH
     - ✓ ALLOW_REFRESH_TOKEN_AUTH
     - ✓ ALLOW_USER_PASSWORD_AUTH

   Token validity:
     - ID token: 1 hour
     - Access token: 1 hour
     - Refresh token: 30 days
   ```

8. **Review and Create**
   - Pool name: `audio-learning-platform`
   - Click "Create pool"

9. **Save These Values** ⚠️
   ```
   User Pool ID: {region}_XXXXXXXXX
   App Client ID: XXXXXXXXXXXXXXXXXXXXXXXXXX
   ```

### Step 2: Create Identity Pool

1. **Navigate to Federated Identities**
   ```
   https://console.aws.amazon.com/cognito/federated
   ```

2. **Create Identity Pool**
   ```yaml
   Identity pool name: audio_learning_identity_pool

   Authentication providers:
     - Cognito:
       - User Pool ID: [from Step 1]
       - App Client ID: [from Step 1]

   Unauthenticated identities: Disable
   ```

3. **Configure IAM Roles**
   - Accept the default roles created
   - Note the Identity Pool ID: `{region}:XXXX-XXXX-XXXX-XXXX`

### Step 3: Configure Domain (Optional for Web Testing)

1. **In User Pool → Domain name**
2. **Choose domain prefix**: `audio-learning-{random}`
3. **Save domain**

## Part 2: Supabase JWT Configuration (15 minutes)

### Step 1: Get Cognito Public Keys

1. **Find your JWKS URL**:
   ```
   https://cognito-idp.{region}.amazonaws.com/{userPoolId}/.well-known/jwks.json
   ```
   Replace `{region}` and `{userPoolId}` with your values.

2. **Visit the URL** and copy the JSON response

### Step 2: Configure Supabase

1. **Navigate to Supabase Dashboard**
   ```
   https://supabase.com/dashboard/project/cmjdciktvfxiyapdseqn
   ```

2. **Go to Settings → Authentication → Providers**

3. **Enable Custom Token (JWT)**

4. **Configure JWT Secret**:
   ```json
   {
     "keys": [
       // Paste the keys from your JWKS URL here
     ]
   }
   ```

5. **Configure JWT Settings**:
   ```yaml
   JWT Issuer: https://cognito-idp.{region}.amazonaws.com/{userPoolId}
   JWT Audience: {your-app-client-id}
   JWT Role Claim: cognito:groups
   JWT Claims:
     - Path: email → email
     - Path: sub → sub
     - Path: name → name
   ```

6. **Save Configuration**

### Step 3: Test JWT Validation

Run this SQL in Supabase SQL Editor to verify JWT configuration:
```sql
-- Check JWT settings
SELECT * FROM auth.settings WHERE key LIKE '%jwt%';
```

## Part 3: Update Flutter Application (10 minutes)

### Step 1: Update Configuration File

1. **Open** `lib/config/app_config.dart`

2. **Update with your values**:
   ```dart
   static const String cognitoUserPoolId = 'us-east-1_XXXXXXXXX';
   static const String cognitoClientId = 'XXXXXXXXXXXXXXXXXXXXXXXXXX';
   static const String cognitoIdentityPoolId = 'us-east-1:XXXX-XXXX-XXXX';
   static const String cognitoRegion = 'us-east-1';
   ```

3. **If using hosted UI**, also update:
   ```dart
   WebDomain: "your-domain.auth.us-east-1.amazoncognito.com"
   ```

### Step 2: Update Environment Variables

1. **Open** `.env` file

2. **Update Cognito values**:
   ```env
   COGNITO_USER_POOL_ID=us-east-1_XXXXXXXXX
   COGNITO_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
   COGNITO_IDENTITY_POOL_ID=us-east-1:XXXX-XXXX-XXXX
   COGNITO_REGION=us-east-1
   ```

### Step 3: Update iOS Configuration (if using SSO)

1. **Open** `ios/Runner/Info.plist`

2. **Add URL Scheme**:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
       <dict>
           <key>CFBundleURLSchemes</key>
           <array>
               <string>myapp</string>
           </array>
       </dict>
   </array>
   ```

### Step 4: Update Android Configuration (if using SSO)

1. **Open** `android/app/src/main/AndroidManifest.xml`

2. **Add Intent Filter**:
   ```xml
   <intent-filter>
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <data android:scheme="myapp" />
   </intent-filter>
   ```

## Part 4: Testing the Setup (15 minutes)

### Step 1: Create Test User

1. **In AWS Cognito Console**
2. **Go to Users and groups**
3. **Create user**:
   ```yaml
   Username: testuser@example.com
   Email: testuser@example.com
   Temporary password: TempPass123!
   ```

### Step 2: Test Authentication Flow

Create a test file `test/auth_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/auth_service.dart';
import '../lib/services/supabase_service.dart';
import '../lib/config/app_config.dart';

void main() {
  test('Configuration is complete', () {
    final config = AppConfig();
    config.validateConfiguration();
    expect(config.isConfigured, true,
      reason: 'Please update app_config.dart with your credentials');
  });

  test('Amplify can be configured', () async {
    final authService = AuthService();
    await authService.configureAmplify();
    expect(authService.isConfigured, true);
  });

  test('Supabase can be initialized', () async {
    final supabaseService = SupabaseService();
    await supabaseService.initialize();
    expect(supabaseService.isInitialized, true);
  });
}
```

Run tests:
```bash
flutter test test/auth_test.dart
```

### Step 3: Manual Testing

1. **Run the app**:
   ```bash
   flutter run
   ```

2. **Test sign in** with your test user

3. **Verify in Supabase**:
   - Check `users` table for new entry
   - Verify JWT token is accepted

## Part 5: Production Checklist

### Security
- [ ] Enable MFA in Cognito for production
- [ ] Review and tighten IAM roles
- [ ] Enable CloudWatch logging
- [ ] Set up monitoring alerts

### Supabase
- [ ] Review RLS policies
- [ ] Test all database operations
- [ ] Enable point-in-time recovery
- [ ] Set up database backups

### Flutter App
- [ ] Remove debug logs
- [ ] Implement proper error handling
- [ ] Add retry logic for network failures
- [ ] Test on real devices

## Troubleshooting

### Common Issues

1. **"Invalid JWT" error in Supabase**
   - Verify JWKS configuration matches Cognito
   - Check issuer and audience settings
   - Ensure token hasn't expired

2. **"User pool does not exist" error**
   - Verify User Pool ID is correct
   - Check region settings
   - Ensure Amplify is configured

3. **"Network error" when connecting**
   - Check internet connectivity
   - Verify Supabase URL is correct
   - Check for CORS issues (web only)

### Debug Commands

Check Supabase JWT configuration:
```sql
-- View current JWT settings
SELECT * FROM auth.settings;

-- Check for auth errors
SELECT * FROM auth.audit_log_entries
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
```

Check Cognito user:
```bash
aws cognito-idp admin-get-user \
  --user-pool-id us-east-1_XXXXXXXXX \
  --username testuser@example.com
```

## Support Resources

- **AWS Cognito Documentation**: https://docs.aws.amazon.com/cognito/
- **Supabase Documentation**: https://supabase.com/docs
- **Amplify Flutter**: https://docs.amplify.aws/lib/auth/getting-started/q/platform/flutter/
- **Project Issues**: Create an issue in the project repository

## Next Steps

After completing this setup:

1. ✅ Test the complete authentication flow
2. ✅ Create sample data in Supabase
3. ✅ Implement the UI screens
4. ✅ Add audio streaming features
5. ✅ Deploy to TestFlight/Play Store

---

**Setup Time Estimate**: 60-90 minutes
**Difficulty**: Intermediate
**Prerequisites**: AWS account, basic knowledge of authentication flows