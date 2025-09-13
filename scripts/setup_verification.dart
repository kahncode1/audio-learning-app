#!/usr/bin/env dart

/// Setup Verification Script
///
/// Purpose: Verify AWS Cognito and Supabase configuration
/// Usage: dart scripts/setup_verification.dart

import 'dart:io';

void main() async {
  print('🔍 Audio Learning Platform - Setup Verification\n');

  final results = <String, bool>{};

  // Check environment file
  print('Checking environment configuration...');
  final envFile = File('.env');
  if (envFile.existsSync()) {
    final content = envFile.readAsStringSync();
    results['✅ .env file exists'] = true;

    // Check for required environment variables
    results['Supabase URL configured'] = content.contains('SUPABASE_URL=https://');
    results['Supabase key configured'] = content.contains('SUPABASE_ANON_KEY=');
    results['Cognito User Pool ID'] = !content.contains('your_user_pool_id_here');
    results['Cognito Client ID'] = !content.contains('your_client_id_here');
    results['Cognito Identity Pool ID'] = !content.contains('your_identity_pool_id_here');
  } else {
    results['❌ .env file missing'] = false;
  }

  // Check app configuration
  print('Checking app configuration...');
  final configFile = File('lib/config/app_config.dart');
  if (configFile.existsSync()) {
    final content = configFile.readAsStringSync();
    results['✅ app_config.dart exists'] = true;

    final hasRealUserPool = !content.contains("'YOUR_USER_POOL_ID_HERE'");
    final hasRealClientId = !content.contains("'YOUR_CLIENT_ID_HERE'");
    final hasRealIdentityPool = !content.contains("'YOUR_IDENTITY_POOL_ID_HERE'");

    results['User Pool ID configured'] = hasRealUserPool;
    results['Client ID configured'] = hasRealClientId;
    results['Identity Pool ID configured'] = hasRealIdentityPool;
  } else {
    results['❌ app_config.dart missing'] = false;
  }

  // Check required directories
  print('Checking project structure...');
  results['lib/models directory'] = Directory('lib/models').existsSync();
  results['lib/services directory'] = Directory('lib/services').existsSync();
  results['lib/providers directory'] = Directory('lib/providers').existsSync();
  results['lib/widgets directory'] = Directory('lib/widgets').existsSync();

  // Check required model files
  print('Checking model files...');
  results['User model'] = File('lib/models/user.dart').existsSync();
  results['Course model'] = File('lib/models/course.dart').existsSync();
  results['Assignment model'] = File('lib/models/assignment.dart').existsSync();
  results['LearningObject model'] = File('lib/models/learning_object.dart').existsSync();
  results['WordTiming model'] = File('lib/models/word_timing.dart').existsSync();
  results['ProgressState model'] = File('lib/models/progress_state.dart').existsSync();
  results['EnrolledCourse model'] = File('lib/models/enrolled_course.dart').existsSync();

  // Check service files
  print('Checking service files...');
  results['AuthService'] = File('lib/services/auth_service.dart').existsSync();
  results['SupabaseService'] = File('lib/services/supabase_service.dart').existsSync();

  // Check provider files
  print('Checking provider files...');
  results['Providers'] = File('lib/providers/providers.dart').existsSync();

  // Display results
  print('\n📊 Verification Results:\n');
  print('─' * 50);

  int passed = 0;
  int failed = 0;

  results.forEach((check, result) {
    final icon = result ? '✅' : '❌';
    print('$icon $check');
    if (result) passed++; else failed++;
  });

  print('─' * 50);
  print('\n📈 Summary: $passed passed, $failed failed\n');

  // Provide next steps
  if (failed > 0) {
    print('⚠️  Some checks failed. Next steps:\n');

    if (!results['Cognito User Pool ID']! ||
        !results['Cognito Client ID']! ||
        !results['Cognito Identity Pool ID']!) {
      print('1. Create AWS Cognito resources:');
      print('   - Follow SETUP_GUIDE.md Part 1');
      print('   - Update lib/config/app_config.dart with your credentials\n');
    }

    if (!results['User Pool ID configured']! ||
        !results['Client ID configured']! ||
        !results['Identity Pool ID configured']!) {
      print('2. Update configuration:');
      print('   - Open lib/config/app_config.dart');
      print('   - Replace placeholder values with actual AWS credentials\n');
    }

    if (results.values.where((v) => !v).length > 5) {
      print('3. Complete project setup:');
      print('   - Run: flutter pub get');
      print('   - Ensure all files were created successfully\n');
    }
  } else {
    print('🎉 All checks passed! Your environment is ready.\n');
    print('Next steps:');
    print('1. Configure JWT in Supabase Dashboard (see SETUP_GUIDE.md Part 2)');
    print('2. Create a test user in AWS Cognito');
    print('3. Run: flutter test test/auth_test.dart');
    print('4. Run: flutter run');
  }

  // Check if we can connect to Supabase
  print('\n🔗 Testing Supabase connection...');
  print('   Run: dart scripts/test_supabase.dart');
}