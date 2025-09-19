#!/usr/bin/env dart
/// Script to generate test MP3 files using Speechify API
///
/// Usage: dart scripts/generate_test_audio.dart
///
/// This script will:
/// 1. Call Speechify API to generate audio for test content
/// 2. Save MP3 files to assets/test_content/
/// 3. Extract and save word timings
/// 4. Create content.json and timing.json files

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Test content definitions
class TestContent {
  final String id;
  final String title;
  final String text;
  final List<String> paragraphs;

  TestContent({
    required this.id,
    required this.title,
    required this.text,
    required this.paragraphs,
  });
}

final testContents = [
  TestContent(
    id: 'test-short',
    title: 'Short Test - Introduction to Case Reserves',
    text: '''Understanding Case Reserve Management. A case reserve represents the estimated amount of money an insurance company expects to pay for a claim. This critical financial tool serves multiple purposes in the claims management process. Accurate reserves are essential for regulatory compliance, strategic planning, and financial reporting. Insurance companies rely on precise reserve calculations to maintain solvency and meet their obligations to policyholders.''',
    paragraphs: [
      'Understanding Case Reserve Management.',
      'A case reserve represents the estimated amount of money an insurance company expects to pay for a claim.',
      'This critical financial tool serves multiple purposes in the claims management process.',
      'Accurate reserves are essential for regulatory compliance, strategic planning, and financial reporting.',
      'Insurance companies rely on precise reserve calculations to maintain solvency and meet their obligations to policyholders.',
    ],
  ),
  TestContent(
    id: 'test-medium',
    title: 'Medium Test - Components of Case Reserves',
    text: '''Case Reserve Components and Calculation Methods. Every case reserve should incorporate multiple elements to ensure accuracy and completeness. The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf. This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases. Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses. These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees. Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle. The timing of payments also affects reserve calculations. A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation. Claims professionals must consider the time value of money, especially for claims that may take years to resolve. Documentation is crucial when setting initial reserves. Adjusters should clearly record their reasoning, the factors considered, and any assumptions made. This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters. Regular review and adjustment of case reserves ensures they remain accurate as claims develop. Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim's complexity and value.''',
    paragraphs: [
      'Case Reserve Components and Calculation Methods.',
      'Every case reserve should incorporate multiple elements to ensure accuracy and completeness.',
      'The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf.',
      'This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases.',
      'Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses.',
      'These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees.',
      'Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle.',
      'The timing of payments also affects reserve calculations.',
      'A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation.',
      'Claims professionals must consider the time value of money, especially for claims that may take years to resolve.',
      'Documentation is crucial when setting initial reserves.',
      'Adjusters should clearly record their reasoning, the factors considered, and any assumptions made.',
      'This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters.',
      'Regular review and adjustment of case reserves ensures they remain accurate as claims develop.',
      'Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim\'s complexity and value.',
    ],
  ),
  TestContent(
    id: '63ad7b78-0970-4265-a4fe-51f3fee39d5f',
    title: 'Full Test - Complete Case Reserve Management',
    text: '''Understanding Case Reserve Management in Insurance Claims Processing. A case reserve represents the estimated amount of money an insurance company expects to pay for a claim. This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting. When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure. This initial evaluation becomes the foundation for the case reserve. The reserve amount includes not only the expected indemnity payment to the claimant but also allocated loss adjustment expenses, legal fees, and expert witness costs that may arise during the claims process. Insurance companies rely on accurate case reserves for several vital business functions. First, reserves directly impact the company's financial statements and must be reported to regulators and shareholders. Second, they influence reinsurance recoveries and treaty arrangements. Third, accurate reserves enable better pricing decisions for future policies. Finally, they provide management with crucial data for strategic planning and capital allocation decisions. Every case reserve should incorporate multiple elements to ensure accuracy and completeness. The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf. This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases. Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses. These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees. Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle. The timing of payments also affects reserve calculations. A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation. Claims professionals must consider the time value of money, especially for claims that may take years to resolve. Establishing accurate initial reserves requires a systematic approach combined with professional judgment. The process begins with a thorough investigation of the claim circumstances, including witness statements, police reports, medical records, and any available surveillance footage. This information provides the factual foundation for the reserve evaluation. Documentation is crucial when setting initial reserves. Adjusters should clearly record their reasoning, the factors considered, and any assumptions made. This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters. Case reserves are not static figures. They require regular review and adjustment as new information emerges and circumstances change. Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim's complexity and value. Thank you for completing this lesson on case reserve management. Remember that effective reserve management remains fundamental to successful claims operations.''',
    paragraphs: [
      'Understanding Case Reserve Management in Insurance Claims Processing.',
      'A case reserve represents the estimated amount of money an insurance company expects to pay for a claim.',
      'This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting.',
      'When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure.',
      'This initial evaluation becomes the foundation for the case reserve.',
      'The reserve amount includes not only the expected indemnity payment to the claimant but also allocated loss adjustment expenses, legal fees, and expert witness costs that may arise during the claims process.',
      'Insurance companies rely on accurate case reserves for several vital business functions.',
      'First, reserves directly impact the company\'s financial statements and must be reported to regulators and shareholders.',
      'Second, they influence reinsurance recoveries and treaty arrangements.',
      'Third, accurate reserves enable better pricing decisions for future policies.',
      'Finally, they provide management with crucial data for strategic planning and capital allocation decisions.',
      'Every case reserve should incorporate multiple elements to ensure accuracy and completeness.',
      'The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf.',
      'This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases.',
      'Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses.',
      'These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees.',
      'Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle.',
      'The timing of payments also affects reserve calculations.',
      'A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation.',
      'Claims professionals must consider the time value of money, especially for claims that may take years to resolve.',
      'Establishing accurate initial reserves requires a systematic approach combined with professional judgment.',
      'The process begins with a thorough investigation of the claim circumstances, including witness statements, police reports, medical records, and any available surveillance footage.',
      'This information provides the factual foundation for the reserve evaluation.',
      'Documentation is crucial when setting initial reserves.',
      'Adjusters should clearly record their reasoning, the factors considered, and any assumptions made.',
      'This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters.',
      'Case reserves are not static figures.',
      'They require regular review and adjustment as new information emerges and circumstances change.',
      'Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim\'s complexity and value.',
      'Thank you for completing this lesson on case reserve management.',
      'Remember that effective reserve management remains fundamental to successful claims operations.',
    ],
  ),
];

