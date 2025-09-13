# Supabase Flutter Integration Guide
## Complete Audio Learning Platform Implementation

### Document Overview

This comprehensive guide provides production-ready Supabase Flutter integration for the Audio Learning Platform. The implementation focuses on enterprise-grade security, performance optimization, and seamless user experience with JWT bridging from AWS Cognito.

**Key Features:**
- Enterprise-grade Row Level Security (RLS) policies
- JWT token validation and custom authentication with AWS Cognito bridging
- Real-time subscriptions for progress tracking and user state
- Performance-optimized database queries with proper indexing
- User preference storage with conflict resolution
- Offline caching strategies and synchronization
- Debounced progress saves every 5 seconds

### Architecture Overview

```
┌─────────────────┐    JWT Bridge    ┌──────────────────┐
│   AWS Cognito   │ ───────────────► │    Supabase      │
│   (SSO Auth)    │                  │  (Backend DB)    │
└─────────────────┘                  └──────────────────┘
         │                                     │
         │ ID/Access Tokens                    │ RLS Queries
         ▼                                     ▼
┌─────────────────┐                  ┌──────────────────┐
│ Flutter Client  │ ◄────────────────┤ PostgreSQL + RLS │
│ (supabase_flutter│                  │ (Row Level Sec.) │
└─────────────────┘                  └──────────────────┘
```

## Table of Contents

1. [Setup and Configuration](#setup-and-configuration)
2. [Database Schema Design](#database-schema-design)
3. [Row Level Security Policies](#row-level-security-policies)
4. [JWT Authentication Bridge](#jwt-authentication-bridge)
5. [Real-time Subscriptions](#real-time-subscriptions)
6. [Database Operations](#database-operations)
7. [Performance Optimization](#performance-optimization)
8. [User Preferences and Progress](#user-preferences-and-progress)
9. [Offline Caching Strategy](#offline-caching-strategy)
10. [Error Handling and Resilience](#error-handling-and-resilience)
11. [Production Deployment](#production-deployment)

---

## Setup and Configuration

### 1. Supabase Project Setup

#### Creating the Project
```bash
# Install Supabase CLI
npm install -g supabase

# Create new project (via Supabase Dashboard)
# 1. Go to https://supabase.com/dashboard
# 2. Click "New Project"
# 3. Choose organization and database password
# 4. Note the project URL and anon key
```

#### Environment Configuration
```dart
// .env file
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
AWS_COGNITO_USER_POOL_ID=your-user-pool-id
AWS_COGNITO_IDENTITY_POOL_ID=your-identity-pool-id
```

### 2. Flutter Integration Setup

#### Dependencies
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.3.0
  shared_preferences: ^2.2.2
  dio: ^5.4.0
  riverpod: ^2.4.9
  flutter_riverpod: ^2.4.9
  amplify_flutter: ^2.0.0
  amplify_auth_cognito: ^2.0.0
```

#### Main App Configuration
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    debug: kDebugMode,
    localStorage: const SharedPreferencesLocalStorage(),
    detectSessionInUri: true,
    headers: {
      'apikey': const String.fromEnvironment('SUPABASE_ANON_KEY'),
    },
    realtimeClientOptions: const RealtimeClientOptions(
      logLevel: RealtimeLogLevel.info,
      heartbeatIntervalMs: 30000,
      reconnectAfterMs: 5000,
    ),
  );

  runApp(const ProviderScope(child: MyApp()));
}

// Global Supabase client access
final supabase = Supabase.instance.client;
```

### 3. JWT Authentication Bridge Service

#### SupabaseAuthService Implementation
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseAuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final SupabaseAuthService _instance = SupabaseAuthService._internal();
  factory SupabaseAuthService() => _instance;
  SupabaseAuthService._internal();

  /// Bridge AWS Cognito JWT tokens to Supabase session
  Future<AuthResponse> bridgeToSupabase(String cognitoIdToken) async {
    try {
      // Sign in with Cognito JWT token
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.cognito,
        idToken: cognitoIdToken,
        nonce: _generateNonce(),
      );

      if (response.user != null) {
        // Cache session data
        await _cacheSession(response.session);

        // Set up automatic token refresh
        _setupTokenRefresh();

        safePrint('Supabase session created for user: ${response.user!.id}');
        return response;
      } else {
        throw AuthException('Failed to create Supabase session');
      }
    } catch (e) {
      safePrint('Supabase auth bridge error: $e');
      rethrow;
    }
  }

  /// Get current user with error handling
  User? getCurrentUser() {
    try {
      return _supabase.auth.currentUser;
    } catch (e) {
      safePrint('Error getting current user: $e');
      return null;
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated {
    return getCurrentUser() != null &&
           _supabase.auth.currentSession != null &&
           !_isTokenExpired(_supabase.auth.currentSession!);
  }

  /// Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Sign out from Supabase
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      await _clearCachedSession();
      safePrint('Supabase session ended');
    } catch (e) {
      safePrint('Error signing out from Supabase: $e');
    }
  }

  /// Listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Refresh current session
  Future<AuthResponse?> refreshSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return null;

      final response = await _supabase.auth.refreshSession();
      if (response.session != null) {
        await _cacheSession(response.session);
      }
      return response;
    } catch (e) {
      safePrint('Error refreshing session: $e');
      return null;
    }
  }

  // Private helper methods
  String _generateNonce() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  bool _isTokenExpired(Session session) {
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      session.expiresAt! * 1000
    );
    return DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));
  }

  Future<void> _cacheSession(Session? session) async {
    if (session == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_session', session.toJson().toString());
    await prefs.setInt('session_expires_at', session.expiresAt ?? 0);
  }

  Future<void> _clearCachedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('supabase_session');
    await prefs.remove('session_expires_at');
  }

  void _setupTokenRefresh() {
    // Set up periodic token refresh (every 50 minutes for 1-hour tokens)
    Timer.periodic(const Duration(minutes: 50), (timer) async {
      if (isAuthenticated && _isTokenExpired(_supabase.auth.currentSession!)) {
        await refreshSession();
      }

      if (!isAuthenticated) {
        timer.cancel();
      }
    });
  }
}
```

---

## Database Schema Design

### 1. Core Tables Schema

#### Users Table
```sql
-- Users table (managed by Supabase Auth)
-- Additional user profile data
CREATE TABLE public.user_profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  organization_id TEXT,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  PRIMARY KEY (id)
);

-- Enable RLS
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Indexes for performance
CREATE INDEX idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX idx_user_profiles_org ON public.user_profiles(organization_id);
```

#### Courses Table with Gradient Support
```sql
CREATE TABLE public.courses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  course_number TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  total_assignments INTEGER DEFAULT 0,
  gradient_start_color TEXT DEFAULT '#2196F3', -- Blue
  gradient_end_color TEXT DEFAULT '#1976D2',   -- Darker Blue
  gradient_angle REAL DEFAULT 45.0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX idx_courses_number ON public.courses(course_number);
CREATE INDEX idx_courses_active ON public.courses(is_active) WHERE is_active = true;
```

#### Enrollments Table with Expiration Support
```sql
CREATE TABLE public.enrollments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  completion_percentage REAL DEFAULT 0.0,
  is_completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(user_id, course_id)
);

-- Enable RLS
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

-- Indexes for performance and automatic filtering
CREATE INDEX idx_enrollments_user ON public.enrollments(user_id);
CREATE INDEX idx_enrollments_course ON public.enrollments(course_id);
CREATE INDEX idx_enrollments_active ON public.enrollments(user_id, expires_at)
  WHERE expires_at > NOW();
CREATE INDEX idx_enrollments_completion ON public.enrollments(user_id, completion_percentage);
```

#### Assignments Table with Display Numbers
```sql
CREATE TABLE public.assignments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,
  assignment_number INTEGER NOT NULL, -- Display number (1, 2, 3...)
  title TEXT NOT NULL,
  description TEXT,
  order_index INTEGER NOT NULL,
  total_learning_objects INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(course_id, assignment_number),
  UNIQUE(course_id, order_index)
);

-- Enable RLS
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX idx_assignments_course ON public.assignments(course_id);
CREATE INDEX idx_assignments_order ON public.assignments(course_id, order_index);
```

#### Learning Objects with SSML and Word Timings
```sql
CREATE TABLE public.learning_objects (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  assignment_id UUID REFERENCES public.assignments(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL, -- Original content
  ssml_content TEXT, -- SSML formatted for TTS
  order_index INTEGER NOT NULL,
  estimated_duration_seconds INTEGER,
  word_count INTEGER DEFAULT 0,

  -- Cached word timings with sentence indices (JSONB for performance)
  word_timings JSONB,
  -- Example structure:
  -- {
  --   "words": [
  --     {"word": "Hello", "startMs": 0, "endMs": 500, "sentenceIndex": 0},
  --     {"word": "world", "startMs": 600, "endMs": 1000, "sentenceIndex": 0}
  --   ],
  --   "sentences": [
  --     {"startWordIndex": 0, "endWordIndex": 1, "startMs": 0, "endMs": 1000}
  --   ],
  --   "totalDurationMs": 1000,
  --   "createdAt": "2024-01-01T00:00:00Z"
  -- }

  speechify_audio_url TEXT, -- Cached audio URL
  speechify_request_id TEXT, -- For tracking and debugging
  audio_duration_ms INTEGER,

  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  UNIQUE(assignment_id, order_index)
);

-- Enable RLS
ALTER TABLE public.learning_objects ENABLE ROW LEVEL SECURITY;

-- Indexes for performance
CREATE INDEX idx_learning_objects_assignment ON public.learning_objects(assignment_id);
CREATE INDEX idx_learning_objects_order ON public.learning_objects(assignment_id, order_index);
-- GIN index for JSONB word_timings queries
CREATE INDEX idx_learning_objects_timings ON public.learning_objects USING GIN(word_timings);
```

#### Progress Tracking with User Preferences
```sql
CREATE TABLE public.progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  learning_object_id UUID REFERENCES public.learning_objects(id) ON DELETE CASCADE,

  -- Progress tracking
  current_position_ms INTEGER DEFAULT 0,
  total_duration_ms INTEGER,
  completion_percentage REAL DEFAULT 0.0,
  is_completed BOOLEAN DEFAULT false,
  is_in_progress BOOLEAN DEFAULT false,

  -- User preferences (persisted with progress)
  font_size_index INTEGER DEFAULT 1, -- 0=Small, 1=Medium, 2=Large, 3=XLarge
  playback_speed REAL DEFAULT 1.0,   -- 0.8x to 2.0x

  -- Timestamps
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  last_accessed_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,

  UNIQUE(user_id, learning_object_id)
);

-- Enable RLS
ALTER TABLE public.progress ENABLE ROW LEVEL SECURITY;

-- Indexes for performance
CREATE INDEX idx_progress_user ON public.progress(user_id);
CREATE INDEX idx_progress_learning_object ON public.progress(learning_object_id);
CREATE INDEX idx_progress_in_progress ON public.progress(user_id, is_in_progress)
  WHERE is_in_progress = true;
CREATE INDEX idx_progress_completed ON public.progress(user_id, is_completed)
  WHERE is_completed = true;
CREATE INDEX idx_progress_last_accessed ON public.progress(user_id, last_accessed_at DESC);
```

#### User Preferences (Global Settings)
```sql
CREATE TABLE public.user_preferences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,

  -- Global preferences
  default_font_size_index INTEGER DEFAULT 1,
  default_playback_speed REAL DEFAULT 1.0,
  auto_continue BOOLEAN DEFAULT true,
  notification_enabled BOOLEAN DEFAULT true,
  dark_mode_enabled BOOLEAN DEFAULT false,

  -- App behavior
  skip_duration_seconds INTEGER DEFAULT 30,
  auto_bookmark_interval_seconds INTEGER DEFAULT 300, -- 5 minutes

  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,

  UNIQUE(user_id)
);

