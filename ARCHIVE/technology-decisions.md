# Technology Decisions & Rationale Archive

## Framework Selections and Detailed Rationale

### Why Amplify Flutter for Authentication
- **Official AWS Support:** Regular updates and long-term maintenance guaranteed
- **federateToIdentityPool API:** Direct identity pool federation without custom implementation
- **Automatic Token Refresh:** Built-in token lifecycle management reduces authentication errors
- **JWT Bridge Support:** Seamless integration with Supabase custom authentication
- **Enterprise Ready:** Production-tested with extensive documentation and community support
- **Working Example:** See `/implementations/auth-service.dart` for complete implementation

### Why just_audio for Audio Playback
- **Mature and Stable:** Most widely-used Flutter audio package with proven reliability
- **StreamAudioSource:** Enables custom streaming implementations required for Speechify
- **Background Playback:** Native support for iOS and Android background audio
- **Platform Integration:** Handles audio focus, interruptions, and system controls
- **Active Development:** Regular updates and responsive maintenance team
- **Working Example:** See `/implementations/audio-service.dart` for StreamAudioSource implementation

### Why Dio for HTTP Client
- **Superior Streaming:** Better streaming support than standard http package
- **Interceptor Architecture:** Clean separation of concerns for auth, caching, and retry
- **Connection Pooling:** Improved performance for multiple concurrent requests
- **Progress Monitoring:** Built-in download/upload progress tracking
- **Error Handling:** Comprehensive error types and recovery mechanisms
- **Singleton Pattern:** See `/implementations/dio-config.dart` for proper configuration
- **Critical:** See `/references/common-pitfalls.md` #1 - Never create multiple instances

### Why Riverpod for State Management
- **Type Safety:** Compile-time checking prevents runtime errors
- **Testing Support:** Easy to mock and test providers
- **Resource Management:** Automatic disposal prevents memory leaks
- **Provider Composition:** Complex state management through provider combination
- **Modern Architecture:** Successor to Provider with improved API
- **Working Example:** See `/implementations/providers.dart` for complete setup
- **Patterns:** See `/references/code-patterns.md` for state management patterns

### Why SharedPreferences for Local Storage
- **Lightweight:** Minimal overhead for simple key-value storage
- **Native Integration:** Uses platform-specific storage mechanisms
- **Synchronous Reads:** Fast access to cached data and preferences
- **No Dependencies:** Core Flutter package with stable API
- **Supabase Alignment:** Matches Supabase's recommended local storage approach
- **Working Example:** See `/implementations/progress-service.dart` for preference persistence

### Custom Implementation for Dual-Level Word Highlighting
**No existing Flutter packages provide the required functionality:**
- **Unique Requirement:** Dual-level synchronization with sentence background and word foreground
- **Performance Critical:** Must maintain 60fps while updating both highlight levels
- **Complex Coordination:** Requires custom integration of audio position, text rendering, and user interaction
- **Optimization Needed:** Binary search and position caching for efficiency
- **Platform Specific:** Requires custom text measurement and rendering logic
- **Tap Interaction:** Word-level tap-to-seek functionality
- **Complete Solution:** See `/implementations/word-highlighting.dart` for full implementation
- **Performance Patterns:** See `/references/code-patterns.md` for optimization techniques

## Detailed Package Analysis

### Audio Core Packages
- **just_audio: ^0.9.36** - Main audio player with StreamAudioSource support for custom streaming
- **just_audio_background: ^0.0.1-beta.11** - Background playback wrapper for iOS and Android
- **audio_session: ^0.1.18** - Audio session configuration and system audio focus management

**Alternative Considered:** audioplayers
**Why Rejected:** Limited streaming capabilities, less reliable background playback

### Authentication Packages
- **amplify_flutter: ^2.0.0** - Official AWS SDK with comprehensive Cognito support
- **amplify_auth_cognito: ^2.0.0** - Cognito plugin with federateToIdentityPool API and automatic token refresh

