# Speechify Highlighting Pipeline

This document explains how Speechify audio generation, word timing, and UI highlighting work end-to-end. It focuses on the exact data formats we expect, how we interpret them, and the main pitfalls to avoid when debugging.

## 1. Speechify Request Flow

1. **Entry point** – `AudioPlayerService.loadLearningObject` calls `SpeechifyService.generateAudioWithTimings`.
2. **Payload** – `SpeechifyService.generateAudioStream` builds a JSON request:

   ```json
   {
     "input": "<plain text or SSML>",
     "voice_id": "henry",
     "model": "simba-turbo",
     "speed": 1.0,
     "include_speech_marks": true,
     "input_format": "ssml",               // only when we know the content is SSML
     "include_sentence_marks": true        // same as above
   }
   ```

   - `include_speech_marks: true` tells Speechify to return timing metadata; without it we cannot highlight.
   - `input_format: ssml` and `include_sentence_marks: true` are sent for forward compatibility. In our production traffic, Speechify still returns a single top-level chunk whose `chunks` are word marks (i.e., not pre-grouped by sentence). We retain these flags in case Speechify enables sentence chunking in the future, but we do not rely on them today.

3. **Expected HTTP response** (status 200):
   - `audio_data` – base64 audio that we stream via `SpeechifyAudioSource`.
   - `audio_format` – e.g. `"mp3"`.
   - `speech_marks` – either a nested object or a flat list (see below).
   - `billable_characters_count` – analytics only.

If the API returns anything else, `SpeechifyService` raises a `NetworkException` or `AudioException`.

## 2. Parsing Speechify Output

`speech_marks` as observed in production most commonly has this shape:

1. **Observed default (single parent + words)**:

   ```json
   {
     "value": "Full transcript",            // Speechify Removes ALL punctuation 
     "chunks": [
       {
         "value": "Hello",
         "start_time": 0,
         "end_time": 400,
         "start": 0,
         "end": 5,
         "type": "word"
       },
       {
         "value": "world",
         "start_time": 400,
         "end_time": 800,
         "start": 6,
         "end": 11,
         "type": "word"
       }
       // ... more words
     ]
   }
   ```


2. **Flat list of word marks** – `speech_marks` is itself a list; each entry is a word with `start_time`, `end_time`, optional `start`/`end`, sometimes `type: "word"`.

`SpeechifyService._parseSpeechMarks` handles all of the above:

- Single parent with words → parsed as `flat_words` mode.
- Nested sentence nodes → `_parseNestedChunk` / `_parseMultipleSentences`.
- Flat list → `_parseFlatWordList`.

All paths produce a `List<WordTiming>` sorted by `start_time`.

### Display Text Extraction

We prefer the transcript Speechify returns; `_extractDisplayValue` walks the nested `value` fields, normalizes whitespace, and stores it as `AudioGenerationResult.displayText`. If Speechify omits text, we fall back to the learning object’s `plainText` (after stripping SSML tags).

## 3. Why Speech Marks Matter

Speech marks provide:

- `start_time` / `end_time` (in ms) → used for binary search when locating the active word.
- Optional `start` / `end` character indices → used to align highlights with actual text.
- Sentence grouping when `chunks` are nested.

Without them we would guess timings, resulting in jerky highlighting.

### Active Word Calculation

`WordTimingCollection.findActiveWordIndex(positionMs)` does:

1. Check last cached index to exploit temporal locality.
2. If that fails, run a binary search across `WordTiming` entries comparing `positionMs` with `[startMs, endMs)`.
3. If no span contains the timestamp, return the closest finished word.

This is called on every position update (throttled to 60 fps) and feeds the UI via `WordTimingService.currentWordStream`.

## 4. Deriving the Active Sentence

Sentence indices come from two sources:

1. **API-provided** – if Speechify ever returns nested sentence chunks with indices, we preserve them (rare/unobserved in our traffic).
2. **Inference (current default)** – with the usual single-parent+words shape, `WordTimingService.ensureSentenceIndexing` rebuilds sentence indices:

   - The service walks through the display text, using each word’s `charStart`/`charEnd` hints (adjusted by `_resolveWordRange`).
   - New sentences are triggered when we cross a significant pause or a terminal punctuation mark that is *not* an abbreviation.
   - Pause detection uses `_sentencePauseThresholdMs` (currently 350 ms gap between word timings).
   - Punctuation detection strips trailing quotes/brackets and checks a terminal regex. `_isLikelyAbbreviation` protects fragments such as “Mr.”, “U.S.”, single-letter initials, and corporate abbreviations from ending sentences.
   - Binary search via `_findSentenceIndexForOffset` maps character offsets back to computed sentence ranges when only char positions are available.

`WordTimingCollection.findActiveSentenceIndex` simply looks up the active word index and returns its `sentenceIndex`.

## 5. SSML Handling, Pauses, and Expression

- `AudioPlayerService` hands `ssmlContent` through untouched when it already starts with `<speak>`.
- `processSSMLContent` wraps plain text into `<s>` blocks and injects `<break time="200ms"/>` pauses so the API respects sentence boundaries.
- When calling Speechify we set `input_format: ssml` and `include_sentence_marks: true`; otherwise Speechify may flatten sentences or ignore `<break>` tags.

Considerations:

