# Service Architecture Documentation
## Audio Learning App - Download-First Architecture

**Created:** 2025-09-19
**Status:** Post-Migration (Download-First)
**Purpose:** Document service relationships and dependencies

---

## 🏗️ Service Layer Architecture

### Core Service Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (Screens/Widgets)               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  EnhancedAudioPlayerScreen                                 │
│         ↓                ↓                                 │
│  AudioPlayerServiceLocal ←→ WordTimingServiceSimplified    │
│         ↓                           ↓                      │
│  LocalContentService ←──────────────┘                      │
│         ↓                                                  │
│  [Local File System]                                       │
│                                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Service Inventory

### Critical Services (DO NOT MODIFY)

#### 1. WordTimingServiceSimplified (`word_timing_service_simplified.dart`)
- **Purpose:** Manages word and sentence timing data for highlighting
- **Critical Features:**
  - Binary search for position lookup (<1ms requirement)
  - LRU cache for timing data (10 items max)
  - Stream-based position updates via RxDart
- **Dependencies:** LocalContentService, RxDart
- **Used By:** EnhancedAudioPlayerScreen, SimplifiedDualLevelHighlightedText
- **⚠️ WARNING:** Core component of highlighting system - DO NOT RENAME OR REFACTOR

#### 2. AudioPlayerServiceLocal (`audio_player_service_local.dart`)
- **Purpose:** Manages local MP3 playback
- **Critical Features:**
  - Singleton pattern for single audio instance
  - Integration with WordTimingServiceSimplified
  - Position stream updates for highlighting sync
- **Dependencies:** just_audio, LocalContentService, WordTimingServiceSimplified
- **Used By:** EnhancedAudioPlayerScreen, audio providers
- **Note:** "Local" suffix indicates download-first architecture

### Content Services

#### 3. LocalContentService (`local_content_service.dart`)
- **Purpose:** Manages access to downloaded content files
- **Features:**
  - Loads content.json, audio.mp3, timing.json
  - Provides unified content access API
  - Handles file system operations
- **Dependencies:** File system, path_provider
- **Used By:** AudioPlayerServiceLocal, WordTimingServiceSimplified, CourseDownloadService

#### 4. CourseDownloadService (`course_download_service.dart`)
- **Purpose:** Downloads and manages course content from CDN
- **Features:**
  - Progress tracking during downloads
  - Connectivity-aware downloading
  - Batch download management
- **Dependencies:** Dio, LocalContentService, connectivity_plus
- **Used By:** Download screens, progress tracking

### Support Services

#### 5. CacheService (`cache_service.dart`)
- **Purpose:** General-purpose LRU cache for app data
- **Features:**
  - 50 item limit with LRU eviction
  - SharedPreferences backed
  - Cache statistics tracking
- **Used By:** ProgressService, general app caching

#### 6. AudioCacheService (`audio_cache_service.dart`)
- **Purpose:** Manages audio file caching (legacy from streaming)
- **Features:**
  - File-based caching via flutter_cache_manager
  - Network-aware caching
  - 100MB cache limit
- **Note:** Less relevant in download-first architecture

#### 7. ProgressService (`progress_service.dart`)
- **Purpose:** Manages learning progress and user preferences
- **Features:**
  - Debounced progress saving (5-second intervals)
  - Font size persistence
  - Playback speed persistence
  - Local/cloud sync
- **Dependencies:** SharedPreferences, Supabase, RxDart
- **Used By:** EnhancedAudioPlayerScreen, settings

#### 8. SupabaseService (`supabase_service.dart`)
- **Purpose:** Manages Supabase client and database operations
- **Features:**
  - Singleton Supabase client
  - Auth state management
  - Database query helpers
- **Used By:** Data services, authentication

### Authentication Services

#### 9. AuthService (`auth_service.dart`)
- **Purpose:** Production authentication via AWS Cognito
- **Features:**
  - SSO authentication
  - Token management
  - Session persistence

#### 10. MockAuthService (`auth/mock_auth_service.dart`)
- **Purpose:** Development authentication bypass
- **Features:**
  - Test user simulation
  - Quick development access
- **Note:** Remove before production

#### 11. AuthFactory (`auth_factory.dart`)
- **Purpose:** Factory pattern for auth service selection
- **Features:**
  - Returns MockAuthService or AuthService based on config

---

## 🔄 Critical Data Flows

### 1. Audio Playback with Highlighting

```
1. User selects learning object
   ↓
2. AudioPlayerServiceLocal.loadAndPlay()
   → Loads audio.mp3 from LocalContentService
   → Loads timing.json from LocalContentService
   → Shares timing data with WordTimingServiceSimplified
   ↓
3. WordTimingServiceSimplified.setCachedTimings()
   → Caches timing data in memory
   → Prepares for position lookups
   ↓
4. Audio playback starts
   → Position updates stream to UI
   → SimplifiedDualLevelHighlightedText queries current word/sentence
   → Highlighting updates at 60fps
```

### 2. Content Download Flow

```
1. User initiates download
   ↓
2. CourseDownloadService.downloadCourse()
   → Fetches content from Supabase CDN
   → Downloads content.json, audio.mp3, timing.json
   → Saves to app's documents directory
   ↓
3. LocalContentService provides access
   → Returns file paths and content
   → Used by audio player and timing services
```

---

## ⚠️ Architecture Constraints

### DO NOT MODIFY
1. **WordTimingServiceSimplified** - Core highlighting component
2. **SimplifiedDualLevelHighlightedText** - Custom highlighting widget
3. **Binary search implementation** - Performance critical (<1ms)
4. **Three-layer paint system** - 60fps requirement
5. **TextPainter lifecycle** - Must remain immutable during paint

### Service Naming Rationale
- **"Simplified" suffix:** Indicates migration from complex streaming version
- **"Local" suffix/prefix:** Indicates download-first architecture
- **"Mock" prefix:** Development-only services

### Performance Requirements
- Binary search: <1ms
- Paint cycles: <16ms (60fps)
- Audio start: <100ms (local files)
- Font size change: <16ms

---

## 🔧 Maintenance Guidelines

### Adding New Services
1. Follow singleton pattern for stateful services
2. Implement proper disposal methods for streams
3. Document dependencies clearly
4. Add validation function at end of file

### Modifying Existing Services
1. **NEVER** modify WordTimingServiceSimplified without extensive testing
2. **NEVER** rename critical services (breaks too many dependencies)
3. Test highlighting at 60fps after any changes
4. Run validation functions after modifications

### Testing Requirements
- Unit tests for all public methods
- Integration tests for service interactions
- Performance tests for timing-critical code
- 60fps validation for highlighting changes

---

## 📈 Metrics to Monitor

### Performance
- Binary search time: Target <1ms, Current: 549μs ✅
- Paint cycle time: Target <16ms, Current: ~0ms ✅
- Memory usage: Target <200MB, Current: ~150MB ✅

### Code Quality
- Service count: 11 services (optimal for app size)
- Singleton patterns: Properly implemented ✅
- Stream disposal: All streams properly closed ✅
- Documentation: All services documented ✅

---

**Last Updated:** 2025-09-19
**Next Review:** After any major feature addition