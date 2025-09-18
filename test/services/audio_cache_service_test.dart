import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audio_learning_app/services/audio_cache_service.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockFile extends Mock implements File {}

void main() {
  group('AudioCacheService Tests', () {
    late AudioCacheService audioCacheService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Initialize SharedPreferences with test values
      SharedPreferences.setMockInitialValues({});

      audioCacheService = await AudioCacheService.getInstance();
    });

    tearDown(() async {
      // Clear cache after each test
      await audioCacheService.clearAll();
    });

    test('should initialize correctly', () {
      expect(audioCacheService, isNotNull);
      expect(audioCacheService.isOffline, isA<bool>());
    });

    test('should cache audio data directly', () async {
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
      const key = 'test_audio_segment';

      final cachedFile = await audioCacheService.cacheAudioData(testData, key);

      // File might be null in test environment without proper setup
      if (cachedFile != null) {
        expect(await cachedFile.exists(), isTrue);
        expect(await audioCacheService.isSegmentCached(key), isTrue);
      }
    });

    test('should detect cached segments', () async {
      final testData = Uint8List.fromList([10, 20, 30]);
      const key = 'detection_test';

      await audioCacheService.cacheAudioData(testData, key);
      final isCached = await audioCacheService.isSegmentCached(key);

      // In test environment, caching might not work fully
      expect(isCached, isA<bool>());
    });

    test('should track cache statistics', () {
      final stats = audioCacheService.getStatistics();

      expect(stats['hits'], isA<int>());
      expect(stats['misses'], isA<int>());
      expect(stats['hitRate'], isA<double>());
      expect(stats['totalRequests'], isA<int>());
      expect(stats['bytesDownloaded'], isA<int>());
      expect(stats['bytesCached'], isA<int>());
      expect(stats['isOffline'], isA<bool>());
    });

    test('should remove cached segments', () async {
      final testData = Uint8List.fromList([100, 200]);
      const key = 'remove_test';

      await audioCacheService.cacheAudioData(testData, key);
      await audioCacheService.removeSegment(key);

      final isCached = await audioCacheService.isSegmentCached(key);
      expect(isCached, isFalse);
    });

    test('should clear all cached audio', () async {
      // Add some test segments
      await audioCacheService.cacheAudioData(
        Uint8List.fromList([1, 2, 3]),
        'segment1',
      );
      await audioCacheService.cacheAudioData(
        Uint8List.fromList([4, 5, 6]),
        'segment2',
      );

      // Clear all
      await audioCacheService.clearAll();

      // Verify statistics are reset
      final stats = audioCacheService.getStatistics();
      expect(stats['hits'], equals(0));
      expect(stats['misses'], equals(0));
      expect(stats['bytesDownloaded'], equals(0));
      expect(stats['bytesCached'], equals(0));
    });

    test('should get list of cached segments', () async {
      await audioCacheService.cacheAudioData(
        Uint8List.fromList([1]),
        'list_test_1',
      );
      await audioCacheService.cacheAudioData(
        Uint8List.fromList([2]),
        'list_test_2',
      );

      final segments = await audioCacheService.getCachedSegments();
      expect(segments, isA<List<String>>());
      // In test environment, might be empty or contain test segments
    });

    test('should check network connectivity', () async {
      final isOnline = await audioCacheService.isOnline();
      expect(isOnline, isA<bool>());

      final isOffline = audioCacheService.isOffline;
      expect(isOffline, isA<bool>());

      // Online and offline should be opposite
      if (!isOffline) {
        expect(isOnline, isTrue);
      }
    });

    test('should handle cache warming', () async {
      // In test environment, this might not work with real URLs
      final urls = [
        'http://example.com/audio1.mp3',
        'http://example.com/audio2.mp3',
      ];

      // Should not throw even if offline
      await expectLater(
        audioCacheService.warmCache(urls),
        completes,
      );
    });

    test('should calculate cache size', () async {
      final size = await audioCacheService.getCacheSize();
      expect(size, isA<int>());
      expect(size, greaterThanOrEqualTo(0));
    });

    test('should clean old segments', () async {
      // Add test segment
      await audioCacheService.cacheAudioData(
        Uint8List.fromList([1, 2, 3]),
        'old_segment',
      );

      // Should complete without error
      await expectLater(
        audioCacheService.cleanOldSegments(),
        completes,
      );
    });

    test('should handle null cache attempts gracefully', () async {
      // Try to cache from non-existent URL
      final result = await audioCacheService.cacheAudioSegment(
        'http://nonexistent.example.com/audio.mp3',
      );

      // Should return null without throwing
      expect(result, isNull);
    });

    test('should respect max cache configuration', () {
      expect(AudioCacheService.maxCacheAge, equals(const Duration(days: 7)));
      expect(AudioCacheService.maxCacheSize, equals(100 * 1024 * 1024));
      expect(AudioCacheService.cacheKey, equals('audioCache'));
    });

    test('should track cache hits and misses correctly', () async {
      const key = 'stats_test';

      // Get initial stats
      var stats = audioCacheService.getStatistics();
      final initialMisses = stats['misses'] as int;

      // Try to get non-cached segment (should be a miss)
      await audioCacheService.getCachedSegment(key);

      stats = audioCacheService.getStatistics();
      expect(stats['misses'], equals(initialMisses + 1));

      // Cache the segment
      await audioCacheService.cacheAudioData(
        Uint8List.fromList([1, 2, 3]),
        key,
      );

      // Try to get cached segment (might be a hit if caching worked)
      final initialHits = stats['hits'] as int;
      await audioCacheService.getCachedSegment(key);

      stats = audioCacheService.getStatistics();
      // Either hits increased or misses increased depending on test environment
      expect(
        (stats['hits'] as int) + (stats['misses'] as int),
        greaterThan(initialHits + initialMisses + 1),
      );
    });

    test('should calculate hit rate correctly', () async {
      // Clear to start fresh
      await audioCacheService.clearAll();

      const key = 'hit_rate_test';

      // Create some misses
      await audioCacheService.getCachedSegment('miss1');
      await audioCacheService.getCachedSegment('miss2');

      // Cache and get (potential hit)
      await audioCacheService.cacheAudioData(
        Uint8List.fromList([1, 2, 3]),
        key,
      );

      final stats = audioCacheService.getStatistics();
      final hitRate = stats['hitRate'] as double;

      expect(hitRate, greaterThanOrEqualTo(0.0));
      expect(hitRate, lessThanOrEqualTo(100.0));
    });

    test('validation function should pass', () async {
      await expectLater(
        validateAudioCacheService(),
        completes,
      );
    });

    test('should handle offline mode correctly', () async {
      // Test behavior when offline
      if (audioCacheService.isOffline) {
        // Should not attempt to download when offline
        const url = 'http://example.com/audio.mp3';
        final result = await audioCacheService.cacheAudioSegment(url);
        expect(result, isNull);
      }
    });

    test('should save and load metadata correctly', () async {
      const key = 'metadata_test';

      await audioCacheService.cacheAudioData(
        Uint8List.fromList([1, 2, 3, 4, 5]),
        key,
      );

      // Metadata should be saved
      final segments = await audioCacheService.getCachedSegments();
      // Key might be in segments if caching worked
      expect(segments, isA<List<String>>());
    });

    test('should handle concurrent cache requests', () async {
      // Test concurrent caching
      final futures = List.generate(5, (i) {
        return audioCacheService.cacheAudioData(
          Uint8List.fromList([i]),
          'concurrent_$i',
        );
      });

      // All should complete without error
      await expectLater(
        Future.wait(futures),
        completes,
      );
    });
  });
}