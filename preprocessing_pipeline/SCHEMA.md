# Content JSON Schema Documentation

## Version 2.0

This document defines the JSON schema for preprocessed audio learning content with synchronized timing data.

## Complete Schema

```typescript
interface ContentJSON {
  // Schema version
  version: "1.0";

  // Source identifier
  source: "elevenlabs-complete";

  // Full text with paragraph breaks (\n)
  displayText: string;

  // Array of paragraph strings
  paragraphs: string[];

  // Detected section headers
  headers: string[];

  // Display formatting preferences
  formatting: {
    boldHeaders: boolean;
    paragraphSpacing: boolean;
  };

  // Content metadata
  metadata: {
    wordCount: number;
    characterCount: number;
    estimatedReadingTime: string;  // e.g., "11 minutes"
    language: string;               // ISO 639-1 code
  };

  // Timing synchronization data
  timing: {
    words: WordTiming[];
    sentences: SentenceTiming[];
    totalDurationMs: number;
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
  wordStartIndex: number;    // First word index in words array
  wordEndIndex: number;      // Last word index in words array
  char_start: number;        // Character position in text
  char_end: number;          // Character end position
}
```

## Field Specifications

### Root Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Schema version identifier, currently "1.0" |
| `source` | string | Yes | Pipeline identifier, "elevenlabs-complete" |
| `displayText` | string | Yes | Complete text with newline characters for paragraphs |
| `paragraphs` | string[] | Yes | Array of paragraph strings |
| `headers` | string[] | Yes | Detected section headers (may be empty) |
| `formatting` | object | Yes | Display preferences |
| `metadata` | object | Yes | Content statistics |
| `timing` | object | Yes | Audio synchronization data |

### Formatting Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `boldHeaders` | boolean | false | Whether to bold headers |
| `paragraphSpacing` | boolean | true | Add spacing between paragraphs |

### Metadata Object

| Field | Type | Description |
|-------|------|-------------|
| `wordCount` | number | Total number of words |
| `characterCount` | number | Total characters including spaces |
| `estimatedReadingTime` | string | Human-readable duration |
| `language` | string | ISO 639-1 language code |

### Timing Object

| Field | Type | Description |
|-------|------|-------------|
| `words` | WordTiming[] | Array of word timing objects |
| `sentences` | SentenceTiming[] | Array of sentence timing objects |
| `totalDurationMs` | number | Total audio duration in milliseconds |

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
| `wordStartIndex` | number | ≥ 0 | First word index |
| `wordEndIndex` | number | ≥ wordStartIndex | Last word index |
| `char_start` | number | ≥ 0 | Starting character index |
| `char_end` | number | ≥ char_start | Ending character index |

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
   - `wordCount` matches words array length
   - Character indices are 0-based

## Example

```json
{
  "version": "1.0",
  "source": "elevenlabs-complete",
  "displayText": "The objective is clear.\nLet's begin.",
  "paragraphs": [
    "The objective is clear.",
    "Let's begin."
  ],
  "headers": [],
  "formatting": {
    "boldHeaders": false,
    "paragraphSpacing": true
  },
  "metadata": {
    "wordCount": 6,
    "characterCount": 36,
    "estimatedReadingTime": "1 minute",
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
        "wordStartIndex": 0,
        "wordEndIndex": 3,
        "char_start": 0,
        "char_end": 23
      }
    ],
    "totalDurationMs": 3000
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