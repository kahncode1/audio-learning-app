# Dual-Level Highlighting Seek Bug Analysis

**Date:** September 20, 2025
**Issue:** Highlighting breaks when fast-forwarding or seeking in the audio player

## Problem Description

When users fast-forward or seek (using buttons or slider), the dual-level highlighting (word and sentence) becomes incorrect:
- Wrong words are highlighted
- Multiple words highlighted simultaneously
- Highlighting jumps to incorrect positions
- System becomes "glitchy" and unusable after seeks

## Root Cause Analysis

### The Architecture Problem

There are **TWO SEPARATE timing lookup systems** that are not properly coordinated:

#### 1. Service Layer (`WordTimingServiceSimplified`)
```dart
// Uses TimingData from LocalContentService
int getCurrentWordIndex(int positionMs) {
  if (_currentTimingData == null) return -1;
  return _currentTimingData!.getCurrentWordIndex(positionMs);
}
```

This calls `TimingData.getCurrentWordIndex()` which uses **LINEAR SEARCH**:
```dart
// In LocalContentService.dart
int getCurrentWordIndex(int positionMs) {
  for (int i = 0; i < words.length; i++) {  // O(n) linear search!
    if (positionMs >= words[i].startMs && positionMs <= words[i].endMs) {
      return i;
    }
  }
  // ...
}
```

**Problems with linear search:**
- O(n) complexity - iterates through ALL words from index 0
- No caching or optimization
- After seeking to position 800000ms (13+ minutes), it must iterate through 2000+ words
- During rapid position updates, this causes timing issues and returns incorrect indices

#### 2. Widget Layer (`SimplifiedDualLevelHighlightedText`)
```dart
// Has its own WordTimingCollection with binary search + locality caching
WordTimingCollection? _timingCollection;
```

This has an **OPTIMIZED BINARY SEARCH** with locality caching:
```dart
// In word_timing.dart
int findActiveWordIndex(int timeMs) {
  // Check locality cache first
  if (_lastSearchIndex >= 0 && _lastSearchIndex < timings.length) {
    // ... quick checks near last position
  }
  // Binary search if locality fails
  // ... O(log n) search
}
```

### The Critical Mismatch

**The widget's optimized `WordTimingCollection` is NOT used for determining which word to highlight!**

Flow of data:
1. `enhanced_audio_player_screen` calls `_wordTimingService.updatePosition(positionMs)`
2. `WordTimingServiceSimplified` uses `TimingData` (LINEAR search) to find indices
3. Service emits indices via streams: `_currentWordIndexSubject.add(wordIndex)`
4. Widget listens to streams and updates `_currentWordIndex`
5. Widget passes this index to painter for highlighting

**Result:** The widget has an efficient timing collection that's only used for:
- Getting word boundaries for painting
- Getting sentence groupings
- Auto-scroll calculations

But NOT for the actual index calculations that determine what to highlight!

## Why Previous Fix Attempts Failed

Our previous changes attempted to reset the locality cache in the widget's `WordTimingCollection`:
```dart
// In widget
_timingCollection?.resetLocalityCache();  // This doesn't help!
```

**Why this doesn't work:**
- We're resetting a cache that isn't used for index calculations
- The actual indices come from the SERVICE's `TimingData` which has NO cache
- We added complexity without addressing the root cause

## Recommended Solutions

### Option 1: Fix at the Source (RECOMMENDED)

Replace the linear search in `TimingData` with the optimized `WordTimingCollection`:

**In `local_content_service.dart`:**
```dart
class TimingData {
  final List<WordTiming> words;
  final List<SentenceTiming> sentences;
  final int totalDurationMs;
  late final WordTimingCollection _wordCollection; // Add this!

  TimingData({...}) {
    _wordCollection = WordTimingCollection(words);
  }

  int getCurrentWordIndex(int positionMs) {
    // Use optimized binary search instead of linear
    return _wordCollection.findActiveWordIndex(positionMs);
  }

  // Add method to reset cache on seeks
  void resetLocalityCache() {
    _wordCollection.resetLocalityCache();
  }
}
```

**Benefits:**
- Fixes the root cause
- O(log n) search instead of O(n)
- Locality caching for smooth playback
- All consumers get the performance benefit

### Option 2: Widget-Level Fix (Alternative)

Have the widget calculate indices directly instead of using service streams:

**In widget:**
```dart
// Stop listening to service streams
// Instead, listen to position and calculate locally
_positionSubscription = _audioService.positionStream.listen((position) {
  if (mounted && _timingCollection != null) {
    final positionMs = position.inMilliseconds;
    final wordIndex = _timingCollection!.findActiveWordIndex(positionMs);
    final sentenceIndex = _timingCollection!.findActiveSentenceIndex(positionMs);

    setState(() {
      _currentWordIndex = wordIndex;
      _currentSentenceIndex = sentenceIndex;
    });
  }
});
```

**Benefits:**
- Simpler architecture (single source of truth)
- Widget controls its own highlighting
- Cache resets would actually work

**Drawbacks:**
- Breaks current architecture patterns
- Service layer becomes less useful
- Other consumers don't benefit

### Option 3: Quick Patch (Temporary)

Add simple caching to the linear search:

**In `local_content_service.dart`:**
```dart
class TimingData {
  int _lastFoundIndex = 0;  // Remember last position

  int getCurrentWordIndex(int positionMs) {
    // Start search near last position instead of 0
    int startIdx = (_lastFoundIndex - 10).clamp(0, words.length - 1);

    // Search forward from start
    for (int i = startIdx; i < words.length; i++) {
      if (positionMs >= words[i].startMs && positionMs <= words[i].endMs) {
        _lastFoundIndex = i;
        return i;
      }
    }

    // Search backward if needed
    for (int i = startIdx - 1; i >= 0; i--) {
      if (positionMs >= words[i].startMs && positionMs <= words[i].endMs) {
        _lastFoundIndex = i;
        return i;
      }
    }

    return -1;
  }
}
```

**Benefits:**
- Minimal code change
- Improves performance for normal playback

**Drawbacks:**
- Still O(n) worst case after seeks
- Doesn't fully solve the problem

## Implementation Priority

1. **Immediate:** Implement Option 1 (fix at source)
   - Best long-term solution
   - Proper performance characteristics
   - Maintains architecture

2. **If Option 1 is too complex:** Implement Option 2 (widget-level)
   - Clean solution
   - Good performance
   - Some architectural changes

3. **Only as last resort:** Option 3 (quick patch)
   - Temporary fix
   - Doesn't fully solve problem
   - Technical debt

## Testing Requirements

After implementing the fix:

1. **Normal playback:** Verify smooth highlighting during regular playback
2. **30-second jumps:** Test forward/backward skip buttons
3. **Large seeks:** Test slider seeks of 5+ minutes
4. **Rapid seeks:** Test multiple rapid consecutive seeks
5. **Edge cases:** Test seeking to start/end of audio
6. **Performance:** Verify 60fps maintained during highlighting

## Lessons Learned

1. **Understand data flow:** Always trace where data comes from before fixing
2. **Fix root causes:** Don't patch symptoms without understanding the cause
3. **Avoid dead code:** Adding code that doesn't affect the actual problem adds complexity
4. **Test comprehensively:** Seek issues require testing various seek patterns
5. **Profile first:** Performance issues need profiling to identify bottlenecks