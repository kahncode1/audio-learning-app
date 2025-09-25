# Complete Upload Pipeline Guide

## Overview

This guide covers the complete pipeline from ElevenLabs TTS generation to production-ready content in Supabase with O(1) lookup tables for 60fps highlighting performance.

## Prerequisites

### Software Requirements
```bash
# Python 3.7+
python --version

# Supabase Python client
pip install supabase python-dotenv

# Environment variables
export SUPABASE_URL="https://cmjdciktvfxiyapdseqn.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
```

### Required IDs
- **Course ID**: UUID of the course in Supabase
- **Assignment ID**: UUID of the assignment
- **Learning Object ID**: UUID for the learning object (generate with `uuidgen`)

## Step-by-Step Pipeline

### Step 1: Generate Audio with ElevenLabs

Use the ElevenLabs API to generate audio with character-level timing:

```python
# Example ElevenLabs API call
{
  "text": "Your educational content here",
  "voice": "voice_id",
  "model_id": "eleven_monolingual_v1",
  "output_format": "mp3_128",
  "with_timing": true
}
```

Output: `elevenlabs_output.json` with character-level timing data

### Step 2: Preprocess with O(1) Lookup Table

Process the ElevenLabs output to generate enhanced content with embedded lookup tables:

```bash
python process_elevenlabs_complete.py elevenlabs_output.json \
  -o enhanced_content.json
```

This generates:
- **Word timing** with no gaps between words
- **Sentence timing** with continuous coverage
- **O(1) lookup table** with 10ms resolution
- **Snake_case fields** for Flutter compatibility

#### What the Lookup Table Does

The lookup table provides instant (O(1)) position queries:

```json
"lookup_table": {
  "version": "1.0",
  "interval": 10,
  "totalDurationMs": 95764,
  "lookup": [
    [0, 0],   // At 0ms: word index 0, sentence index 0
    [0, 0],   // At 10ms: still word 0, sentence 0
    [1, 0],   // At 20ms: moved to word 1, still sentence 0
    [-1, -1], // At 30ms: gap between words
    [2, 0],   // At 40ms: word 2, sentence 0
    ...
  ]
}
```

To find the current word at any time:
```python
# O(1) lookup instead of O(log n) binary search
time_ms = 5432
index = time_ms // 10  # 543
word_index, sentence_index = lookup_table['lookup'][index]
```

### Step 3: Upload to Supabase

Upload the enhanced content with embedded lookup table:

```bash
python upload_to_supabase.py enhanced_content.json \
  --id "63ad7b78-0970-4265-a4fe-51f3fee39d5f" \
  --assignment-id "a1b2c3d4-e5f6-7890-abcd-ef1234567890" \
  --title "Risk Management Fundamentals" \
  --audio-file "audio.mp3" \
  --order 1
```

#### What Gets Uploaded

1. **Learning Object Record** in `learning_objects` table:
   - All timing data in `word_timings` JSONB field
   - Embedded lookup table for O(1) performance
   - Audio URL pointing to Supabase Storage

2. **Audio File** to Supabase Storage (if provided):
   - Uploaded to `course-audio` bucket with path: `courses/{course}/assignments/{assignment}/{filename}.mp3`
   - Automatically served via CDN
   - 50MB max file size

### Step 4: Verify Upload

Check that the lookup table was successfully uploaded:

```bash
python upload_to_supabase.py enhanced_content.json \
  --id "63ad7b78-0970-4265-a4fe-51f3fee39d5f" \
  --verify-only
```

Expected output:
```
✅ Verified lookup table for 63ad7b78-0970-4265-a4fe-51f3fee39d5f
   Entries: 9577
   Version: 1.0
```

## Production Workflow

### Batch Processing

For multiple learning objects:

