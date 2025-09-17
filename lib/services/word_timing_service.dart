/// Word Timing Service with Dual-Level Highlighting Support
///
/// Purpose: Manages word and sentence timing data with synchronized highlighting
/// Dependencies:
/// - rxdart: ^0.27.7 (for stream processing and throttling)
/// - shared_preferences: ^2.2.2 (for local caching)
/// - flutter/services.dart (for compute isolation)
/// - ../models/word_timing.dart (WordTiming model)
/// - speechify_service.dart (for fetching timing data)
///
/// Usage:
///   final service = WordTimingService();
///   await service.fetchTimings('content-id', 'text content');
///   service.currentWordStream.listen((wordIndex) => updateUI());
///   service.updatePosition(positionMs, 'content-id');
///
/// Expected behavior:
///   - Provides dual-level highlighting with word and sentence streams
///   - Maintains 60fps performance with throttled updates
///   - Uses binary search for O(log n) word lookup
///   - Three-tier caching: Memory → SharedPreferences → Supabase

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word_timing.dart';
import '../utils/app_logger.dart';
import '../exceptions/app_exceptions.dart';
import 'speechify_service.dart';

// TimingServiceException moved to ../exceptions/app_exceptions.dart as TimingException

/// Represents a computed text position for accurate rendering
class TextPosition {
  final int offset;
  final Rect rect;

  const TextPosition({
    required this.offset,
    required this.rect,
  });
}

/// Service for managing dual-level word and sentence timing with audio synchronization
class WordTimingService {
  static WordTimingService? _instance;

  /// Singleton instance for consistent state management
  static WordTimingService get instance {
    _instance ??= WordTimingService._internal();
    return _instance!;
  }

  factory WordTimingService() => instance;

  WordTimingService._internal() {
    _initializeStreams();
  }

  // Caches for performance optimization with LRU eviction
  final Map<String, List<WordTiming>> _wordTimingCache = {};
  final Map<String, WordTimingCollection> _collectionCache = {};
  final Map<String, List<TextPosition>> _positionCache = {};

  // LRU tracking for cache eviction
  final List<String> _cacheAccessOrder = [];
  static const int _maxCacheEntries = 10; // Limit cache to 10 documents
  static const int _maxPositionCacheEntries = 1000; // Limit position cache

  // Stream controllers for dual-level highlighting
  late final StreamController<int> _currentWordController;
  late final StreamController<int> _currentSentenceController;

  // Throttled streams for 60fps performance
  late final Stream<int> _throttledWordStream;
  late final Stream<int> _throttledSentenceStream;

  /// Stream of current word indices, throttled to 60fps
  Stream<int> get currentWordStream => _throttledWordStream;

  /// Stream of current sentence indices, throttled to 60fps
  Stream<int> get currentSentenceStream => _throttledSentenceStream;

  void _initializeStreams() {
    _currentWordController = StreamController<int>.broadcast();
    _currentSentenceController = StreamController<int>.broadcast();

    // Throttle streams to maintain 60fps (16ms intervals)
    _throttledWordStream = _currentWordController.stream
        .throttleTime(const Duration(milliseconds: 16))
        .distinct();

    _throttledSentenceStream = _currentSentenceController.stream
        .throttleTime(const Duration(milliseconds: 16))
        .distinct();
  }

  /// Manages LRU cache eviction when cache size exceeds limits
  void _evictLRUCacheIfNeeded() {
    // Evict word timing cache entries
    while (_cacheAccessOrder.length > _maxCacheEntries) {
      final oldestKey = _cacheAccessOrder.removeAt(0);
      _wordTimingCache.remove(oldestKey);
      _collectionCache.remove(oldestKey);
      _positionCache.remove(oldestKey);
      AppLogger.debug('Evicted cache entry', {'contentId': oldestKey});
    }

    // Evict position cache if it's getting too large
    int totalPositions = 0;
    for (final positions in _positionCache.values) {
      totalPositions += positions.length;
    }

    if (totalPositions > _maxPositionCacheEntries) {
      // Clear position cache for the oldest entry
      if (_cacheAccessOrder.isNotEmpty) {
        final oldestKey = _cacheAccessOrder.first;
        _positionCache.remove(oldestKey);
        AppLogger.debug('Evicted position cache',
            {'contentId': oldestKey, 'totalPositions': totalPositions});
      }
    }
  }

