# Content JSON Schema Documentation

## Version 2.1

This document defines the JSON schema for preprocessed audio learning content with synchronized timing data.

## Complete Schema

```typescript
interface ContentJSON {
  // Schema version
  version: "1.0";

  // Source identifier
  source: "elevenlabs-complete";

  // Full text with paragraph breaks (\n)
  display_text: string;

  // Array of paragraph strings
  paragraphs: string[];

  // Detected section headers
  headers: string[];

  // Display formatting preferences
  formatting: {
    bold_headers: boolean;
    paragraph_spacing: boolean;
  };

  // Content metadata
  metadata: {
    word_count: number;
    character_count: number;
    estimated_reading_time: string;  // e.g., "11 minutes"
    language: string;                // ISO 639-1 code
  };

  // Timing synchronization data
  timing: {
    words: WordTiming[];
    sentences: SentenceTiming[];
    total_duration_ms: number;
    lookup_table?: LookupTable;  // O(1) position lookup (embedded)
  };
}

interface WordTiming {
  word: string;           // The word text
  start_ms: number;       // Start time in milliseconds
  end_ms: number;         // End time in milliseconds
  char_start: number;     // Character position in original text
  char_end: number;       // Character end position
  sentence_index: number; // Sentence this word belongs to (0-based)
}

interface SentenceTiming {
  text: string;              // Full sentence text
  start_ms: number;          // Start time (extended for coverage)
  end_ms: number;            // End time (extended for coverage)
  sentence_index: number;    // Unique sentence ID (0-based)
  word_start_index: number;  // First word index in words array
  word_end_index: number;    // Last word index in words array
  char_start: number;        // Character position in text
  char_end: number;          // Character end position
}

interface LookupTable {
  version: string;           // Schema version (e.g., "1.0")
  interval: number;          // Time interval in ms (typically 10)
  totalDurationMs: number;   // Total duration covered
  lookup: Array<[number, number]>;  // [word_index, sentence_index] pairs
}
```

## Field Specifications

### Root Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Schema version identifier, currently "1.0" |
| `source` | string | Yes | Pipeline identifier, "elevenlabs-complete" |
| `display_text` | string | Yes | Complete text with newline characters for paragraphs |
| `paragraphs` | string[] | Yes | Array of paragraph strings |
| `headers` | string[] | Yes | Detected section headers (may be empty) |
| `formatting` | object | Yes | Display preferences |
| `metadata` | object | Yes | Content statistics |
| `timing` | object | Yes | Audio synchronization data |

### Formatting Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `bold_headers` | boolean | false | Whether to bold headers |
| `paragraph_spacing` | boolean | true | Add spacing between paragraphs |

### Metadata Object

| Field | Type | Description |
|-------|------|-------------|
| `word_count` | number | Total number of words |
| `character_count` | number | Total characters including spaces |
| `estimated_reading_time` | string | Human-readable duration |
| `language` | string | ISO 639-1 language code |

### Timing Object

| Field | Type | Description |
|-------|------|-------------|
| `words` | WordTiming[] | Array of word timing objects |
| `sentences` | SentenceTiming[] | Array of sentence timing objects |
| `total_duration_ms` | number | Total audio duration in milliseconds |
| `lookup_table` | LookupTable | O(1) lookup table for position queries (optional, embedded) |

### WordTiming Object

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `word` | string | - | Word text (no whitespace) |
| `start_ms` | number | ≥ 0 | Start time in milliseconds |
| `end_ms` | number | > start_ms | End time in milliseconds |
| `char_start` | number | ≥ 0 | Starting character index |
| `char_end` | number | ≥ char_start | Ending character index |
| `sentence_index` | number | ≥ 0 | Parent sentence index |

### SentenceTiming Object

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `text` | string | - | Complete sentence text |
| `start_ms` | number | ≥ 0 | Start time (extended for coverage) |
| `end_ms` | number | > start_ms | End time (extended for coverage) |
| `sentence_index` | number | ≥ 0 | Unique sentence identifier |
| `word_start_index` | number | ≥ 0 | First word index |
| `word_end_index` | number | ≥ word_start_index | Last word index |
| `char_start` | number | ≥ 0 | Starting character index |
| `char_end` | number | ≥ char_start | Ending character index |

### LookupTable Object

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Lookup table schema version (e.g., "1.0") |
| `interval` | number | Time interval between entries in ms (typically 10) |
| `totalDurationMs` | number | Total duration covered by lookup table |
| `lookup` | Array<[number, number]> | Array of [word_index, sentence_index] pairs for O(1) lookup |

## Validation Rules

1. **Timing Constraints**
   - All `*_ms` fields must be non-negative
   - `end_ms` must be greater than `start_ms`
   - Words and sentences ordered chronologically

2. **Continuous Coverage**
   - No gaps between adjacent sentences
   - Every millisecond covered by exactly one sentence
   - Sentence boundaries meet at midpoints

3. **Index Constraints**
   - All array indices must be within bounds
   - Every word must have valid `sentence_index`
   - Words within sentence must be contiguous

4. **Field Naming**
   - ALL timing fields use snake_case
   - Matches Flutter app JSON parsing

5. **Content Rules**
   - No empty text fields
   - `word_count` matches words array length
   - Character indices are 0-based

6. **Lookup Table Rules** (when present)
   - Lookup array length = ceil(total_duration_ms / interval) + 1
   - Each entry is [word_index, sentence_index] where indices are -1 if no word/sentence at that time
   - Provides O(1) time complexity for position queries

## Example

```json
{
  "version": "1.0",
  "source": "elevenlabs-complete",
  "display_text": "The objective is clear.\nLet's begin.",
  "paragraphs": [
    "The objective is clear.",
    "Let's begin."
  ],
  "headers": [],
  "formatting": {
    "bold_headers": false,
    "paragraph_spacing": true
  },
  "metadata": {
    "word_count": 6,
    "character_count": 36,
    "estimated_reading_time": "1 minute",
    "language": "en"
  },
  "timing": {
    "words": [
      {
        "word": "The",
        "start_ms": 0,
        "end_ms": 116,
        "char_start": 0,
        "char_end": 3,
        "sentence_index": 0
      }
    ],
    "sentences": [
      {
        "text": "The objective is clear.",
        "start_ms": 0,
        "end_ms": 1500,
        "sentence_index": 0,
        "word_start_index": 0,
        "word_end_index": 3,
        "char_start": 0,
        "char_end": 23
      }
    ],
    "total_duration_ms": 3000,
    "lookup_table": {
      "version": "1.0",
      "interval": 10,
      "totalDurationMs": 3000,
      "lookup": [
        [0, 0], [0, 0], [0, 0], [0, 0], [0, 0],  // 0-40ms: word 0, sentence 0
        [1, 0], [1, 0], [1, 0], [1, 0], [1, 0],  // 50-90ms: word 1, sentence 0
        // ... continues for full duration
      ]
    }
  }
}
```

## Flutter Integration

The schema matches Flutter's JSON parsing expectations:

```dart
factory WordTiming.fromJson(Map<String, dynamic> json) {
  return WordTiming(
    word: json['word'] as String,
    startMs: json['start_ms'] as int,        // snake_case
    endMs: json['end_ms'] as int,            // snake_case
    sentenceIndex: json['sentence_index'] as int? ?? 0,
    charStart: json['char_start'] as int?,
    charEnd: json['char_end'] as int?,
  );
}
```

## Notes

- The preprocessing handles complex text formatting including lists, abbreviations, quotations, and mathematical expressions
- Sentence detection is configurable via `config.json`
- See [Usage Guide](USAGE.md) for configuration options