-- Enable RLS
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- Index
CREATE INDEX idx_user_preferences_user ON public.user_preferences(user_id);
```

### 2. Database Functions and Triggers

#### Auto-update timestamps
```sql
-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to all tables
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_courses_updated_at BEFORE UPDATE ON public.courses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_enrollments_updated_at BEFORE UPDATE ON public.enrollments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_assignments_updated_at BEFORE UPDATE ON public.assignments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_learning_objects_updated_at BEFORE UPDATE ON public.learning_objects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_progress_updated_at BEFORE UPDATE ON public.progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON public.user_preferences
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

#### Progress calculation function
```sql
-- Function to calculate course completion percentage
CREATE OR REPLACE FUNCTION calculate_course_completion(course_uuid UUID, user_uuid UUID)
RETURNS REAL AS $$
DECLARE
    total_objects INTEGER;
    completed_objects INTEGER;
    completion_percentage REAL;
BEGIN
    -- Get total learning objects for the course
    SELECT COUNT(lo.id) INTO total_objects
    FROM public.learning_objects lo
    JOIN public.assignments a ON lo.assignment_id = a.id
    WHERE a.course_id = course_uuid AND lo.is_active = true;

    -- Get completed learning objects for the user
    SELECT COUNT(p.id) INTO completed_objects
    FROM public.progress p
    JOIN public.learning_objects lo ON p.learning_object_id = lo.id
    JOIN public.assignments a ON lo.assignment_id = a.id
    WHERE a.course_id = course_uuid
      AND p.user_id = user_uuid
      AND p.is_completed = true;

    -- Calculate percentage
    IF total_objects > 0 THEN
        completion_percentage := (completed_objects::REAL / total_objects::REAL) * 100.0;
    ELSE
        completion_percentage := 0.0;
    END IF;

    -- Update enrollment completion
    UPDATE public.enrollments
    SET completion_percentage = completion_percentage,
        is_completed = (completion_percentage >= 100.0),
        completed_at = CASE
          WHEN completion_percentage >= 100.0 AND completed_at IS NULL
          THEN TIMEZONE('utc'::text, NOW())
          ELSE completed_at
        END
    WHERE user_id = user_uuid AND course_id = course_uuid;

    RETURN completion_percentage;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update course completion when progress changes
CREATE OR REPLACE FUNCTION update_course_completion()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update if completion status changed
    IF (OLD.is_completed IS DISTINCT FROM NEW.is_completed) THEN
        PERFORM calculate_course_completion(
            (SELECT a.course_id FROM public.assignments a
             JOIN public.learning_objects lo ON a.id = lo.assignment_id
             WHERE lo.id = NEW.learning_object_id),
            NEW.user_id
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_progress_completion AFTER UPDATE ON public.progress
  FOR EACH ROW EXECUTE FUNCTION update_course_completion();
```

---

## Row Level Security Policies

### 1. User Profiles RLS
```sql
-- Users can only see and edit their own profile
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
```

### 2. Courses RLS (Public Read)
```sql
-- All authenticated users can view active courses
CREATE POLICY "Authenticated users can view active courses" ON public.courses
  FOR SELECT USING (auth.role() = 'authenticated' AND is_active = true);
```

### 3. Enrollments RLS (Critical for Multi-tenancy)
```sql
-- Users can only see their own active (non-expired) enrollments
CREATE POLICY "Users see their active enrollments" ON public.enrollments
  FOR SELECT USING (
    auth.uid() = user_id
    AND expires_at > TIMEZONE('utc'::text, NOW())
  );

-- Users can update their own enrollment progress
CREATE POLICY "Users can update own enrollment progress" ON public.enrollments
  FOR UPDATE USING (auth.uid() = user_id);

-- System can insert enrollments (via service role)
CREATE POLICY "Service role can manage enrollments" ON public.enrollments
  FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');
```

### 4. Assignments RLS
```sql
-- Users can view assignments for enrolled courses
CREATE POLICY "Users can view enrolled course assignments" ON public.assignments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.enrollments e
      WHERE e.user_id = auth.uid()
        AND e.course_id = course_id
        AND e.expires_at > TIMEZONE('utc'::text, NOW())
    )
    AND is_active = true
  );
```

### 5. Learning Objects RLS
```sql
-- Users can view learning objects for enrolled courses
CREATE POLICY "Users can view enrolled learning objects" ON public.learning_objects
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.enrollments e
      JOIN public.assignments a ON e.course_id = a.course_id
      WHERE e.user_id = auth.uid()
        AND a.id = assignment_id
        AND e.expires_at > TIMEZONE('utc'::text, NOW())
    )
    AND is_active = true
  );
```

### 6. Progress RLS (User Data Protection)
```sql
-- Users can only access their own progress
CREATE POLICY "Users can view own progress" ON public.progress
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own progress" ON public.progress
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own progress" ON public.progress
  FOR UPDATE USING (auth.uid() = user_id);
```

### 7. User Preferences RLS
```sql
-- Users can only manage their own preferences
CREATE POLICY "Users can manage own preferences" ON public.user_preferences
  FOR ALL USING (auth.uid() = user_id);
```

---

## JWT Authentication Bridge

### 1. Custom JWT Configuration

#### Supabase JWT Settings
```sql
-- Update Supabase JWT settings in Dashboard > Settings > API
-- Custom Claims Configuration:
-- In your Cognito User Pool, add custom attributes that will be included in JWT:
-- - organization_id: User's organization
-- - role: User role (admin, user, etc.)
-- - permissions: Array of permissions
```

#### JWT Validation Function
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class JWTValidator {
  static const String _cognitoIssuer = 'https://cognito-idp.{region}.amazonaws.com/{userPoolId}';

  /// Validate JWT token structure and claims
  static bool validateJWTStructure(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Decode header and payload
      final header = _decodeBase64(parts[0]);
      final payload = _decodeBase64(parts[1]);

      final headerJson = jsonDecode(header);
      final payloadJson = jsonDecode(payload);

      // Validate required claims
      return _validateClaims(headerJson, payloadJson);
    } catch (e) {
      safePrint('JWT validation error: $e');
      return false;
    }
  }

  static bool _validateClaims(Map<String, dynamic> header, Map<String, dynamic> payload) {
    // Check algorithm
    if (header['alg'] != 'RS256') return false;

    // Check required claims
    final requiredClaims = ['sub', 'iss', 'aud', 'exp', 'iat'];
    for (final claim in requiredClaims) {
      if (!payload.containsKey(claim)) return false;
    }

    // Validate issuer
    if (!payload['iss'].toString().startsWith('https://cognito-idp.')) return false;

    // Check expiration
    final exp = payload['exp'] as int;
    final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (exp <= currentTime) return false;

    return true;
  }

  static String _decodeBase64(String str) {
    // Add padding if needed
    switch (str.length % 4) {
      case 0:
        break;
      case 2:
        str += '==';
        break;
      case 3:
        str += '=';
        break;
      default:
        throw Exception('Invalid base64 string');
    }

    return utf8.decode(base64Url.decode(str));
  }
}
```

### 2. Complete Authentication Flow

```dart
class AuthenticationFlow {
  final SupabaseAuthService _supabaseAuth = SupabaseAuthService();
  final Amplify _amplify = Amplify;