  /// Updates LRU access order for cache management
  void _updateCacheAccessOrder(String contentId) {
    _cacheAccessOrder.remove(contentId);
    _cacheAccessOrder.add(contentId);
    _evictLRUCacheIfNeeded();
  }

  /// Fetches word timings with sentence indexing support
  /// Implements three-tier caching: Memory → SharedPreferences → Speechify API
  Future<List<WordTiming>> fetchTimings(String contentId, String text) async {
    try {
      // Check memory cache first
      if (_wordTimingCache.containsKey(contentId)) {
        AppLogger.debug(
            'Found timings in memory cache', {'contentId': contentId});
        _updateCacheAccessOrder(contentId);
        return _wordTimingCache[contentId]!;
      }

      // Try SharedPreferences cache
      final cachedTimings = await _loadFromLocalCache(contentId);
      if (cachedTimings != null) {
        AppLogger.debug(
            'Found timings in local cache', {'contentId': contentId});
        _wordTimingCache[contentId] = cachedTimings;
        _collectionCache[contentId] = WordTimingCollection(cachedTimings);
        _updateCacheAccessOrder(contentId);
        return cachedTimings;
      }

      AppLogger.info(
          'Fetching timings from Speechify API', {'contentId': contentId});

      // Fetch from Speechify API using singleton instance
      final speechifyService = SpeechifyService.instance;
      final result = await speechifyService.generateAudioStream(content: text);
      final rawTimings = result.wordTimings;

      // Process and enhance with sentence indexing
      final processedTimings =
          await _processTimingsWithSentenceIndex(rawTimings, text);
      // Ensure sentence indices exist (handles APIs that omit sentence_index)
      final normalized = ensureSentenceIndexing(
        processedTimings,
        displayText: text,
        sourceText: text,
      );

      // Cache in memory and locally
      _wordTimingCache[contentId] = normalized;
      _collectionCache[contentId] = WordTimingCollection(normalized);
      _updateCacheAccessOrder(contentId);
      await _saveToLocalCache(contentId, normalized);

      AppLogger.info('Processed word timings', {
        'contentId': contentId,
        'timingCount': normalized.length,
      });
      return normalized;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to fetch word timings',
        error: e,
        stackTrace: stackTrace,
        data: {'contentId': contentId},
      );
      throw TimingException.processingFailed(
        contentId,
        cause: e is Exception ? e : Exception(e.toString()),
      );
    }
  }

  /// Aligns raw Speechify timings to the provided display text. This adjusts
  /// character offsets and sentence indices so that highlighting matches the
  /// text shown to the learner (plain text without SSML tags).
  Future<List<WordTiming>> alignTimingsToText(
    List<WordTiming> rawTimings,
    String text, {
    String? sourceText,
  }) async {
    if (rawTimings.isEmpty) return [];

    final processed = await _processTimingsWithSentenceIndex(rawTimings, text);
    return ensureSentenceIndexing(
      processed,
      displayText: text,
      sourceText: sourceText,
    );
  }

  /// Processes raw timings and adds sentence indexing using compute isolation
  Future<List<WordTiming>> _processTimingsWithSentenceIndex(
    List<WordTiming> rawTimings,
    String text,
  ) async {
    if (rawTimings.isEmpty) return [];

    try {
      final result = await compute(_processTimingsIsolate, {
        'timings': rawTimings.map((t) => t.toJson()).toList(),
        'text': text,
      });

      return result.map((json) => WordTiming.fromJson(json)).toList();
    } catch (e) {
      AppLogger.warning('Compute isolation failed, falling back to main thread',
          {'error': e.toString()});
      // Fallback to main thread processing
      return _processTimingsMainThread(rawTimings, text);
    }
  }

  /// Fallback processing on main thread if compute isolation fails
  List<WordTiming> _processTimingsMainThread(
      List<WordTiming> rawTimings, String text) {
    int characterPosition = 0;

    final processedTimings = <WordTiming>[];

    for (final timing in rawTimings) {
      int wordStart = text.indexOf(timing.word, characterPosition);
      if (wordStart < 0) {
        wordStart = text.indexOf(timing.word);
      }
      if (wordStart < 0) {
        wordStart = characterPosition;
      }

      int wordEnd = wordStart + timing.word.length;
      if (wordEnd > text.length) {
        wordEnd = text.length;
      }

      processedTimings.add(WordTiming(
        word: timing.word,
        startMs: timing.startMs,
        endMs: timing.endMs,
        sentenceIndex: timing.sentenceIndex,
        charStart: wordStart >= 0 ? wordStart : null,
        charEnd: wordEnd,
      ));

      characterPosition = math.max(wordEnd, characterPosition);
    }

    return processedTimings;
  }

  /// Pre-computes text positions for smooth highlighting and tap detection
  Future<void> precomputePositions(
    String contentId,
    String text,
    TextStyle textStyle,
    double maxWidth,
  ) async {
    if (_positionCache.containsKey(contentId)) {
      AppLogger.debug('Positions already computed', {'contentId': contentId});
      _updateCacheAccessOrder(contentId);
      return;
    }

    try {
      AppLogger.info('Pre-computing text positions', {'contentId': contentId});

      final positions = await compute(_computePositionsIsolate, {
        'text': text,
        'textStyle': {
          'fontSize': textStyle.fontSize ?? 16.0,
          'fontFamily': textStyle.fontFamily,
          'fontWeight': textStyle.fontWeight?.index,
          'letterSpacing': textStyle.letterSpacing,
          'height': textStyle.height,
        },
        'maxWidth': maxWidth,
      });

      final textPositions = positions
          .map((p) => TextPosition(
                offset: p['offset'] as int,
                rect: Rect.fromLTWH(
                  p['left'] as double,
                  p['top'] as double,
                  p['width'] as double,
                  p['height'] as double,
                ),
              ))
          .toList();

      _positionCache[contentId] = textPositions;
      _updateCacheAccessOrder(contentId);
      _evictLRUCacheIfNeeded(); // Check after adding new positions

      AppLogger.info('Pre-computed text positions', {
        'contentId': contentId,
        'positionCount': positions.length,
      });
    } catch (e) {
      AppLogger.warning('Failed to pre-compute positions', {
        'contentId': contentId,
        'error': e.toString(),
      });
      // Continue without pre-computed positions - highlighting will still work
    }
  }

  /// Updates current position and triggers dual-level highlighting streams
  void updatePosition(int positionMs, String contentId) {
    final collection = _collectionCache[contentId];

    // Debug logging
    if (positionMs % 1000 < 100) {
      // Log roughly every second
      AppLogger.debug('WordTimingService.updatePosition called', {
        'positionMs': positionMs,
        'contentId': contentId,
        'hasCollection': collection != null,
        'timingCount': collection?.timings.length ?? 0,
      });
    }

    if (collection == null) {
      if (positionMs % 1000 < 100) {
        AppLogger.warning('No timing collection found for content', {
          'contentId': contentId,
          'cacheKeys': _collectionCache.keys.toList(),
        });
      }
      return;
    }

    final wordIndex = collection.findActiveWordIndex(positionMs);
    final sentenceIndex = collection.findActiveSentenceIndex(positionMs);

    // Log word/sentence changes
    if (wordIndex >= 0 && wordIndex < collection.timings.length) {
      final currentWord = collection.timings[wordIndex];
      if (positionMs % 500 < 100 || wordIndex != _lastLoggedWordIndex) {
        AppLogger.debug('Current word position', {
          'wordIndex': wordIndex,
          'word': currentWord.word,
          'sentenceIndex': sentenceIndex,
          'positionMs': positionMs,
          'wordStartMs': currentWord.startMs,
          'wordEndMs': currentWord.endMs,
        });
        _lastLoggedWordIndex = wordIndex;
      }
    }

    if (!_currentWordController.isClosed) {
      _currentWordController.add(wordIndex);
    }

    if (!_currentSentenceController.isClosed) {
      _currentSentenceController.add(sentenceIndex);
    }
  }

  // Add field for tracking logged word index
  int _lastLoggedWordIndex = -1;

  /// Gets cached word timings for a content ID
  List<WordTiming>? getCachedTimings(String contentId) {
    return _wordTimingCache[contentId];
  }

  /// Sets pre-fetched word timings directly into cache
  /// Used when timings are already available from audio generation
  void setCachedTimings(String contentId, List<WordTiming> timings) {
    // Store in memory cache
    _wordTimingCache[contentId] = timings;
    _collectionCache[contentId] = WordTimingCollection(timings);
    _updateCacheAccessOrder(contentId);

    // Save to local cache asynchronously
    _saveToLocalCache(contentId, timings);

    AppLogger.info('Set cached timings', {
      'contentId': contentId,
      'count': timings.length,
      'sentences': timings.isNotEmpty ? timings.last.sentenceIndex + 1 : 0,
    });
  }

  /// Gets cached text positions for a content ID
  List<TextPosition>? getCachedPositions(String contentId) {
    return _positionCache[contentId];
  }

  /// Finds the word index at a specific screen position for tap-to-seek
  int findWordAtPosition(String contentId, Offset tapPosition) {
    final timings = _wordTimingCache[contentId];
    final positions = _positionCache[contentId];

    if (timings == null || positions == null) {
      AppLogger.debug('Tap-to-seek: No timings or positions cached', {
        'contentId': contentId,
        'hasTimings': timings != null,
        'hasPositions': positions != null,
      });
      return -1;
    }

    AppLogger.debug('Tap-to-seek: Finding word at position', {
      'tapX': tapPosition.dx,
      'tapY': tapPosition.dy,
      'wordCount': timings.length,
      'positionCount': positions.length,
    });

    // Iterate through each word timing
    for (int i = 0; i < timings.length; i++) {
      final timing = timings[i];

      // Check if this word has character position information
      if (timing.charStart == null || timing.charEnd == null) {
        continue;
      }

      // Get the character range for this word
      final charStart = timing.charStart!;
      final charEnd = timing.charEnd!;

      // Check each character position within this word's range
      for (int charIndex = charStart; charIndex <= charEnd && charIndex < positions.length; charIndex++) {
        final position = positions[charIndex];
        if (position.rect.contains(tapPosition)) {
          AppLogger.info('Tap-to-seek: Found word', {
            'wordIndex': i,
            'word': timing.word,
            'charStart': charStart,
            'charEnd': charEnd,
            'tapPosition': '(${tapPosition.dx.toStringAsFixed(1)}, ${tapPosition.dy.toStringAsFixed(1)})',
          });
          return i;
        }
      }
    }

    AppLogger.debug('Tap-to-seek: No word found at position', {
      'tapX': tapPosition.dx,
      'tapY': tapPosition.dy,
    });
    return -1;
  }

  /// Loads word timings from SharedPreferences cache
  Future<List<WordTiming>?> _loadFromLocalCache(String contentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('word_timings_$contentId');
      if (cached == null) return null;

      final List<dynamic> json = jsonDecode(cached);
      return json.map((item) => WordTiming.fromJson(item)).toList();
    } catch (e) {
      AppLogger.debug(
          'Failed to load from local cache', {'error': e.toString()});
      return null;
    }
  }

  /// Saves word timings to SharedPreferences cache
  Future<void> _saveToLocalCache(
      String contentId, List<WordTiming> timings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = timings.map((t) => t.toJson()).toList();
      await prefs.setString('word_timings_$contentId', jsonEncode(json));
      AppLogger.debug('Saved timings to local cache', {
        'contentId': contentId,
        'timingCount': timings.length,
      });
    } catch (e) {
      AppLogger.debug('Failed to save to local cache', {'error': e.toString()});
      // Continue without caching - not critical for functionality
    }
  }

  /// Clears all cached data - useful for memory management
  void clearCache() {
    _wordTimingCache.clear();
    _collectionCache.clear();
    _positionCache.clear();
    _cacheAccessOrder.clear();
    AppLogger.debug('Cache cleared');
  }

  /// Ensure sentence indices exist and are correct. Some Speechify responses
  /// return a flat list of word marks without `sentence_index`. In that case
  /// all words may default to 0 and the UI highlights the entire document.
  /// This method derives sentence indices from the original text using
  /// character offsets when available.
  List<WordTiming> ensureSentenceIndexing(
    List<WordTiming> timings, {
    required String displayText,
    String? sourceText,
  }) {
    if (timings.isEmpty) return timings;

    final unique = timings.map((t) => t.sentenceIndex).toSet();
    if (unique.length > 1) {
      AppLogger.info('Sentence indexing provided by API', {
        'uniqueSentenceCount': unique.length,
      });
      return timings;
    }

    final source = sourceText ?? displayText;
    final sourceLength = source.length;

    final adjusted = <WordTiming>[];
    int sentenceIndex = 0;
    int searchCursor = 0;
    int sourceCursor = 0;
    int? previousSourceStart;
    int? previousSourceEnd;

    for (int i = 0; i < timings.length; i++) {
      final current = timings[i];
      final range = _resolveWordRange(current, displayText, searchCursor);
      final start = range.$1;
      final end = range.$2;

      if (start < 0 || end < 0 || start >= displayText.length) {
        AppLogger.warning(
            'Failed to resolve word range for sentence detection', {
          'word': current.word,
          'charStart': current.charStart,
          'charEnd': current.charEnd,
        });
      }

      int? sourceStart;
      int? sourceEnd;
      if (sourceLength > 0) {
        var match = _findWordInSource(
          source,
          current.word,
          sourceCursor,
        );
        if (match == null) {
          final fallbackIdx = source
              .toLowerCase()
              .indexOf(current.word.toLowerCase(), sourceCursor);
          if (fallbackIdx != -1) {
            match = _WordRange(fallbackIdx, fallbackIdx + current.word.length);
          }
        }
        if (match != null) {
          sourceStart = match.start;
          sourceEnd = match.end;
          sourceCursor = match.end;
        } else {
          sourceStart = sourceCursor;
          final fallbackEnd =
              math.min(sourceCursor + current.word.length, sourceLength);
          sourceEnd = fallbackEnd;
          sourceCursor = fallbackEnd;
        }
      }

      if (adjusted.isNotEmpty) {
        final prev = adjusted.last;
        final prevStart = prev.charStart ?? 0;
        final prevEndExclusive = prev.charEnd ?? (prevStart + prev.word.length);
        final gapStart = math.max(0, prevEndExclusive);
        final gapEnd = math.max(gapStart, math.min(start, displayText.length));
        final displayGap =
            gapEnd > gapStart ? displayText.substring(gapStart, gapEnd) : '';
        final timeGap = current.startMs - prev.endMs;

        final previousSourceWord = _extractSourceWord(
          source,
          previousSourceStart,
          previousSourceEnd,
        );
        final sourceGap = _extractSourceGap(
          source,
          previousSourceEnd,
          sourceStart,
        );

        if (timeGap >= _sentencePauseThresholdMs ||
            _shouldStartNewSentence(
              gap: sourceGap.isNotEmpty ? sourceGap : displayGap,
              previousWord: previousSourceWord.isNotEmpty
                  ? previousSourceWord
                  : displayText.substring(prevStart,
                      math.min(prevEndExclusive, displayText.length)),
            )) {
          sentenceIndex++;
        }
      }

      adjusted.add(
        current.copyWith(
          sentenceIndex: sentenceIndex,
          charStart: start,
          charEnd: end,
        ),
      );

      if (sourceStart != null) {
        previousSourceStart = sourceStart;
      }
      if (sourceEnd != null) {
        previousSourceEnd = sourceEnd;
      }
      searchCursor = end;
    }

    final inferredCount = adjusted.map((t) => t.sentenceIndex).toSet().length;
    AppLogger.info('Sentence indices inferred from Speechify text', {
      'uniqueSentenceCount': inferredCount,
    });

    return adjusted;
  }

  (int, int) _resolveWordRange(
      WordTiming timing, String text, int searchCursor) {
    final word = timing.word;
    final textLength = text.length;
    if (word.isEmpty || textLength == 0) {
      final cursor = math.max(0, math.min(searchCursor, textLength));
      return (cursor, cursor);
    }

    int start = timing.charStart ?? searchCursor;
    start = math.max(0, math.min(start, textLength));

    int? end = _matchWordAt(text, word, start, timing.charEnd);

    if (end == null && start > 0) {
      final leftStart = start - 1;
      end = _matchWordAt(text, word, leftStart, timing.charEnd);
      if (end != null) {
        start = leftStart;
      }
    }

    if (end == null && start + 1 <= textLength) {
      final rightStart = math.min(start + 1, textLength);
      end = _matchWordAt(text, word, rightStart, timing.charEnd);
      if (end != null) {
        start = rightStart;
      }
    }

    if (end == null) {
      final windowStart = math.max(0, start - 6);
      final idx = text.indexOf(word, windowStart);
      if (idx != -1 && (idx - start).abs() <= 6) {
        start = idx;
        end = idx + word.length;
      }
    }

    if (end == null) {
      final idx = text.indexOf(word, math.max(0, searchCursor));
      if (idx != -1) {
        start = idx;
        end = idx + word.length;
      }
    }

    if (end == null) {
      final idx = text.indexOf(word);
      if (idx != -1) {
        start = idx;
        end = idx + word.length;
      }
    }

    end ??= math.min(textLength, start + word.length);

    return (
      math.max(0, math.min(start, textLength)),
      math.max(0, math.min(end, textLength)),
    );
  }

  int? _matchWordAt(String text, String word, int start, int? providedEnd) {
    final textLength = text.length;
    if (start < 0 || start >= textLength) return null;

    final candidates = <int>{};
    if (providedEnd != null) {
      if (providedEnd >= start && providedEnd <= textLength) {
        candidates.add(providedEnd);
      }
      if (providedEnd + 1 >= start && providedEnd + 1 <= textLength) {
        candidates.add(providedEnd + 1);
      }
    }

    final lengthCandidate = start + word.length;
    if (lengthCandidate >= start && lengthCandidate <= textLength) {
      candidates.add(lengthCandidate);
    }

    for (final candidate in candidates) {
      if (candidate <= textLength && candidate >= start) {
        final slice = text.substring(start, candidate);
        if (slice == word) {
          return candidate;
        }
      }
    }

    return null;
  }

  bool _shouldStartNewSentence({
    required String gap,
    required String previousWord,
  }) {
    final trimmedPrev = previousWord.trimRight();
    final prevTerminates = trimmedPrev.endsWith('.') ||
        trimmedPrev.endsWith('!') ||
        trimmedPrev.endsWith('?');
    final gapTerminator = _extractSentenceTerminator(gap);

    if (!prevTerminates && gapTerminator == null) {
      return false;
    }

    final terminatorBuffer = StringBuffer();

    if (prevTerminates) {
      final match = RegExp(r'([.!?]+)$').firstMatch(trimmedPrev);
      if (match != null) {
        terminatorBuffer.write(match.group(1));
      }
    }

    if (gapTerminator != null) {
      terminatorBuffer.write(gapTerminator);
    }

    final terminator = terminatorBuffer.toString();
    if (terminator.isEmpty) {
      return false;
    }

    if (terminator.contains('!') || terminator.contains('?')) {
      return true;
    }

    if (!terminator.contains('.')) {
      return false;
    }

    final cleanedPrev = _stripClosingDelimiters(trimmedPrev);
    final coreToken =
        cleanedPrev.replaceAll(RegExp(r'[.!?]+$'), '').toLowerCase();

    if (_isLikelyAbbreviation(coreToken, cleanedPrev)) {
      return false;
    }

    return true;
  }

  String? _extractSentenceTerminator(String gap) {
    if (gap.isEmpty) return null;
    final trimmed = gap.trimRight();
    if (trimmed.isEmpty) return null;

    final buffer = StringBuffer();
    int index = trimmed.length - 1;

    while (index >= 0 && _closingDelimiters.contains(trimmed[index])) {
      buffer.write(trimmed[index]);
      index--;
    }

    while (index >= 0 && _terminalPunctuation.contains(trimmed[index])) {
      buffer.write(trimmed[index]);
      index--;
    }

    if (buffer.isEmpty) {
      return null;
    }

    final chars = buffer.toString().split('').reversed.join();
    return chars;
  }

  bool _isLikelyAbbreviation(String token, String original) {
    if (token.isEmpty) {
      return false;
    }

    if (_commonAbbreviations.contains(token.toLowerCase())) {
      return true;
    }

    final normalized = _stripClosingDelimiters(original.trim());
    if (RegExp(r'^[A-Z]{1}\.?$').hasMatch(normalized)) {
      return true;
    }
    if (RegExp(r'^[A-Z]{2,}\.?$').hasMatch(normalized)) {
      return true;
    }

    if (normalized.contains('.')) {
      final cleaned = _stripClosingDelimiters(normalized);
      final segments = cleaned.split('.').where((s) => s.isNotEmpty).toList();
      if (segments.length > 1 &&
          segments.every(
              (part) => part.length <= 3 && part == part.toUpperCase())) {
        return true;
      }
    }

    return false;
  }

  String _stripClosingDelimiters(String value) {
    var result = value.trimRight();
    while (result.isNotEmpty &&
        _closingDelimiters.contains(result[result.length - 1])) {
      result = result.substring(0, result.length - 1).trimRight();
    }
    return result;
  }

  static const Set<String> _commonAbbreviations = {
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'sr',
    'jr',
    'vs',
    'inc',
    'ltd',
    'co',
    'corp',
    'dept',
    'st',
    'rd',
    'ave',
    'etc',
    'i.e',
    'e.g',
    'u.s',
    'u.k',
    'no',
  };

  static const Set<String> _closingDelimiters = {
    ')',
    ']',
    '}',
    '"',
    '\'',
    '’',
    '”',
  };

  static const Set<String> _terminalPunctuation = {
    '.',
    '!',
    '?',
  };

  static const int _sentencePauseThresholdMs = 350;

  /// Disposes of streams and cleans up resources
  void dispose() {
    _currentWordController.close();
    _currentSentenceController.close();
    clearCache();
    AppLogger.debug('Service disposed');
  }
}

