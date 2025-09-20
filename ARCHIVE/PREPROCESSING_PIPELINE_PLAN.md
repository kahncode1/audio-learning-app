# External Preprocessing Pipeline Development Plan

## Overview
Create a standalone, external preprocessing pipeline to transform ElevenLabs character timing data into app-compatible formats. This pipeline will be completely separate from the app codebase and designed for external use.

## Current State Analysis
- **Test files provided**: MP3 audio (5.7MB), character timing JSON (625KB), text Markdown (15KB)
- **ElevenLabs format**: Character-level timings in `character_start_times_seconds` array with matching `characters` array
- **App requires**: Word-level timings with sentence boundaries matching WordTiming model schema

## Key Transformations Required

### 1. Character-to-Word Conversion Algorithm
- Parse ElevenLabs `character_start_times_seconds` (float array) and `characters` (string array)
- Group characters into words by detecting whitespace boundaries
- Calculate word start time: first character's timestamp
- Calculate word end time: last character's timestamp (or next word's start)
- Map character positions to display text positions (char_start, char_end)
- Handle edge cases: punctuation attachment, hyphenated words, contractions

### 2. Sentence Detection Algorithm
- Implement sentence boundary detection using:
  - **Punctuation detection**: periods, exclamation marks, question marks
  - **Timing gap heuristic**: 350ms pause between sentences (configurable)
  - **Abbreviation protection**: Handle "Mr.", "Dr.", "Inc.", etc. to prevent false breaks
- Assign sequential sentence indices to each word (0, 1, 2, ...)
- Calculate sentence boundaries (start/end times, word index ranges)

### 3. Schema Generation Requirements

#### Content JSON Schema (content.json)
```json
{
  "version": "1.0",
  "displayText": "Full text for highlighting widget",
  "paragraphs": ["Paragraph 1", "Paragraph 2", ...],
  "metadata": {
    "wordCount": 1234,
    "characterCount": 6789,
    "estimatedReadingTime": "5 minutes",
    "language": "en"
  }
}
```

#### Timing JSON Schema (timing.json)
```json
{
  "version": "1.0",
  "words": [
    {
      "word": "Hello",
      "startMs": 1000,
      "endMs": 1500,
      "charStart": 0,
      "charEnd": 5
    }
  ],
  "sentences": [
    {
      "text": "Hello world.",
      "startMs": 1000,
      "endMs": 2000,
      "wordStartIndex": 0,
      "wordEndIndex": 1,
      "charStart": 0,
      "charEnd": 12
    }
  ],
  "totalDurationMs": 26300
}
```

## Implementation Structure

### 1. External Pipeline Folder Structure
```
preprocessing_pipeline/
├── scripts/
│   ├── character_to_word_converter.js
│   ├── sentence_detector.js
│   ├── content_processor.js
│   └── pipeline_runner.js
├── examples/
│   ├── input_sample.json
│   └── output_samples/
├── output/
│   └── processed_content/
├── validation/
│   ├── schema_validator.js
│   └── app_compatibility_test.js
└── documentation/
    ├── PREPROCESSING_GUIDE.md
    └── TROUBLESHOOTING.md
```

### 2. Core Processing Scripts

#### Character-to-Word Converter
- **Input**: ElevenLabs `{characters: [...], character_start_times_seconds: [...]}`
- **Output**: Word array with timing data
- **Algorithm**:
  1. Iterate through character array
  2. Detect word boundaries (whitespace, punctuation rules)
  3. Group characters into words with start/end times
  4. Calculate character positions in display text
  5. Handle special cases (contractions, hyphenated words)

#### Sentence Detector
- **Input**: Word array from converter
- **Output**: Sentence array with boundaries
- **Algorithm**:
  1. Scan for sentence-ending punctuation
  2. Apply 350ms timing gap heuristic
  3. Check abbreviation exceptions
  4. Assign sentence indices to words
  5. Calculate sentence start/end times and word ranges

#### Content Processor
- **Input**: Markdown text file
- **Output**: Structured content.json
- **Features**:
  1. Convert Markdown to plain text for displayText
  2. Split into logical paragraphs
  3. Calculate metadata (word count, character count)
  4. Estimate reading time (200 WPM average)

### 3. Testing & Validation Process

#### Phase A: Process Test Content
1. Run your ElevenLabs JSON through character-to-word converter
2. Apply sentence detection with 350ms threshold
3. Generate content.json from your Markdown file
4. Create timing.json with both word and sentence data