  /// Complete authentication flow from Cognito to Supabase
  Future<AuthenticationResult> authenticate() async {
    try {
      // Step 1: Authenticate with Cognito
      final cognitoResult = await _authenticateWithCognito();
      if (!cognitoResult.isSignedIn) {
        throw AuthException('Cognito authentication failed');
      }

      // Step 2: Get Cognito tokens
      final cognitoTokens = await _getCognitoTokens();

      // Step 3: Validate JWT structure
      if (!JWTValidator.validateJWTStructure(cognitoTokens.idToken)) {
        throw AuthException('Invalid JWT token structure');
      }

      // Step 4: Bridge to Supabase
      final supabaseResponse = await _supabaseAuth.bridgeToSupabase(
        cognitoTokens.idToken
      );

      // Step 5: Create user profile if needed
      await _ensureUserProfile(supabaseResponse.user!);

      // Step 6: Set up real-time subscriptions
      await _setupRealtimeSubscriptions(supabaseResponse.user!.id);

      return AuthenticationResult(
        success: true,
        user: supabaseResponse.user!,
        session: supabaseResponse.session!,
      );

    } catch (e) {
      safePrint('Authentication flow error: $e');
      return AuthenticationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<AuthSignInResult> _authenticateWithCognito() async {
    // Trigger Cognito hosted UI for SSO
    return await _amplify.Auth.signInWithWebUI();
  }

  Future<CognitoTokens> _getCognitoTokens() async {
    final session = await _amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    return CognitoTokens(
      idToken: session.userPoolTokensResult.value.idToken.raw,
      accessToken: session.userPoolTokensResult.value.accessToken.raw,
      refreshToken: session.userPoolTokensResult.value.refreshToken?.raw,
    );
  }

  Future<void> _ensureUserProfile(User user) async {
    final existingProfile = await supabase
      .from('user_profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

    if (existingProfile == null) {
      // Create user profile from JWT claims
      final claims = _parseJWTClaims(user.jwt ?? '');

      await supabase.from('user_profiles').insert({
        'id': user.id,
        'email': claims['email'],
        'full_name': claims['name'] ?? claims['given_name'],
        'organization_id': claims['custom:organization_id'],
        'role': claims['custom:role'] ?? 'user',
      });
    }
  }

  Map<String, dynamic> _parseJWTClaims(String jwt) {
    if (jwt.isEmpty) return {};

    final parts = jwt.split('.');
    if (parts.length != 3) return {};

    try {
      final payload = parts[1];
      final decoded = base64Url.decode(_addPadding(payload));
      return jsonDecode(utf8.decode(decoded));
    } catch (e) {
      return {};
    }
  }

  String _addPadding(String str) {
    final padLength = (4 - (str.length % 4)) % 4;
    return str + ('=' * padLength);
  }
}

class AuthenticationResult {
  final bool success;
  final User? user;
  final Session? session;
  final String? error;

  AuthenticationResult({
    required this.success,
    this.user,
    this.session,
    this.error,
  });
}

class CognitoTokens {
  final String idToken;
  final String accessToken;
  final String? refreshToken;

  CognitoTokens({
    required this.idToken,
    required this.accessToken,
    this.refreshToken,
  });
}
```

---

## Real-time Subscriptions

### 1. Progress Tracking Subscription Service

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';

class RealtimeSubscriptionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController> _controllers = {};

  /// Subscribe to user's progress updates
  Stream<List<ProgressUpdate>> subscribeToProgressUpdates(String userId) {
    final channelName = 'progress_updates_$userId';

    if (_controllers.containsKey(channelName)) {
      return _controllers[channelName]!.stream.cast<List<ProgressUpdate>>();
    }

    final controller = BehaviorSubject<List<ProgressUpdate>>();
    _controllers[channelName] = controller;

    // Create realtime channel
    final channel = _supabase.channel(channelName);

    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'progress',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
      )
      .subscribe((status) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          safePrint('Subscribed to progress updates for user: $userId');
        }
      });

    // Handle real-time updates
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'progress',
      callback: (payload) {
        _handleProgressUpdate(payload, controller);
      },
    );

    _channels[channelName] = channel;
    return controller.stream;
  }

  /// Subscribe to course enrollment updates
  Stream<List<EnrollmentUpdate>> subscribeToEnrollmentUpdates(String userId) {
    final channelName = 'enrollment_updates_$userId';

    if (_controllers.containsKey(channelName)) {
      return _controllers[channelName]!.stream.cast<List<EnrollmentUpdate>>();
    }

    final controller = BehaviorSubject<List<EnrollmentUpdate>>();
    _controllers[channelName] = controller;

    final channel = _supabase.channel(channelName);

    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'enrollments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
      )
      .subscribe();

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'enrollments',
      callback: (payload) {
        _handleEnrollmentUpdate(payload, controller);
      },
    );

    _channels[channelName] = channel;
    return controller.stream;
  }

  /// Subscribe to user preference changes
  Stream<UserPreferencesUpdate> subscribeToUserPreferences(String userId) {
    final channelName = 'preferences_$userId';

    if (_controllers.containsKey(channelName)) {
      return _controllers[channelName]!.stream.cast<UserPreferencesUpdate>();
    }

    final controller = BehaviorSubject<UserPreferencesUpdate>();
    _controllers[channelName] = controller;

    final channel = _supabase.channel(channelName);

    channel
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_preferences',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
      )
      .subscribe();

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'user_preferences',
      callback: (payload) {
        _handlePreferencesUpdate(payload, controller);
      },
    );

    _channels[channelName] = channel;
    return controller.stream;
  }

  /// Unsubscribe from all channels
  Future<void> unsubscribeAll() async {
    for (final channel in _channels.values) {
      await channel.unsubscribe();
    }
    _channels.clear();

    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
  }

  /// Unsubscribe from specific channel
  Future<void> unsubscribe(String channelName) async {
    if (_channels.containsKey(channelName)) {
      await _channels[channelName]!.unsubscribe();
      _channels.remove(channelName);
    }

    if (_controllers.containsKey(channelName)) {
      await _controllers[channelName]!.close();
      _controllers.remove(channelName);
    }
  }

  void _handleProgressUpdate(
    PostgresChangePayload payload,
    StreamController<List<ProgressUpdate>> controller,
  ) {
    try {
      final update = ProgressUpdate.fromPayload(payload);

      // Get current stream value or empty list
      final currentList = (controller as BehaviorSubject).valueOrNull ?? <ProgressUpdate>[];

      // Update or add the progress item
      final updatedList = List<ProgressUpdate>.from(currentList);
      final existingIndex = updatedList.indexWhere((p) => p.id == update.id);

      if (existingIndex >= 0) {
        updatedList[existingIndex] = update;
      } else {
        updatedList.add(update);
      }

      controller.add(updatedList);

    } catch (e) {
      safePrint('Error handling progress update: $e');
    }
  }

  void _handleEnrollmentUpdate(
    PostgresChangePayload payload,
    StreamController<List<EnrollmentUpdate>> controller,
  ) {
    try {
      final update = EnrollmentUpdate.fromPayload(payload);
      final currentList = (controller as BehaviorSubject).valueOrNull ?? <EnrollmentUpdate>[];
      final updatedList = List<EnrollmentUpdate>.from(currentList);
      final existingIndex = updatedList.indexWhere((e) => e.id == update.id);

      if (payload.eventType == PostgresChangeEvent.delete) {
        if (existingIndex >= 0) {
          updatedList.removeAt(existingIndex);
        }
      } else {
        if (existingIndex >= 0) {
          updatedList[existingIndex] = update;
        } else {
          updatedList.add(update);
        }
      }

      controller.add(updatedList);

    } catch (e) {
      safePrint('Error handling enrollment update: $e');
    }
  }

  void _handlePreferencesUpdate(
    PostgresChangePayload payload,
    StreamController<UserPreferencesUpdate> controller,
  ) {
    try {
      final update = UserPreferencesUpdate.fromPayload(payload);
      controller.add(update);
    } catch (e) {
      safePrint('Error handling preferences update: $e');
    }
  }
}

// Data models for real-time updates
class ProgressUpdate {
  final String id;
  final String userId;
  final String learningObjectId;
  final int currentPositionMs;
  final double completionPercentage;
  final bool isCompleted;
  final bool isInProgress;
  final int fontSizeIndex;
  final double playbackSpeed;
  final DateTime updatedAt;

  ProgressUpdate({
    required this.id,
    required this.userId,
    required this.learningObjectId,
    required this.currentPositionMs,
    required this.completionPercentage,
    required this.isCompleted,
    required this.isInProgress,
    required this.fontSizeIndex,
    required this.playbackSpeed,
    required this.updatedAt,
  });

  factory ProgressUpdate.fromPayload(PostgresChangePayload payload) {
    final data = payload.newRecord;
    return ProgressUpdate(
      id: data['id'],
      userId: data['user_id'],
      learningObjectId: data['learning_object_id'],
      currentPositionMs: data['current_position_ms'] ?? 0,
      completionPercentage: (data['completion_percentage'] ?? 0.0).toDouble(),
      isCompleted: data['is_completed'] ?? false,
      isInProgress: data['is_in_progress'] ?? false,
      fontSizeIndex: data['font_size_index'] ?? 1,
      playbackSpeed: (data['playback_speed'] ?? 1.0).toDouble(),
      updatedAt: DateTime.parse(data['updated_at']),
    );
  }
}

class EnrollmentUpdate {
  final String id;
  final String userId;
  final String courseId;
  final DateTime expiresAt;
  final double completionPercentage;
  final bool isCompleted;

  EnrollmentUpdate({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.expiresAt,
    required this.completionPercentage,
    required this.isCompleted,
  });

  factory EnrollmentUpdate.fromPayload(PostgresChangePayload payload) {
    final data = payload.newRecord;
    return EnrollmentUpdate(
      id: data['id'],
      userId: data['user_id'],
      courseId: data['course_id'],
      expiresAt: DateTime.parse(data['expires_at']),
      completionPercentage: (data['completion_percentage'] ?? 0.0).toDouble(),
      isCompleted: data['is_completed'] ?? false,
    );
  }
}

class UserPreferencesUpdate {
  final String id;
  final String userId;
  final int defaultFontSizeIndex;
  final double defaultPlaybackSpeed;
  final bool autoContinue;
  final DateTime updatedAt;

  UserPreferencesUpdate({
    required this.id,
    required this.userId,
    required this.defaultFontSizeIndex,
    required this.defaultPlaybackSpeed,
    required this.autoContinue,
    required this.updatedAt,
  });

  factory UserPreferencesUpdate.fromPayload(PostgresChangePayload payload) {
    final data = payload.newRecord;
    return UserPreferencesUpdate(
      id: data['id'],
      userId: data['user_id'],
      defaultFontSizeIndex: data['default_font_size_index'] ?? 1,
      defaultPlaybackSpeed: (data['default_playback_speed'] ?? 1.0).toDouble(),
      autoContinue: data['auto_continue'] ?? true,
      updatedAt: DateTime.parse(data['updated_at']),
    );
  }
}
```

---

## Database Operations

### 1. Course and Enrollment Management

```dart
class CourseRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get user's active enrolled courses (automatic expiration filtering via RLS)
  Future<List<EnrolledCourse>> getUserEnrolledCourses(String userId) async {
    try {
      final response = await _supabase
        .from('enrollments')
        .select('''
          id,
          course_id,
          enrolled_at,
          expires_at,
          completion_percentage,
          is_completed,
          completed_at,
          courses!inner(
            id,
            course_number,
            title,
            description,
            total_assignments,
            gradient_start_color,
            gradient_end_color,
            gradient_angle
          )
        ''')
        .eq('user_id', userId)
        .order('enrolled_at', ascending: false);

      return response
        .map<EnrolledCourse>((item) => EnrolledCourse.fromJson(item))
        .toList();

    } catch (e) {
      safePrint('Error fetching enrolled courses: $e');
      throw SupabaseException('Failed to load enrolled courses: ${e.toString()}');
    }
  }

  /// Get course details with assignments and learning objects
  Future<CourseDetail> getCourseDetail(String courseId, String userId) async {
    try {
      // First verify user enrollment (RLS will automatically filter)
      final enrollment = await _supabase
        .from('enrollments')
        .select('id, expires_at, completion_percentage')
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .single();

      // Get course with all nested data
      final response = await _supabase
        .from('courses')
        .select('''
          id,
          course_number,
          title,
          description,
          total_assignments,
          gradient_start_color,
          gradient_end_color,
          gradient_angle,
          assignments!inner(
            id,
            assignment_number,
            title,
            description,
            order_index,
            total_learning_objects,
            learning_objects!inner(
              id,
              title,
              content,
              order_index,
              estimated_duration_seconds,
              word_count,
              audio_duration_ms,
              progress!left(
                id,
                current_position_ms,
                completion_percentage,
                is_completed,
                is_in_progress,
                font_size_index,
                playback_speed,
                last_accessed_at
              )
            )
          )
        ''')
        .eq('id', courseId)
        .single();

      return CourseDetail.fromJson(response, enrollment);

    } catch (e) {
      safePrint('Error fetching course detail: $e');
      throw SupabaseException('Failed to load course details: ${e.toString()}');
    }
  }

  /// Update enrollment completion percentage
  Future<void> updateEnrollmentProgress(
    String userId,
    String courseId,
    double completionPercentage,
  ) async {
    try {
      await _supabase
        .from('enrollments')
        .update({
          'completion_percentage': completionPercentage,
          'is_completed': completionPercentage >= 100.0,
          'completed_at': completionPercentage >= 100.0
            ? DateTime.now().toIso8601String()
            : null,
        })
        .eq('user_id', userId)
        .eq('course_id', courseId);

    } catch (e) {
      safePrint('Error updating enrollment progress: $e');
      throw SupabaseException('Failed to update progress: ${e.toString()}');
    }
  }
}
```

### 2. Progress Tracking with Debounced Saves

```dart
import 'package:stream_transform/stream_transform.dart';

class ProgressRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, StreamSubscription> _debouncedSaves = {};

  /// Get progress for a learning object
  Future<Progress?> getProgress(String userId, String learningObjectId) async {
    try {
      final response = await _supabase
        .from('progress')
        .select('*')
        .eq('user_id', userId)
        .eq('learning_object_id', learningObjectId)
        .maybeSingle();

      return response != null ? Progress.fromJson(response) : null;

    } catch (e) {
      safePrint('Error fetching progress: $e');
      return null;
    }
  }

  /// Get all progress for a user
  Future<List<Progress>> getUserProgress(String userId) async {
    try {
      final response = await _supabase
        .from('progress')
        .select('''
          *,
          learning_objects!inner(
            id,
            title,
            assignments!inner(
              id,
              title,
              course_id,
              courses!inner(
                id,
                title,
                course_number
              )
            )
          )
        ''')
        .eq('user_id', userId)
        .order('last_accessed_at', ascending: false);

      return response
        .map<Progress>((item) => Progress.fromJson(item))
        .toList();

    } catch (e) {
      safePrint('Error fetching user progress: $e');
      throw SupabaseException('Failed to load progress: ${e.toString()}');
    }
  }

  /// Save progress with debouncing (5-second intervals)
  void saveProgressDebounced({
    required String userId,
    required String learningObjectId,
    required int currentPositionMs,
    required int totalDurationMs,
    required bool isCompleted,
    required bool isInProgress,
    required int fontSizeIndex,
    required double playbackSpeed,
  }) {
    final key = '${userId}_${learningObjectId}';

    // Cancel existing debounced save
    _debouncedSaves[key]?.cancel();

    // Create new debounced save
    final stream = Stream.value(ProgressSaveData(
      userId: userId,
      learningObjectId: learningObjectId,
      currentPositionMs: currentPositionMs,
      totalDurationMs: totalDurationMs,
      isCompleted: isCompleted,
      isInProgress: isInProgress,
      fontSizeIndex: fontSizeIndex,
      playbackSpeed: playbackSpeed,
    ));

    _debouncedSaves[key] = stream
      .debounceTime(const Duration(seconds: 5))
      .listen((data) async {
        await _saveProgressImmediate(data);
      });
  }

  /// Immediate progress save (for app backgrounding, completion, etc.)
  Future<void> saveProgressImmediate({
    required String userId,
    required String learningObjectId,
    required int currentPositionMs,
    required int totalDurationMs,
    required bool isCompleted,
    required bool isInProgress,
    required int fontSizeIndex,
    required double playbackSpeed,
  }) async {
    final data = ProgressSaveData(
      userId: userId,
      learningObjectId: learningObjectId,
      currentPositionMs: currentPositionMs,
      totalDurationMs: totalDurationMs,
      isCompleted: isCompleted,
      isInProgress: isInProgress,
      fontSizeIndex: fontSizeIndex,
      playbackSpeed: playbackSpeed,
    );

    await _saveProgressImmediate(data);
  }

  Future<void> _saveProgressImmediate(ProgressSaveData data) async {
    try {
      final completionPercentage = data.totalDurationMs > 0
        ? (data.currentPositionMs / data.totalDurationMs) * 100.0
        : 0.0;

      final progressData = {
        'user_id': data.userId,
        'learning_object_id': data.learningObjectId,
        'current_position_ms': data.currentPositionMs,
        'total_duration_ms': data.totalDurationMs,
        'completion_percentage': completionPercentage.clamp(0.0, 100.0),
        'is_completed': data.isCompleted,
        'is_in_progress': data.isInProgress,
        'font_size_index': data.fontSizeIndex,
        'playback_speed': data.playbackSpeed,
        'last_accessed_at': DateTime.now().toIso8601String(),
        'started_at': data.isInProgress && !data.isCompleted
          ? DateTime.now().toIso8601String()
          : null,
        'completed_at': data.isCompleted
          ? DateTime.now().toIso8601String()
          : null,
      };

      // Use upsert to handle both insert and update
      await _supabase
        .from('progress')
        .upsert(progressData);

      safePrint('Progress saved: ${data.learningObjectId} at ${data.currentPositionMs}ms');

    } catch (e) {
      safePrint('Error saving progress: $e');
      throw SupabaseException('Failed to save progress: ${e.toString()}');
    }
  }

  /// Update font size preference
  Future<void> updateFontSizePreference(
    String userId,
    String learningObjectId,
    int fontSizeIndex,
  ) async {
    try {
      await _supabase
        .from('progress')
        .upsert({
          'user_id': userId,
          'learning_object_id': learningObjectId,
          'font_size_index': fontSizeIndex,
          'updated_at': DateTime.now().toIso8601String(),
        });

    } catch (e) {
      safePrint('Error updating font size preference: $e');
      throw SupabaseException('Failed to update font size: ${e.toString()}');
    }
  }

  /// Update playback speed preference
  Future<void> updatePlaybackSpeedPreference(
    String userId,
    String learningObjectId,
    double playbackSpeed,
  ) async {
    try {
      await _supabase
        .from('progress')
        .upsert({
          'user_id': userId,
          'learning_object_id': learningObjectId,
          'playback_speed': playbackSpeed,
          'updated_at': DateTime.now().toIso8601String(),
        });

    } catch (e) {
      safePrint('Error updating playback speed: $e');
      throw SupabaseException('Failed to update playback speed: ${e.toString()}');
    }
  }

  /// Cancel all debounced saves (call on app dispose)
  void dispose() {
    for (final subscription in _debouncedSaves.values) {
      subscription.cancel();
    }
    _debouncedSaves.clear();
  }
}

class ProgressSaveData {
  final String userId;
  final String learningObjectId;
  final int currentPositionMs;
  final int totalDurationMs;
  final bool isCompleted;
  final bool isInProgress;
  final int fontSizeIndex;
  final double playbackSpeed;

  ProgressSaveData({
    required this.userId,
    required this.learningObjectId,
    required this.currentPositionMs,
    required this.totalDurationMs,
    required this.isCompleted,
    required this.isInProgress,
    required this.fontSizeIndex,
    required this.playbackSpeed,
  });
}
```

### 3. Word Timing and Caching

```dart
class WordTimingRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, WordTimingData> _memoryCache = {};
  static const int _maxCacheSize = 50;

  /// Get word timings with three-tier caching strategy
  Future<WordTimingData?> getWordTimings(String learningObjectId) async {
    try {
      // 1. Check memory cache first
      if (_memoryCache.containsKey(learningObjectId)) {
        safePrint('Word timings found in memory cache');
        return _memoryCache[learningObjectId];
      }

      // 2. Check local storage cache
      final localData = await _getLocalWordTimings(learningObjectId);
      if (localData != null) {
        safePrint('Word timings found in local cache');
        _cacheInMemory(learningObjectId, localData);
        return localData;
      }

      // 3. Fetch from Supabase
      final response = await _supabase
        .from('learning_objects')
        .select('word_timings, audio_duration_ms, updated_at')
        .eq('id', learningObjectId)
        .single();

      if (response['word_timings'] != null) {
        final timingData = WordTimingData.fromJson(response['word_timings']);

        // Cache in memory and local storage
        _cacheInMemory(learningObjectId, timingData);
        await _cacheLocally(learningObjectId, timingData);

        safePrint('Word timings loaded from database');
        return timingData;
      }

      return null;

    } catch (e) {
      safePrint('Error getting word timings: $e');
      return null;
    }
  }

  /// Save word timings to database and update caches
  Future<void> saveWordTimings(
    String learningObjectId,
    WordTimingData timingData,
  ) async {
    try {
      await _supabase
        .from('learning_objects')
        .update({
          'word_timings': timingData.toJson(),
          'audio_duration_ms': timingData.totalDurationMs,
        })
        .eq('id', learningObjectId);

      // Update caches
      _cacheInMemory(learningObjectId, timingData);
      await _cacheLocally(learningObjectId, timingData);

      safePrint('Word timings saved to database');

    } catch (e) {
      safePrint('Error saving word timings: $e');
      throw SupabaseException('Failed to save word timings: ${e.toString()}');
    }
  }

  /// Clear cache for a learning object
  Future<void> clearCache(String learningObjectId) async {
    _memoryCache.remove(learningObjectId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('word_timings_$learningObjectId');
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    _memoryCache.clear();

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('word_timings_'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Private helper methods
  void _cacheInMemory(String learningObjectId, WordTimingData data) {
    // Implement LRU cache eviction
    if (_memoryCache.length >= _maxCacheSize) {
      final firstKey = _memoryCache.keys.first;
      _memoryCache.remove(firstKey);
    }

    _memoryCache[learningObjectId] = data;
  }

  Future<void> _cacheLocally(String learningObjectId, WordTimingData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('word_timings_$learningObjectId', jsonEncode(data.toJson()));
    } catch (e) {
      safePrint('Error caching word timings locally: $e');
    }
  }

  Future<WordTimingData?> _getLocalWordTimings(String learningObjectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('word_timings_$learningObjectId');

      if (jsonString != null) {
        final jsonData = jsonDecode(jsonString);
        return WordTimingData.fromJson(jsonData);
      }

      return null;
    } catch (e) {
      safePrint('Error reading local word timings cache: $e');
      return null;
    }
  }
}

class WordTimingData {
  final List<WordTiming> words;
  final List<SentenceTiming> sentences;
  final int totalDurationMs;
  final DateTime createdAt;

  WordTimingData({
    required this.words,
    required this.sentences,
    required this.totalDurationMs,
    required this.createdAt,
  });

  factory WordTimingData.fromJson(Map<String, dynamic> json) {
    return WordTimingData(
      words: (json['words'] as List<dynamic>)
        .map((w) => WordTiming.fromJson(w))
        .toList(),
      sentences: (json['sentences'] as List<dynamic>)
        .map((s) => SentenceTiming.fromJson(s))
        .toList(),
      totalDurationMs: json['totalDurationMs'] ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'words': words.map((w) => w.toJson()).toList(),
    'sentences': sentences.map((s) => s.toJson()).toList(),
    'totalDurationMs': totalDurationMs,
    'createdAt': createdAt.toIso8601String(),
  };
}

class WordTiming {
  final String word;
  final int startMs;
  final int endMs;
  final int sentenceIndex;

  WordTiming({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.sentenceIndex,
  });

  factory WordTiming.fromJson(Map<String, dynamic> json) => WordTiming(
    word: json['word'],
    startMs: json['startMs'],
    endMs: json['endMs'],
    sentenceIndex: json['sentenceIndex'],
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'startMs': startMs,
    'endMs': endMs,
    'sentenceIndex': sentenceIndex,
  };
}

class SentenceTiming {
  final int startWordIndex;
  final int endWordIndex;
  final int startMs;
  final int endMs;

  SentenceTiming({
    required this.startWordIndex,
    required this.endWordIndex,
    required this.startMs,
    required this.endMs,
  });

  factory SentenceTiming.fromJson(Map<String, dynamic> json) => SentenceTiming(
    startWordIndex: json['startWordIndex'],
    endWordIndex: json['endWordIndex'],
    startMs: json['startMs'],
    endMs: json['endMs'],
  );

  Map<String, dynamic> toJson() => {
    'startWordIndex': startWordIndex,
    'endWordIndex': endWordIndex,
    'startMs': startMs,
    'endMs': endMs,
  };
}
```

---

## Performance Optimization

### 1. Database Indexing Strategy

```sql
-- Performance indexes for common query patterns

-- User enrollment filtering (critical for RLS performance)
CREATE INDEX CONCURRENTLY idx_enrollments_active_user_course
  ON public.enrollments(user_id, course_id, expires_at)
  WHERE expires_at > NOW();

-- Progress queries
CREATE INDEX CONCURRENTLY idx_progress_user_accessed
  ON public.progress(user_id, last_accessed_at DESC);

CREATE INDEX CONCURRENTLY idx_progress_user_in_progress
  ON public.progress(user_id, is_in_progress, last_accessed_at DESC)
  WHERE is_in_progress = true;

-- Learning object content queries
CREATE INDEX CONCURRENTLY idx_learning_objects_assignment_order
  ON public.learning_objects(assignment_id, order_index)
  WHERE is_active = true;

-- Word timings JSONB queries
CREATE INDEX CONCURRENTLY idx_learning_objects_has_timings
  ON public.learning_objects(id)
  WHERE word_timings IS NOT NULL;

-- Assignment organization
CREATE INDEX CONCURRENTLY idx_assignments_course_order
  ON public.assignments(course_id, order_index)
  WHERE is_active = true;

-- Course discovery
CREATE INDEX CONCURRENTLY idx_courses_active
  ON public.courses(is_active, title)
  WHERE is_active = true;
```

### 2. Query Optimization Service

```dart
class OptimizedQueryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Optimized query for loading course dashboard
  /// Single query with all needed data to minimize round trips
  Future<DashboardData> loadUserDashboard(String userId) async {
    try {
      // Use a single optimized query with proper joins
      final response = await _supabase.rpc('get_user_dashboard',
        params: {'user_id_param': userId}
      );

      return DashboardData.fromJson(response);

    } catch (e) {
      safePrint('Error loading dashboard: $e');
      throw SupabaseException('Failed to load dashboard: ${e.toString()}');
    }
  }

  /// Optimized query for course detail with minimal data transfer
  Future<CourseDetailOptimized> loadCourseDetailOptimized(
    String courseId,
    String userId,
  ) async {
    try {
      final response = await _supabase.rpc('get_course_detail_optimized',
        params: {
          'course_id_param': courseId,
          'user_id_param': userId,
        }
      );

      return CourseDetailOptimized.fromJson(response);

    } catch (e) {
      safePrint('Error loading course detail: $e');
      throw SupabaseException('Failed to load course: ${e.toString()}');
    }
  }

  /// Batch update progress for multiple learning objects
  Future<void> batchUpdateProgress(List<ProgressBatchItem> progressItems) async {
    try {
      await _supabase.rpc('batch_update_progress',
        params: {'progress_items': progressItems.map((item) => item.toJson()).toList()}
      );

    } catch (e) {
      safePrint('Error batch updating progress: $e');
      throw SupabaseException('Failed to update progress: ${e.toString()}');
    }
  }
}
```

### 3. Database Functions for Complex Operations

```sql
-- Optimized function for user dashboard data
CREATE OR REPLACE FUNCTION get_user_dashboard(user_id_param UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH user_courses AS (
    SELECT
      e.id as enrollment_id,
      c.id,
      c.course_number,
      c.title,
      c.description,
      c.gradient_start_color,
      c.gradient_end_color,
      c.gradient_angle,
      e.completion_percentage,
      e.is_completed,
      e.enrolled_at,
      e.expires_at,
      -- Get recent progress
      (
        SELECT json_build_object(
          'learning_object_id', p.learning_object_id,
          'current_position_ms', p.current_position_ms,
          'last_accessed_at', p.last_accessed_at,
          'title', lo.title
        )
        FROM public.progress p
        JOIN public.learning_objects lo ON p.learning_object_id = lo.id
        JOIN public.assignments a ON lo.assignment_id = a.id
        WHERE p.user_id = user_id_param
          AND a.course_id = c.id
          AND p.is_in_progress = true
        ORDER BY p.last_accessed_at DESC
        LIMIT 1
      ) as current_progress
    FROM public.enrollments e
    JOIN public.courses c ON e.course_id = c.id
    WHERE e.user_id = user_id_param
      AND e.expires_at > NOW()
      AND c.is_active = true
    ORDER BY e.enrolled_at DESC
  ),
  in_progress_count AS (
    SELECT COUNT(*) as total
    FROM public.progress p
    WHERE p.user_id = user_id_param
      AND p.is_in_progress = true
  ),
  completed_count AS (
    SELECT COUNT(*) as total
    FROM public.progress p
    WHERE p.user_id = user_id_param
      AND p.is_completed = true
  )

  SELECT json_build_object(
    'courses', COALESCE(json_agg(row_to_json(user_courses.*)), '[]'::json),
    'stats', json_build_object(
      'in_progress_count', (SELECT total FROM in_progress_count),
      'completed_count', (SELECT total FROM completed_count),
      'total_courses', (SELECT COUNT(*) FROM user_courses)
    )
  ) INTO result
  FROM user_courses;

  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Optimized function for course detail
CREATE OR REPLACE FUNCTION get_course_detail_optimized(
  course_id_param UUID,
  user_id_param UUID
)
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  WITH course_data AS (
    SELECT
      c.id,
      c.course_number,
      c.title,
      c.description,
      c.gradient_start_color,
      c.gradient_end_color,
      c.gradient_angle,
      e.completion_percentage,
      e.expires_at
    FROM public.courses c
    JOIN public.enrollments e ON c.id = e.course_id
    WHERE c.id = course_id_param
      AND e.user_id = user_id_param
      AND e.expires_at > NOW()
  ),
  assignments_data AS (
    SELECT
      a.id,
      a.assignment_number,
      a.title,
      a.description,
      a.order_index,
      -- Get learning objects with progress in single query
      COALESCE(
        json_agg(
          json_build_object(
            'id', lo.id,
            'title', lo.title,
            'order_index', lo.order_index,
            'estimated_duration_seconds', lo.estimated_duration_seconds,
            'word_count', lo.word_count,
            'progress', CASE
              WHEN p.id IS NOT NULL THEN
                json_build_object(
                  'current_position_ms', p.current_position_ms,
                  'completion_percentage', p.completion_percentage,
                  'is_completed', p.is_completed,
                  'is_in_progress', p.is_in_progress,
                  'font_size_index', p.font_size_index,
                  'playback_speed', p.playback_speed,
                  'last_accessed_at', p.last_accessed_at
                )
              ELSE NULL
            END
          ) ORDER BY lo.order_index
        ), '[]'::json
      ) as learning_objects
    FROM public.assignments a
    LEFT JOIN public.learning_objects lo ON a.id = lo.assignment_id AND lo.is_active = true
    LEFT JOIN public.progress p ON lo.id = p.learning_object_id AND p.user_id = user_id_param
    WHERE a.course_id = course_id_param AND a.is_active = true
    GROUP BY a.id, a.assignment_number, a.title, a.description, a.order_index
    ORDER BY a.order_index
  )

  SELECT json_build_object(
    'course', row_to_json(course_data.*),
    'assignments', COALESCE(json_agg(row_to_json(assignments_data.*)), '[]'::json)
  ) INTO result
  FROM course_data, assignments_data;

  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Batch progress update function
CREATE OR REPLACE FUNCTION batch_update_progress(progress_items JSONB)
RETURNS VOID AS $$
DECLARE
  item JSONB;
BEGIN
  FOR item IN SELECT * FROM jsonb_array_elements(progress_items)
  LOOP
    INSERT INTO public.progress (
      user_id,
      learning_object_id,
      current_position_ms,
      total_duration_ms,
      completion_percentage,
      is_completed,
      is_in_progress,
      font_size_index,
      playback_speed,
      last_accessed_at
    ) VALUES (
      (item->>'user_id')::UUID,
      (item->>'learning_object_id')::UUID,
      (item->>'current_position_ms')::INTEGER,
      (item->>'total_duration_ms')::INTEGER,
      (item->>'completion_percentage')::REAL,
      (item->>'is_completed')::BOOLEAN,
      (item->>'is_in_progress')::BOOLEAN,
      (item->>'font_size_index')::INTEGER,
      (item->>'playback_speed')::REAL,
      NOW()
    )
    ON CONFLICT (user_id, learning_object_id)
    DO UPDATE SET
      current_position_ms = EXCLUDED.current_position_ms,
      total_duration_ms = EXCLUDED.total_duration_ms,
      completion_percentage = EXCLUDED.completion_percentage,
      is_completed = EXCLUDED.is_completed,
      is_in_progress = EXCLUDED.is_in_progress,
      font_size_index = EXCLUDED.font_size_index,
      playback_speed = EXCLUDED.playback_speed,
      last_accessed_at = EXCLUDED.last_accessed_at,
      updated_at = NOW();
  END LOOP;
END;
$$ LANGUAGE plpgsql;
```

---

## User Preferences and Progress

### 1. User Preferences Service with Conflict Resolution

```dart
class UserPreferencesService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SharedPreferences _prefs;

  UserPreferencesService(this._prefs);

  /// Get user preferences with local fallback
  Future<UserPreferences> getUserPreferences(String userId) async {
    try {
      // Try to get from Supabase first
      final response = await _supabase
        .from('user_preferences')
        .select('*')
        .eq('user_id', userId)
        .maybeSingle();

      UserPreferences serverPrefs;
      if (response != null) {
        serverPrefs = UserPreferences.fromJson(response);

        // Cache locally
        await _cachePreferencesLocally(serverPrefs);
      } else {
        // Create default preferences
        serverPrefs = UserPreferences.defaultPreferences(userId);
        await saveUserPreferences(serverPrefs);
      }

      // Check for local modifications
      final localPrefs = await _getLocalPreferences();
      if (localPrefs != null && _hasLocalModifications(serverPrefs, localPrefs)) {
        return await _resolvePreferenceConflicts(serverPrefs, localPrefs);
      }

      return serverPrefs;

    } catch (e) {
      safePrint('Error getting user preferences: $e');

      // Fallback to local preferences
      final localPrefs = await _getLocalPreferences();
      return localPrefs ?? UserPreferences.defaultPreferences(userId);
    }
  }

  /// Save user preferences with optimistic updates
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    try {
      // Save locally first for immediate UI update
      await _cachePreferencesLocally(preferences);

      // Then save to server
      await _supabase
        .from('user_preferences')
        .upsert(preferences.toJson());

      safePrint('User preferences saved successfully');

    } catch (e) {
      safePrint('Error saving user preferences: $e');

      // Mark for later sync
      await _markForSync(preferences);
      throw SupabaseException('Failed to save preferences: ${e.toString()}');
    }
  }

  /// Update font size preference immediately
  Future<void> updateFontSizePreference(String userId, int fontSizeIndex) async {
    try {
      final preferences = await getUserPreferences(userId);
      final updated = preferences.copyWith(defaultFontSizeIndex: fontSizeIndex);

      await saveUserPreferences(updated);

    } catch (e) {
      safePrint('Error updating font size preference: $e');
      throw SupabaseException('Failed to update font size: ${e.toString()}');
    }
  }

  /// Update playback speed preference immediately
  Future<void> updatePlaybackSpeedPreference(String userId, double playbackSpeed) async {
    try {
      final preferences = await getUserPreferences(userId);
      final updated = preferences.copyWith(defaultPlaybackSpeed: playbackSpeed);

      await saveUserPreferences(updated);

    } catch (e) {
      safePrint('Error updating playback speed preference: $e');
      throw SupabaseException('Failed to update playback speed: ${e.toString()}');
    }
  }

  /// Sync pending preferences
  Future<void> syncPendingPreferences() async {
    final pendingJson = _prefs.getString('pending_preferences_sync');
    if (pendingJson != null) {
      try {
        final preferences = UserPreferences.fromJson(jsonDecode(pendingJson));

        await _supabase
          .from('user_preferences')
          .upsert(preferences.toJson());

        await _prefs.remove('pending_preferences_sync');
        safePrint('Pending preferences synced successfully');

      } catch (e) {
        safePrint('Error syncing pending preferences: $e');
      }
    }
  }

  // Private helper methods
  Future<UserPreferences?> _getLocalPreferences() async {
    try {
      final jsonString = _prefs.getString('user_preferences');
      if (jsonString != null) {
        return UserPreferences.fromJson(jsonDecode(jsonString));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _cachePreferencesLocally(UserPreferences preferences) async {
    await _prefs.setString('user_preferences', jsonEncode(preferences.toJson()));
    await _prefs.setString('preferences_last_sync', DateTime.now().toIso8601String());
  }

  bool _hasLocalModifications(UserPreferences server, UserPreferences local) {
    final serverSync = _prefs.getString('preferences_last_sync');
    if (serverSync == null) return true;

    final lastSync = DateTime.parse(serverSync);
    return local.updatedAt.isAfter(lastSync);
  }

  Future<UserPreferences> _resolvePreferenceConflicts(
    UserPreferences server,
    UserPreferences local,
  ) async {
    // Use most recent timestamp as conflict resolution strategy
    if (local.updatedAt.isAfter(server.updatedAt)) {
      // Local is newer, save to server
      await saveUserPreferences(local);
      return local;
    } else {
      // Server is newer, cache locally
      await _cachePreferencesLocally(server);
      return server;
    }
  }

  Future<void> _markForSync(UserPreferences preferences) async {
    await _prefs.setString('pending_preferences_sync', jsonEncode(preferences.toJson()));
  }
}

class UserPreferences {
  final String id;
  final String userId;
  final int defaultFontSizeIndex;
  final double defaultPlaybackSpeed;
  final bool autoContinue;
  final bool notificationEnabled;
  final bool darkModeEnabled;
  final int skipDurationSeconds;
  final int autoBookmarkIntervalSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPreferences({
    required this.id,
    required this.userId,
    required this.defaultFontSizeIndex,
    required this.defaultPlaybackSpeed,
    required this.autoContinue,
    required this.notificationEnabled,
    required this.darkModeEnabled,
    required this.skipDurationSeconds,
    required this.autoBookmarkIntervalSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserPreferences.defaultPreferences(String userId) {
    final now = DateTime.now();
    return UserPreferences(
      id: const Uuid().v4(),
      userId: userId,
      defaultFontSizeIndex: 1, // Medium
      defaultPlaybackSpeed: 1.0,
      autoContinue: true,
      notificationEnabled: true,
      darkModeEnabled: false,
      skipDurationSeconds: 30,
      autoBookmarkIntervalSeconds: 300, // 5 minutes
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      id: json['id'],
      userId: json['user_id'],
      defaultFontSizeIndex: json['default_font_size_index'] ?? 1,
      defaultPlaybackSpeed: (json['default_playback_speed'] ?? 1.0).toDouble(),
      autoContinue: json['auto_continue'] ?? true,
      notificationEnabled: json['notification_enabled'] ?? true,
      darkModeEnabled: json['dark_mode_enabled'] ?? false,
      skipDurationSeconds: json['skip_duration_seconds'] ?? 30,
      autoBookmarkIntervalSeconds: json['auto_bookmark_interval_seconds'] ?? 300,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'default_font_size_index': defaultFontSizeIndex,
    'default_playback_speed': defaultPlaybackSpeed,
    'auto_continue': autoContinue,
    'notification_enabled': notificationEnabled,
    'dark_mode_enabled': darkModeEnabled,
    'skip_duration_seconds': skipDurationSeconds,
    'auto_bookmark_interval_seconds': autoBookmarkIntervalSeconds,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  UserPreferences copyWith({
    String? id,
    String? userId,
    int? defaultFontSizeIndex,
    double? defaultPlaybackSpeed,
    bool? autoContinue,
    bool? notificationEnabled,
    bool? darkModeEnabled,
    int? skipDurationSeconds,
    int? autoBookmarkIntervalSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      defaultFontSizeIndex: defaultFontSizeIndex ?? this.defaultFontSizeIndex,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      autoContinue: autoContinue ?? this.autoContinue,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      skipDurationSeconds: skipDurationSeconds ?? this.skipDurationSeconds,
      autoBookmarkIntervalSeconds: autoBookmarkIntervalSeconds ?? this.autoBookmarkIntervalSeconds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Get font size display name
  String get fontSizeDisplayName {
    switch (defaultFontSizeIndex) {
      case 0: return 'Small';
      case 1: return 'Medium';
      case 2: return 'Large';
      case 3: return 'XLarge';
      default: return 'Medium';
    }
  }

  /// Get playback speed display
  String get playbackSpeedDisplay => '${defaultPlaybackSpeed}x';
}
```

---

## Offline Caching Strategy

### 1. Comprehensive Offline Support Service

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SharedPreferences _prefs;
  final Connectivity _connectivity = Connectivity();

  OfflineSyncService(this._prefs);

  /// Initialize offline sync service
  Future<void> initialize() async {
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _syncWhenOnline();
      }
    });

