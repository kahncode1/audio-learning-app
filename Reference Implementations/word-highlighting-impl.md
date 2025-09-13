# /implementations/word-highlighting.dart

```dart
/// Dual-Level Word Highlighting Service
/// 
/// Provides synchronized dual-level highlighting with:
/// - Word-level foreground highlighting for current word
/// - Sentence-level background highlighting for context
/// - Binary search for O(log n) performance
/// - Pre-computed word positions for 60fps performance
/// - Tap-to-seek functionality

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class WordTiming {
  final String word;
  final int startMs;
  final int endMs;
  final int sentenceIndex;

  const WordTiming({
    required this.word,
    required this.startMs,
    required this.endMs,
    required this.sentenceIndex,
  });

  factory WordTiming.fromJson(Map<String, dynamic> json) {
    return WordTiming(
      word: json['word'],
      startMs: json['startMs'],
      endMs: json['endMs'],
      sentenceIndex: json['sentenceIndex'],
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'startMs': startMs,
    'endMs': endMs,
    'sentenceIndex': sentenceIndex,
  };
}

class WordTimingService {
  static const int _throttleMs = 16; // 60fps
  final Map<String, List<WordTiming>> _cache = {};
  final BehaviorSubject<int> _currentWordIndex = BehaviorSubject.seeded(-1);
  final BehaviorSubject<int> _currentSentenceIndex = BehaviorSubject.seeded(-1);
  
  Stream<int> get currentWordIndex => _currentWordIndex.stream;
  Stream<int> get currentSentenceIndex => _currentSentenceIndex.stream;
  
  /// Pre-compute word positions for performance
  Future<Map<int, Rect>> precomputeWordPositions(
    String content,
    TextStyle textStyle,
    Size constraints,
  ) async {
    // Use compute() to run in isolate
    return await compute(
      _computeWordPositions,
      _ComputeParams(content, textStyle, constraints),
    );
  }
  
  static Map<int, Rect> _computeWordPositions(_ComputeParams params) {
    final positions = <int, Rect>{};
    final textPainter = TextPainter(
      text: TextSpan(text: params.content, style: params.textStyle),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: params.constraints.width);
    
    // Calculate position for each word
    final words = params.content.split(' ');
    int currentIndex = 0;
    
    for (int i = 0; i < words.length; i++) {
      final startOffset = textPainter.getPositionForOffset(
        Offset(currentIndex.toDouble(), 0),
      );
      currentIndex += words[i].length + 1; // +1 for space
      
      final endOffset = textPainter.getPositionForOffset(
        Offset(currentIndex.toDouble(), 0),
      );
      
      positions[i] = Rect.fromPoints(
        startOffset.offset,
        endOffset.offset,
      );
    }
    
    return positions;
  }
  
  /// Binary search for current word (O(log n))
  int findCurrentWord(List<WordTiming> timings, Duration position) {
    if (timings.isEmpty) return -1;
    
    final positionMs = position.inMilliseconds;
    int left = 0;
    int right = timings.length - 1;
    
    while (left <= right) {
      final mid = left + ((right - left) >> 1); // Avoid overflow
      final timing = timings[mid];
      
      if (positionMs < timing.startMs) {
        right = mid - 1;
      } else if (positionMs > timing.endMs) {
        left = mid + 1;
      } else {
        return mid; // Found the word
      }
    }
    
    return left > 0 ? left - 1 : -1;
  }
  
  /// Find current sentence for dual-level highlighting
  int findCurrentSentence(List<WordTiming> timings, Duration position) {
    if (timings.isEmpty) return -1;
    
    final positionMs = position.inMilliseconds;
    for (final timing in timings) {
      if (timing.startMs <= positionMs && timing.endMs > positionMs) {
        return timing.sentenceIndex;
      }
    }
    return -1;
  }
  
  /// Stream word and sentence positions with throttling
  Stream<int> watchCurrentWord(
    Stream<Duration> positionStream,
    List<WordTiming> timings,
  ) {
    return positionStream
        .throttleTime(const Duration(milliseconds: _throttleMs))
        .map((position) => findCurrentWord(timings, position))
        .distinct() // Only emit when word changes
        .doOnData((index) => _currentWordIndex.add(index));
  }
  
  Stream<int> watchCurrentSentence(
    Stream<Duration> positionStream,
    List<WordTiming> timings,
  ) {
    return positionStream
        .throttleTime(const Duration(milliseconds: _throttleMs))
        .map((position) => findCurrentSentence(timings, position))
        .distinct() // Only emit when sentence changes
        .doOnData((index) => _currentSentenceIndex.add(index));
  }
  
  /// Fetch word timings from API or cache
  Future<List<WordTiming>?> fetchTimings(String loid) async {
    // Check cache first
    if (_cache.containsKey(loid)) {
      return _cache[loid];
    }
    
    // Fetch from API (implementation depends on your backend)
    // This is a placeholder - replace with actual API call
    final timings = await _fetchFromApi(loid);
    
    if (timings != null) {
      _cache[loid] = timings;
    }
    
    return timings;
  }
  
  Future<List<WordTiming>?> _fetchFromApi(String loid) async {
    // Placeholder for API call
    // Replace with actual implementation
    return null;
  }
  
  WordTiming? getWordTiming(int index) {
    // Get timing for specific word index
    // Implementation depends on your data structure
    return null;
  }
  
  void updatePosition(Duration position) {
    // Update position for internal tracking
    // Used by the audio player screen
  }
  
  void dispose() {
    _currentWordIndex.close();
    _currentSentenceIndex.close();
  }
}

/// Compute parameters for isolate
class _ComputeParams {
  final String content;
  final TextStyle textStyle;
  final Size constraints;
  
  _ComputeParams(this.content, this.textStyle, this.constraints);
}

/// Dual-Level Highlighted Text Widget
class DualLevelHighlightedTextWidget extends StatefulWidget {
  final String content;
  final List<WordTiming> timings;
  final Stream<Duration> positionStream;
  final Function(int wordIndex)? onWordTap;
  final double fontSize;
  
  const DualLevelHighlightedTextWidget({
    super.key,
    required this.content,
    required this.timings,
    required this.positionStream,
    this.onWordTap,
    required this.fontSize,
  });
  
  @override
  _DualLevelHighlightedTextWidgetState createState() => 
      _DualLevelHighlightedTextWidgetState();
}

class _DualLevelHighlightedTextWidgetState extends State<DualLevelHighlightedTextWidget> {
  late final WordTimingService _timingService;
  StreamSubscription<int>? _wordSubscription;
  StreamSubscription<int>? _sentenceSubscription;
  int _currentWordIndex = -1;
  int _currentSentenceIndex = -1;
  Map<int, Rect>? _wordPositions;
  
  @override
  void initState() {
    super.initState();
    _timingService = WordTimingService();
    _precomputePositions();
    _subscribeToChanges();
  }
  
  Future<void> _precomputePositions() async {
    final positions = await _timingService.precomputeWordPositions(
      widget.content,
      TextStyle(fontSize: widget.fontSize),
      MediaQuery.of(context).size,
    );
    setState(() => _wordPositions = positions);
  }
  
  void _subscribeToChanges() {
    _wordSubscription = _timingService.watchCurrentWord(
      widget.positionStream,
      widget.timings,
    ).listen((index) {
      setState(() => _currentWordIndex = index);
    });
    
    _sentenceSubscription = _timingService.watchCurrentSentence(
      widget.positionStream,
      widget.timings,
    ).listen((index) {
      setState(() => _currentSentenceIndex = index);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary( // CRITICAL: Isolate repaints for performance
      child: RichText(
        text: TextSpan(
          children: _buildDualLevelSpans(),
        ),
      ),
    );
  }
  
  List<TextSpan> _buildDualLevelSpans() {
    final sentences = widget.content.split(RegExp(r'(?<=[.!?])\s+'));
    final List<TextSpan> spans = [];
    
    for (int sentenceIdx = 0; sentenceIdx < sentences.length; sentenceIdx++) {
      final sentence = sentences[sentenceIdx];
      final words = sentence.split(' ');
      final isCurrentSentence = sentenceIdx == _currentSentenceIndex;
      
      for (int wordIdx = 0; wordIdx < words.length; wordIdx++) {
        final globalWordIndex = _calculateGlobalWordIndex(sentenceIdx, wordIdx);
        final isCurrentWord = globalWordIndex == _currentWordIndex;
        
        spans.add(TextSpan(
          text: '${words[wordIdx]} ',
          style: TextStyle(
            fontSize: widget.fontSize,
            color: isCurrentWord 
                ? const Color(0xFF1976D2) // Darker blue for current word
                : const Color(0xFF424242),
            backgroundColor: isCurrentWord
                ? const Color(0xFFFFF59D) // Yellow for current word
                : isCurrentSentence
                    ? const Color(0xFFE3F2FD) // Light blue for current sentence
                    : null,
            fontWeight: isCurrentWord ? FontWeight.w600 : FontWeight.normal,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => widget.onWordTap?.call(globalWordIndex),
        ));
      }
    }
    
    return spans;
  }
  
  int _calculateGlobalWordIndex(int sentenceIndex, int wordIndexInSentence) {
    // Calculate the global word index based on sentence and word position
    final sentences = widget.content.split(RegExp(r'(?<=[.!?])\s+'));
    int globalIndex = 0;
    
    for (int i = 0; i < sentenceIndex; i++) {
      globalIndex += sentences[i].split(' ').length;
    }
    
    return globalIndex + wordIndexInSentence;
  }
  
  @override
  void dispose() {
    _wordSubscription?.cancel();
    _sentenceSubscription?.cancel();
    _timingService.dispose();
    super.dispose();
  }
}

// Validation function
void main() async {
  print('🔧 Testing Dual-Level Word Highlighting Service...\n');
  
  final List<String> validationFailures = [];
  int totalTests = 0;
  
  // Test 1: Binary search performance
  totalTests++;
  try {
    final timings = List.generate(10000, (i) => WordTiming(
      word: 'word$i',
      startMs: i * 100,
      endMs: (i + 1) * 100 - 10,
      sentenceIndex: i ~/ 10,
    ));
    
    final service = WordTimingService();
    final stopwatch = Stopwatch()..start();
    
    // Perform 100 searches
    for (int i = 0; i < 100; i++) {
      service.findCurrentWord(timings, Duration(milliseconds: 500000));
    }
    
    stopwatch.stop();
    final avgSearchTime = stopwatch.elapsedMilliseconds / 100;
    
    if (avgSearchTime < 5) {
      print('✓ Binary search performance: ${avgSearchTime.toStringAsFixed(2)}ms average');
    } else {
      validationFailures.add('Binary search too slow: ${avgSearchTime}ms (expected <5ms)');
    }
  } catch (e) {
    validationFailures.add('Binary search test failed: $e');
  }
  
  // Test 2: Sentence index finding
  totalTests++;
  try {
    final timings = [
      WordTiming(word: 'Hello', startMs: 0, endMs: 500, sentenceIndex: 0),
      WordTiming(word: 'world', startMs: 500, endMs: 1000, sentenceIndex: 0),
      WordTiming(word: 'This', startMs: 1000, endMs: 1500, sentenceIndex: 1),
      WordTiming(word: 'works', startMs: 1500, endMs: 2000, sentenceIndex: 1),
    ];
    
    final service = WordTimingService();
    final sentenceIndex = service.findCurrentSentence(
      timings,
      Duration(milliseconds: 750),
    );
    
    if (sentenceIndex == 0) {
      print('✓ Sentence index finding accurate');
    } else {
      validationFailures.add('Incorrect sentence index: expected 0, got $sentenceIndex');
    }
  } catch (e) {
    validationFailures.add('Sentence finding test failed: $e');
  }
  
  // Test 3: Stream throttling
  totalTests++;
  try {
    final controller = StreamController<Duration>();
    final service = WordTimingService();
    final timings = [
      WordTiming(word: 'test', startMs: 0, endMs: 1000, sentenceIndex: 0),
    ];
    
    int emitCount = 0;
    service.watchCurrentWord(controller.stream, timings).listen((_) {
      emitCount++;
    });
    
    // Emit 100 updates rapidly
    for (int i = 0; i < 100; i++) {
      controller.add(Duration(milliseconds: i * 10));
    }
    
    await Future.delayed(Duration(milliseconds: 100));
    
    // Should be throttled to ~6 updates (100ms / 16ms)
    if (emitCount <= 10) {
      print('✓ Stream throttling working: $emitCount emissions');
    } else {
      validationFailures.add('Throttling not working: $emitCount emissions (expected ≤10)');
    }
    
    controller.close();
  } catch (e) {
    validationFailures.add('Stream throttling test failed: $e');
  }
  
  // Test 4: Dual-level accuracy
  totalTests++;
  try {
    final timings = [
      WordTiming(word: 'First', startMs: 0, endMs: 500, sentenceIndex: 0),
      WordTiming(word: 'sentence', startMs: 500, endMs: 1000, sentenceIndex: 0),
      WordTiming(word: 'Second', startMs: 1000, endMs: 1500, sentenceIndex: 1),
      WordTiming(word: 'sentence', startMs: 1500, endMs: 2000, sentenceIndex: 1),
    ];
    
    final service = WordTimingService();
    final position = Duration(milliseconds: 750);
    
    final wordIndex = service.findCurrentWord(timings, position);
    final sentenceIndex = service.findCurrentSentence(timings, position);
    
    if (wordIndex == 1 && sentenceIndex == 0) {
      print('✓ Dual-level highlighting accurate');
    } else {
      validationFailures.add(
        'Dual-level mismatch: word=$wordIndex (expected 1), sentence=$sentenceIndex (expected 0)'
      );
    }
  } catch (e) {
    validationFailures.add('Dual-level accuracy test failed: $e');
  }
  
  // Final validation results
  print('\n' + '=' * 50);
  if (validationFailures.isNotEmpty) {
    print('❌ VALIDATION FAILED - ${validationFailures.length} of $totalTests tests failed:\n');
    for (final failure in validationFailures) {
      print('  • $failure');
    }
    exit(1);
  } else {
    print('✅ VALIDATION PASSED - All $totalTests tests produced expected results');
    print('Dual-level highlighting ready for 60fps performance');
    exit(0);
  }
}
```