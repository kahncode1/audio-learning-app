# ElevenLabs Audio Content Preprocessing Pipeline

## Overview

Converts ElevenLabs TTS output with character-level timing data into an optimized JSON format for the Audio Learning App's dual-level word and sentence highlighting system with O(1) lookup performance.

## Key Features

- **Character-to-Word Conversion**: Transforms character arrays into word-level timing
- **Intelligent Sentence Detection**: Handles abbreviations, lists, quotes, and edge cases
- **Continuous Coverage**: Eliminates timing gaps for smooth highlighting
- **O(1) Lookup Tables**: Generates position lookup tables for instant 60fps performance
- **Paragraph Preservation**: Maintains original text formatting
- **Snake_case Output**: Matches Flutter app field expectations
- **Configurable Processing**: Customizable via config.json
- **Supabase Integration**: Direct upload to database with embedded lookup tables

## Quick Start

```bash
# Basic preprocessing
python process_elevenlabs_complete.py input.json

# With output path
python process_elevenlabs_complete.py input.json -o output.json

# With original content for formatting
python process_elevenlabs_complete.py input.json -c original.json -o output.json

# Upload to Supabase with embedded lookup table
python upload_to_supabase.py output.json \
  --id <learning-object-id> \
  --assignment-id <assignment-id> \
  --title "Learning Object Title" \
  --audio-file audio.mp3
```

## Documentation

- [**Complete Usage Guide**](USAGE.md) - Installation, configuration, edge cases, troubleshooting
- [**JSON Schema Reference**](SCHEMA.md) - Output format specification and field definitions

## Project Structure

```
preprocessing_pipeline/
├── process_elevenlabs_complete.py  # Main processing script
├── upload_to_supabase.py          # Database upload with lookup tables
├── edge_case_handlers.py          # Enhanced sentence detection
├── config.json                    # Processing configuration
├── abbreviations.json             # Abbreviation database (500+ entries)
├── tests/                         # Test scripts and data
│   ├── test_edge_case_handling.py # Edge case tests
│   ├── test_lookup_generation.py  # Lookup table tests
│   └── data/                      # Test data files
└── Test_LO_Content/               # Production test content
```

## Input/Output

**Input**: ElevenLabs JSON with character-level timing
```json
{
  "alignment": {
    "characters": ["T", "h", "e", " ", ...],
    "character_start_times_seconds": [0.0, 0.058, ...],
    "character_end_times_seconds": [0.058, 0.093, ...]
  }
}
```

**Output**: Enhanced content JSON with word/sentence timing and O(1) lookup table
```json
{
  "version": "1.0",
  "display_text": "Full text with paragraph breaks",
  "timing": {
    "words": [{"word": "The", "start_ms": 0, "end_ms": 116, ...}],
    "sentences": [{"text": "The objective...", "start_ms": 0, ...}],
    "total_duration_ms": 95764,
    "lookup_table": {
      "version": "1.0",
      "interval": 10,
      "totalDurationMs": 95764,
      "lookup": [[0, 0], [0, 0], ...]  // Word & sentence indices at each 10ms
    }
  }
}
```

## Requirements

- Python 3.7+
- No external dependencies for preprocessing (uses standard library only)
- For Supabase upload: `pip install supabase python-dotenv dio`

## License

Part of the Audio Learning App project