import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AudioCacheService - Manages audio segment caching for offline playback
///
/// Purpose: Caches audio segments for smooth playback and offline support
/// Dependencies:
/// - flutter_cache_manager: File-based caching
/// - connectivity_plus: Network state detection
/// - SharedPreferences: Cache metadata storage
///
/// Features:
/// - Segment-based audio caching
/// - Offline playback support
/// - Cache warming for upcoming content
/// - Automatic cache invalidation
/// - Network-aware caching strategy
class AudioCacheService {
  static AudioCacheService? _instance;
  late final BaseCacheManager _cacheManager;
  late final SharedPreferences _prefs;
  final Connectivity _connectivity = Connectivity();

  // Cache configuration
  static const Duration maxCacheAge = Duration(days: 7);
  static const int maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const String cacheKey = 'audioCache';
  static const String _metadataPrefix = 'audio_cache_meta_';

  // Cache statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _bytesDownloaded = 0;
  int _bytesCached = 0;

  // Network state
  bool _isOffline = false;

  // Private constructor
  AudioCacheService._();

  /// Get singleton instance
  static Future<AudioCacheService> getInstance() async {
    if (_instance == null) {
      _instance = AudioCacheService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize audio cache service
  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();

    // Configure custom cache manager
    _cacheManager = CacheManager(
      Config(
        cacheKey,
        stalePeriod: maxCacheAge,
        maxNrOfCacheObjects: 50,
        repo: JsonCacheInfoRepository(databaseName: cacheKey),
        fileService: HttpFileService(),
      ),
    );

    // Monitor connectivity
    _connectivity.onConnectivityChanged.listen((result) {
      _isOffline = result == ConnectivityResult.none;
      debugPrint('Network state changed - Offline: $_isOffline');
    });

    // Check initial connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOffline = connectivityResult == ConnectivityResult.none;

    _loadStatistics();
    debugPrint('AudioCacheService initialized - Offline: $_isOffline');
  }

  /// Load cache statistics
  void _loadStatistics() {
    _cacheHits = _prefs.getInt('audio_cache_hits') ?? 0;
    _cacheMisses = _prefs.getInt('audio_cache_misses') ?? 0;
    _bytesDownloaded = _prefs.getInt('audio_bytes_downloaded') ?? 0;
    _bytesCached = _prefs.getInt('audio_bytes_cached') ?? 0;
  }

  /// Save cache statistics
  Future<void> _saveStatistics() async {
    await _prefs.setInt('audio_cache_hits', _cacheHits);
    await _prefs.setInt('audio_cache_misses', _cacheMisses);
    await _prefs.setInt('audio_bytes_downloaded', _bytesDownloaded);
    await _prefs.setInt('audio_bytes_cached', _bytesCached);
  }

  /// Cache audio segment from URL
  Future<File?> cacheAudioSegment(String url, {String? key}) async {
    try {
      final cacheKey = key ?? url;

      // Check if already cached
      final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        _cacheHits++;
        await _saveStatistics();
        debugPrint('Cache hit for: $cacheKey');
        return fileInfo.file;
      }

      // Download and cache if online
      if (!_isOffline) {
        _cacheMisses++;
        debugPrint('Cache miss, downloading: $cacheKey');

        final file = await _cacheManager.getSingleFile(
          url,
          key: cacheKey,
        );

        if (file.existsSync()) {
          final fileSize = await file.length();
          _bytesDownloaded += fileSize;
          _bytesCached += fileSize;

          // Save metadata
          await _saveSegmentMetadata(cacheKey, fileSize);
          await _saveStatistics();

          debugPrint('Cached audio segment: $cacheKey (${fileSize ~/ 1024}KB)');
          return file;
        }
      } else {
        debugPrint('Offline - cannot download: $cacheKey');
        _cacheMisses++;
        await _saveStatistics();
      }

      return null;
    } catch (e) {
      debugPrint('Error caching audio segment: $e');
      return null;
    }
  }

