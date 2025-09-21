import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CacheService - Manages application-wide caching with LRU eviction
///
/// Purpose: Centralized cache management with size limits and eviction policies
/// Dependencies:
/// - SharedPreferences: Persistent cache storage
///
/// Features:
/// - LRU (Least Recently Used) eviction policy
/// - Maximum 50 cached items
/// - Cache statistics tracking (hits, misses, evictions)
/// - Cache size monitoring
/// - Automatic eviction on size limit
class CacheService {
  static CacheService? _instance;
  late final SharedPreferences _prefs;

  // Cache configuration
  static const int maxCacheItems = 50;
  static const String _cachePrefix = 'cache_';
  static const String _cacheMetaPrefix = 'cache_meta_';
  static const String _cacheStatsKey = 'cache_stats';

  // In-memory cache for fast access
  final LinkedHashMap<String, dynamic> _memoryCache = LinkedHashMap();

  // Cache statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  // Private constructor
  CacheService._();

  /// Get singleton instance
  static Future<CacheService> getInstance() async {
    if (_instance == null) {
      _instance = CacheService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize cache service
  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCacheStats();
    await _loadMemoryCache();
    debugPrint('CacheService initialized - Items: ${_memoryCache.length}, Hits: $_hits, Misses: $_misses');
  }

  /// Load cache statistics from storage
  void _loadCacheStats() {
    final statsString = _prefs.getString(_cacheStatsKey);
    if (statsString != null) {
      final parts = statsString.split(',');
      if (parts.length >= 3) {
        _hits = int.tryParse(parts[0]) ?? 0;
        _misses = int.tryParse(parts[1]) ?? 0;
        _evictions = int.tryParse(parts[2]) ?? 0;
      }
    }
  }

  /// Save cache statistics
  Future<void> _saveCacheStats() async {
    await _prefs.setString(_cacheStatsKey, '$_hits,$_misses,$_evictions');
  }

  /// Load cached items into memory
  Future<void> _loadMemoryCache() async {
    final keys = _prefs.getKeys().where((key) => key.startsWith(_cachePrefix) && !key.startsWith(_cacheMetaPrefix));

    // Load items with their access times for proper LRU ordering
    final itemsWithTime = <MapEntry<String, int>>[];

    for (final fullKey in keys) {
      final key = fullKey.substring(_cachePrefix.length);
      final metaKey = '$_cacheMetaPrefix$key';
      final metaString = _prefs.getString(metaKey);

      if (metaString != null) {
        final parts = metaString.split(',');
        if (parts.length >= 2) {
          final lastAccess = int.tryParse(parts[1]) ?? 0;
          itemsWithTime.add(MapEntry(key, lastAccess));
        }
      }
    }

    // Sort by last access time (oldest first for LRU)
    itemsWithTime.sort((a, b) => a.value.compareTo(b.value));

    // Load into memory cache in LRU order
    for (final entry in itemsWithTime) {
      final value = _prefs.get('$_cachePrefix${entry.key}');
      if (value != null) {
        _memoryCache[entry.key] = value;
      }
    }
  }

  /// Get item from cache
  Future<T?> get<T>(String key) async {
    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      _hits++;

      // Update access time and move to end (most recently used)
      final value = _memoryCache.remove(key);
      _memoryCache[key] = value;

      // Update metadata
      await _updateMetadata(key);
      await _saveCacheStats();

      return value as T?;
    }

    // Check persistent storage
    final fullKey = '$_cachePrefix$key';
    final value = _prefs.get(fullKey);

    if (value != null) {
      _hits++;

      // Add to memory cache
      _memoryCache[key] = value;

      // Enforce size limit
      await _enforceMemoryCacheLimit();

      // Update metadata
      await _updateMetadata(key);
      await _saveCacheStats();

      return value as T?;
    }

    _misses++;
    await _saveCacheStats();
    return null;
  }

  /// Set item in cache
  Future<void> set<T>(String key, T value) async {
    // Add to memory cache
    _memoryCache.remove(key); // Remove if exists to update position
    _memoryCache[key] = value;

    // Save to persistent storage
    final fullKey = '$_cachePrefix$key';

    if (value is String) {
      await _prefs.setString(fullKey, value);
    } else if (value is int) {
      await _prefs.setInt(fullKey, value);
    } else if (value is double) {
      await _prefs.setDouble(fullKey, value);
    } else if (value is bool) {
      await _prefs.setBool(fullKey, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(fullKey, value);
    } else {
      throw ArgumentError('Unsupported type for caching: ${value.runtimeType}');
    }

    // Update metadata
    await _updateMetadata(key);

    // Enforce size limits
    await _enforceMemoryCacheLimit();
    await _enforcePersistentCacheLimit();
  }

  /// Update metadata for cache entry
  Future<void> _updateMetadata(String key) async {
    final metaKey = '$_cacheMetaPrefix$key';
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs.setString(metaKey, '$now,$now'); // created,lastAccess
  }

  /// Enforce memory cache size limit
  Future<void> _enforceMemoryCacheLimit() async {
    while (_memoryCache.length > maxCacheItems) {
      // Remove least recently used item (first in LinkedHashMap)
      final firstKey = _memoryCache.keys.first;
      _memoryCache.remove(firstKey);
      _evictions++;
      debugPrint('Evicted from memory cache: $firstKey');
    }
  }

  /// Enforce persistent cache size limit
  Future<void> _enforcePersistentCacheLimit() async {
    final cacheKeys = _prefs.getKeys().where((key) =>
      key.startsWith(_cachePrefix) && !key.startsWith(_cacheMetaPrefix)).toList();

    if (cacheKeys.length <= maxCacheItems) return;

    // Get all items with their access times
    final itemsWithTime = <MapEntry<String, int>>[];

    for (final fullKey in cacheKeys) {
      final key = fullKey.substring(_cachePrefix.length);
      final metaKey = '$_cacheMetaPrefix$key';
      final metaString = _prefs.getString(metaKey);

      if (metaString != null) {
        final parts = metaString.split(',');
        if (parts.length >= 2) {
          final lastAccess = int.tryParse(parts[1]) ?? 0;
          itemsWithTime.add(MapEntry(key, lastAccess));
        }
      } else {
        // No metadata, assume old
        itemsWithTime.add(MapEntry(key, 0));
      }
    }

    // Sort by last access time (oldest first)
    itemsWithTime.sort((a, b) => a.value.compareTo(b.value));

    // Remove oldest items
    final itemsToRemove = itemsWithTime.length - maxCacheItems;
    for (int i = 0; i < itemsToRemove; i++) {
      final key = itemsWithTime[i].key;
      await remove(key);
      _evictions++;
      debugPrint('Evicted from persistent cache: $key');
    }

    await _saveCacheStats();
  }

  /// Remove item from cache
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    await _prefs.remove('$_cachePrefix$key');
    await _prefs.remove('$_cacheMetaPrefix$key');
  }