void main() async {
  print('🎙️ Speechify Test Audio Generator');
  print('=' * 50);

  // Load environment variables
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['SPEECHIFY_API_KEY'];

  if (apiKey == null || apiKey == 'YOUR_ACTUAL_SPEECHIFY_API_KEY_HERE') {
    print('❌ ERROR: Please set your actual Speechify API key in .env file');
    print('   Edit .env and replace YOUR_ACTUAL_SPEECHIFY_API_KEY_HERE with your key');
    exit(1);
  }

  print('✅ API key loaded from .env');

  // Create Dio client
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.sws.speechify.com',
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  // Create output directory
  final outputDir = Directory('assets/test_content/learning_objects');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
    print('📁 Created output directory: ${outputDir.path}');
  }

  // Process each test content
  for (final content in testContents) {
    print('\n📝 Processing: ${content.title}');
    print('   Text length: ${content.text.length} characters');

    try {
      // Create content directory
      final contentDir = Directory('${outputDir.path}/${content.id}');
      if (!contentDir.existsSync()) {
        contentDir.createSync(recursive: true);
      }

      // Call Speechify API
      print('   🌐 Calling Speechify API...');
      final response = await dio.post(
        '/v1/audio/speech',
        data: {
          'input': content.text,
          'voice_id': 'henry',
          'model': 'simba-turbo',
          'speed': 1.0,
          'include_speech_marks': true,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Save MP3 file
        if (data['audio_data'] != null) {
          final audioBytes = base64.decode(data['audio_data']);
          final audioFile = File('${contentDir.path}/audio.mp3');
          await audioFile.writeAsBytes(audioBytes);
          print('   ✅ Saved audio.mp3 (${audioBytes.length} bytes)');
        }

        // Create content.json
        final contentJson = {
          'version': '1.0',
          'displayText': content.text,
          'paragraphs': content.paragraphs,
          'metadata': {
            'wordCount': content.text.split(RegExp(r'\s+')).length,
            'characterCount': content.text.length,
            'estimatedReadingTime': '${(content.text.split(RegExp(r'\s+')).length / 200).ceil()} minutes',
            'language': 'en',
          },
        };

        final contentFile = File('${contentDir.path}/content.json');
        await contentFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(contentJson),
        );
        print('   ✅ Saved content.json');

        // Process word timings
        if (data['speech_marks'] != null) {
          final speechMarks = data['speech_marks'] as List;
          final words = <Map<String, dynamic>>[];
          final sentences = <Map<String, dynamic>>[];

          int wordIndex = 0;
          int currentSentenceStart = 0;
          String currentSentenceText = '';
          int sentenceStartMs = 0;

          for (final mark in speechMarks) {
            if (mark['type'] == 'word') {
              final word = {
                'word': mark['value'],
                'startMs': mark['time'],
                'endMs': mark['end_time'] ?? mark['time'] + 200,
                'charStart': mark['start'],
                'charEnd': mark['end'],
              };
              words.add(word);

              currentSentenceText += '${mark['value']} ';

              // Detect sentence boundary (simplified)
              if (mark['value'].endsWith('.') ||
                  mark['value'].endsWith('!') ||
                  mark['value'].endsWith('?')) {
                sentences.add({
                  'text': currentSentenceText.trim(),
                  'startMs': sentenceStartMs,
                  'endMs': mark['end_time'] ?? mark['time'] + 200,
                  'wordStartIndex': currentSentenceStart,
                  'wordEndIndex': wordIndex,
                  'charStart': words[currentSentenceStart]['charStart'],
                  'charEnd': mark['end'],
                });

                currentSentenceStart = wordIndex + 1;
                currentSentenceText = '';
                sentenceStartMs = mark['end_time'] ?? mark['time'] + 350;
              }

              wordIndex++;
            }
          }

          // Handle remaining text as final sentence
          if (currentSentenceText.isNotEmpty) {
            sentences.add({
              'text': currentSentenceText.trim(),
              'startMs': sentenceStartMs,
              'endMs': words.isNotEmpty ? words.last['endMs'] : 0,
              'wordStartIndex': currentSentenceStart,
              'wordEndIndex': words.length - 1,
              'charStart': currentSentenceStart < words.length ? words[currentSentenceStart]['charStart'] : 0,
              'charEnd': words.isNotEmpty ? words.last['charEnd'] : content.text.length,
            });
          }

          // Create timing.json
          final timingJson = {
            'version': '1.0',
            'words': words,
            'sentences': sentences,
            'totalDurationMs': words.isNotEmpty ? words.last['endMs'] : 0,
          };

          final timingFile = File('${contentDir.path}/timing.json');
          await timingFile.writeAsString(
            const JsonEncoder.withIndent('  ').convert(timingJson),
          );
          print('   ✅ Saved timing.json (${words.length} words, ${sentences.length} sentences)');
        }

        print('   ✅ Complete: ${content.id}');
      } else {
        print('   ❌ API error: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Error: $e');
    }
  }

  print('\n✅ Test audio generation complete!');
  print('📁 Files saved to: assets/test_content/learning_objects/');
  print('\n📝 Next steps:');
  print('   1. Update pubspec.yaml to include the assets');
  print('   2. Run flutter pub get');
  print('   3. Test with LocalContentService');
}