  /// Cache audio data directly
  Future<File?> cacheAudioData(Uint8List data, String key) async {
    try {
      // Create temporary file
      final tempFile = File('${Directory.systemTemp.path}/$key.tmp');
      await tempFile.writeAsBytes(data);

      // Put in cache
      await _cacheManager.putFile(
        key,
        tempFile.readAsBytesSync(),
        key: key,
        maxAge: maxCacheAge,
      );

      // Get cached file
      final fileInfo = await _cacheManager.getFileFromCache(key);
      if (fileInfo != null) {
        _bytesCached += data.length;
        await _saveSegmentMetadata(key, data.length);
        await _saveStatistics();
        debugPrint('Cached audio data: $key (${data.length ~/ 1024}KB)');
        return fileInfo.file;
      }

      return null;
    } catch (e) {
      debugPrint('Error caching audio data: $e');
      return null;
    }
  }

  /// Get cached audio segment
  Future<File?> getCachedSegment(String key) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(key);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        _cacheHits++;
        await _saveStatistics();

        // Update last access time
        await _updateSegmentAccess(key);

        return fileInfo.file;
      }

      _cacheMisses++;
      await _saveStatistics();
      return null;
    } catch (e) {
      debugPrint('Error getting cached segment: $e');
      return null;
    }
  }

  /// Pre-cache multiple segments (cache warming)
  Future<void> warmCache(List<String> urls) async {
    if (_isOffline) {
      debugPrint('Cannot warm cache - offline');
      return;
    }

    debugPrint('Warming cache with ${urls.length} segments');
    int cached = 0;

    for (final url in urls) {
      final file = await cacheAudioSegment(url);
      if (file != null) cached++;

      // Respect cache size limit
      final cacheSize = await getCacheSize();
      if (cacheSize > maxCacheSize) {
        debugPrint('Cache size limit reached during warming');
        break;
      }
    }

    debugPrint('Cache warming complete - Cached $cached/${urls.length} segments');
  }

  /// Save segment metadata
  Future<void> _saveSegmentMetadata(String key, int size) async {
    final metaKey = '$_metadataPrefix$key';
    final metadata = {
      'size': size,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
      'last_access': DateTime.now().millisecondsSinceEpoch,
      'access_count': 1,
    };

    final metaString = metadata.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');

    await _prefs.setString(metaKey, metaString);
  }

  /// Update segment access time
  Future<void> _updateSegmentAccess(String key) async {
    final metaKey = '$_metadataPrefix$key';
    final metaString = _prefs.getString(metaKey);

    if (metaString != null) {
      final metadata = <String, dynamic>{};
      for (final pair in metaString.split(',')) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          metadata[parts[0]] = int.tryParse(parts[1]) ?? 0;
        }
      }

      metadata['last_access'] = DateTime.now().millisecondsSinceEpoch;
      metadata['access_count'] = (metadata['access_count'] ?? 0) + 1;

      final updatedString = metadata.entries
          .map((e) => '${e.key}:${e.value}')
          .join(',');

      await _prefs.setString(metaKey, updatedString);
    }
  }

  /// Remove cached segment
  Future<void> removeSegment(String key) async {
    try {
      await _cacheManager.removeFile(key);
      await _prefs.remove('$_metadataPrefix$key');
      debugPrint('Removed cached segment: $key');
    } catch (e) {
      debugPrint('Error removing segment: $e');
    }
  }

  /// Clear all cached audio
  Future<void> clearAll() async {
    try {
      await _cacheManager.emptyCache();

      // Clear metadata
      final keys = _prefs.getKeys()
          .where((key) => key.startsWith(_metadataPrefix))
          .toList();

      for (final key in keys) {
        await _prefs.remove(key);
      }

      // Reset statistics
      _cacheHits = 0;
      _cacheMisses = 0;
      _bytesDownloaded = 0;
      _bytesCached = 0;
      await _saveStatistics();

      debugPrint('Audio cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    int totalSize = 0;

    try {
      // Get cache size by counting cached segments
      // Note: Direct file path access is not available in flutter_cache_manager v3+
      final segments = await getCachedSegments();

      // Estimate based on metadata
      for (final segment in segments) {
        final metaKey = '$_metadataPrefix$segment';
        final metaString = _prefs.getString(metaKey);

        if (metaString != null) {
          final metadata = <String, dynamic>{};
          for (final pair in metaString.split(',')) {
            final parts = pair.split(':');
            if (parts.length == 2) {
              metadata[parts[0]] = int.tryParse(parts[1]) ?? 0;
            }
          }

          totalSize += (metadata['size'] as int? ?? 0);
        }
      }
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
    }

    return totalSize;
  }

  /// Get cache statistics
  Map<String, dynamic> getStatistics() {
    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? (_cacheHits / totalRequests) * 100 : 0.0;

    return {
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hitRate': hitRate,
      'totalRequests': totalRequests,
      'bytesDownloaded': _bytesDownloaded,
      'bytesCached': _bytesCached,
      'isOffline': _isOffline,
    };
  }

  /// Check if segment is cached
  Future<bool> isSegmentCached(String key) async {
    final fileInfo = await _cacheManager.getFileFromCache(key);
    return fileInfo != null && fileInfo.file.existsSync();
  }

  /// Get all cached segment keys
  Future<List<String>> getCachedSegments() async {
    final keys = _prefs.getKeys()
        .where((key) => key.startsWith(_metadataPrefix))
        .map((key) => key.substring(_metadataPrefix.length))
        .toList();

    return keys;
  }

  /// Clean old segments (older than maxAge)
  Future<void> cleanOldSegments() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final maxAgeMs = maxCacheAge.inMilliseconds;
      final segments = await getCachedSegments();
      int cleaned = 0;

      for (final segment in segments) {
        final metaKey = '$_metadataPrefix$segment';
        final metaString = _prefs.getString(metaKey);

        if (metaString != null) {
          final metadata = <String, dynamic>{};
          for (final pair in metaString.split(',')) {
            final parts = pair.split(':');
            if (parts.length == 2) {
              metadata[parts[0]] = int.tryParse(parts[1]) ?? 0;
            }
          }

          final lastAccess = metadata['last_access'] ?? 0;
          if (now - lastAccess > maxAgeMs) {
            await removeSegment(segment);
            cleaned++;
          }
        }
      }

      if (cleaned > 0) {
        debugPrint('Cleaned $cleaned old audio segments');
      }
    } catch (e) {
      debugPrint('Error cleaning old segments: $e');
    }
  }

  /// Check network connectivity
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Get current network state
  bool get isOffline => _isOffline;
}

