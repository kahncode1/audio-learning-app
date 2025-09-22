# ElevenLabs Audio Content Preprocessing Pipeline

## Overview

Converts ElevenLabs TTS output with character-level timing data into an optimized JSON format for the Audio Learning App's dual-level word and sentence highlighting system.

## Key Features

- **Character-to-Word Conversion**: Transforms character arrays into word-level timing
- **Intelligent Sentence Detection**: Handles abbreviations, lists, quotes, and edge cases
- **Continuous Coverage**: Eliminates timing gaps for smooth highlighting
- **Paragraph Preservation**: Maintains original text formatting
- **Snake_case Output**: Matches Flutter app field expectations
- **Configurable Processing**: Customizable via config.json

## Quick Start

```bash
# Basic usage
python process_elevenlabs_complete.py input.json

# With output path
python process_elevenlabs_complete.py input.json -o output.json

# With original content for formatting
python process_elevenlabs_complete.py input.json -c original.json -o output.json
```

## Documentation

- [**Complete Usage Guide**](USAGE.md) - Installation, configuration, edge cases, troubleshooting
- [**JSON Schema Reference**](SCHEMA.md) - Output format specification and field definitions

## Project Structure

```
preprocessing_pipeline/
├── process_elevenlabs_complete.py  # Main processing script
├── edge_case_handlers.py          # Enhanced sentence detection
├── config.json                    # Processing configuration
├── abbreviations.json             # Abbreviation database (500+ entries)
├── test_edge_case_handling.py     # Test suite
└── tests/                         # Test data and examples
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

**Output**: Enhanced content JSON with word/sentence timing
```json
{
  "version": "1.0",
  "displayText": "Full text with paragraph breaks",
  "timing": {
    "words": [{"word": "The", "start_ms": 0, "end_ms": 116, ...}],
    "sentences": [{"text": "The objective...", "start_ms": 0, ...}]
  }
}
```

## Requirements

- Python 3.7+
- No external dependencies (uses standard library only)

## License

Part of the Audio Learning App project