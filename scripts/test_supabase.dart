#!/usr/bin/env dart

/// Supabase Connection Test and Sample Data Creation
///
/// Purpose: Test Supabase connection and optionally create sample data
/// Usage: dart scripts/test_supabase.dart

import 'dart:io';
import 'dart:convert';

void main() async {

  // Read environment variables
  final envFile = File('.env');
  if (!envFile.existsSync()) {
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
    exit(1);
  }


  // Test connection
  try {
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('$supabaseUrl/rest/v1/courses?select=count'),
    );
    request.headers.add('apikey', supabaseAnonKey);
    request.headers.add('Authorization', 'Bearer $supabaseAnonKey');

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 200) {

      final data = jsonDecode(responseBody);
    } else {
    }

    client.close();
  } catch (e) {
    exit(1);
  }

  // Prompt to create sample data
  final input = stdin.readLineSync();

  if (input?.toLowerCase() == 'y') {
    await createSampleData(supabaseUrl, supabaseAnonKey);
  } else {
  }

}

Future<void> createSampleData(String supabaseUrl, String anonKey) async {

  final client = HttpClient();

  try {
    // Create sample courses
    final coursesData = [
      {
        'course_number': 'INS-101',
        'title': 'Introduction to Insurance Fundamentals',
        'description': 'Learn the basics of insurance principles, risk management, and industry practices.',
        'gradient_start_color': '#2196F3',
        'gradient_end_color': '#1976D2',
        'total_duration_ms': 7200000, // 2 hours
      },
      {
        'course_number': 'INS-201',
        'title': 'Advanced Risk Management',
        'description': 'Deep dive into risk assessment, mitigation strategies, and enterprise risk management.',
        'gradient_start_color': '#4CAF50',
        'gradient_end_color': '#388E3C',
        'total_duration_ms': 10800000, // 3 hours
      },
      {
        'course_number': 'INS-301',
        'title': 'Insurance Law and Regulations',
        'description': 'Comprehensive overview of insurance law, regulations, and compliance requirements.',
        'gradient_start_color': '#FF5722',
        'gradient_end_color': '#E64A19',
        'total_duration_ms': 9000000, // 2.5 hours
      },
    ];

    for (final course in coursesData) {
      final request = await client.postUrl(
        Uri.parse('$supabaseUrl/rest/v1/courses'),
      );
      request.headers.add('apikey', anonKey);
      request.headers.add('Authorization', 'Bearer $anonKey');
      request.headers.add('Content-Type', 'application/json');
      request.headers.add('Prefer', 'return=representation');

      request.write(jsonEncode(course));
      final response = await request.close();

      if (response.statusCode == 201) {
        final responseBody = await response.transform(utf8.decoder).join();
        final created = jsonDecode(responseBody);
        if (created is List && created.isNotEmpty) {

          // Create assignments for this course
          await createAssignments(supabaseUrl, anonKey, created[0]['id'] as String, course['course_number'] as String);
        }
      } else {
        final error = await response.transform(utf8.decoder).join();
      }
    }

  } catch (e) {
  } finally {
    client.close();
  }
}

Future<void> createAssignments(
  String supabaseUrl,
  String anonKey,
  String courseId,
  String courseNumber,
) async {
  final client = HttpClient();

  try {
    final assignmentsData = [
      {
        'course_id': courseId,
        'assignment_number': 1,
        'title': 'Module 1: Foundation Concepts',
        'description': 'Introduction to core concepts and terminology',
        'order_index': 0,
      },
      {
        'course_id': courseId,
        'assignment_number': 2,
        'title': 'Module 2: Practical Applications',
        'description': 'Real-world applications and case studies',
        'order_index': 1,
      },
      {
        'course_id': courseId,
        'assignment_number': 3,
        'title': 'Module 3: Advanced Topics',
        'description': 'Deep dive into specialized areas',
        'order_index': 2,
      },
    ];

    for (final assignment in assignmentsData) {
      final request = await client.postUrl(
        Uri.parse('$supabaseUrl/rest/v1/assignments'),
      );
      request.headers.add('apikey', anonKey);
      request.headers.add('Authorization', 'Bearer $anonKey');
      request.headers.add('Content-Type', 'application/json');
      request.headers.add('Prefer', 'return=representation');

      request.write(jsonEncode(assignment));
      final response = await request.close();

      if (response.statusCode == 201) {
        final responseBody = await response.transform(utf8.decoder).join();
        final created = jsonDecode(responseBody);
        if (created is List && created.isNotEmpty) {

          // Create learning objects for this assignment
          await createLearningObjects(supabaseUrl, anonKey, created[0]['id']);
        }
      } else {
        final error = await response.transform(utf8.decoder).join();
      }
    }

  } catch (e) {
  } finally {
    client.close();
  }
}

Future<void> createLearningObjects(
  String supabaseUrl,
  String anonKey,
  String assignmentId,
) async {
  final client = HttpClient();

  try {
    final learningObjectsData = [
      {
        'assignment_id': assignmentId,
        'title': 'Introduction Video',
        'content_type': 'video',
        'plain_text': 'Welcome to this module. In this section, we will explore the fundamental concepts that form the foundation of our subject matter.',
        'duration_ms': 300000, // 5 minutes
        'order_index': 0,
      },
      {
        'assignment_id': assignmentId,
        'title': 'Main Content',
        'content_type': 'text',
        'plain_text': 'This is the main content of the learning module. It contains detailed information about the topic, with examples and explanations.',
        'ssml_content': '<speak>This is the main content of the learning module. <break time="500ms"/> It contains detailed information about the topic, with examples and explanations.</speak>',
        'duration_ms': 600000, // 10 minutes
        'order_index': 1,
      },
      {
        'assignment_id': assignmentId,
        'title': 'Summary and Review',
        'content_type': 'text',
        'plain_text': 'Let\'s review what we\'ve learned in this module. The key takeaways are important for your understanding.',
        'duration_ms': 180000, // 3 minutes
        'order_index': 2,
      },
    ];

    for (final learningObject in learningObjectsData) {
      final request = await client.postUrl(
        Uri.parse('$supabaseUrl/rest/v1/learning_objects'),
      );
      request.headers.add('apikey', anonKey);
      request.headers.add('Authorization', 'Bearer $anonKey');
      request.headers.add('Content-Type', 'application/json');
      request.headers.add('Prefer', 'return=representation');

      request.write(jsonEncode(learningObject));
      final response = await request.close();

      if (response.statusCode == 201) {
        final responseBody = await response.transform(utf8.decoder).join();
        final created = jsonDecode(responseBody);
        if (created is List && created.isNotEmpty) {
        }
      } else {
        final error = await response.transform(utf8.decoder).join();
      }
    }

  } catch (e) {
  } finally {
    client.close();
  }
}

// Run: dart scripts/test_supabase.dart