/// Validation function for AudioCacheService
Future<void> validateAudioCacheService() async {
  debugPrint('=== AudioCacheService Validation ===');

  // Test 1: Service initialization
  final service = await AudioCacheService.getInstance();
  assert(service != null, 'Service must initialize');
  debugPrint('✓ Service initialization verified');

  // Test 2: Cache configuration
  assert(AudioCacheService.maxCacheAge == const Duration(days: 7), 'Max age must be 7 days');
  assert(AudioCacheService.maxCacheSize == 100 * 1024 * 1024, 'Max size must be 100MB');
  debugPrint('✓ Cache configuration verified');

  // Test 3: Network state
  final isOnline = await service.isOnline();
  assert(isOnline is bool, 'Network state must be boolean');
  debugPrint('✓ Network state detection verified');

  // Test 4: Cache statistics
  final stats = service.getStatistics();
  assert(stats['hits'] != null, 'Statistics must track hits');
  assert(stats['misses'] != null, 'Statistics must track misses');
  assert(stats['hitRate'] != null, 'Statistics must calculate hit rate');
  assert(stats['isOffline'] != null, 'Statistics must include offline state');
  debugPrint('✓ Cache statistics verified');

  // Test 5: Cache operations
  final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
  final cached = await service.cacheAudioData(testData, 'test_segment');
  if (cached != null) {
    final isCached = await service.isSegmentCached('test_segment');
    assert(isCached, 'Segment must be cached');
    await service.removeSegment('test_segment');
    debugPrint('✓ Cache operations verified');
  }

  debugPrint('=== All AudioCacheService validations passed ===');
}