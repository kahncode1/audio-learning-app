# Preprocessing Pipeline Usage Guide

## Installation & Requirements

### Prerequisites
- Python 3.7+
- For preprocessing: No external dependencies (uses standard library only)
- For Supabase upload: `pip install supabase python-dotenv`
- ElevenLabs TTS output JSON file with character timing
- (Optional) Original content JSON for formatting preservation

### File Setup
Ensure these files are in the `preprocessing_pipeline` directory:
- `process_elevenlabs_complete.py` - Main script with O(1) lookup generation
- `upload_to_supabase.py` - Database upload with embedded lookup tables
- `edge_case_handlers.py` - Edge case detection module
- `config.json` - Configuration settings
- `abbreviations.json` - Abbreviation database

## Basic Usage

### Simple Processing
```bash
python process_elevenlabs_complete.py input.json
```
Creates `input_enhanced.json` in the same directory.

### Custom Output Path
```bash
python process_elevenlabs_complete.py input.json -o output.json
```

### With Original Content
Preserves paragraph formatting from source:
```bash
python process_elevenlabs_complete.py input.json \
  -c original_content.json \
  -o final.json
```

## Command-Line Options

```
python process_elevenlabs_complete.py <input> [options]

Required:
  input                Path to ElevenLabs JSON with character timing

Options:
  -o, --output PATH    Output path (default: input_enhanced.json)
  -c, --original-content PATH  Original content for formatting
  --config PATH        Configuration file (default: config.json)
  -h, --help          Show help message
```

## Edge Case Configuration

### Overview
The pipeline intelligently handles various text formatting edge cases that would otherwise break sentence detection. This is controlled via `config.json`.

### Handled Edge Cases

#### 1. Lists
**Colon-introduced:**
```
Examples of technology include:
Telematics
Wearables
IoT sensors
```
Each item becomes a separate sentence for clear highlighting.

**Numbered/Bulleted:**
- `1. First item` or `1) First item`
- `• Bullet point` or `- List item`
- `a) Option A` or `a. Option A`

#### 2. Abbreviations
Over 500 recognized abbreviations prevent false sentence breaks:
- **Titles**: Dr., Mr., Mrs., Prof., Rev.
- **Academic**: Ph.D., M.D., B.A., MBA
- **Organizations**: Inc., Corp., Ltd., LLC
- **Locations**: St., Ave., Blvd.
- **Time**: a.m., p.m., hr., min.
- **Medical**: mg., ml., ICU, ER
- **Legal**: v., vs., et al., i.e.
- **Insurance**: ins., prem., ded., liab.

#### 3. Mathematical & Technical
- **Equations**: `E = mc²` preserved as single unit
- **Calculations**: `2 + 2 = 4` not broken at equals
- **Ratios**: `3:1` colon not treated as list
- **Percentages**: `95.5%` kept intact
- **URLs**: `www.example.com` dots don't break sentences
- **Emails**: `info@example.com` preserved

#### 4. Quotations & Dialog
- **Direct quotes**: `She said, "Hello."`
- **Dialog format**: `Manager: "Status?"`
- **Nested quotes**: Properly handled

#### 5. Special Punctuation
- **Ellipses**: `Well...` doesn't break
- **Em dashes**: `The solution—if any—is clear`
- **Semicolons**: Configurable breaking
- **Multiple**: `Really?!` treated as single

### Configuration File

Edit `config.json` to control edge case handling:

```json
{
  "sentence_detection": {
    "use_enhanced_detection": true,  // Master switch
    "handle_lists": true,            // Process list items separately
    "split_long_quotes": true,       // Break very long quotations
    "preserve_equations": true,      // Keep math expressions intact
    "max_sentence_length_ms": 20000, // Maximum sentence duration

    "edge_case_handling": {
      "colon_lists": {
        "enabled": true,
        "split_items": true,
        "min_items_for_list": 2
      },
      "numbered_lists": {
        "enabled": true
      },
      "bulleted_lists": {
        "enabled": true
      },
      "quotations": {
        "enabled": true,
        "max_quote_length_ms": 10000
      },
      "abbreviations": {
        "enabled": true,
        "use_external_database": true
      }
    }
  },

  "output": {
    "include_debug_info": false,     // Add debug fields
    "include_break_reasons": false   // Show why sentences broke
  }
}
```

### Adding Custom Abbreviations

Add to `abbreviations.json` under the appropriate category:
```json
{
  "custom": ["Your", "Custom", "Abbrev"],
  "insurance_terms": ["Add", "More", "Here"]
}
```

### Disabling Edge Case Detection

For simple punctuation-based breaking:
```json
{
  "sentence_detection": {
    "use_enhanced_detection": false
  }
}
```

## Flutter App Integration

### File Placement
Place generated content in the Flutter app's assets:
```bash
cp output.json ../assets/test_content/learning_objects/{id}/content.json
```

Where `{id}` is the learning object ID (e.g., `63ad7b78-0970-4265-a4fe-51f3fee39d5f`)

### Field Name Compatibility
The pipeline outputs snake_case fields matching Flutter's expectations:
```dart
// Flutter expects:
json['start_ms']       // NOT startMs
json['end_ms']         // NOT endMs
json['sentence_index'] // NOT sentenceIndex
```

