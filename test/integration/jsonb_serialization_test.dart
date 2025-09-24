/// JSONB Serialization Test
///
/// Purpose: Test JSONB field serialization/deserialization
/// This test validates proper handling of snake_case JSONB fields

import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/models/learning_object_v2.dart';
import 'package:audio_learning_app/models/word_timing.dart';
import 'package:audio_learning_app/models/sentence_timing.dart';
import 'package:audio_learning_app/models/content_metadata.dart';

void main() {
  group('JSONB Serialization Tests', () {
    test('Word timings should serialize/deserialize with snake_case', () {
      // Create test data with snake_case fields
      final jsonData = {
        'word': 'Insurance',
        'start_ms': 0,
        'end_ms': 500,
        'char_start': 0,
        'char_end': 9,
        'sentence_index': 0,
      };

      // Deserialize
      final wordTiming = WordTiming.fromJson(jsonData);
      expect(wordTiming.word, equals('Insurance'));
      expect(wordTiming.startMs, equals(0));
      expect(wordTiming.endMs, equals(500));
      expect(wordTiming.charStart, equals(0));
      expect(wordTiming.charEnd, equals(9));
      expect(wordTiming.sentenceIndex, equals(0));

      // Serialize back
      final serialized = wordTiming.toJson();
      expect(serialized['word'], equals('Insurance'));
      expect(serialized['start_ms'], equals(0));
      expect(serialized['end_ms'], equals(500));
      expect(serialized['char_start'], equals(0));
      expect(serialized['char_end'], equals(9));
      expect(serialized['sentence_index'], equals(0));
    });

    test('Sentence timings should serialize/deserialize with snake_case', () {
      final jsonData = {
        'text': 'Insurance is a critical component of risk management.',
        'start_ms': 0,
        'end_ms': 3000,
        'sentence_index': 0,
        'word_start_index': 0,
        'word_end_index': 8,
        'char_start': 0,
        'char_end': 54,
      };

      // Deserialize
      final sentenceTiming = SentenceTiming.fromJson(jsonData);
      expect(sentenceTiming.text,
          equals('Insurance is a critical component of risk management.'));
      expect(sentenceTiming.startMs, equals(0));
      expect(sentenceTiming.endMs, equals(3000));
      expect(sentenceTiming.sentenceIndex, equals(0));
      expect(sentenceTiming.wordStartIndex, equals(0));
      expect(sentenceTiming.wordEndIndex, equals(8));

      // Serialize back
      final serialized = sentenceTiming.toJson();
      expect(serialized['text'],
          equals('Insurance is a critical component of risk management.'));
      expect(serialized['start_ms'], equals(0));
      expect(serialized['end_ms'], equals(3000));
      expect(serialized['sentence_index'], equals(0));
      expect(serialized['word_start_index'], equals(0));
      expect(serialized['word_end_index'], equals(8));
    });

    test('Content metadata should serialize/deserialize correctly', () {
      final jsonData = {
        'word_count': 150,
        'character_count': 950,
        'estimated_reading_time': '2 min',
        'language': 'en',
        'complexity_score': 7.5,
      };

      // Deserialize
      final metadata = ContentMetadata.fromJson(jsonData);
      expect(metadata.wordCount, equals(150));
      expect(metadata.characterCount, equals(950));
      expect(metadata.estimatedReadingTime, equals('2 min'));
      expect(metadata.language, equals('en'));
      // complexityScore not implemented yet

      // Serialize back
      final serialized = metadata.toJson();
      expect(serialized['word_count'], equals(150));
      expect(serialized['character_count'], equals(950));
      expect(serialized['estimated_reading_time'], equals('2 min'));
      expect(serialized['language'], equals('en'));
      expect(serialized['complexity_score'], equals(7.5));
    });

    test('LearningObjectV2 should handle complete JSONB structure', () {
      // Complete test data mimicking database structure
      final jsonData = {
        'id': 'lo-test-123',
        'assignment_id': 'assignment-456',
        'course_id': 'course-789',
        'title': 'Insurance Fundamentals',
        'order_index': 0,
        'display_text': 'Insurance is essential.\n\nIt provides protection.',
        'paragraphs': [
          'Insurance is essential.',
          'It provides protection.',
        ],
        'headers': [
          {'text': 'Introduction', 'level': 1, 'position': 0}
        ],
        'formatting': {
          'bold_headers': true,
          'paragraph_spacing': true,
        },
        'metadata': {
          'word_count': 5,
          'character_count': 45,
          'estimated_reading_time': '1 min',
          'language': 'en',
        },
        'word_timings': [
          {
            'word': 'Insurance',
            'start_ms': 0,
            'end_ms': 500,
            'char_start': 0,
            'char_end': 9,
            'sentence_index': 0,
          },
          {
            'word': 'is',
            'start_ms': 500,
            'end_ms': 700,
            'char_start': 10,
            'char_end': 12,
            'sentence_index': 0,
          },
        ],
        'sentence_timings': [
          {
            'text': 'Insurance is essential.',
            'start_ms': 0,
            'end_ms': 1500,
            'sentence_index': 0,
            'word_start_index': 0,
            'word_end_index': 2,
            'char_start': 0,
            'char_end': 23,
          },
        ],
        'total_duration_ms': 5000,
        'audio_url': 'https://cdn.example.com/audio.mp3',
        'audio_size_bytes': 102400,
        'audio_format': 'mp3',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-02T00:00:00Z',
      };

      // Deserialize
      final learningObject = LearningObjectV2.fromJson(jsonData);

      // Verify all fields
      expect(learningObject.id, equals('lo-test-123'));
      expect(learningObject.title, equals('Insurance Fundamentals'));
      expect(learningObject.displayText, contains('Insurance is essential'));
      expect(learningObject.paragraphs.length, equals(2));
      expect(learningObject.wordTimings.length, equals(2));
      expect(learningObject.sentenceTimings.length, equals(1));
      expect(learningObject.metadata.wordCount, equals(5));
      expect(learningObject.formatting.boldHeaders, isTrue);
      expect(learningObject.totalDurationMs, equals(5000));
      expect(
          learningObject.audioUrl, equals('https://cdn.example.com/audio.mp3'));

      // Serialize back and verify structure
      final serialized = learningObject.toJson();
      expect(serialized['word_timings'], isList);
      expect((serialized['word_timings'] as List).first['start_ms'], equals(0));
      expect(serialized['sentence_timings'], isList);
      expect((serialized['sentence_timings'] as List).first['start_ms'],
          equals(0));
      expect(serialized['metadata']['word_count'], equals(5));
      expect(serialized['formatting']['bold_headers'], isTrue);
    });

    test('JSONB arrays should maintain order', () {
      final wordTimings = [
        WordTiming(
          word: 'First',
          startMs: 0,
          endMs: 100,
          sentenceIndex: 0,
        ),
        WordTiming(
          word: 'Second',
          startMs: 100,
          endMs: 200,
          sentenceIndex: 0,
        ),
        WordTiming(
          word: 'Third',
          startMs: 200,
          endMs: 300,
          sentenceIndex: 1,
        ),
      ];

      // Serialize to JSON array
      final jsonArray = wordTimings.map((wt) => wt.toJson()).toList();

      // Verify order is maintained
      expect(jsonArray[0]['word'], equals('First'));
      expect(jsonArray[1]['word'], equals('Second'));
      expect(jsonArray[2]['word'], equals('Third'));

      // Deserialize back
      final deserialized =
          jsonArray.map((json) => WordTiming.fromJson(json)).toList();

      expect(deserialized[0].word, equals('First'));
      expect(deserialized[1].word, equals('Second'));
      expect(deserialized[2].word, equals('Third'));
    });

    test('Nested JSONB objects should handle null values', () {
      // Test with minimal data (many nulls)
      final minimalJson = {
        'id': 'lo-minimal',
        'assignment_id': 'assignment-1',
        'course_id': 'course-1',
        'title': 'Minimal',
        'order_index': 0,
        'display_text': 'Text',
        'paragraphs': ['Text'],
        'headers': [],
        'formatting': {},
        'metadata': {
          'word_count': 1,
          'character_count': 4,
          'estimated_reading_time': '1 min',
          'language': 'en',
        },
        'word_timings': [],
        'sentence_timings': [],
        'total_duration_ms': 1000,
        'audio_url': 'https://example.com/audio.mp3',
        'audio_size_bytes': 1024,
        'audio_format': 'mp3',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      // Should not throw
      final learningObject = LearningObjectV2.fromJson(minimalJson);
      expect(learningObject.wordTimings, isEmpty);
      expect(learningObject.sentenceTimings, isEmpty);
      expect(learningObject.headers, isEmpty);
      expect(learningObject.formatting.boldHeaders, isFalse); // default value
    });
  });
}
