# Preprocessing Pipeline

This directory contains scripts for preprocessing audio content with ElevenLabs timing data.

## Directory Structure

```
preprocessing_pipeline/
├── scripts/           # Processing scripts and configuration
│   ├── process_elevenlabs_complete_with_paragraphs.py  # Main processing script
│   ├── edge_case_handlers.py                           # Edge case handling
│   ├── upload_to_supabase.py                          # Upload to Supabase
│   └── config files (.json)                           # Configuration files
├── docs/             # Documentation
│   ├── README.md     # Main documentation
│   ├── SCHEMA.md     # JSON schema documentation
│   └── USAGE.md      # Usage instructions
├── tests/            # Test content and data
├── processed/        # Processed output files (gitignored)
└── output/           # Temporary test outputs (gitignored)
```

## Quick Start

Use the main processing script for all content:

```bash
cd scripts
python3 process_elevenlabs_complete_with_paragraphs.py \
    input.json \
    -c original.md \
    -o ../processed/output.json
```

This single script handles:
- ✅ Word and sentence timing extraction
- ✅ Edge case handling (abbreviations, lists, etc.)
- ✅ Paragraph preservation with proper spacing
- ✅ Character position accuracy for highlighting

## Key Features

- **Paragraph Formatting**: Preserves original paragraph structure with `\n\n` spacing
- **Edge Case Handling**: Comprehensive handling of abbreviations, lists, quotes, etc.
- **Character Accuracy**: Maintains exact character positions for highlighting system
- **O(1) Lookup**: Generates efficient lookup tables for real-time performance

## Documentation

- See `docs/USAGE.md` for detailed usage instructions
- See `docs/SCHEMA.md` for JSON output schema
- See `docs/UPLOAD_GUIDE.md` for Supabase upload instructions