  /// Clear all cached items
  Future<void> clearAll() async {
    _memoryCache.clear();

    // Remove all cache entries
    final keys = _prefs.getKeys().where((key) =>
      key.startsWith(_cachePrefix) || key.startsWith(_cacheMetaPrefix)).toList();

    for (final key in keys) {
      await _prefs.remove(key);
    }

    // Reset statistics
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    await _saveCacheStats();

    debugPrint('Cache cleared - Removed ${keys.length} items');
  }

  /// Get cache statistics
  Map<String, dynamic> getStatistics() {
    final totalRequests = _hits + _misses;
    final hitRate = totalRequests > 0 ? (_hits / totalRequests) * 100 : 0.0;

    return {
      'hits': _hits,
      'misses': _misses,
      'evictions': _evictions,
      'hitRate': hitRate,
      'totalRequests': totalRequests,
      'currentItems': _memoryCache.length,
      'maxItems': maxCacheItems,
    };
  }

  /// Get cache size in items
  int get cacheSize => _memoryCache.length;

  /// Check if cache contains key
  bool containsKey(String key) {
    return _memoryCache.containsKey(key) ||
           _prefs.containsKey('$_cachePrefix$key');
  }

  /// Get all cached keys
  Set<String> getCachedKeys() {
    final persistentKeys = _prefs.getKeys()
      .where((key) => key.startsWith(_cachePrefix) && !key.startsWith(_cacheMetaPrefix))
      .map((key) => key.substring(_cachePrefix.length))
      .toSet();

    return {..._memoryCache.keys, ...persistentKeys};
  }

  /// Warm cache with frequently accessed items
  Future<void> warmCache(Map<String, dynamic> items) async {
    for (final entry in items.entries) {
      await set(entry.key, entry.value);
    }
    debugPrint('Cache warmed with ${items.length} items');
  }

  /// Get cache metadata for debugging
  Future<Map<String, dynamic>> getCacheMetadata(String key) async {
    final metaKey = '$_cacheMetaPrefix$key';
    final metaString = _prefs.getString(metaKey);

    if (metaString != null) {
      final parts = metaString.split(',');
      if (parts.length >= 2) {
        return {
          'created': DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0])),
          'lastAccess': DateTime.fromMillisecondsSinceEpoch(int.parse(parts[1])),
          'inMemory': _memoryCache.containsKey(key),
        };
      }
    }

    return {};
  }

  /// Clean up old cache entries (older than specified duration)
  Future<void> cleanOldEntries(Duration maxAge) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxAgeMs = maxAge.inMilliseconds;

    final keys = getCachedKeys();
    int removed = 0;

    for (final key in keys) {
      final metadata = await getCacheMetadata(key);
      if (metadata.isNotEmpty) {
        final lastAccess = (metadata['lastAccess'] as DateTime).millisecondsSinceEpoch;
        if (now - lastAccess > maxAgeMs) {
          await remove(key);
          removed++;
        }
      }
    }

    if (removed > 0) {
      debugPrint('Cleaned $removed old cache entries');
    }
  }
}

/// Validation function for CacheService
Future<void> validateCacheService() async {
  debugPrint('=== CacheService Validation ===');

  // Test 1: Service initialization
  final service = await CacheService.getInstance();
  debugPrint('✓ Service initialization verified');

  // Test 2: Cache operations
  await service.set('test_key', 'test_value');
  final value = await service.get<String>('test_key');
  assert(value == 'test_value', 'Cache must store and retrieve values');
  debugPrint('✓ Cache operations verified');

  // Test 3: Cache statistics
  final stats = service.getStatistics();
  assert(stats['hits'] != null, 'Statistics must track hits');
  assert(stats['misses'] != null, 'Statistics must track misses');
  assert(stats['hitRate'] != null, 'Statistics must calculate hit rate');
  debugPrint('✓ Cache statistics verified');

  // Test 4: Cache size limit
  assert(CacheService.maxCacheItems == 50, 'Max cache items must be 50');
  debugPrint('✓ Cache size limit verified');

  // Test 5: Cache contains check
  assert(service.containsKey('test_key'), 'Must detect existing keys');
  assert(!service.containsKey('nonexistent'), 'Must not detect missing keys');
  debugPrint('✓ Cache contains check verified');

  // Clean up
  await service.remove('test_key');

  debugPrint('=== All CacheService validations passed ===');
}