#### Phase B: App Compatibility Testing
1. Place generated files in app's test content structure
2. Test with existing LocalContentService.getContent()
3. Verify WordTiming.fromJson() compatibility
4. Test dual-level highlighting with SimplifiedDualLevelHighlightedText
5. Validate performance (JSON load <100ms, highlighting at 60fps)

#### Phase C: Validation Metrics
- **Word accuracy**: 100% of words correctly timed
- **Sentence accuracy**: All sentence boundaries detected
- **Timing precision**: ±50ms alignment with audio
- **Schema compliance**: Valid JSON matching app requirements
- **Performance**: Processed files load <100ms in app

## Detailed Processing Algorithms

### Character-to-Word Algorithm Details

```javascript
function convertCharactersToWords(characters, timings) {
  const words = [];
  let currentWord = '';
  let wordStartTime = 0;
  let wordStartCharIndex = 0;

  for (let i = 0; i < characters.length; i++) {
    const char = characters[i];
    const time = timings[i] * 1000; // Convert to milliseconds

    if (char === ' ' || char === '\t' || char === '\n') {
      // End current word if it exists
      if (currentWord.length > 0) {
        words.push({
          word: currentWord,
          startMs: Math.round(wordStartTime),
          endMs: Math.round(time),
          charStart: wordStartCharIndex,
          charEnd: wordStartCharIndex + currentWord.length
        });
        currentWord = '';
      }
      // Skip whitespace for next word start
      while (i + 1 < characters.length && isWhitespace(characters[i + 1])) {
        i++;
      }
      if (i + 1 < characters.length) {
        wordStartTime = timings[i + 1] * 1000;
        wordStartCharIndex = i + 1;
      }
    } else {
      // Add character to current word
      if (currentWord.length === 0) {
        wordStartTime = time;
        wordStartCharIndex = i;
      }
      currentWord += char;
    }
  }

  // Handle final word
  if (currentWord.length > 0) {
    words.push({
      word: currentWord,
      startMs: Math.round(wordStartTime),
      endMs: Math.round(timings[timings.length - 1] * 1000),
      charStart: wordStartCharIndex,
      charEnd: wordStartCharIndex + currentWord.length
    });
  }

  return words;
}
```

### Sentence Detection Algorithm Details

```javascript
const ABBREVIATIONS = ['Mr', 'Mrs', 'Dr', 'Prof', 'Inc', 'Corp', 'Ltd'];
const SENTENCE_ENDINGS = ['.', '!', '?'];
const SENTENCE_GAP_THRESHOLD_MS = 350;

function detectSentences(words) {
  const sentences = [];
  let currentSentence = {
    words: [],
    text: '',
    startMs: 0,
    endMs: 0,
    wordStartIndex: 0,
    charStart: 0
  };

  for (let i = 0; i < words.length; i++) {
    const word = words[i];

    if (currentSentence.words.length === 0) {
      // Start new sentence
      currentSentence.startMs = word.startMs;
      currentSentence.wordStartIndex = i;
      currentSentence.charStart = word.charStart;
    }

    currentSentence.words.push(word);
    currentSentence.text += (currentSentence.text ? ' ' : '') + word.word;

    // Check for sentence ending
    const endsWithPunctuation = SENTENCE_ENDINGS.some(p => word.word.endsWith(p));
    const nextWordGap = i < words.length - 1 ?
      words[i + 1].startMs - word.endMs : 0;

    if (endsWithPunctuation && !isAbbreviation(word.word)) {
      if (nextWordGap >= SENTENCE_GAP_THRESHOLD_MS || i === words.length - 1) {
        // End current sentence
        currentSentence.endMs = word.endMs;
        currentSentence.wordEndIndex = i;
        currentSentence.charEnd = word.charEnd;

        sentences.push({...currentSentence});

        // Reset for next sentence
        currentSentence = {
          words: [],
          text: '',
          startMs: 0,
          endMs: 0,
          wordStartIndex: 0,
          charStart: 0
        };
      }
    }
  }

  // Handle final sentence if not closed
  if (currentSentence.words.length > 0) {
    const lastWord = currentSentence.words[currentSentence.words.length - 1];
    currentSentence.endMs = lastWord.endMs;
    currentSentence.wordEndIndex = currentSentence.wordStartIndex + currentSentence.words.length - 1;
    currentSentence.charEnd = lastWord.charEnd;
    sentences.push(currentSentence);
  }

  return sentences;
}
```

### Content Processing Algorithm

