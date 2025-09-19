#!/usr/bin/env dart
// Verification script for the download architecture migration

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

Future<void> main() async {
  print('\n=== Supabase Migration Verification ===\n');

  try {
    // Load environment variables
    await dotenv.load(fileName: '.env');
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      print('❌ Error: Missing Supabase credentials in .env file');
      exit(1);
    }

    // Initialize Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    final supabase = Supabase.instance.client;

    print('1. Checking new tables...');

    // Check download_progress table
    final downloadProgressResult = await supabase
        .from('download_progress')
        .select('*')
        .limit(1);
    print('   ✓ download_progress table exists');

    // Check course_downloads table
    final courseDownloadsResult = await supabase
        .from('course_downloads')
        .select('*')
        .limit(1);
    print('   ✓ course_downloads table exists');

    print('\n2. Checking learning_objects table updates...');

    // Check new columns in learning_objects
    final learningObjectResult = await supabase
        .from('learning_objects')
        .select('id, title, audio_url, content_url, timing_url, file_version, download_status')
        .eq('id', '63ad7b78-0970-4265-a4fe-51f3fee39d5f')
        .single();

    print('   ✓ New columns added to learning_objects table');
    print('\n3. Test learning object CDN URLs:');
    print('   - Title: ${learningObjectResult['title']}');
    print('   - Audio URL: ${learningObjectResult['audio_url']}');
    print('   - Content URL: ${learningObjectResult['content_url']}');
    print('   - Timing URL: ${learningObjectResult['timing_url']}');
    print('   - Download Status: ${learningObjectResult['download_status']}');
    print('   - File Version: ${learningObjectResult['file_version']}');

    print('\n4. Testing helper function...');

    // Test the helper function (will return empty results since no user data exists)
    final functionResult = await supabase.rpc('get_course_download_stats', params: {
      'p_user_id': '00000000-0000-0000-0000-000000000000',  // Dummy UUID
      'p_course_id': '8c42f8b7-3d91-4b5e-a5f6-2e7d8c9b1a3f'   // Our test course ID
    });

    print('   ✓ Helper function get_course_download_stats exists');
    print('   - Function returned: $functionResult');

    print('\n✅ Migration verified successfully!');
    print('\nNext steps:');
    print('1. Storage buckets still need to be created (course-audio, course-content, course-timing)');
    print('2. Pre-processed content needs to be generated and uploaded');
    print('3. CourseDownloadService can now fetch CDN URLs from the database');

  } catch (e) {
    print('❌ Error during verification: $e');
    exit(1);
  }

  exit(0);
}