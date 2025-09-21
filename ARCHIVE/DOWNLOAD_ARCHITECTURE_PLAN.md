# Download-First Architecture Plan

## Executive Summary

Transform the Audio Learning App from real-time TTS streaming to a download-first approach with pre-processed content. Users will download all course materials (audio, text, and timing files) upon first login, enabling offline learning and eliminating per-request TTS costs.

## Architecture Overview

### Current State (Streaming)
- Real-time TTS generation via Speechify/ElevenLabs APIs
- Complex sentence detection algorithms (350ms pause + punctuation)
- Network-dependent playback
- Per-request API costs
- ~$2.63 per user per course

### Future State (Download-First)
- Pre-processed audio, text, and timing files
- Download once, play offline
- No runtime TTS costs
- Instant playback
- Simplified codebase

## File Structure

### Per Learning Object (3 files each)
```
learning_object_id/
├── audio.mp3       # Pre-generated audio (~3MB)
├── content.json    # Display text and metadata (~10KB)
└── timing.json     # Word and sentence timings (~50KB)
```

### Total Course Size
- 35 Learning Objects × 3 files = 105 files
- Total size: ~107MB per course

## JSON Schema Definitions

### 1. Content File Schema (`content.json`)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "displayText", "paragraphs"],
  "properties": {
    "version": {
      "type": "string",
      "description": "Schema version for future compatibility",
      "const": "1.0"
    },
    "displayText": {
      "type": "string",
      "description": "Complete formatted text for display"
    },
    "paragraphs": {
      "type": "array",
      "description": "Text broken into paragraphs for better rendering",
      "items": {
        "type": "string"
      }
    },
    "metadata": {
      "type": "object",
      "properties": {
        "wordCount": {"type": "integer"},
        "characterCount": {"type": "integer"},
        "estimatedReadingTime": {"type": "string"},
        "language": {"type": "string", "default": "en"}
      }
    }
  }
}
```

#### Example Content File
```json
{
  "version": "1.0",
  "displayText": "Welcome to Insurance Case Management. This course covers the essential principles of establishing and managing case reserves. You will learn how to accurately assess claim values and set appropriate reserves.",
  "paragraphs": [
    "Welcome to Insurance Case Management.",
    "This course covers the essential principles of establishing and managing case reserves.",
    "You will learn how to accurately assess claim values and set appropriate reserves."
  ],
  "metadata": {
    "wordCount": 28,
    "characterCount": 195,
    "estimatedReadingTime": "10 seconds",
    "language": "en"
  }
}
```

### 2. Timing File Schema (`timing.json`)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "words", "sentences", "totalDurationMs"],
  "properties": {
    "version": {
      "type": "string",
      "const": "1.0"
    },
    "words": {
      "type": "array",
      "description": "Individual word timing data",
      "items": {
        "type": "object",
        "required": ["word", "startMs", "endMs", "charStart", "charEnd"],
        "properties": {
          "word": {"type": "string"},
          "startMs": {"type": "integer", "description": "Start time in milliseconds"},
          "endMs": {"type": "integer", "description": "End time in milliseconds"},
          "charStart": {"type": "integer", "description": "Start position in displayText"},
          "charEnd": {"type": "integer", "description": "End position in displayText"}
        }
      }
    },
    "sentences": {
      "type": "array",
      "description": "Pre-processed sentence boundaries",
      "items": {
        "type": "object",
        "required": ["text", "startMs", "endMs", "wordStartIndex", "wordEndIndex"],
        "properties": {
          "text": {"type": "string"},
          "startMs": {"type": "integer"},
          "endMs": {"type": "integer"},
          "wordStartIndex": {"type": "integer", "description": "Index in words array"},
          "wordEndIndex": {"type": "integer", "description": "Index in words array (inclusive)"},
          "charStart": {"type": "integer"},
          "charEnd": {"type": "integer"}
        }
      }
    },
    "totalDurationMs": {"type": "integer", "description": "Total audio duration"}
  }
}
```

#### Example Timing File
```json
{
  "version": "1.0",
  "words": [
    {"word": "Welcome", "startMs": 0, "endMs": 500, "charStart": 0, "charEnd": 7},
    {"word": "to", "startMs": 500, "endMs": 700, "charStart": 8, "charEnd": 10},
    {"word": "Insurance", "startMs": 700, "endMs": 1200, "charStart": 11, "charEnd": 20},
    {"word": "Case", "startMs": 1200, "endMs": 1500, "charStart": 21, "charEnd": 25},
    {"word": "Management", "startMs": 1500, "endMs": 2000, "charStart": 26, "charEnd": 36}
  ],
  "sentences": [
    {
      "text": "Welcome to Insurance Case Management.",
      "startMs": 0,
      "endMs": 2000,
      "wordStartIndex": 0,
      "wordEndIndex": 4,
      "charStart": 0,
      "charEnd": 37
    }
  ],
  "totalDurationMs": 10000
}
```

## Database Schema Updates

```sql
-- Update learning_objects table
ALTER TABLE public.learning_objects
ADD COLUMN audio_url TEXT,           -- CDN URL for MP3
ADD COLUMN content_url TEXT,         -- CDN URL for content JSON
ADD COLUMN timing_url TEXT,          -- CDN URL for timing JSON
ADD COLUMN file_version INTEGER DEFAULT 1,
ADD COLUMN download_status TEXT DEFAULT 'pending',
ADD COLUMN local_audio_path TEXT,
ADD COLUMN local_content_path TEXT,
ADD COLUMN local_timing_path TEXT,
DROP COLUMN ssml_content,            -- No longer needed
DROP COLUMN word_timings;            -- Now in separate file

-- Add download tracking table
CREATE TABLE public.download_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  learning_object_id UUID REFERENCES public.learning_objects(id),
  download_status TEXT NOT NULL, -- pending/downloading/completed/failed
  progress_percentage INTEGER DEFAULT 0,
  retry_count INTEGER DEFAULT 0,
  error_message TEXT,
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(user_id, learning_object_id)
);
```