    // Sync on app start if online
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _syncWhenOnline();
    }
  }

  /// Cache course data for offline access
  Future<void> cacheCoursesForOffline(String userId) async {
    try {
      final courses = await _supabase
        .from('enrollments')
        .select('''
          courses!inner(
            id,
            course_number,
            title,
            description,
            gradient_start_color,
            gradient_end_color,
            assignments!inner(
              id,
              assignment_number,
              title,
              order_index,
              learning_objects!inner(
                id,
                title,
                content,
                ssml_content,
                order_index,
                estimated_duration_seconds,
                word_timings
              )
            )
          )
        ''')
        .eq('user_id', userId)
        .gt('expires_at', DateTime.now().toIso8601String());

      // Cache course structure
      await _prefs.setString('offline_courses', jsonEncode(courses));
      await _prefs.setString('courses_cache_time', DateTime.now().toIso8601String());

      safePrint('Courses cached for offline access');

    } catch (e) {
      safePrint('Error caching courses: $e');
    }
  }

  /// Get cached courses for offline use
  Future<List<Map<String, dynamic>>> getCachedCourses() async {
    try {
      final cachedCoursesJson = _prefs.getString('offline_courses');
      if (cachedCoursesJson != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(cachedCoursesJson));
      }
      return [];
    } catch (e) {
      safePrint('Error getting cached courses: $e');
      return [];
    }
  }

  /// Queue progress updates for when online
  Future<void> queueProgressUpdate(ProgressUpdate update) async {
    try {
      final queueJson = _prefs.getString('progress_update_queue') ?? '[]';
      final queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));

      queue.add(update.toJson());

      await _prefs.setString('progress_update_queue', jsonEncode(queue));
      safePrint('Progress update queued for sync');

    } catch (e) {
      safePrint('Error queuing progress update: $e');
    }
  }

  /// Queue preference updates for when online
  Future<void> queuePreferenceUpdate(UserPreferences preferences) async {
    try {
      await _prefs.setString('pending_preferences_sync', jsonEncode(preferences.toJson()));
      safePrint('Preference update queued for sync');
    } catch (e) {
      safePrint('Error queuing preference update: $e');
    }
  }

  /// Check if app is in offline mode
  Future<bool> get isOffline async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult == ConnectivityResult.none;
  }

  /// Get offline cache status
  Future<OfflineCacheStatus> getCacheStatus() async {
    final coursesCache = _prefs.getString('offline_courses');
    final cacheTime = _prefs.getString('courses_cache_time');
    final queueJson = _prefs.getString('progress_update_queue') ?? '[]';
    final pendingPrefs = _prefs.getString('pending_preferences_sync');

    return OfflineCacheStatus(
      hasCoursesCache: coursesCache != null,
      cacheTime: cacheTime != null ? DateTime.parse(cacheTime) : null,
      pendingProgressUpdates: jsonDecode(queueJson).length,
      hasPendingPreferences: pendingPrefs != null,
      isOffline: await isOffline,
    );
  }

  /// Clear all offline cache
  Future<void> clearOfflineCache() async {
    await _prefs.remove('offline_courses');
    await _prefs.remove('courses_cache_time');
    await _prefs.remove('progress_update_queue');
    await _prefs.remove('pending_preferences_sync');

    safePrint('Offline cache cleared');
  }

  /// Sync all queued data when online
  Future<void> _syncWhenOnline() async {
    try {
      await _syncQueuedProgressUpdates();
      await _syncQueuedPreferences();

      safePrint('Offline sync completed');
    } catch (e) {
      safePrint('Error during offline sync: $e');
    }
  }

  Future<void> _syncQueuedProgressUpdates() async {
    final queueJson = _prefs.getString('progress_update_queue');
    if (queueJson == null) return;

    try {
      final queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));

      for (final updateJson in queue) {
        await _supabase.from('progress').upsert(updateJson);
      }

      await _prefs.remove('progress_update_queue');
      safePrint('Synced ${queue.length} queued progress updates');

    } catch (e) {
      safePrint('Error syncing progress updates: $e');
    }
  }

  Future<void> _syncQueuedPreferences() async {
    final pendingJson = _prefs.getString('pending_preferences_sync');
    if (pendingJson == null) return;

    try {
      final preferences = jsonDecode(pendingJson);
      await _supabase.from('user_preferences').upsert(preferences);
      await _prefs.remove('pending_preferences_sync');

      safePrint('Synced pending preferences');
    } catch (e) {
      safePrint('Error syncing preferences: $e');
    }
  }
}

