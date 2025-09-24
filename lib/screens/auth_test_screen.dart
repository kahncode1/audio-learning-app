/// Authentication Test Screen
///
/// Provides a UI for testing the Cognito OAuth flow and Supabase integration.
/// This screen helps validate that deep linking, JWT bridging, and RLS policies
/// are working correctly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_factory.dart';

class AuthTestScreen extends ConsumerStatefulWidget {
  const AuthTestScreen({super.key});

  @override
  ConsumerState<AuthTestScreen> createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends ConsumerState<AuthTestScreen> {
  String _status = 'Not authenticated';
  String _userInfo = '';
  String _jwtToken = '';
  String _supabaseStatus = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final authService = AuthFactory.instance;
      await authService.initialize();
      print('✅ Auth service initialized');
      await _checkAuthStatus();
    } catch (e) {
      setState(() {
        _status = '❌ Initialization error: $e';
      });
    }
  }

  Future<void> _checkAuthStatus() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthFactory.instance;
      final isSignedIn = await authService.isSignedIn();

      if (isSignedIn) {
        final user = await authService.getCurrentUser();
        final jwt = await authService.getJwtToken();

        setState(() {
          _status = '✅ Authenticated';
          _userInfo = '''
User ID: ${user?.userId ?? 'Unknown'}
Username: ${user?.username ?? 'Unknown'}
''';
          _jwtToken = jwt?.substring(0, 50) ?? 'No token';
        });

        // Check Supabase connection
        await _checkSupabaseConnection();
      } else {
        setState(() {
          _status = '❌ Not authenticated';
          _userInfo = '';
          _jwtToken = '';
          _supabaseStatus = '';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthFactory.instance;

      // This will trigger the OAuth flow with Cognito hosted UI
      final result = await authService.signIn('', '');

      if (result.isSignedIn) {
        await _checkAuthStatus();
        _showMessage('✅ Sign in successful!');
      } else {
        _showMessage('❌ Sign in cancelled or failed');
      }
    } catch (e) {
      _showMessage('❌ Sign in error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthFactory.instance;
      await authService.signOut();

      await _checkAuthStatus();
      _showMessage('✅ Sign out successful!');
    } catch (e) {
      _showMessage('❌ Sign out error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshTokens() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthFactory.instance;
      await authService.refreshTokens();

      await _checkAuthStatus();
      _showMessage('✅ Tokens refreshed!');
    } catch (e) {
      _showMessage('❌ Token refresh error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkSupabaseConnection() async {
    try {
      final client = Supabase.instance.client;

      // Check if Authorization header is set (new approach for external JWT)
      final hasAuthHeader = client.headers.containsKey('Authorization');

      if (hasAuthHeader) {
        setState(() {
          _supabaseStatus = '✅ JWT Token set in Authorization header';
        });

        // Test a simple query with RLS to verify JWT is working
        try {
          await client.from('courses').select('id, title').limit(1);

          setState(() {
            _supabaseStatus = '''
✅ Supabase Connected via JWT
✅ Authorization header is set
✅ RLS Test: Can access courses
✅ JWT validation successful
''';
          });
        } catch (queryError) {
          // If query fails, JWT might be invalid or RLS policies blocking
          setState(() {
            _supabaseStatus = '''
⚠️ JWT Token set but query failed
Authorization header: ${hasAuthHeader ? 'Set' : 'Not set'}
Query error: $queryError

Possible causes:
- JWT expired (1 hour lifetime)
- RLS policies need 'role' claim
- Lambda function not adding claims
''';
          });
        }
      } else {
        setState(() {
          _supabaseStatus = '''
❌ No Supabase JWT bridge
Authorization header not set
Run _bridgeToSupabase() after auth
''';
        });
      }
    } catch (e) {
      setState(() {
        _supabaseStatus = '❌ Supabase error: $e';
      });
    }
  }

  Future<void> _testDeepLink() async {
    _showMessage('''
Deep Link Test:
1. Sign out if authenticated
2. Click "Sign In with Cognito"
3. You should be redirected to: users.login-test.theinstitutes.org
4. After login, you should return to the app via: audiocourses://oauth/callback
5. Check that authentication status updates
''');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cognito OAuth Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Configuration Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cognito Configuration',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text('User Pool ID: us-east-1_vAMMFcpew'),
                          const Text('Client ID: 7n2o5r6em0latepiui4rfg6vmi'),
                          const Text('Region: us-east-1'),
                          const Text(
                              'Hosted UI: users.login-test.theinstitutes.org'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Auth Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Authentication Status',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(_status),
                          if (_userInfo.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_userInfo),
                          ],
                          if (_jwtToken.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('JWT Token: $_jwtToken...'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Supabase Status Card
                  if (_supabaseStatus.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supabase Integration',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(_supabaseStatus),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons
                  Center(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _signIn,
                          icon: const Icon(Icons.login),
                          label: const Text('Sign In with Cognito'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign Out'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _refreshTokens,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Tokens'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _checkAuthStatus,
                          icon: const Icon(Icons.check),
                          label: const Text('Check Status'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _testDeepLink,
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Deep Link Info'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Instructions
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Testing Instructions:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                              '1. Click "Sign In with Cognito" to test OAuth flow'),
                          Text(
                              '2. You should be redirected to Cognito hosted UI'),
                          Text(
                              '3. After login, you return via audiocourses://oauth/callback'),
                          Text('4. Check that JWT token is received'),
                          Text('5. Verify Supabase connection is established'),
                          Text(
                              '6. Test "Refresh Tokens" to ensure refresh works'),
                          Text('7. Test "Sign Out" to clear all sessions'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