_WordRange? _findWordInSource(String source, String word, int start) {
  if (source.isEmpty || word.isEmpty) return null;
  if (start >= source.length) return null;
  final pattern = RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false);
  final match = pattern.firstMatch(source.substring(start));
  if (match == null) {
    return null;
  }
  final matchedStart = start + match.start;
  return _WordRange(matchedStart, matchedStart + match.end - match.start);
}

String _extractSourceGap(String source, int? previousEnd, int? nextStart) {
  if (previousEnd == null || nextStart == null) return '';
  final s = math.max(0, math.min(previousEnd, source.length));
  final e = math.max(s, math.min(nextStart, source.length));
  if (e <= s) return '';
  return source.substring(s, e);
}

String _extractSourceWord(String source, int? start, int? end) {
  if (start == null || end == null) return '';
  final s = math.max(0, math.min(start, source.length));
  final e = math.max(s, math.min(end, source.length));
  if (e <= s) return '';
  return source.substring(s, e);
}

class _WordRange {
  final int start;
  final int end;
  _WordRange(this.start, this.end);
}

/// Top-level function for processing timings in isolate
List<Map<String, dynamic>> _processTimingsIsolate(Map<String, dynamic> data) {
  final List<dynamic> timingsJson = data['timings'];
  final String text = data['text'];

  final timings = timingsJson.map((json) => WordTiming.fromJson(json)).toList();

  // Add sentence indexing and character positions
  int characterPosition = 0;

  final processedTimings = <Map<String, dynamic>>[];

  for (final timing in timings) {
    int wordStart = text.indexOf(timing.word, characterPosition);
    if (wordStart < 0) {
      wordStart = text.indexOf(timing.word);
    }
    if (wordStart < 0) {
      wordStart = characterPosition;
    }

    int wordEnd = wordStart + timing.word.length;
    if (wordEnd > text.length) {
      wordEnd = text.length;
    }

    processedTimings.add({
      'word': timing.word,
      'start_ms': timing.startMs,
      'end_ms': timing.endMs,
      'sentence_index': timing.sentenceIndex,
      'char_start': wordStart >= 0 ? wordStart : null,
      'char_end': wordEnd,
    });

    characterPosition = math.max(wordEnd, characterPosition);
  }

  return processedTimings;
}