### App Loading Process
1. App loads JSON from assets directory
2. Parses using snake_case field names
3. Displays with paragraph formatting preserved
4. Synchronizes highlighting with continuous coverage

## Step-by-Step Workflow

### 1. Generate Audio with ElevenLabs
```python
# Use ElevenLabs API with timing enabled
response = elevenlabs.generate(
    text=content,
    voice="voice_id",
    with_timestamps=True  # Critical for timing
)
```

### 2. Save ElevenLabs Output
Save the complete JSON response containing:
- Character array
- Start/end time arrays
- Audio file reference

### 3. Run Preprocessing
```bash
python process_elevenlabs_complete.py elevenlabs_output.json
```

### 4. Verify Output
Check the summary:
```
✅ Saved enhanced content to: content_enhanced.json

📊 Summary:
   Text: 15407 characters
   Words: 2347
   Sentences: 116
   Paragraphs: 78
   Duration: 16.0 minutes
```

### 5. Deploy to App
```bash
cp content_enhanced.json ../assets/test_content/learning_objects/{id}/content.json
```

## Troubleshooting

### Common Issues

**Sentence highlighting flashes**
- Ensure snake_case field names (not camelCase)
- Verify continuous coverage algorithm is applied

**No paragraph breaks in display**
- Provide original content with `-c` option
- Check that `displayText` contains `\n` characters

**Lists appear as single sentence**
- Enable `"use_enhanced_detection": true` in config
- Verify `"handle_lists": true` is set

**Breaks at abbreviations (Dr., Inc.)**
- Check `abbreviations.json` exists
- Add missing abbreviations to database
- Ensure `"use_enhanced_detection": true`

**Mathematical expressions broken**
- Set `"preserve_equations": true` in config
- Check edge case handling is enabled

**Words with sentence_index = -1**
- Script auto-fixes this with continuous coverage
- Check for warnings in output

## Complete Pipeline: ElevenLabs to Supabase

### Step 1: Generate Audio with ElevenLabs
```bash
# Use ElevenLabs API to generate audio with timing data
# Output: JSON with character-level timing
```

### Step 2: Preprocess with Lookup Table Generation
```bash
python process_elevenlabs_complete.py elevenlabs_output.json \
  -o enhanced_content.json
```

This generates:
- Word and sentence timing with no gaps
- O(1) lookup table embedded in JSON (10ms intervals)
- Snake_case field names for Flutter compatibility

### Step 3: Upload to Supabase
```bash
# Set environment variables
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"

# Upload with embedded lookup table
python upload_to_supabase.py enhanced_content.json \
  --id "learning-object-uuid" \
  --assignment-id "assignment-uuid" \
  --title "Learning Object Title" \
  --audio-file audio.mp3
```

### Step 4: Verify Upload
```bash
# Check if lookup table was uploaded
python upload_to_supabase.py enhanced_content.json \
  --id "learning-object-uuid" \
  --verify-only
```

## Lookup Table Features

### Performance Benefits
- **O(1) time complexity** for position queries (vs O(log n) binary search)
- **60fps highlighting** guaranteed with 10ms resolution
- **No gaps** in timing coverage for smooth transitions

### How It Works
```json
"lookup_table": {
  "version": "1.0",
  "interval": 10,  // Query every 10ms
  "totalDurationMs": 95764,
  "lookup": [
    [0, 0],   // At 0ms: word 0, sentence 0
    [0, 0],   // At 10ms: word 0, sentence 0
    [1, 0],   // At 20ms: word 1, sentence 0
    ...
  ]
}
```

### Validation Checks

The script performs automatic validation:
- ✅ No invalid sentence indices
- ✅ Continuous timing coverage
- ✅ Text matches original (if provided)
- ✅ Snake_case field names
- ✅ Chronological ordering

### Debug Mode

Enable debug output in config.json:
```json
{
  "output": {
    "include_debug_info": true,
    "include_break_reasons": true
  }
}
```

This adds:
- `break_reason` field to sentences (why they ended)
- Additional validation output
- Character position tracking

## Testing

### Run Test Suite
```bash
python test_edge_case_handling.py
```

### Test Corpus
Use files in `tests/` directory to verify edge case handling.

### Manual Testing
1. Process a test file with known edge cases
2. Check sentence boundaries in output JSON
3. Verify in Flutter app for proper highlighting

## Examples

### Example 1: Insurance Content
```bash
python process_elevenlabs_complete.py \
  insurance_lesson.json \
  -c original_lesson.json \
  -o processed_lesson.json
```

### Example 2: Custom Config
```bash
python process_elevenlabs_complete.py \
  content.json \
  --config custom_config.json \
  -o output.json
```

### Example 3: Debug Mode
```bash
# Enable debug in config.json first
python process_elevenlabs_complete.py debug_test.json
```

## Performance Notes

- Processing time: ~1-2 seconds per minute of audio
- Edge case detection adds ~5-10% overhead
- Output file size similar to input
- No impact on app performance (preprocessing only)

## Best Practices

1. **Always verify** output summary for correct counts
2. **Use original content** when available for formatting
3. **Test edge cases** with sample content first
4. **Keep backups** of working configurations
5. **Update abbreviations** as needed for your domain
6. **Monitor warnings** in script output
7. **Validate in app** after preprocessing