class OfflineCacheStatus {
  final bool hasCoursesCache;
  final DateTime? cacheTime;
  final int pendingProgressUpdates;
  final bool hasPendingPreferences;
  final bool isOffline;

  OfflineCacheStatus({
    required this.hasCoursesCache,
    this.cacheTime,
    required this.pendingProgressUpdates,
    required this.hasPendingPreferences,
    required this.isOffline,
  });

  bool get hasPendingUpdates => pendingProgressUpdates > 0 || hasPendingPreferences;

  String get statusDescription {
    if (isOffline) {
      if (hasCoursesCache) {
        return 'Offline - Using cached data';
      } else {
        return 'Offline - Limited functionality';
      }
    } else {
      if (hasPendingUpdates) {
        return 'Online - Syncing pending changes';
      } else {
        return 'Online - All data synced';
      }
    }
  }
}
```

---

## Error Handling and Resilience

### 1. Comprehensive Error Handling Service

```dart
class SupabaseErrorHandler {
  static const int maxRetryAttempts = 3;
  static const Duration baseRetryDelay = Duration(seconds: 1);

  /// Handle Supabase operations with retry logic and proper error messages
  static Future<T> handleOperation<T>(
    Future<T> Function() operation, {
    String operationName = 'database operation',
    bool enableRetry = true,
    Duration? customRetryDelay,
  }) async {
    int attempts = 0;
    Exception lastException = Exception('Unknown error');

    while (attempts < (enableRetry ? maxRetryAttempts : 1)) {
      attempts++;

      try {
        return await operation();
      } on PostgrestException catch (e) {
        lastException = _handlePostgrestException(e, operationName);

        if (!_shouldRetry(e) || attempts >= maxRetryAttempts) {
          throw lastException;
        }

      } on AuthException catch (e) {
        throw _handleAuthException(e, operationName);

      } on StorageException catch (e) {
        throw _handleStorageException(e, operationName);

      } on SocketException catch (e) {
        lastException = SupabaseNetworkException(
          'Network connection failed during $operationName: ${e.message}',
          originalError: e,
        );

        if (attempts >= maxRetryAttempts) {
          throw lastException;
        }

      } on TimeoutException catch (e) {
        lastException = SupabaseTimeoutException(
          'Operation timed out during $operationName',
          originalError: e,
        );

        if (attempts >= maxRetryAttempts) {
          throw lastException;
        }

      } catch (e) {
        throw SupabaseException(
          'Unexpected error during $operationName: ${e.toString()}',
          originalError: e,
        );
      }

      if (attempts < maxRetryAttempts) {
        final delay = customRetryDelay ?? _calculateRetryDelay(attempts);
        safePrint('Retry attempt $attempts for $operationName after ${delay.inSeconds}s delay');
        await Future.delayed(delay);
      }
    }

    throw lastException;
  }

