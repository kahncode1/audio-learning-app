#!/usr/bin/env dart

/// Script to upload test content to Supabase Storage
///
/// This script uploads our test learning object files to the Supabase Storage buckets
/// to enable testing of the CDN download functionality.
///
/// Usage: dart scripts/upload_test_content.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://cmjdciktvfxiyapdseqn.supabase.co';
const String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtamRjaWt0dmZ4aXlhcGRzZXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjYyODU5MzcsImV4cCI6MjA0MTg2MTkzN30.qI37kGFa7p9WRC0G3F8oUdN1604OXZ0l1wVlZsLRmLo';

// Test learning object ID
const String learningObjectId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f';
const String courseId = 'INS-101'; // Course ID for organization

// Local file paths
const String basePath = 'assets/test_content/learning_objects/$learningObjectId';

Future<void> main() async {
  print('🚀 Starting Supabase Storage upload script...\n');

  try {
    // Initialize Supabase client
    print('📦 Initializing Supabase client...');
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );

    final supabase = Supabase.instance.client;
    print('✅ Supabase client initialized\n');

    // Upload audio file
    await uploadFile(
      supabase: supabase,
      bucket: 'course-audio',
      localPath: '$basePath/audio.mp3',
      storagePath: '$courseId/$learningObjectId/audio.mp3',
      contentType: 'audio/mpeg',
    );

    // Upload content JSON
    await uploadFile(
      supabase: supabase,
      bucket: 'course-content',
      localPath: '$basePath/content.json',
      storagePath: '$courseId/$learningObjectId/content.json',
      contentType: 'application/json',
    );

    // Upload timing JSON
    await uploadFile(
      supabase: supabase,
      bucket: 'course-timing',
      localPath: '$basePath/timing.json',
      storagePath: '$courseId/$learningObjectId/timing.json',
      contentType: 'application/json',
    );

    print('\n✅ All files uploaded successfully!\n');

    // Generate and display CDN URLs
    print('📍 CDN URLs for uploaded files:\n');
    print('Audio URL:');
    print('  ${supabaseUrl}/storage/v1/object/public/course-audio/$courseId/$learningObjectId/audio.mp3');
    print('\nContent URL:');
    print('  ${supabaseUrl}/storage/v1/object/public/course-content/$courseId/$learningObjectId/content.json');
    print('\nTiming URL:');
    print('  ${supabaseUrl}/storage/v1/object/public/course-timing/$courseId/$learningObjectId/timing.json');

    print('\n📝 Next step: Update the database with these CDN URLs');

  } catch (e, stack) {
    print('❌ Error: $e');
    print('Stack trace:\n$stack');
    exit(1);
  }

  exit(0);
}

Future<void> uploadFile({
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
      throw Exception('File not found: $localPath');
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

  } catch (e) {
    print('   ❌ Upload failed: $e');
    rethrow;
  }
}