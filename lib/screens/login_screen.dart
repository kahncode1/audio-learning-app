import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../utils/app_logger.dart';

/// LoginScreen - Production authentication screen
///
/// Provides a clean, professional login interface for AWS Cognito SSO
/// authentication. This is the entry point for all users.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // Trigger OAuth flow with Cognito hosted UI
      final result = await authService.signIn('', '');

      if (result.isSignedIn) {
        AppLogger.info('User signed in successfully');
        // Navigate to main screen after successful login
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
      } else {
        // Sign in was not successful (e.g., user cancelled)
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.error('Sign in failed', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign in failed. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                Column(
                  children: [
                    Image.asset(
                      'assets/images/TheInstitutesLogo.png',
                      height: 72,  // Optimized logo size per specs
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback if logo doesn't load
                        return Icon(
                          Icons.business,
                          size: 72,
                          color: const Color(0xFF003B7B),
                        );
                      },
                    ),
                    // Logo already contains text, no separate brand name needed
                  ],
                ),
                const SizedBox(height: 48), // Logo Section to Welcome spacing

                // Welcome Section
                Column(
                  children: [
                    Text(
                      'Audio Courses',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D1D1F),
                        letterSpacing: -0.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14), // Welcome title to subtitle spacing
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        'Access audio versions of your enrolled courses',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF6E6E73),
                          height: 1.41, // 24px line height
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 56), // Welcome Section to Button spacing

                // Action Section
                Column(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 264),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      String.fromCharCode(0x2192), // Right arrow
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Button to helper text spacing
                    Text(
                      'Use your Institutes credentials\nto access your courses',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF8E8E93),
                        height: 1.38, // 18px line height
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFFE0B2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: const Color(0xFFE65100),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: const Color(0xFFE65100),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}