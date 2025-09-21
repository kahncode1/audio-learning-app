# Preprocessing Pipeline Usage Guide

## Quick Start

### 1. Prerequisites
- Python 3.7+
- ElevenLabs TTS output JSON file
- (Optional) Original content JSON for formatting preservation

### 2. Basic Usage

Process a single ElevenLabs file:
```bash
cd preprocessing_pipeline
python process_elevenlabs_complete.py ../path/to/elevenlabs_output.json
```

### 3. With Original Content

Preserve paragraph formatting from original:
```bash
python process_elevenlabs_complete.py \
  ../Test_LO_Content/elevenlabs_output.json \
  -c ../Test_LO_Content/original_content.json \
  -o ../assets/test_content/learning_objects/{id}/content.json
```

## File Locations

### Input Files
- **ElevenLabs JSON**: Output from ElevenLabs API with character timing
- **Original Content**: Source text with paragraph structure

### Output Location
Place the generated `content.json` in:
```
assets/test_content/learning_objects/{learning_object_id}/content.json
```

Where `{learning_object_id}` matches the database ID (e.g., `63ad7b78-0970-4265-a4fe-51f3fee39d5f`)

## Step-by-Step Workflow

### Step 1: Generate Audio with ElevenLabs
Use ElevenLabs API to generate audio with character-level timing:
```python
# Example ElevenLabs API call (not part of this pipeline)
response = elevenlabs.generate(
    text=content,
    voice="voice_id",
    model="eleven_monolingual_v1",
    output_format="mp3_44100_128",
    with_timestamps=True  # Critical for timing data
)
```

### Step 2: Save ElevenLabs Output
Save the API response JSON containing:
- Audio file URL/data
- Character alignment arrays
- Timing information

### Step 3: Run Preprocessing
```bash
python process_elevenlabs_complete.py elevenlabs_output.json
```

This generates `content_complete.json` with:
- Word-level timing
- Sentence boundaries
- Preserved paragraphs
- Snake_case field names

### Step 4: Deploy to App
Copy the generated content to the app's assets:
```bash
cp content_complete.json ../assets/test_content/learning_objects/{id}/content.json
```

### Step 5: Verify in App
The Flutter app will:
1. Load the JSON from assets
2. Parse using snake_case field names
3. Display with proper paragraph breaks
4. Synchronize highlighting without flashing

## Command-Line Options

```
python process_elevenlabs_complete.py <elevenlabs_json> [options]

Arguments:
  elevenlabs_json    Path to ElevenLabs JSON file with character timing

Options:
  -o, --output PATH          Output path for enhanced JSON (default: *_complete.json)
  -c, --original-content PATH  Path to original content JSON for verification
  -h, --help                Show help message
```

## Examples

### Example 1: Basic Processing
```bash
python process_elevenlabs_complete.py audio_data.json
```
Output: `audio_data_complete.json`

### Example 2: Custom Output Path
```bash
python process_elevenlabs_complete.py audio_data.json -o processed/content.json
```
Output: `processed/content.json`

### Example 3: With Original Content Verification
```bash
python process_elevenlabs_complete.py \
  elevenlabs.json \
  -c original.json \
  -o final.json
```
Output: `final.json` with preserved formatting from `original.json`

## Validation Output

The script provides validation feedback:
```
📊 Loaded ElevenLabs data:
   Characters: 15407
   Start times: 15407
   End times: 15407

✅ Saved enhanced content to: content_complete.json

📊 Summary:
   Text: 15407 characters
   Words: 2347
   Sentences: 116
   Paragraphs: 78
   Duration: 957.6 seconds
   Duration: 16.0 minutes

✅ Text matches original content perfectly!
```

## Troubleshooting

### Issue: Sentence highlighting flashes
**Solution**: Ensure field names use snake_case (not camelCase)

### Issue: No paragraph breaks in display
**Solution**: Provide original content with `-c` option to preserve formatting

### Issue: Words have sentence_index = -1
**Solution**: Script automatically fixes this with continuous coverage algorithm

### Issue: Field name mismatch errors in Flutter
**Solution**: Verify all timing fields use snake_case:
- ✅ `start_ms` (not `startMs`)
- ✅ `end_ms` (not `endMs`)
- ✅ `sentence_index` (not `sentenceIndex`)

## Integration with Flutter App

The Flutter app expects the content.json at:
```dart
final contentPath = 'assets/test_content/learning_objects/$learningObjectId/content.json';
```

The app's `WordTiming.fromJson()` expects snake_case fields:
```dart
factory WordTiming.fromJson(Map<String, dynamic> json) {
  return WordTiming(
    word: json['word'] as String,
    startMs: json['start_ms'] as int,        // snake_case
    endMs: json['end_ms'] as int,            // snake_case
    sentenceIndex: json['sentence_index'] as int? ?? 0,  // snake_case
  );
}
```

## Best Practices

1. **Always verify** the output summary shows correct counts
2. **Use original content** when available for best formatting
3. **Check for warnings** about invalid sentence indices
4. **Test in app** after preprocessing to verify highlighting works
5. **Keep backups** of working content.json files