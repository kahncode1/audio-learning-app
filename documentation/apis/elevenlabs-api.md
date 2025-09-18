# ElevenLabs API Integration Guide

## Overview
ElevenLabs provides modern text-to-speech capabilities with HTTP streaming, designed as an alternative to Speechify for the Audio Learning App. This implementation focuses on mobile-optimized streaming with plain text input only.

## Key Features
- HTTP streaming with chunked transfer encoding
- Character-level timing information
- Multiple voice models and languages
- Binary audio streaming (not base64)
- Mobile-optimized (no WebSockets required)
- Better battery efficiency than persistent connections
- Plain text input only (simplified approach)

## API Configuration

### Base URL
```
https://api.elevenlabs.io
```

### Authentication
All requests require an API key in the header:
```
xi-api-key: YOUR_API_KEY_HERE
```

## Primary Endpoints

### 1. Stream with Timestamps
**Endpoint:** `POST /v1/text-to-speech/{voice_id}/stream/with-timestamps`

**Purpose:** Generate audio with character-level timing for word synchronization

**Request:**
```json
{
  "text": "Your plain text content here",
  "model_id": "eleven_multilingual_v2",
  "voice_settings": {
    "stability": 0.5,
    "similarity_boost": 0.75,
    "style": 0.0,
    "use_speaker_boost": true
  },
  "output_format": "mp3_44100_128"
}
```

**Response:** Binary audio stream with timing metadata in headers or initial chunks

### 2. Standard Streaming (without timestamps)
**Endpoint:** `POST /v1/text-to-speech/{voice_id}/stream`

**Purpose:** Simple audio streaming without timing data

**Note:** Use the `/with-timestamps` endpoint for our highlighting requirements

## Timing Data Format

### ElevenLabs Response Structure
```json
{
  "audio_chunk": "binary_data",
  "character_start_times": [
    {"character": "H", "start_time_ms": 0},
    {"character": "e", "start_time_ms": 100},
    {"character": "l", "start_time_ms": 200},
    {"character": "l", "start_time_ms": 300},
    {"character": "o", "start_time_ms": 400},
    {"character": " ", "start_time_ms": 500},
    {"character": "w", "start_time_ms": 600},
    {"character": "o", "start_time_ms": 700},
    {"character": "r", "start_time_ms": 800},
    {"character": "l", "start_time_ms": 900},
    {"character": "d", "start_time_ms": 1000}
  ]
}
```

### Required Transformation to WordTiming
Our app requires word-level timing with sentence indices. The transformation algorithm:

1. **Group characters into words** by detecting spaces
2. **Calculate word boundaries** from character positions
3. **Detect sentence boundaries** using:
   - Terminal punctuation (. ! ?)
   - 350ms pause between words
   - Protection for abbreviations (Dr., Inc., etc.)
4. **Create WordTiming objects** with sentenceIndex

Example transformation:
```dart
// Input: character_start_times array
// Output: List<WordTiming>
[
  WordTiming(
    word: "Hello",
    startMs: 0,
    endMs: 500,
    sentenceIndex: 0,
  ),
  WordTiming(
    word: "world",
    startMs: 600,
    endMs: 1000,
    sentenceIndex: 0,
  ),
]
```

## Voice Configuration

### Available Models
- `eleven_multilingual_v2` - Recommended for quality
- `eleven_turbo_v2` - Faster generation, slightly lower quality
- `eleven_monolingual_v1` - English only, legacy

### Voice IDs
Voice IDs are unique identifiers for each voice. Examples:
- Get available voices: `GET /v1/voices`
- Default voices provided by ElevenLabs
- Custom cloned voices (if available)

### Voice Settings
- **stability** (0.0 - 1.0): Voice consistency
- **similarity_boost** (0.0 - 1.0): Voice clarity
- **style** (0.0 - 1.0): Style exaggeration
- **use_speaker_boost** (boolean): Enhanced speaker clarity

## Mobile Implementation Considerations

### HTTP Streaming Benefits
1. **No persistent connection** - Better for battery life
2. **Standard HTTP caching** - Works with CDNs
3. **Easy retry logic** - Simple error recovery
4. **Background/foreground friendly** - No reconnection needed

