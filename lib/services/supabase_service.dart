/// Supabase Service with JWT Bridging
///
/// Purpose: Manages Supabase integration with Cognito JWT bridging
/// Dependencies:
///   - supabase_flutter: Supabase client
///   - auth_service.dart: Cognito authentication
///   - shared_preferences: Session persistence
///
/// Usage:
///   final supabaseService = SupabaseService();
///   await supabaseService.initialize();
///   await supabaseService.bridgeFromCognito();
///
/// Expected behavior:
///   - Initializes Supabase client
///   - Bridges Cognito JWT to Supabase session
///   - Manages database operations with RLS
///   - Handles real-time subscriptions

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import '../models/models.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late SupabaseClient _client;
  final AuthService _authService = AuthService();
  Timer? _refreshTimer;
  bool _isInitialized = false;

  /// Get Supabase client
  SupabaseClient get client => _client;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize Supabase
  Future<void> initialize() async {
    if (_isInitialized) {
      safePrint('Supabase already initialized');
      return;
    }

    try {
      await Supabase.initialize(
        url: const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: 'https://cmjdciktvfxiyapdseqn.supabase.co',
        ),
        anonKey: const String.fromEnvironment(
          'SUPABASE_ANON_KEY',
          defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtamRjaWt0dmZ4aXlhcGRzZXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3ODAwODAsImV4cCI6MjA3MzM1NjA4MH0.qIhF8LgDnm6OrlnhNWNJziNc6OopUu0qCYtgJhXouB8',
        ),
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
      );

      _client = Supabase.instance.client;
      _isInitialized = true;
      safePrint('Supabase initialized successfully');

      // Set up auth state listener
      _setupAuthStateListener();
    } catch (e) {
      safePrint('Error initializing Supabase: $e');
      rethrow;
    }
  }

  /// Bridge Cognito JWT to Supabase session
  Future<bool> bridgeFromCognito() async {
    try {
      // Get Cognito ID token
      final idToken = await _authService.getIdToken();
      if (idToken == null) {
        safePrint('No Cognito ID token available');
        return false;
      }

      // Get Cognito user data
      final cognitoUser = await _authService.createUserFromCognito();
      if (cognitoUser == null) {
        safePrint('Failed to get Cognito user data');
        return false;
      }

      // First, ensure user exists in Supabase
      await _ensureUserExists(cognitoUser);

      // Sign in to Supabase with custom JWT
      // Note: This requires Supabase to be configured to accept Cognito JWTs
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.custom,
        idToken: idToken,
      );

      if (response.user != null) {
        safePrint('Supabase session created for user: ${response.user!.id}');
        await _cacheSession(response.session);
        _setupTokenRefresh();
        return true;
      }

      return false;
    } catch (e) {
      safePrint('Error bridging to Supabase: $e');
      return false;
    }
  }

  /// Ensure user exists in Supabase database
  Future<void> _ensureUserExists(User cognitoUser) async {
    try {
      // Check if user exists
      final response = await _client
          .from('users')
          .select()
          .eq('cognito_sub', cognitoUser.cognitoSub)
          .maybeSingle();

      if (response == null) {
        // Create new user
        await _client.from('users').insert({
          'cognito_sub': cognitoUser.cognitoSub,
          'email': cognitoUser.email,
          'full_name': cognitoUser.fullName,
          'organization': cognitoUser.organization,
        });
        safePrint('Created new user in Supabase');
      } else {
        // Update existing user
        await _client
            .from('users')
            .update({
              'email': cognitoUser.email,
              'full_name': cognitoUser.fullName,
              'organization': cognitoUser.organization,
            })
            .eq('cognito_sub', cognitoUser.cognitoSub);
        safePrint('Updated existing user in Supabase');
      }
    } catch (e) {
      safePrint('Error ensuring user exists: $e');
      rethrow;
    }
  }

  /// Get current Supabase user
  User? getCurrentUser() {
    return _client.auth.currentUser;
  }

  /// Get current session
  Session? getCurrentSession() {
    return _client.auth.currentSession;
  }

  /// Check if authenticated
  bool get isAuthenticated {
    return _client.auth.currentSession != null;
  }

  /// Sign out from Supabase
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      await _clearCachedSession();
      _refreshTimer?.cancel();
      safePrint('Signed out from Supabase');
    } catch (e) {
      safePrint('Error signing out from Supabase: $e');
    }
  }

  // Database Operations

  /// Fetch user's enrolled courses
  Future<List<EnrolledCourse>> fetchEnrolledCourses() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) throw Exception('User not authenticated');

      final response = await _client
          .from('enrollments')
          .select('*, courses(*)')
          .eq('user_id', userId)
          .order('enrolled_at', ascending: false);

      return (response as List)
          .map((json) => EnrolledCourse.fromJson(json))
          .toList();
    } catch (e) {
      safePrint('Error fetching enrolled courses: $e');
      rethrow;
    }
  }

  /// Fetch assignments for a course
  Future<List<Assignment>> fetchAssignments(String courseId) async {
    try {
      final response = await _client
          .from('assignments')
          .select()
          .eq('course_id', courseId)
          .order('order_index');

      return (response as List)
          .map((json) => Assignment.fromJson(json))
          .toList();
    } catch (e) {
      safePrint('Error fetching assignments: $e');
      rethrow;
    }
  }

  /// Fetch learning objects for an assignment
  Future<List<LearningObject>> fetchLearningObjects(String assignmentId) async {
    try {
      final response = await _client
          .from('learning_objects')
          .select()
          .eq('assignment_id', assignmentId)
          .order('order_index');

      return (response as List)
          .map((json) => LearningObject.fromJson(json))
          .toList();
    } catch (e) {
      safePrint('Error fetching learning objects: $e');
      rethrow;
    }
  }

  /// Fetch progress for a learning object
  Future<ProgressState?> fetchProgress(String learningObjectId) async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return null;

      final response = await _client
          .from('progress')
          .select()
          .eq('user_id', userId)
          .eq('learning_object_id', learningObjectId)
          .maybeSingle();

      if (response != null) {
        return ProgressState.fromJson(response);
      }
      return null;
    } catch (e) {
      safePrint('Error fetching progress: $e');
      return null;
    }
  }

  /// Save progress
  Future<void> saveProgress(ProgressState progress) async {
    try {
      await _client.from('progress').upsert(
        progress.toJson(),
        onConflict: 'user_id,learning_object_id',
      );
    } catch (e) {
      safePrint('Error saving progress: $e');
      rethrow;
    }
  }

  /// Set up real-time subscription for progress updates
  RealtimeChannel subscribeToProgress(String userId, Function(ProgressState) onUpdate) {
    return _client
        .channel('progress_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'progress',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final progress = ProgressState.fromJson(payload.newRecord);
            onUpdate(progress);
          },
        )
        .subscribe();
  }

  // Private helper methods

  Future<String?> _getCurrentUserId() async {
    try {
      final cognitoUser = await _authService.getCurrentUser();
      if (cognitoUser == null) return null;

      final response = await _client
          .from('users')
          .select('id')
          .eq('cognito_sub', cognitoUser.userId)
          .maybeSingle();

      return response?['id'] as String?;
    } catch (e) {
      safePrint('Error getting current user ID: $e');
      return null;
    }
  }

  void _setupAuthStateListener() {
    _client.auth.onAuthStateChange.listen((event) {
      switch (event.event) {
        case AuthChangeEvent.signedIn:
          safePrint('Supabase auth: signed in');
          break;
        case AuthChangeEvent.signedOut:
          safePrint('Supabase auth: signed out');
          _refreshTimer?.cancel();
          break;
        case AuthChangeEvent.tokenRefreshed:
          safePrint('Supabase auth: token refreshed');
          break;
        default:
          break;
      }
    });
  }

  void _setupTokenRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 50), (timer) async {
      if (isAuthenticated) {
        await _client.auth.refreshSession();
      }
    });
  }

  Future<void> _cacheSession(Session? session) async {
    if (session == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_session_token', session.accessToken);
      await prefs.setInt('supabase_session_expires', session.expiresAt ?? 0);
    } catch (e) {
      safePrint('Error caching Supabase session: $e');
    }
  }

  Future<void> _clearCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('supabase_session_token');
      await prefs.remove('supabase_session_expires');
    } catch (e) {
      safePrint('Error clearing cached session: $e');
    }
  }

  void dispose() {
    _refreshTimer?.cancel();
  }
}

/// Validation function to verify SupabaseService implementation
void validateSupabaseService() {
  print('Validating SupabaseService...');

  final supabaseService = SupabaseService();

  // Test singleton pattern
  final supabaseService2 = SupabaseService();
  assert(identical(supabaseService, supabaseService2));

  // Test initial state
  assert(supabaseService.isInitialized == false);
  assert(supabaseService.isAuthenticated == false);

  print('✓ SupabaseService validation passed');
  print('Note: Full validation requires Supabase configuration');
}