```bash
# Process all ElevenLabs files
for file in elevenlabs_outputs/*.json; do
  output="enhanced/$(basename $file)"
  python process_elevenlabs_complete.py "$file" -o "$output"
done

# Upload all to Supabase
for file in enhanced/*.json; do
  # Extract metadata from filename or config
  id=$(uuidgen)
  title=$(basename "$file" .json | tr '_' ' ')

  python upload_to_supabase.py "$file" \
    --id "$id" \
    --assignment-id "$ASSIGNMENT_ID" \
    --title "$title" \
    --audio-file "audio/${title}.mp3"
done
```

### Error Handling

Common issues and solutions:

#### RLS Policy Blocking Upload
```
⚠️ Could not upload audio to Storage (RLS policy)
```
**Solution**: The script automatically uses a fallback URL. Audio can be uploaded manually via Supabase dashboard.

#### Missing Required Fields
```
Error: course_id is required
```
**Solution**: Ensure the course exists in Supabase and add to upload script:
```python
record['course_id'] = 'your-course-uuid'
```

#### Lookup Table Too Large
For very long content (>2 hours), the lookup table may be large. Consider:
- Increasing interval to 20ms or 50ms
- Storing lookup table separately
- Using compression

## Performance Benefits

### Without Lookup Table (Binary Search)
- **Complexity**: O(log n) for each position query
- **60fps requirement**: 16.67ms per frame
- **With 10,000 words**: ~13 comparisons per query
- **Risk**: Frame drops during rapid seeking

### With Lookup Table (Direct Index)
- **Complexity**: O(1) for each position query
- **60fps requirement**: Easily met
- **With 10,000 words**: 1 array access
- **Result**: Smooth 60fps guaranteed

## Flutter App Integration

The app downloads and uses the lookup table:

```dart
// course_download_api_service.dart extracts embedded lookup table
if (wordTimingsData['lookupTable'] != null) {
  lookupTableData = wordTimingsData['lookupTable'];
  final lookupFile = File('${contentDir.path}/position_lookup.json');
  await lookupFile.writeAsString(json.encode(lookupTableData));
}

// word_timing_service_simplified.dart uses O(1) lookup
int getWordIndexAtTime(int timeMs) {
  if (lookupTable != null) {
    final index = timeMs ~/ lookupTable['interval'];
    if (index < lookupTable['lookup'].length) {
      return lookupTable['lookup'][index][0];  // O(1)
    }
  }
  return _binarySearch(timeMs);  // Fallback to O(log n)
}
```

## Testing

### Test with Sample Content

```bash
# Use provided test content
cd tests/test_content
python ../../process_elevenlabs_complete.py \
  "Risk Management and Insurance in Action.json" \
  -o test_enhanced.json

# Upload to test assignment
python ../../upload_to_supabase.py test_enhanced.json \
  --id "test-$(uuidgen)" \
  --assignment-id "test-assignment-id" \
  --title "Test Learning Object" \
  --audio-file "Risk Management and Insurance in Action.mp3"
```

### Verify in App

1. Download the course in the Flutter app
2. Check console logs for lookup table confirmation:
   ```
   ✅ Found embedded lookup table
      Entries: 9577
      Interval: 10ms
   ```
3. Test highlighting performance at 60fps

## Troubleshooting

### Issue: Words Skipping During Playback
**Cause**: Gaps in timing data
**Solution**: Preprocessing automatically eliminates gaps

### Issue: Performance Below 60fps
**Cause**: Missing lookup table, falling back to binary search
**Solution**: Verify lookup table is embedded and being extracted

### Issue: Font Size Changes Delayed
**Cause**: Stream throttling too aggressive
**Solution**: Check throttle settings in Flutter app (50ms recommended)

## Summary

This pipeline ensures:
1. ✅ **No gaps** in word timing for smooth highlighting
2. ✅ **O(1) lookups** for guaranteed 60fps performance
3. ✅ **Embedded storage** for atomic data operations
4. ✅ **CDN delivery** of audio files via Supabase Storage
5. ✅ **Production ready** with error handling and fallbacks