```javascript
function processMarkdownContent(markdownText) {
  // Convert Markdown to plain text
  const displayText = markdownText
    .replace(/^#+\s+/gm, '') // Remove headers
    .replace(/\*\*(.*?)\*\*/g, '$1') // Remove bold
    .replace(/\*(.*?)\*/g, '$1') // Remove italics
    .replace(/\[(.*?)\]\(.*?\)/g, '$1') // Remove links, keep text
    .replace(/\n\s*\n/g, '\n') // Normalize line breaks
    .trim();

  // Split into paragraphs
  const paragraphs = displayText
    .split('\n')
    .map(p => p.trim())
    .filter(p => p.length > 0);

  // Calculate metadata
  const wordCount = displayText.split(/\s+/).length;
  const characterCount = displayText.length;
  const readingTimeMinutes = Math.ceil(wordCount / 200); // 200 WPM

  return {
    version: "1.0",
    displayText,
    paragraphs,
    metadata: {
      wordCount,
      characterCount,
      estimatedReadingTime: `${readingTimeMinutes} minute${readingTimeMinutes !== 1 ? 's' : ''}`,
      language: "en"
    }
  };
}
```

## Configuration Options

### Configurable Parameters
```javascript
const CONFIG = {
  // Sentence detection
  sentenceGapThresholdMs: 350,
  abbreviations: ['Mr', 'Mrs', 'Dr', 'Prof', 'Inc', 'Corp', 'Ltd'],
  sentenceEndings: ['.', '!', '?'],

  // Content processing
  readingSpeedWPM: 200,
  language: 'en',

  // Validation
  maxTimingGapMs: 1000,
  minWordDurationMs: 50,
  maxWordDurationMs: 5000
};
```

### Quality Validation Rules
1. **Timing validation**: No gaps > 1 second between consecutive words
2. **Word validation**: All words have reasonable duration (50ms - 5s)
3. **Sentence validation**: No empty sentences, proper word index ranges
4. **Schema validation**: All required fields present, correct data types
5. **Character alignment**: char_start/char_end positions match display text

## Testing Procedures

### Step 1: Basic Processing Test
```bash
node pipeline_runner.js --input "Test_LO_Content/Risk Management and Insurance in Action.json" --markdown "Test_LO_Content/Risk Management and Insurance in Action.md" --output "output/processed/"
```

### Step 2: Schema Validation
```bash
node validation/schema_validator.js output/processed/content.json
node validation/schema_validator.js output/processed/timing.json
```

### Step 3: App Integration Test
1. Copy generated files to app test structure
2. Run app's LocalContentService validation
3. Test highlighting functionality
4. Measure performance metrics

### Expected Output Files

#### Generated content.json (example)
```json
{
  "version": "1.0",
  "displayText": "The objective of this lesson is to illustrate how insurance facilitates key societal activities. Let's begin...",
  "paragraphs": [
    "The objective of this lesson is to illustrate how insurance facilitates key societal activities.",
    "Let's begin.",
    "Insurance is a vital component of an individual's or organization's approach to managing risk..."
  ],
  "metadata": {
    "wordCount": 2847,
    "characterCount": 15427,
    "estimatedReadingTime": "15 minutes",
    "language": "en"
  }
}
```

#### Generated timing.json (example)
```json
{
  "version": "1.0",
  "words": [
    {"word": "The", "startMs": 0, "endMs": 104, "charStart": 0, "charEnd": 3},
    {"word": "objective", "startMs": 104, "endMs": 221, "charStart": 4, "charEnd": 13},
    {"word": "of", "startMs": 221, "endMs": 267, "charStart": 14, "charEnd": 16}
  ],
  "sentences": [
    {
      "text": "The objective of this lesson is to illustrate how insurance facilitates key societal activities.",
      "startMs": 0,
      "endMs": 3250,
      "wordStartIndex": 0,
      "wordEndIndex": 12,
      "charStart": 0,
      "charEnd": 95
    }
  ],
  "totalDurationMs": 890000
}
```

## Success Criteria

### Technical Requirements
- ✅ Characters converted to words with 100% accuracy
- ✅ Sentence boundaries detected using 350ms + punctuation
- ✅ JSON output matches app schema exactly
- ✅ Character position mapping aligns with display text
- ✅ Performance: Generated files load in <100ms

### App Integration Requirements
- ✅ LocalContentService can load generated files
- ✅ WordTiming.fromJson() parses timing data correctly
- ✅ Dual-level highlighting works at 60fps
- ✅ Audio playback syncs with timing data (±50ms accuracy)
- ✅ No app code changes required

### Pipeline Requirements
- ✅ Completely external to app codebase
- ✅ Reusable for future content
- ✅ Configurable parameters
- ✅ Comprehensive validation
- ✅ Complete documentation

This external preprocessing pipeline will transform ElevenLabs character timing data into perfectly app-compatible formats while remaining completely separate from the app codebase.