- Keep SSML well-formed; malformed tags typically break the request.
- Use `<break>` for pauses, `<prosody>` or `<emphasis>` for expression, and `<mark>` only if downstream systems understand them (we strip `<mark>` in the fallback plain-text conversion).
- Avoid excessive punctuation in SSML; Speechify may duplicate pauses if both punctuation and `<break>` are present.

## 6. Highlight Rendering Flow

1. `AudioPlayerService` stores normalized timings in `WordTimingService.setCachedTimings`, ensuring both services use the same aligned data.
2. `SimplifiedDualLevelHighlightedText` listens to the service streams:
   - Sentence highlight uses `TextPainter.getBoxesForSelection` to build a continuous background for the sentence range.
   - Word highlight recalculates the best `[start, end)` span using `_computeSelectionForWord`, tolerating off-by-one char offsets and inclusive `end` values.
   - Auto-scroll keeps the current word visible in the viewport with smooth animation.

## 7. Common Mistakes & Pitfalls

- **Missing `include_speech_marks`** → no highlighting data; always set it.
- **Incorrect SSML flag** → Speechify will treat SSML markup as plain text; sentence grouping breaks.
- **Assuming `charEnd` is exclusive** → some responses treat it as inclusive; `_computeSelectionForWord` compensates, but custom code should not make assumptions.
- **Ignoring abbreviation detection** → leads to premature sentence breaks (e.g., highlighting everything after “Dr.” as a new sentence). Keep `_commonAbbreviations` updated when new edge cases appear.
- **Forgetting pause threshold** – adjust `_sentencePauseThresholdMs` if transcripts lack punctuation but rely on timing gaps for sentence separation.
- **Non-normalized display text** – highlight alignment fails if UI text diverges from the `displayText` Speechify provided. Ensure downstream transformers keep text in sync.

## 8. When Things Look Off

- **Highlight drift** – confirm that `displayText` matches what is shown; resynchronize timings via `WordTimingService.alignTimingsToText`.
- **Sentence highlight covers entire document** – check if every word has `sentenceIndex = 0`; the API might have returned flat marks. Verify `_sentencePauseThresholdMs` and abbreviation handling.
- **Speechify errors** – log output includes full endpoint, type of speech marks, and character coverage stats. Use those logs to adjust parsing.

This pipeline relies on the combination of Speechify's rich timing metadata and our post-processing to keep the transcript, audio, and UI aligned. Maintain consistency when editing any part of the flow to avoid cascading highlighting regressions.

## 9. UI Component Architecture

**Note:** Tap-to-seek functionality was removed on 2025-09-17 to simplify the implementation and improve maintainability.

### SimplifiedDualLevelHighlightedText Widget

The main UI widget (`lib/widgets/simplified_dual_level_highlighted_text.dart`) implements a high-performance dual-level highlighting system:

**Core Architecture:**
- **Three-layer paint system** – Renders sentence background, then word highlight, then text
- **Single immutable TextPainter** – Created once, never modified during paint cycles
- **Direct service integration** – Subscribes to WordTimingService throttled streams
- **Auto-scrolling** – Keeps current word centered in viewport with smooth animation
- **Fallback UI** – Shows status bar when highlighting data unavailable

**Performance Characteristics:**
- Binary search: **549μs** for 1000 lookups (10x better than 5ms target)
- Paint cycles: Consistent **60fps** with no frame drops
- Memory: Minimal state with direct service integration
- LRU cache: Limits to 10 documents to prevent memory growth

### OptimizedHighlightPainter

The custom painter uses a three-layer rendering approach for optimal visual hierarchy:

**Layer 1: Sentence Background**
- Color: `#E3F2FD` (light blue)
- Uses `TextPainter.getBoxesForSelection` for continuous highlight
- Falls back to per-word rectangles if character positions missing

**Layer 2: Word Highlight**
- Color: `#FFF59D` (yellow)
- Painted over sentence background for current word
- 2dp rounded corners for visual polish

**Layer 3: Text Content**
- Static TextPainter painted without modifications
- All highlighting effects come from colored rectangles behind text
- Text style never changes during paint (critical for performance)

### Character Position Alignment

The `_computeSelectionForWord()` method handles API offset mismatches:

1. **Fast path** – Check if word matches at provided position
2. **End offset handling** – Try both exclusive and inclusive interpretations
3. **Index shift correction** – Check ±1 character for 0/1-based indexing
4. **Window search** – Search within ±5 characters for minor discrepancies
5. **Fallback** – Use API-provided end if available, clamped to bounds

This robust approach ensures highlights align correctly even when:
- Speechify uses 1-based indexing instead of 0-based
- Character end positions are inclusive instead of exclusive
- Minor punctuation/whitespace differences exist

### Integration with WordTimingService

**Stream Management:**
- Subscribes to `currentWordStream` (throttled to 60fps via RxDart)
- Subscribes to `currentSentenceStream` (also throttled)
- Updates trigger `setState()` only when indices change
- Proper disposal in reverse order of initialization

**Position Updates:**
- Updates are throttled to maintain 60fps
- Binary search ensures fast word lookup
- No position pre-computation needed after tap-to-seek removal

**Fallback Behavior:**
When highlighting data is unavailable (no speech marks or character positions):
- Displays plain scrollable text
- Shows gray status bar: "Highlighting not available for this content"
- Maintains full audio playback functionality
- User can still control playback via standard controls