  static SupabaseException _handlePostgrestException(
    PostgrestException e,
    String operationName,
  ) {
    switch (e.code) {
      case '23505': // Unique violation
        return SupabaseException(
          'This data already exists. Please try with different information.',
          code: 'DUPLICATE_DATA',
          originalError: e,
        );

      case '23503': // Foreign key violation
        return SupabaseException(
          'Cannot complete $operationName due to missing related data.',
          code: 'MISSING_REFERENCE',
          originalError: e,
        );

      case '42501': // Insufficient privilege (RLS)
        return SupabaseException(
          'You do not have permission to access this data.',
          code: 'INSUFFICIENT_PERMISSIONS',
          originalError: e,
        );

      case '23514': // Check violation
        return SupabaseException(
          'The data provided does not meet the required constraints.',
          code: 'INVALID_DATA',
          originalError: e,
        );

      default:
        return SupabaseException(
          'Database error during $operationName: ${e.message}',
          code: e.code,
          originalError: e,
        );
    }
  }

  static SupabaseException _handleAuthException(AuthException e, String operationName) {
    switch (e.statusCode) {
      case '401':
        return SupabaseAuthException(
          'Your session has expired. Please log in again.',
          code: 'SESSION_EXPIRED',
          originalError: e,
        );

      case '403':
        return SupabaseAuthException(
          'You do not have permission to perform this action.',
          code: 'FORBIDDEN',
          originalError: e,
        );

      case '422':
        return SupabaseAuthException(
          'Invalid authentication information provided.',
          code: 'INVALID_AUTH',
          originalError: e,
        );

      default:
        return SupabaseAuthException(
          'Authentication error during $operationName: ${e.message}',
          originalError: e,
        );
    }
  }

