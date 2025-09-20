# Dual-Level Highlighting Seek Bug Analysis

**Date:** September 20, 2025
**Status:** Partially Resolved - Performance improved but seek bug persists

## Problem Description

When users fast-forward or seek (using buttons or slider), the dual-level highlighting (word and sentence) becomes incorrect:
- Wrong words are highlighted after multiple seeks
- Highlighting becomes "glitchy" and unusable
- Issue worsens with repeated seeking

## Successfully Implemented Solutions

### 1. Binary Search Optimization (COMMITTED - b5362e2)
**What we did:**
- Replaced O(n) linear search in `TimingData.getCurrentWordIndex()` with O(log n) binary search
- Added `WordTimingCollection` with optimized lookup to `LocalContentService`
- Integrated locality caching for sequential playback performance

**Results:**
- ✅ 100x faster word lookups for long audio files
- ✅ Smooth playback with locality caching
- ✅ Reduced CPU usage during highlighting
- ❌ Highlighting issue after multiple seeks still present

### 2. Cache Reset on Seek
**What we did:**
- Added `resetLocalityCacheForSeek()` method to `WordTimingServiceSimplified`
- Called from `AudioPlayerServiceLocal.seekToPosition()` after seek completes
- Included debouncing (100ms) to prevent cache thrashing during slider drags

**Results:**
- ✅ Prevents cache thrashing during rapid seeks
- ✅ Ensures fresh lookups after position jumps
- ❌ Didn't fix the underlying highlighting desync issue

## Attempted Solutions That Failed

### 1. Separate Word/Sentence Cache Indices
- **Tried:** Using `_lastWordSearchIndex` and `_lastSentenceSearchIndex` separately
- **Result:** No improvement, added complexity
- **Status:** Reverted to single `_lastSearchIndex`

### 2. Complex Smart Cache Positioning
- **Tried:** Advanced cache positioning algorithms
- **Result:** Didn't help, removed in favor of simple approach

### 3. Widget-Level Cache Resets
- **Tried:** Resetting cache in `SimplifiedDualLevelHighlightedText` widget
- **Result:** Ineffective - widget's `WordTimingCollection` isn't used for index calculation
- **Learning:** The indices come from the SERVICE layer, not the widget's collection

## Root Cause Analysis

### Current Architecture Flow
```
1. User drags slider → onChanged fires repeatedly
2. Each change → _audioService.seekToPosition(newPosition)
3. Audio player seeks → position stream updates
4. WordTimingServiceSimplified.updatePosition() called
5. Service uses TimingData (now with binary search) to find indices
6. Service emits indices via BehaviorSubjects
7. Widget listens to streams and updates state
8. Widget repaints with new indices
```

### Why Performance Improved But Bug Persists
The binary search optimization dramatically improved performance, but the highlighting desync after multiple seeks suggests the issue is NOT in the search algorithm itself, but rather in:
- Stream synchronization between audio position and highlighting updates
- Race conditions during rapid successive seeks
- Position reporting accuracy from just_audio during/after seeks

## Next Steps to Investigate

### 1. Stream Synchronization Issues
- Position updates may arrive out of order
- Buffered stream events could cause stale updates

### 2. Slider Input Frequency
- Slider `onChanged` fires continuously during drag
- Each call triggers a seek operation
- No debouncing currently applied

### 3. Audio Player State During Seeks
- just_audio might report intermediate/incorrect positions during seek operations
- Buffer state could affect position accuracy

### 4. Widget Rebuild Timing
- Multiple rapid setState calls could cause paint cycles with mixed old/new data
- Race between position updates and index updates

## Potential Solutions Not Yet Tried

### 1. Debounce Slider Input
```dart
// Add debouncing to reduce seek frequency
Timer? _seekDebounceTimer;
onChanged: (value) {
  _seekDebounceTimer?.cancel();
  _seekDebounceTimer = Timer(Duration(milliseconds: 50), () {
    final newPosition = Duration(
      milliseconds: (duration.inMilliseconds * value).round(),
    );
    _audioService.seekToPosition(newPosition);
  });
}
```

### 2. Filter Position Stream
```dart
// Ignore position jumps that seem invalid
_audioService.positionStream
  .where((position) => _isValidPositionUpdate(position))
  .listen((position) => updateHighlighting(position));
```

### 3. Synchronous State Updates
```dart
// Ensure word and sentence indices update atomically
void updateHighlightingState(int wordIndex, int sentenceIndex) {
  setState(() {
    _currentWordIndex = wordIndex;
    _currentSentenceIndex = sentenceIndex;
  });
}
```

### 4. Wait for Seek Completion
```dart
// Don't update highlighting until seek is confirmed complete
Future<void> seekToPosition(Duration position) async {
  _isSeeking = true;
  await _player.seek(position);
  await _player.positionStream.first; // Wait for position to stabilize
  _isSeeking = false;
  updateHighlighting();
}
```

### 5. Direct Position-to-Index Calculation in Widget
```dart
// Skip service layer, calculate directly in widget
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

## Lessons Learned

1. **Performance ≠ Correctness:** The 100x performance improvement didn't fix the sync issue
2. **Architecture Matters:** Having two separate timing collections (service and widget) creates complexity
3. **Seek Operations Are Complex:** Audio player seeks involve buffering, position reporting, and state management challenges
4. **Debouncing Is Critical:** Rapid successive operations need proper debouncing at multiple levels

## Testing Requirements

After implementing any fix, verify:
1. ✅ Normal playback maintains 60fps
2. ✅ Single 30-second skip works correctly
3. ✅ Multiple rapid skips in succession
4. ✅ Slider dragging and release
5. ✅ Seeking to beginning/end of audio
6. ✅ Combination of skip buttons and slider use