### Chunked Transfer Encoding
```dart
// Dio configuration for streaming
final response = await dio.post(
  '/v1/text-to-speech/$voiceId/stream/with-timestamps',
  data: requestBody,
  options: Options(
    responseType: ResponseType.stream,
    headers: {
      'xi-api-key': apiKey,
      'Accept': 'audio/mpeg',
    },
  ),
);

// Process chunks as they arrive
await for (final chunk in response.data.stream) {
  // Handle audio chunk
  // Extract timing data if present
}
```

### Error Handling
Common error codes:
- `401` - Invalid API key
- `422` - Invalid request parameters
- `429` - Rate limit exceeded
- `500` - Server error

## Key Differences from Speechify

| Feature | Speechify | ElevenLabs |
|---------|-----------|------------|
| Response Format | JSON with base64 audio | Binary stream |
| Timing Data | Word-level with sentences | Character-level |
| Input Format | SSML or plain text | Plain text only |
| Streaming | Base64 in JSON | HTTP chunked |
| SDK | None (custom Dio) | None (custom Dio) |
| Sentence Detection | API provides | Client computes |

## Implementation Checklist

### Phase 1: Service Setup
- [ ] Create ElevenLabsService class
- [ ] Match SpeechifyService interface
- [ ] Implement HTTP streaming with Dio
- [ ] Parse character timing data

### Phase 2: Timing Transformation
- [ ] Character to word grouping algorithm
- [ ] Sentence boundary detection
- [ ] WordTiming object creation
- [ ] Compatibility with existing model

### Phase 3: Audio Integration
- [ ] Binary stream handling
- [ ] Progressive buffering
- [ ] Error recovery
- [ ] Memory management

### Phase 4: Testing
- [ ] Unit tests for transformation
- [ ] Integration tests with API
- [ ] Device testing (iOS/Android)
- [ ] Performance benchmarks

## Configuration in App

### Environment Variables
```yaml
# .env file
ELEVENLABS_API_KEY=your_api_key_here
ELEVENLABS_VOICE_ID=preferred_voice_id
USE_ELEVENLABS=false  # Feature flag
```

### Service Selection
```dart
// In AudioPlayerService or factory
final ttsService = EnvConfig.useElevenLabs
  ? ElevenLabsService()
  : SpeechifyService();
```

## Testing Strategy

### Accuracy Targets
- Word timing accuracy: ≥95%
- Sentence detection: 100%
- Audio quality: Comparable to Speechify
- Latency: <2 seconds to first audio

### Comparison Testing
1. Generate audio for same content with both services
2. Compare word timing accuracy
3. Validate sentence boundaries
4. Measure performance metrics
5. User acceptance testing

## Limitations

### Plain Text Only
ElevenLabs accepts plain text input only. Unlike Speechify which supports SSML tags for prosody control, ElevenLabs relies on:
- Voice settings for overall speech characteristics
- Natural language processing for emphasis
- Punctuation for pause detection

The service is designed for simplicity and ease of use with natural text.

## Performance Optimization

### Caching Strategy
- Cache generated audio segments locally
- Store timing data in SharedPreferences
- Implement LRU eviction for memory management

### Streaming Optimization
- Use appropriate buffer sizes (64KB recommended)
- Implement progressive playback
- Handle network interruptions gracefully

## Monitoring and Debugging

### Logging Requirements
- Log API request/response times
- Track timing transformation accuracy
- Monitor streaming performance
- Record error rates and types

### Debug Information
```dart
AppLogger.info('ElevenLabs API', {
  'endpoint': '/stream/with-timestamps',
  'voiceId': voiceId,
  'textLength': text.length,
  'responseTime': responseTime,
  'characterCount': characterTimings.length,
  'wordCount': wordTimings.length,
  'sentenceCount': sentenceCount,
});
```

## Migration Path

1. **Parallel Development** - Keep both services active
2. **Feature Flag Control** - Runtime switching
3. **Gradual Rollout** - Test with subset of users
4. **Performance Monitoring** - Track metrics
5. **Full Migration** - Switch default to ElevenLabs

## References

- [ElevenLabs API Documentation](https://docs.elevenlabs.io/api-reference)
- [Audio Streaming Best Practices](https://docs.elevenlabs.io/guides/streaming)
- Project Implementation: `/lib/services/elevenlabs_service.dart` (to be created)
- Existing Speechify Implementation: `/lib/services/speechify_service.dart`