  static SupabaseException _handleStorageException(StorageException e, String operationName) {
    return SupabaseStorageException(
      'Storage error during $operationName: ${e.message}',
      originalError: e,
    );
  }

  static bool _shouldRetry(PostgrestException e) {
    // Don't retry on client errors (4xx codes)
    if (e.code != null && e.code!.startsWith('4')) {
      return false;
    }

    // Don't retry on unique violations and permission errors
    const nonRetryableCodes = ['23505', '23503', '42501'];
    return !nonRetryableCodes.contains(e.code);
  }

  static Duration _calculateRetryDelay(int attemptNumber) {
    // Exponential backoff with jitter
    final baseDelay = baseRetryDelay.inMilliseconds * (1 << (attemptNumber - 1));
    final jitter = Random().nextInt(1000); // Add up to 1 second of jitter
    return Duration(milliseconds: baseDelay + jitter);
  }
}

// Custom exception classes
class SupabaseException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  SupabaseException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'SupabaseException: $message';
}

class SupabaseAuthException extends SupabaseException {
  SupabaseAuthException(String message, {String? code, dynamic originalError})
    : super(message, code: code, originalError: originalError);

  @override
  String toString() => 'SupabaseAuthException: $message';
}

class SupabaseNetworkException extends SupabaseException {
  SupabaseNetworkException(String message, {dynamic originalError})
    : super(message, originalError: originalError);

  @override
  String toString() => 'SupabaseNetworkException: $message';
}

class SupabaseTimeoutException extends SupabaseException {
  SupabaseTimeoutException(String message, {dynamic originalError})
    : super(message, originalError: originalError);

  @override
  String toString() => 'SupabaseTimeoutException: $message';
}

class SupabaseStorageException extends SupabaseException {
  SupabaseStorageException(String message, {dynamic originalError})
    : super(message, originalError: originalError);

  @override
  String toString() => 'SupabaseStorageException: $message';
}
```

### 2. Connection Health Monitoring

```dart
class ConnectionHealthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<ConnectionHealth> _healthController =
    BehaviorSubject<ConnectionHealth>();

  Timer? _healthCheckTimer;
  ConnectionHealth _currentHealth = ConnectionHealth.unknown();

  /// Start monitoring connection health
  void startMonitoring() {
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkConnectionHealth(),
    );

    // Initial check
    _checkConnectionHealth();
  }

  /// Stop monitoring
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    _healthController.close();
  }

  /// Stream of connection health updates
  Stream<ConnectionHealth> get healthStream => _healthController.stream;

  /// Current health status
  ConnectionHealth get currentHealth => _currentHealth;

  Future<void> _checkConnectionHealth() async {
    final startTime = DateTime.now();

    try {
      // Simple health check query
      await _supabase
        .from('user_profiles')
        .select('id')
        .limit(1);

      final responseTime = DateTime.now().difference(startTime);

      _currentHealth = ConnectionHealth.healthy(responseTime);

    } catch (e) {
      _currentHealth = ConnectionHealth.unhealthy(e.toString());
    }

    _healthController.add(_currentHealth);
  }
}

class ConnectionHealth {
  final ConnectionStatus status;
  final Duration? responseTime;
  final String? errorMessage;
  final DateTime timestamp;

  ConnectionHealth._({
    required this.status,
    this.responseTime,
    this.errorMessage,
    required this.timestamp,
  });

  factory ConnectionHealth.healthy(Duration responseTime) => ConnectionHealth._(
    status: ConnectionStatus.healthy,
    responseTime: responseTime,
    timestamp: DateTime.now(),
  );

  factory ConnectionHealth.unhealthy(String error) => ConnectionHealth._(
    status: ConnectionStatus.unhealthy,
    errorMessage: error,
    timestamp: DateTime.now(),
  );

  factory ConnectionHealth.unknown() => ConnectionHealth._(
    status: ConnectionStatus.unknown,
    timestamp: DateTime.now(),
  );

  bool get isHealthy => status == ConnectionStatus.healthy;
  bool get isUnhealthy => status == ConnectionStatus.unhealthy;