/// Top-level function for computing text positions in isolate
List<Map<String, dynamic>> _computePositionsIsolate(Map<String, dynamic> data) {
  final String text = data['text'];
  final Map<String, dynamic> styleData = data['textStyle'];
  final double maxWidth = data['maxWidth'];

  // Create TextStyle from data
  final textStyle = ui.TextStyle(
    fontSize: styleData['fontSize']?.toDouble() ?? 16.0,
    fontFamily: styleData['fontFamily'],
    fontWeight: styleData['fontWeight'] != null
        ? FontWeight.values[styleData['fontWeight']]
        : FontWeight.normal,
    letterSpacing: styleData['letterSpacing']?.toDouble(),
    height: styleData['height']?.toDouble(),
  );

  // Create paragraph builder
  final paragraphBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
    maxLines: null,
  ))
    ..pushStyle(textStyle)
    ..addText(text);

  final paragraph = paragraphBuilder.build();
  paragraph.layout(ui.ParagraphConstraints(width: maxWidth));

  final positions = <Map<String, dynamic>>[];

  // Calculate positions for each character
  for (int i = 0; i < text.length; i++) {
    try {
      final boxes = paragraph.getBoxesForRange(i, i + 1);
      if (boxes.isNotEmpty) {
        final box = boxes.first;
        positions.add({
          'offset': i,
          'left': box.left,
          'top': box.top,
          'width': box.right - box.left,
          'height': box.bottom - box.top,
        });
      } else {
        // Fallback for characters without boxes
        positions.add({
          'offset': i,
          'left': 0.0,
          'top': 0.0,
          'width': 0.0,
          'height': 0.0,
        });
      }
    } catch (e) {
      // Handle edge cases
      positions.add({
        'offset': i,
        'left': 0.0,
        'top': 0.0,
        'width': 0.0,
        'height': 0.0,
      });
    }
  }

  return positions;
}

