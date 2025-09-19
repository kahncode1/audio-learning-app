# Audio Learning App - Content Preprocessing Pipeline
## Complete Documentation & Integration Guide

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Installation & Setup](#installation--setup)
4. [Pipeline Architecture](#pipeline-architecture)
5. [Input/Output Specifications](#inputoutput-specifications)
6. [Usage & Commands](#usage--commands)
7. [Backend Integration](#backend-integration)
8. [Examples & Test Data](#examples--test-data)
9. [Validation & Testing](#validation--testing)
10. [Troubleshooting](#troubleshooting)

---

## Overview

This pipeline converts ElevenLabs TTS character-level timing data into app-compatible word and sentence timing formats with proper paragraph spacing for enhanced readability.

### What It Does
- Converts character timings → word timings
- Detects sentence boundaries using 350ms gaps + punctuation
- Formats text with paragraph spacing (double newlines)
- Generates JSON files compatible with the Flutter app

### Status
✅ **Production Ready** (Validated 2025-09-19)
- All tests passing
- 2,347 words processed correctly in test data
- 116 sentences detected with 350ms threshold
- Character positions accurate

---

## Quick Start

```bash
# 1. Navigate to pipeline directory
cd preprocessing_pipeline

# 2. Run validation to ensure everything works
node validation/validate_pipeline.js

# 3. Process your content
cd scripts
node pipeline_runner.js input.json content.md audio.mp3 \
  --learning-object-id=your-unique-id
```

---

## Installation & Setup

### Prerequisites
- **Node.js 14+** (no npm packages needed - pure Node.js)
- **Directory structure** automatically created by pipeline

### Required Files
```
preprocessing_pipeline/
├── scripts/                        # Core pipeline scripts
│   ├── pipeline_runner.js         # Main orchestrator
│   ├── character_to_word_converter.js
│   ├── sentence_detector.js
│   └── enhanced_content_processor.js
├── validation/                     # Testing tools
│   └── validate_pipeline.js       # Validation script
└── output/                        # Generated files (auto-created)
```

---

## Pipeline Architecture

```
Input Files                 Processing Steps              Output Files
-----------                 ----------------              ------------
ElevenLabs JSON      →     Character to Word      →     timing.json
(character timings)         Conversion

Markdown Content     →     Sentence Detection     →     content.json
(display text)             (350ms gaps + punct)

Audio MP3           →      Content Processing     →     audio.mp3
(TTS output)               (paragraph spacing)         (copied)
```

### Processing Flow
1. **Read** Markdown content
2. **Convert** characters to words using ElevenLabs timing
3. **Detect** sentences using gaps and punctuation
4. **Format** paragraphs with spacing
5. **Generate** timing.json and content.json
6. **Copy** audio file to output

---

## Input/Output Specifications

### Input Requirements

#### 1. ElevenLabs JSON Format
```json
{
  "alignment": {
    "characters": ["T", "h", "e", " ", "o", "b", "j", ...],
    "character_start_times_seconds": [0.0, 0.058, 0.116, ...],
    "character_end_times_seconds": [0.058, 0.116, 0.197, ...]
  }
}
```

#### 2. Markdown Content
- Plain text or Markdown format
- Must match audio content exactly
- No bold/italic formatting (causes position issues)

#### 3. Audio File
- MP3 format from ElevenLabs
- Duration must match timing data

### Output Specifications

#### timing.json Structure
```json
{
  "version": "1.0",
  "totalDurationMs": 957777,
  "words": [{
    "word": "The",
    "startMs": 0,
    "endMs": 197,
    "sentenceIndex": 0,
    "charStart": 0,
    "charEnd": 3
  }],
  "sentences": [{
    "text": "The objective of this lesson...",
    "startMs": 0,
    "endMs": 5190,
    "wordStartIndex": 0,
    "wordEndIndex": 13
  }]
}
```

#### content.json Structure
```json
{
  "version": "1.0",
  "displayText": "Text with\n\nparagraph breaks",
  "paragraphs": ["First paragraph", "Second paragraph"],
  "headers": ["Section Title"],
  "formatting": {
    "boldHeaders": false,
    "paragraphSpacing": true
  },
  "metadata": {
    "wordCount": 2347,
    "characterCount": 15463,
    "estimatedReadingTime": "12 minutes",
    "language": "en"
  }
}
```

---

## Usage & Commands

### Basic Command
```bash
node scripts/pipeline_runner.js <elevenlabs.json> <content.md> <audio.mp3>
```

### With Options
```bash
node scripts/pipeline_runner.js input.json content.md audio.mp3 \
  --output-dir=./output \
  --learning-object-id=63ad7b78-0970-4265-a4fe-51f3fee39d5f \
  --gap-threshold=350
```

### Options
- `--output-dir`: Where to save files (default: `./output/processed`)
- `--learning-object-id`: Unique ID for the learning object
- `--gap-threshold`: Milliseconds for sentence detection (default: 350)

### Test with Sample Data
```bash
cd scripts
node pipeline_runner.js \
  "../../Test_LO_Content/Risk Management and Insurance in Action.json" \
  "../../Test_LO_Content/Risk Management and Insurance in Action.md" \
  "../../Test_LO_Content/Risk Management and Insurance in Action.mp3"
```

---

## Backend Integration

### Express.js Example
```javascript
const express = require('express');
const multer = require('multer');
const { runPipeline } = require('./scripts/pipeline_runner');

const app = express();
const upload = multer({ dest: 'uploads/' });

app.post('/api/learning-objects/process',
  upload.fields([
    { name: 'timing', maxCount: 1 },
    { name: 'content', maxCount: 1 },
    { name: 'audio', maxCount: 1 }
  ]),
  async (req, res) => {
    try {
      const result = await runPipeline({
        elevenLabsJson: req.files.timing[0].path,
        markdownFile: req.files.content[0].path,
        audioFile: req.files.audio[0].path,
        outputDir: './processed',
        learningObjectId: req.body.learning_object_id
      });

      if (result.success) {
        // Upload to CDN and return URLs
        res.json({
          success: true,
          files: result.files
        });
      }
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  }
);
```

### Database Schema
```sql
CREATE TABLE learning_objects (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  content_url TEXT,    -- URL to content.json
  timing_url TEXT,     -- URL to timing.json
  audio_url TEXT,      -- URL to audio.mp3
  duration_ms INTEGER,
  word_count INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### CDN Structure
```
cdn.example.com/
└── learning-objects/
    └── [learning_object_id]/
        ├── content.json
        ├── timing.json
        └── audio.mp3
```

---

## Examples & Test Data

### Simple Example

#### Input: "Hello world. This is a test."
```json
// ElevenLabs JSON
{
  "alignment": {
    "characters": ["H","e","l","l","o"," ","w","o","r","l","d","."],
    "character_start_times_seconds": [0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1],
    "character_end_times_seconds": [0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1.0,1.1,1.2]
  }
}
```

#### Output timing.json:
```json
{
  "words": [
    {"word": "Hello", "startMs": 0, "endMs": 500, "charStart": 0, "charEnd": 5},
    {"word": "world.", "startMs": 600, "endMs": 1200, "charStart": 6, "charEnd": 12}
  ],
  "sentences": [
    {"text": "Hello world.", "startMs": 0, "endMs": 1200, "wordStartIndex": 0, "wordEndIndex": 1}
  ]
}
```

### Production Example
Real test data results:
- **Input**: 15,407 characters, 957.78 seconds audio
- **Output**: 2,347 words, 116 sentences, 57 paragraphs
- **File sizes**: content.json (31.5 KB), timing.json (394.6 KB), audio.mp3 (5.5 MB)

---

## Validation & Testing

### Run Validation Script
```bash
node validation/validate_pipeline.js
```

This script:
1. Checks Node.js version
2. Verifies all scripts exist
3. Runs pipeline with test data
4. Validates output structure
5. Checks data consistency

### Expected Validation Output
```
✅ Node.js version: v14.0.0+
✅ All scripts found
✅ Pipeline executed successfully
✅ timing.json valid (words, sentences, duration)
✅ content.json valid (text, paragraphs, metadata)
✅ Character positions accurate
✅ Word timing continuous
✅ Sentence boundaries valid
```

### Manual Testing Checklist
- [ ] Character positions match display text
- [ ] No overlapping word timings
- [ ] Sentences align with word indices
- [ ] Paragraphs separated by \n\n
- [ ] Total duration matches audio
- [ ] All output files generated

---

## Troubleshooting

### Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| "Character mismatch" | Text doesn't match audio | Ensure content matches ElevenLabs input exactly |
| "Missing timing data" | Wrong JSON format | Check ElevenLabs output has alignment field |
| "No sentences detected" | Short pauses | Adjust --gap-threshold parameter |
| "Large file sizes" | Long content | Consider splitting into smaller segments |

### Debug Mode
```bash
# Enable verbose output
DEBUG=true node scripts/pipeline_runner.js input.json content.md audio.mp3
```

### Error Messages
- `"ElevenLabs JSON file not found"` - Check file path
- `"Character count mismatch"` - Text must match audio exactly
- `"No timing data found"` - Verify ElevenLabs JSON format

### Performance Guidelines
- Processing: ~1-2 seconds per minute of audio
- Memory: ~50MB for 15-minute content
- Output ratios: ~25KB/min for timing.json

---

## Important Notes

1. **NO Bold/Markdown Formatting**: Causes character position misalignment
2. **Exact Text Matching**: Content must match audio character-for-character
3. **CamelCase Fields**: Use startMs not start_ms for Flutter compatibility
4. **350ms Gap Threshold**: Standard for sentence detection
5. **Paragraph Spacing**: Double newlines (\n\n) only

---

## Version History

- **v1.0** (2025-09-19): Initial production release
  - Character to word conversion
  - Sentence detection with gaps
  - Paragraph spacing support
  - No markdown formatting

---

## Support

For issues or questions:
1. Run validation script first
2. Check test data examples
3. Review error messages
4. Verify input formats match specifications

---

**Pipeline Version:** 1.0
**Last Updated:** 2025-09-19
**Status:** Production Ready