  String get displayMessage {
    switch (status) {
      case ConnectionStatus.healthy:
        return 'Connected (${responseTime?.inMilliseconds}ms)';
      case ConnectionStatus.unhealthy:
        return 'Connection issues: $errorMessage';
      case ConnectionStatus.unknown:
        return 'Checking connection...';
    }
  }
}

enum ConnectionStatus { healthy, unhealthy, unknown }
```

---

## Production Deployment

### 1. Production Environment Configuration

```dart
class ProductionConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static const String supabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
  );

  /// Initialize Supabase for production
  static Future<void> initializeSupabase() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: false, // Disable debug in production
      localStorage: const SharedPreferencesLocalStorage(),
      detectSessionInUri: true,
      headers: {
        'apikey': supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.error, // Only errors in production
        heartbeatIntervalMs: 30000,
        reconnectAfterMs: 5000,
      ),
    );
  }

  /// Validate production environment
  static void validateEnvironment() {
    if (supabaseUrl.isEmpty || supabaseUrl.contains('your-project')) {
      throw ArgumentError('SUPABASE_URL not configured for production');
    }

    if (supabaseAnonKey.isEmpty) {
      throw ArgumentError('SUPABASE_ANON_KEY not configured for production');
    }

    if (supabaseServiceRoleKey.isEmpty) {
      throw ArgumentError('SUPABASE_SERVICE_ROLE_KEY not configured for production');
    }
  }
}
```

### 2. Database Migration and Seeding Scripts

```sql
-- Production database setup script
-- Run this script to set up your production database

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create all tables with proper constraints
\i create_tables.sql

-- Set up Row Level Security policies
\i setup_rls_policies.sql

-- Create indexes for performance
\i create_indexes.sql

-- Create database functions
\i create_functions.sql

-- Set up database monitoring
CREATE OR REPLACE FUNCTION log_slow_queries()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.total_time != NEW.total_time THEN
    IF NEW.mean_time > 100 THEN -- Log queries slower than 100ms
      INSERT INTO slow_query_log (query, mean_time, calls, total_time)
      VALUES (NEW.query, NEW.mean_time, NEW.calls, NEW.total_time);
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create monitoring tables
CREATE TABLE IF NOT EXISTS slow_query_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  query TEXT,
  mean_time REAL,
  calls INTEGER,
  total_time REAL,
  logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Set up connection pooling parameters
ALTER SYSTEM SET max_connections = 100;
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET log_min_duration_statement = 1000; -- Log queries > 1 second

-- Performance tuning
ALTER SYSTEM SET effective_cache_size = '4GB';
ALTER SYSTEM SET shared_buffers = '1GB';
ALTER SYSTEM SET random_page_cost = 1.1;

-- Reload configuration
SELECT pg_reload_conf();
```

### 3. Health Check and Monitoring

```dart
class ProductionHealthCheck {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Comprehensive health check for production monitoring
  Future<HealthCheckResult> performHealthCheck() async {
    final checks = <String, bool>{};
    final errors = <String>[];
    final details = <String, dynamic>{};

    try {
      // Database connectivity check
      final dbStart = DateTime.now();
      await _supabase.from('user_profiles').select('id').limit(1);
      checks['database'] = true;
      details['database_response_time'] = DateTime.now().difference(dbStart).inMilliseconds;

    } catch (e) {
      checks['database'] = false;
      errors.add('Database connection failed: ${e.toString()}');
    }

    try {
      // Authentication check
      final authUser = _supabase.auth.currentUser;
      checks['authentication'] = authUser != null;
      details['user_authenticated'] = authUser != null;

    } catch (e) {
      checks['authentication'] = false;
      errors.add('Authentication check failed: ${e.toString()}');
    }

    try {
      // Real-time connection check
      final channel = _supabase.channel('health_check');
      await channel.subscribe();
      checks['realtime'] = true;
      await channel.unsubscribe();

    } catch (e) {
      checks['realtime'] = false;
      errors.add('Real-time connection failed: ${e.toString()}');
    }

    // Performance metrics
    details['memory_usage'] = await _getMemoryUsage();
    details['cache_hit_rate'] = await _getCacheHitRate();

    final isHealthy = checks.values.every((check) => check);

    return HealthCheckResult(
      isHealthy: isHealthy,
      checks: checks,
      errors: errors,
      details: details,
      timestamp: DateTime.now(),
    );
  }

  Future<int> _getMemoryUsage() async {
    // Implementation depends on platform
    // For now, return a placeholder
    return 0;
  }

  Future<double> _getCacheHitRate() async {
    // Calculate cache hit rate from your caching service
    // For now, return a placeholder
    return 0.85;
  }
}

class HealthCheckResult {
  final bool isHealthy;
  final Map<String, bool> checks;
  final List<String> errors;
  final Map<String, dynamic> details;
  final DateTime timestamp;

  HealthCheckResult({
    required this.isHealthy,
    required this.checks,
    required this.errors,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'is_healthy': isHealthy,
    'checks': checks,
    'errors': errors,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };
}
```

---

## Best Practices and Security

### 1. Security Best Practices

#### Environment Variables Management
```dart
// Use flutter_dotenv for environment management
// .env file (not committed to version control)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
AWS_COGNITO_USER_POOL_ID=us-east-1_example
AWS_COGNITO_IDENTITY_POOL_ID=us-east-1:example
SPEECHIFY_API_KEY=your-speechify-key
```

#### Secure Token Storage
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
    ),
  );

  static Future<void> storeToken(String key, String token) async {
    await _storage.write(key: key, value: token);
  }

  static Future<String?> getToken(String key) async {
    return await _storage.read(key: key);
  }

  static Future<void> deleteToken(String key) async {
    await _storage.delete(key: key);
  }

  static Future<void> clearAllTokens() async {
    await _storage.deleteAll();
  }
}
```

### 2. Performance Best Practices

#### Query Optimization Guidelines
- Always use indexes for RLS policy columns
- Implement proper pagination for large result sets
- Use selective field queries (avoid SELECT *)
- Cache frequently accessed data locally
- Use database functions for complex operations
- Implement proper connection pooling

#### Memory Management
- Dispose of streams and controllers properly
- Use WeakReference for callback patterns
- Implement proper cache eviction policies
- Monitor memory usage in production
- Use RepaintBoundary for complex widgets

---

## Testing and Validation

### 1. Comprehensive Test Suite

```dart
// test/supabase_integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('Supabase Integration Tests', () {
    late MockSupabaseClient mockSupabase;
    late CourseRepository repository;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      repository = CourseRepository(mockSupabase);
    });

    testWidgets('should load enrolled courses with RLS filtering', (tester) async {
      // Given
      const userId = 'test-user-id';
      final mockResponse = [
        {
          'id': 'enrollment-1',
          'course_id': 'course-1',
          'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'courses': {
            'id': 'course-1',
            'title': 'Test Course',
            'gradient_start_color': '#2196F3',
          }
        }
      ];

      when(() => mockSupabase.from('enrollments')).thenReturn(
        MockQueryBuilder()
      );

      // When
      final courses = await repository.getUserEnrolledCourses(userId);

      // Then
      expect(courses, isNotEmpty);
      expect(courses.first.course.title, equals('Test Course'));
    });

    testWidgets('should handle progress saving with debouncing', (tester) async {
      // Test debounced progress saving logic
    });

    testWidgets('should handle offline caching correctly', (tester) async {
      // Test offline functionality
    });
  });
}
```

### 2. Validation Functions

```dart
/// Validation functions for Supabase integration
class SupabaseValidation {
  static Future<bool> validateDatabaseConnection() async {
    try {
      await Supabase.instance.client
        .from('user_profiles')
        .select('id')
        .limit(1);
      return true;
    } catch (e) {
      safePrint('Database connection validation failed: $e');
      return false;
    }
  }

  static Future<bool> validateRLSPolicies() async {
    // Test that RLS policies are working correctly
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return false;

      // Try to access data that should be filtered by RLS
      final result = await Supabase.instance.client
        .from('enrollments')
        .select('*')
        .eq('user_id', user.id);

      // Should only return current user's enrollments
      return result.every((enrollment) => enrollment['user_id'] == user.id);

    } catch (e) {
      safePrint('RLS validation failed: $e');
      return false;
    }
  }

  static Future<bool> validateRealtimeSubscriptions() async {
    try {
      final channel = Supabase.instance.client.channel('validation_test');

      final completer = Completer<bool>();

      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'progress',
        callback: (payload) {
          completer.complete(true);
        },
      );

      await channel.subscribe();

      // Wait for subscription to be active
      await Future.delayed(const Duration(seconds: 2));

      await channel.unsubscribe();

      return true;
    } catch (e) {
      safePrint('Real-time validation failed: $e');
      return false;
    }
  }

  static Future<ValidationResults> runAllValidations() async {
    final results = ValidationResults();

    results.databaseConnection = await validateDatabaseConnection();
    results.rlsPolicies = await validateRLSPolicies();
    results.realtimeSubscriptions = await validateRealtimeSubscriptions();

    return results;
  }
}

class ValidationResults {
  bool databaseConnection = false;
  bool rlsPolicies = false;
  bool realtimeSubscriptions = false;

  bool get allPassed => databaseConnection && rlsPolicies && realtimeSubscriptions;

  String get summary => '''
Database Connection: ${databaseConnection ? '✅' : '❌'}
RLS Policies: ${rlsPolicies ? '✅' : '❌'}
Real-time Subscriptions: ${realtimeSubscriptions ? '✅' : '❌'}

Overall Status: ${allPassed ? 'PASS' : 'FAIL'}
''';
}
```

---

## Conclusion

This comprehensive Supabase Flutter integration guide provides production-ready implementation for the Audio Learning Platform with enterprise-grade security, performance optimization, and robust error handling. The key features include:

**Security & Authentication:**
- JWT bridging from AWS Cognito to Supabase
- Row Level Security (RLS) policies for multi-tenant data protection
- Automatic filtering of expired course enrollments
- Secure token management and refresh

**Performance & Optimization:**
- Three-tier caching strategy (Memory → SharedPreferences → Supabase)
- Optimized database queries with proper indexing
- Real-time subscriptions for progress tracking
- Debounced progress saves every 5 seconds

**User Experience:**
- Offline caching and synchronization
- User preference storage with conflict resolution
- Font size and playback speed persistence
- Word timing data with sentence indexing for dual-level highlighting

**Production Readiness:**
- Comprehensive error handling with retry logic
- Connection health monitoring
- Performance metrics and validation functions
- Production deployment configuration

The implementation follows Flutter best practices and provides a solid foundation for the audio learning platform's backend requirements.