## Test Data Strategy

### Temporary Local Storage
Since we're using temporary authorization during development, test files will be stored locally:

```
assets/
  test_content/
    learning_objects/
      63ad7b78-0970-4265-a4fe-51f3fee39d5f/
        audio.mp3         # Test audio file
        content.json      # Test text content
        timing.json       # Test timing data
```

### Flutter Asset Configuration
```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/test_content/learning_objects/
```

## New Services Architecture

### 1. CourseDownloadService
```dart
class CourseDownloadService {
  // Downloads all course content on first login
  Future<void> downloadCourse(String courseId);
  Stream<DownloadProgress> get progressStream;
  Future<bool> isContentAvailable(String learningObjectId);
  Future<void> retryFailedDownloads();
  Future<void> deleteOldContent();
}
```

### 2. LocalContentService
```dart
class LocalContentService {
  // Manages local file access
  Future<String> getAudioPath(String learningObjectId);
  Future<Map<String, dynamic>> getContent(String learningObjectId);
  Future<TimingData> getTimingData(String learningObjectId);
  Future<void> clearCache();
}
```

### 3. Modified AudioPlayerService
- Load from local MP3 files instead of streaming
- Remove TTS service dependencies
- Simpler error handling (no network errors during playback)

### 4. Simplified WordTimingService
- Load pre-processed timing data from JSON
- Remove sentence detection algorithm
- Direct sentence mapping from timing.json
- No runtime calculations needed

## Components to Remove

### Services
- `SpeechifyService` - No longer needed
- `ElevenLabsService` - No longer needed
- `TtsServiceFactory` - No longer needed
- `SpeechifyAudioSource` - Replaced by local files
- `ElevenLabsAudioSource` - Replaced by local files

### Algorithms
- Sentence detection (350ms pause + punctuation)
- Abbreviation protection logic
- Word timing inference
- Character-to-word mapping
- SSML to plain text conversion

### Dependencies
- Real-time TTS API calls
- Streaming audio processing
- Complex network error recovery

## Implementation Phases

### Phase 1: Test Data & Local Implementation (Week 1)
- Create test JSON files following schemas
- Store in assets folder temporarily
- Implement LocalContentService to read from assets
- Test dual-level highlighting with pre-processed sentences

### Phase 2: Download Infrastructure (Week 2)
- Implement CourseDownloadService with progress tracking
- Create download queue with retry logic
- Build download progress UI
- Use flutter_cache_manager for storage

### Phase 3: Supabase Integration (Week 3)
- Backend team generates production files
- Upload to Supabase Storage
- Update LocalContentService to download from CDN
- Test complete download flow

### Phase 4: Simplification & Cleanup (Week 4)
- Remove all TTS services
- Remove sentence detection algorithms
- Simplify highlighting widget
- Performance optimization
- Complete testing

## Benefits Analysis

### Cost Reduction
- **Before:** $0.015 per 1000 chars × ~5000 chars/LO × 35 LOs = $2.63 per user per course
- **After:** $0 (one-time pre-processing cost only)
- **Savings:** 100% reduction in runtime costs

### Performance Improvements
- Playback start: Instant (vs 2-3 seconds)
- No network latency during playback
- Predictable timing (no API variations)
- Simplified codebase (~40% less code)

### User Experience
- Complete offline capability
- Faster, more responsive playback
- No internet required after initial download
- Consistent experience across all users

## MP3 Compatibility

MP3 format is fully supported on both platforms:
- **iOS:** Native support via AVAudioPlayer
- **Android:** Native support via MediaPlayer
- **Flutter:** just_audio package handles platform differences transparently
- **Compression:** ~1MB per minute of audio

## Migration Strategy

### 1. Parallel Operation Period
- Keep TTS services temporarily
- Add feature flag for new download mode
- Test with subset of users

### 2. Data Migration
- Pre-generate all audio/timing files on backend
- Upload to Supabase Storage CDN
- Update database with file URLs

### 3. Rollout
- Beta test with new users first
- Gradual migration of existing users
- Full cutover after validation

## Success Metrics

- Download success rate > 99%
- Offline playback reliability > 99.9%
- User satisfaction increase
- Support ticket reduction
- Cost savings of >90%

## Risk Mitigation

### Storage Requirements (~107MB per course)
- Show clear download progress
- Allow background downloading
- WiFi-only download option
- Automatic cleanup of old content

### Initial Download Time
- Progressive download (start with first assignment)
- Allow course preview before full download
- Retry mechanism for failed downloads

### Update Mechanism
- Version tracking for content updates
- Incremental updates (only changed files)
- Background update checks

## Next Steps

1. **Immediate:** Create test data files using defined schemas
2. **This Week:** Implement LocalContentService for test files
3. **Next Week:** Test simplified highlighting with pre-processed sentences
4. **Future:** Full Supabase integration when backend is ready

## Conclusion

This download-first architecture will dramatically simplify the codebase, eliminate runtime costs, and provide a superior offline learning experience. The pre-processed content approach removes complex runtime calculations and provides predictable, consistent performance across all devices.