**Alternative Considered:** firebase_auth
**Why Rejected:** Different authentication flow, no direct Cognito integration

### Backend Integration
- **supabase_flutter: ^2.3.0** - Supabase client providing database queries and real-time listeners

**Alternative Considered:** Direct PostgreSQL client
**Why Rejected:** Missing real-time subscriptions, no built-in RLS support

### HTTP & Network
- **dio: ^5.4.0** - Advanced HTTP client with interceptors for streaming and retry logic
- **dio_cache_interceptor: ^3.5.0** - Response caching to reduce API calls and improve performance
- **connectivity_plus: ^5.0.2** - Network state detection for offline handling

**Alternative Considered:** http package
**Why Rejected:** Limited streaming support, no built-in interceptor system

### Stream Processing
- **rxdart: ^0.27.7** - Reactive extensions for audio/highlight synchronization
- **stream_transform: ^2.1.0** - Stream utilities for debouncing and throttling updates

**Alternative Considered:** Built-in Dart streams
**Why Rejected:** Missing advanced operators like debounce, throttle, combineLatest

### Local Storage
- **shared_preferences: ^2.2.2** - Lightweight key-value storage for settings, preferences, and cache
- **flutter_secure_storage: ^9.0.0** - Encrypted storage for sensitive tokens (optional)
- **flutter_cache_manager: ^3.3.1** - Audio segment caching for offline support

**Alternative Considered:** SQLite (sqflite)
**Why Rejected:** Overkill for simple preference storage, adds complexity

### UI Components
- **percent_indicator: ^4.2.3** - Visual progress indicators for courses and playback

**Alternative Considered:** Custom progress widgets
**Why Rejected:** Well-tested package saves development time

### Testing
- **mocktail: ^1.0.1** - Null-safety mocking without code generation
- **patrol: ^3.3.0** - Integration testing with native interaction support

**Alternative Considered:** mockito
**Why Rejected:** Requires code generation, more complex setup

## API Integration Decisions

### Speechify API Integration
**Base URL:** `https://api.sws.speechify.com`
**Main Endpoint:** `/v1/audio/speech`
**Response Format:** JSON with base64-encoded WAV audio and speech marks
**Valid Models:** `simba-turbo` (default), `simba-base`, `simba-english`, `simba-multilingual`
**Voice IDs:** `henry` (default), other voices available
**Required Parameters:** `input` (text), `voice_id`, `model`

**Why Speechify over alternatives:**
- Professional voice quality superior to Google/Amazon TTS
- Accurate word-level timing data with sentence indexing
- SSML processing for educational content
- Reliable API with good documentation
- Reasonable pricing for educational use

### AWS Cognito Integration
**Why Cognito over other auth providers:**
- Enterprise SSO integration required by client
- JWT token format compatible with Supabase
- Automatic token refresh reduces auth errors
- Scalable user pool management
- Integration with existing organizational identity providers

## Architecture Pattern Decisions

### Three-Tier Caching Strategy
**Level 1:** Memory cache for immediate access
**Level 2:** SharedPreferences for persistent local storage
**Level 3:** Supabase for cloud sync and backup

**Why this approach:**
- Optimal performance for frequently accessed data
- Offline capability with local persistence
- Cross-device sync through cloud storage
- Graceful degradation when network unavailable

### Debounced Progress Saves
**Implementation:** Save every 5 seconds during active playback
**Why not immediate saves:**
- Reduces database write load
- Prevents progress conflicts from rapid updates
- Battery optimization on mobile devices
- Network bandwidth conservation

### Binary Search for Word Positions
**Algorithm:** O(log n) search through pre-computed word positions
**Why not linear search:**
- Performance requirement of <5ms for 10,000 words
- Maintains 60fps during dual-level highlighting
- Scales efficiently with longer content
- Memory efficient with position caching