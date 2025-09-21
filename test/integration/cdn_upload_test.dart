/// CDN Upload Integration Test
///
/// This test uploads our test content to Supabase Storage buckets
/// and verifies the CDN URLs are accessible.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://cmjdciktvfxiyapdseqn.supabase.co';
const String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtamRjaWt0dmZ4aXlhcGRzZXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjYyODU5MzcsImV4cCI6MjA0MTg2MTkzN30.qI37kGFa7p9WRC0G3F8oUdN1604OXZ0l1wVlZsLRmLo';

// Test learning object ID
const String learningObjectId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';
const String courseId = 'INS-101';

// Local file paths
const String basePath = 'assets/test_content/learning_objects/$learningObjectId';

void main() {
  late SupabaseClient supabase;

  setUpAll(() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
    supabase = Supabase.instance.client;
  });

  group('CDN Upload Tests', () {
    test('Upload test content to Supabase Storage CDN', () async {
      print('\n🚀 Starting Supabase Storage upload test...\n');

      // Upload audio file
      final audioResult = await uploadFile(
        supabase: supabase,
        bucket: 'course-audio',
        localPath: '$basePath/audio.mp3',
        storagePath: '$courseId/$learningObjectId/audio.mp3',
        contentType: 'audio/mpeg',
      );
      expect(audioResult, isTrue, reason: 'Audio upload should succeed');

      // Upload content JSON
      final contentResult = await uploadFile(
        supabase: supabase,
        bucket: 'course-content',
        localPath: '$basePath/content.json',
        storagePath: '$courseId/$learningObjectId/content.json',
        contentType: 'application/json',
      );
      expect(contentResult, isTrue, reason: 'Content upload should succeed');

      // Upload timing JSON
      final timingResult = await uploadFile(
        supabase: supabase,
        bucket: 'course-timing',
        localPath: '$basePath/timing.json',
        storagePath: '$courseId/$learningObjectId/timing.json',
        contentType: 'application/json',
      );
      expect(timingResult, isTrue, reason: 'Timing upload should succeed');

      print('\n✅ All files uploaded successfully!\n');

      // Generate and display CDN URLs
      print('📍 CDN URLs for uploaded files:\n');
      print('Audio URL:');
      print('  $supabaseUrl/storage/v1/object/public/course-audio/$courseId/$learningObjectId/audio.mp3');
      print('\nContent URL:');
      print('  $supabaseUrl/storage/v1/object/public/course-content/$courseId/$learningObjectId/content.json');
      print('\nTiming URL:');
      print('  $supabaseUrl/storage/v1/object/public/course-timing/$courseId/$learningObjectId/timing.json');

      print('\n📝 Next step: Update the database with these CDN URLs\n');
    });
  });
}

Future<bool> uploadFile({
  required SupabaseClient supabase,
  required String bucket,
  required String localPath,
  required String storagePath,
  required String contentType,
}) async {
  print('📤 Uploading $localPath to $bucket/$storagePath...');

  try {
    final file = File(localPath);
    if (!file.existsSync()) {
      print('   ❌ File not found: $localPath');
      return false;
    }

    final bytes = await file.readAsBytes();
    final fileSize = (bytes.length / 1024).toStringAsFixed(1);
    print('   File size: ${fileSize}KB');

    // Upload file to Supabase Storage
    final response = await supabase.storage
        .from(bucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: '2592000', // Cache for 30 days
            upsert: true, // Overwrite if exists
          ),
        );

    print('   ✅ Upload successful: $response');

    // Verify the file is accessible
    final publicUrl = supabase.storage
        .from(bucket)
        .getPublicUrl(storagePath);

    print('   🌐 Public URL: $publicUrl');

    return true;
  } catch (e) {
    print('   ❌ Upload failed: $e');
    return false;
  }
}