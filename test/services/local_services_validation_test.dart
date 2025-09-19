import 'package:flutter_test/flutter_test.dart';
import 'package:audio_learning_app/services/local_content_service.dart';
import 'package:audio_learning_app/services/word_timing_service_simplified.dart';
import 'package:audio_learning_app/services/audio_player_service_local.dart';

/// Test suite to run all validation functions for local services
///
/// Purpose: Validates that all download-first architecture services work correctly
/// This runs the built-in validation functions from each service.
void main() {
  group('Download-First Architecture - Phase 1 Validation', () {
    test('LocalContentService validation', () async {
      await validateLocalContentService();
    });

    test('WordTimingServiceSimplified validation', () async {
      await validateWordTimingServiceSimplified();
    });

    test('AudioPlayerServiceLocal validation', () async {
      await validateAudioPlayerServiceLocal();
    });
  });
}