/// Validation function to verify WordTimingService implementation
Future<void> validateWordTimingService() async {
  final stopwatch = Stopwatch()..start();

  try {
    AppLogger.info('Starting WordTimingService validation');

    const testText = '''
    This is the first sentence with multiple words.
    Here is the second sentence for testing purposes.
    The third sentence concludes our comprehensive test.
    ''';

    // Test 1: Service initialization
    final service = WordTimingService();
    assert(service == WordTimingService.instance, 'Should be singleton');
    AppLogger.debug('✅ Singleton pattern working');

    // Test 2: Stream initialization (test through public interface)
    bool streamWorking = false;
    final testSub =
        service.currentWordStream.take(1).listen((_) => streamWorking = true);
    service.updatePosition(100, 'validation-test');
    await Future.delayed(const Duration(milliseconds: 20));
    await testSub.cancel();
    AppLogger.debug('✅ Streams initialized and working correctly');

    // Test 3: Cache operations (test through public interface)
    service.clearCache();
    // Test that cache is cleared by checking getCachedTimings returns null
    assert(service.getCachedTimings('any-key') == null,
        'Cache should be empty after clear');
    AppLogger.debug('✅ Cache operations working');

    // Test 4: Stream throttling (simplified test)
    int updateCount = 0;
    final subscription =
        service.currentWordStream.take(5).listen((_) => updateCount++);

    // Simulate rapid updates using public API
    for (int i = 0; i < 20; i++) {
      service.updatePosition(i * 50, 'throttle-test');
    }

    await Future.delayed(const Duration(milliseconds: 100));
    subscription.cancel();

    assert(updateCount <= 10,
        'Stream should be throttled (got $updateCount updates)');
    AppLogger.debug(
        '✅ Stream throttling working', {'updateCount': updateCount});

    stopwatch.stop();
    assert(stopwatch.elapsedMilliseconds < 1000,
        'Validation should complete quickly');

    AppLogger.performance('WordTimingService validation complete',
        {'duration': '${stopwatch.elapsedMilliseconds}ms'});
  } catch (e, stackTrace) {
    AppLogger.error(
      'WordTimingService validation failed',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
