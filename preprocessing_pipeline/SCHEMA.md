# Content JSON Schema Documentation

## Version 1.0

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

## Field Details

### Root Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Schema version identifier, currently "1.0" |
| `source` | string | Yes | Pipeline identifier, "elevenlabs-complete" for this processor |
| `displayText` | string | Yes | Complete text with newline characters preserving paragraph breaks |
| `paragraphs` | string[] | Yes | Array of paragraph strings for structured display |
| `headers` | string[] | Yes | Detected section headers (may be empty array) |
| `formatting` | object | Yes | Display preferences object |
| `metadata` | object | Yes | Content statistics and information |
| `timing` | object | Yes | Audio synchronization data |

### Formatting Object

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `boldHeaders` | boolean | false | Whether to bold detected headers |
| `paragraphSpacing` | boolean | true | Whether to add spacing between paragraphs |

### Metadata Object

| Field | Type | Description |
|-------|------|-------------|
| `wordCount` | number | Total number of words in content |
| `characterCount` | number | Total character count including spaces |
| `estimatedReadingTime` | string | Human-readable duration (e.g., "11 minutes") |
| `language` | string | ISO 639-1 language code (e.g., "en") |

### Timing Object

| Field | Type | Description |
|-------|------|-------------|
| `words` | WordTiming[] | Array of word timing objects |
| `sentences` | SentenceTiming[] | Array of sentence timing objects |
| `totalDurationMs` | number | Total audio duration in milliseconds |

### WordTiming Object

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `word` | string | - | The word text (no leading/trailing spaces) |
| `start_ms` | number | ≥ 0 | Word start time in milliseconds |
| `end_ms` | number | > start_ms | Word end time in milliseconds |
| `char_start` | number | ≥ 0 | Starting character index in original text |
| `char_end` | number | ≥ char_start | Ending character index in original text |
| `sentence_index` | number | ≥ 0 | Index of sentence containing this word |

### SentenceTiming Object

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `text` | string | - | Complete sentence text |
| `start_ms` | number | ≥ 0 | Sentence start (may extend before first word) |
| `end_ms` | number | > start_ms | Sentence end (may extend after last word) |
| `sentence_index` | number | ≥ 0 | Unique sentence identifier |
| `wordStartIndex` | number | ≥ 0 | Index of first word in words array |
| `wordEndIndex` | number | ≥ wordStartIndex | Index of last word in words array |
| `char_start` | number | ≥ 0 | Starting character index |
| `char_end` | number | ≥ char_start | Ending character index |

## Important Constraints

### Timing Continuity
- Sentences MUST have continuous coverage with no gaps
- Adjacent sentences share boundaries at their midpoint
- Every millisecond from 0 to totalDurationMs is covered by exactly one sentence

### Word-Sentence Relationship
- Every word MUST have a valid sentence_index
- Words are ordered chronologically by start_ms
- Words within a sentence are contiguous in the array

### Field Naming Convention
- ALL timing fields use snake_case (not camelCase)
- This matches Flutter app's JSON parsing expectations

### Character Indices
- Character indices refer to positions in the reconstructed text
- Indices are 0-based
- Include all characters (letters, spaces, punctuation)

## Example Snippet

```json
{
  "version": "1.0",
  "source": "elevenlabs-complete",
  "displayText": "The objective of this lesson is to illustrate.\nLet's begin.",
  "paragraphs": [
    "The objective of this lesson is to illustrate.",
    "Let's begin."
  ],
  "headers": [],
  "formatting": {
    "boldHeaders": false,
    "paragraphSpacing": true
  },
  "metadata": {
    "wordCount": 10,
    "characterCount": 60,
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
      },
      {
        "word": "objective",
        "start_ms": 116,
        "end_ms": 627,
        "char_start": 4,
        "char_end": 13,
        "sentence_index": 0
      }
    ],
    "sentences": [
      {
        "text": "The objective of this lesson is to illustrate.",
        "start_ms": 0,
        "end_ms": 2500,
        "sentence_index": 0,
        "wordStartIndex": 0,
        "wordEndIndex": 7,
        "char_start": 0,
        "char_end": 47
      },
      {
        "text": "Let's begin.",
        "start_ms": 2500,
        "end_ms": 4000,
        "sentence_index": 1,
        "wordStartIndex": 8,
        "wordEndIndex": 9,
        "char_start": 48,
        "char_end": 60
      }
    ],
    "totalDurationMs": 4000
  }
}
```

## Validation Rules

1. **No negative times**: All _ms fields must be ≥ 0
2. **Chronological order**: Words and sentences must be ordered by start_ms
3. **Valid indices**: All array indices must be within bounds
4. **Complete coverage**: No timing gaps between sentences
5. **Non-empty text**: All text fields must contain content
6. **Consistent counts**: wordCount must match actual word array length