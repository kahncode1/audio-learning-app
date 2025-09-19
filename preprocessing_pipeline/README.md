# Audio Learning App - Content Preprocessing Pipeline

## ✅ Production Ready

Converts ElevenLabs TTS character-level timing into app-compatible word/sentence formats with paragraph spacing.

## 📁 Structure

```
preprocessing_pipeline/
├── README.md                         # This file
├── documentation/
│   └── COMPLETE_PIPELINE_GUIDE.md  # All documentation
├── scripts/                         # Core pipeline scripts
│   ├── pipeline_runner.js          # Main entry point
│   ├── character_to_word_converter.js
│   ├── sentence_detector.js
│   └── enhanced_content_processor.js
└── validation/
    └── validate_pipeline.js        # Testing script
```

## 🚀 Quick Start

```bash
# Test the pipeline
cd preprocessing_pipeline
node validation/validate_pipeline.js

# Process content
node scripts/pipeline_runner.js input.json content.md audio.mp3 \
  --learning-object-id=unique-id
```

## 📊 Test Results

✅ Validated with 15-minute test content:
- 2,347 words processed
- 116 sentences detected
- 57 paragraphs formatted
- Character positions accurate

## 📚 Documentation

**See `documentation/COMPLETE_PIPELINE_GUIDE.md` for:**
- Complete technical specifications
- Backend integration examples
- Input/output formats
- API implementation guide
- Troubleshooting

## ⚠️ Key Requirements

- Node.js 14+ (no npm packages)
- Exact text/audio matching
- 350ms sentence gap threshold
- No bold/markdown formatting
- CamelCase field names

---

**Version:** 1.0 | **Updated:** 2025-09-19