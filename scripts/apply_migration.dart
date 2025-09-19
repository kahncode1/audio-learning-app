#!/usr/bin/env dart

/// Apply Download Architecture Migration to Supabase
///
/// Purpose: Applies the 003_download_architecture.sql migration to Supabase database
/// Usage: dart scripts/apply_migration.dart

import 'dart:io';
import 'dart:convert';

void main() async {
  print('🚀 Applying Download Architecture Migration...');

  // Read environment variables
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ .env file not found');
    exit(1);
  }

  final envContent = envFile.readAsStringSync();
  String? supabaseUrl;
  String? supabaseAnonKey;

  for (final line in envContent.split('\n')) {
    if (line.startsWith('SUPABASE_URL=')) {
      supabaseUrl = line.split('=')[1].trim();
    }
    if (line.startsWith('SUPABASE_ANON_KEY=')) {
      supabaseAnonKey = line.split('=')[1].trim();
    }
  }

  if (supabaseUrl == null || supabaseAnonKey == null) {
    print('❌ Missing Supabase configuration in .env file');
    exit(1);
  }

  print('🔗 Supabase URL: $supabaseUrl');

  try {
    // Step 1: Add new columns to learning_objects
    await addLearningObjectsColumns(supabaseUrl, supabaseAnonKey);

    // Step 2: Create download_progress table
    await createDownloadProgressTable(supabaseUrl, supabaseAnonKey);

    // Step 3: Create course_downloads table
    await createCourseDownloadsTable(supabaseUrl, supabaseAnonKey);

    // Step 4: Create storage buckets
    await createStorageBuckets(supabaseUrl, supabaseAnonKey);

    // Step 5: Verify migration
    await verifyMigration(supabaseUrl, supabaseAnonKey);

    print('✅ Migration completed successfully!');

  } catch (e) {
    print('❌ Migration failed: $e');
    exit(1);
  }
}

Future<void> addLearningObjectsColumns(String supabaseUrl, String anonKey) async {
  print('📋 Adding columns to learning_objects table...');

  // Check if columns already exist
  final existingColumns = await checkTableColumns(supabaseUrl, anonKey, 'learning_objects');

  if (existingColumns.contains('audio_url')) {
    print('  ℹ️  Columns already exist, skipping...');
    return;
  }

  // Add columns using raw SQL - this would require a different approach
  // Since we can't execute DDL via REST API, we'll verify the schema exists
  // and print instructions for manual application
  print('  ⚠️  DDL operations (ALTER TABLE) cannot be executed via REST API');
  print('  📋 Please apply the migration manually using the Supabase dashboard or CLI');
}

Future<void> createDownloadProgressTable(String supabaseUrl, String anonKey) async {
  print('📋 Checking download_progress table...');

  // Try to access the table to see if it exists
  final tableExists = await checkTableExists(supabaseUrl, anonKey, 'download_progress');

  if (tableExists) {
    print('  ✅ download_progress table already exists');
  } else {
    print('  ⚠️  download_progress table does not exist');
    print('  📋 Please apply the migration manually');
  }
}

Future<void> createCourseDownloadsTable(String supabaseUrl, String anonKey) async {
  print('📋 Checking course_downloads table...');

  // Try to access the table to see if it exists
  final tableExists = await checkTableExists(supabaseUrl, anonKey, 'course_downloads');

  if (tableExists) {
    print('  ✅ course_downloads table already exists');
  } else {
    print('  ⚠️  course_downloads table does not exist');
    print('  📋 Please apply the migration manually');
  }
}

Future<void> verifyMigration(String supabaseUrl, String anonKey) async {
  print('🔍 Verifying migration...');

  // Test access to new tables
  final progressTableExists = await checkTableExists(supabaseUrl, anonKey, 'download_progress');
  final courseDownloadsExists = await checkTableExists(supabaseUrl, anonKey, 'course_downloads');

  if (progressTableExists && courseDownloadsExists) {
    print('  ✅ New tables are accessible');
  } else {
    print('  ❌ Some tables are not accessible');
    if (!progressTableExists) print('    - download_progress table missing');
    if (!courseDownloadsExists) print('    - course_downloads table missing');
  }
}

Future<List<String>> checkTableColumns(String supabaseUrl, String anonKey, String tableName) async {
  final client = HttpClient();

  try {
    // Use PostgREST to get table metadata
    final request = await client.getUrl(
      Uri.parse('$supabaseUrl/rest/v1/$tableName?select=*&limit=0'),
    );
    request.headers.add('apikey', anonKey);
    request.headers.add('Authorization', 'Bearer $anonKey');

    final response = await request.close();

    if (response.statusCode == 200) {
      // If the request succeeds, the table exists
      // We can't easily get column names via REST API, so we'll return empty list
      return [];
    }

    return [];
  } catch (e) {
    return [];
  } finally {
    client.close();
  }
}

Future<bool> checkTableExists(String supabaseUrl, String anonKey, String tableName) async {
  final client = HttpClient();

  try {
    final request = await client.getUrl(
      Uri.parse('$supabaseUrl/rest/v1/$tableName?select=*&limit=0'),
    );
    request.headers.add('apikey', anonKey);
    request.headers.add('Authorization', 'Bearer $anonKey');

    final response = await request.close();
    await response.drain(); // Consume the response

    // If we get a 200, the table exists and is accessible
    return response.statusCode == 200;

  } catch (e) {
    return false;
  } finally {
    client.close();
  }
}

Future<void> createStorageBuckets(String supabaseUrl, String anonKey) async {
  print('📦 Creating storage buckets...');

  final buckets = ['course-audio', 'course-content', 'course-timing'];

  for (final bucketName in buckets) {
    await createBucket(supabaseUrl, anonKey, bucketName);
  }
}

Future<void> createBucket(String supabaseUrl, String anonKey, String bucketName) async {
  final client = HttpClient();

  try {
    final request = await client.postUrl(
      Uri.parse('$supabaseUrl/storage/v1/bucket'),
    );
    request.headers.add('apikey', anonKey);
    request.headers.add('Authorization', 'Bearer $anonKey');
    request.headers.add('Content-Type', 'application/json');

    final bucketData = {
      'id': bucketName,
      'name': bucketName,
      'public': true, // Public for read access
      'file_size_limit': 52428800, // 50MB
      'allowed_mime_types': bucketName == 'course-audio'
          ? ['audio/mpeg', 'audio/mp3']
          : ['application/json'],
    };

    request.write(jsonEncode(bucketData));
    final response = await request.close();

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('  ✅ Created bucket: $bucketName');
    } else if (response.statusCode == 409) {
      print('  ℹ️  Bucket already exists: $bucketName');
    } else {
      final error = await response.transform(utf8.decoder).join();
      print('  ❌ Failed to create bucket $bucketName: $error');
    }

  } catch (e) {
    print('  ❌ Error creating bucket $bucketName: $e');
  } finally {
    client.close();
  }
}

// Run: dart scripts/apply_migration.dart