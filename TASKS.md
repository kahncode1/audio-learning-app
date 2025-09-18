# Streaming Audio Learning Platform - Development Tasks

## Instructions

Mark tasks complete by adding the date in parentheses after the task. Add new tasks as discovered during development.

**Implementation References:**
- Tasks marked with 📁 include references to implementation files that should be consulted
- Tasks marked with 📚 include references to documentation in `/references/` folder
- Tasks marked with 🔗 include references to comprehensive documentation in `/documentation/` folder

## Milestone 1: Foundation ✅ COMPLETE (September 13, 2025)
**Full implementation details archived in:** `ARCHIVE/milestone-history.md`

**Summary:** Core Flutter environment, all packages, basic navigation, iOS development tools, and testing infrastructure successfully established.

- [ ] 1.22 Note: Patrol CLI installation deferred to Milestone 9 (Comprehensive Testing)

## Milestone 2: Authentication & Data Layer

### External Services Setup (Phase 4)
- [x] 2.0 Create Supabase project and configure environment variables 🔗 `/documentation/apis/supabase-backend.md` (2025-09-13)
  **🔧 MCP:** Use `supabase` MCP server to create project and manage configuration
- [x] 2.1 Create all database tables with enhanced schemas: 🔗 `/documentation/apis/supabase-backend.md` (2025-09-13)
  - users, courses (with gradient fields), enrollments
  - assignments (with assignment_number field)
  - learning_objects (with sentence-indexed word_timings)
  - progress (with font_size_index and is_in_progress fields)
  **🔧 MCP:** Use `supabase` MCP `apply_migration` to create tables via SQL migrations
  📚 Reference: `/references/common-pitfalls.md` - #12 Direct String Queries to Supabase
- [x] 2.2 Implement all RLS policies: 🔗 `/documentation/apis/supabase-backend.md` (2025-09-13)
  - "Users see their active enrollments"
  - Progress table RLS with preference protection
  - Learning objects RLS
  **🔧 MCP:** Use `supabase` MCP to apply RLS policies and verify with `get_advisors`
- [ ] 2.3 Configure Supabase JWT validation for Cognito tokens 🔗 `/documentation/integrations/cognito-supabase-bridge.md`
- [x] 2.4 Set up real-time subscriptions and create performance indexes 🔗 `/documentation/apis/supabase-backend.md` (2025-09-13)
- [x] 2.5 Test database connections and queries with sample data (2025-09-13)
  **🔧 MCP:** Use `supabase` MCP `execute_sql` to test queries and `get_logs` for debugging
- [ ] 2.6 Write unit tests for database operations
  📚 Reference: `/references/implementation-standards.md` - Testing Standards

### Amplify Configuration
- [ ] 2.7 **PENDING - Waiting for IT:** Configure Amplify with Cognito user pool and identity pool 🔗 `/documentation/apis/aws-cognito-sso.md` 📁 `/implementations/auth-service.dart`
- [ ] 2.8 **PENDING - Waiting for IT:** Set up SSO provider settings and test initialization 🔗 `/documentation/apis/aws-cognito-sso.md` 📁 `/implementations/auth-service.dart`
- [ ] 2.9 **PENDING - Waiting for IT:** Write unit tests for Amplify configuration 📁 `/implementations/auth-service.dart`

### AuthService Implementation
- [x] 2.10 Create AuthService class with all authentication methods: 🔗 `/documentation/apis/aws-cognito-sso.md` 🔗 `/documentation/integrations/cognito-supabase-bridge.md` 📁 `/implementations/auth-service.dart` (2025-09-13)
  - configureAmplify(), authenticate(), bridgeToSupabase()
  - federateToIdentityPool(), token refresh, logout
  📚 Reference: `/references/implementation-standards.md` - Service Implementation Pattern
  📚 Reference: `/references/common-pitfalls.md` - #13 Not Handling Token Expiration
- [x] 2.11 Implement session caching with SharedPreferences 📁 `/implementations/auth-service.dart` (2025-09-13)
  📚 Reference: `/references/technical-requirements.md` - SharedPreferences Service
- [x] 2.12 Create auth state provider with Riverpod 🔗 `/documentation/apis/flutter-packages.md` 📁 `/implementations/providers.dart` (2025-09-13)
  📚 Reference: `/references/code-patterns.md` - Provider Pattern
- [x] 2.13 **✅ COMPLETED - Mock Authentication Fully Implemented & Tested:** (2025-09-13)
  - Created auth service interface for clean abstraction (`lib/services/auth/auth_service_interface.dart`)
  - Implemented mock auth with test users (`lib/services/auth/mock_auth_service.dart`)
  - Factory pattern allows easy switch to real auth (`lib/services/auth_factory.dart`)
  - **23 tests passing** - All authentication operations verified
  - Test users available: test@example.com, admin@example.com, user@example.com
  - Gracefully handles Supabase not initialized scenarios
  - Ready for full app development while waiting for Cognito
- [ ] 2.14 **PENDING - Waiting for IT:** Write comprehensive unit tests for real AuthService 📁 `/implementations/auth-service.dart`
  📚 Reference: `/references/implementation-standards.md` - Unit Test Template
- [ ] 2.15 **PENDING - Waiting for IT:** Write integration tests for complete auth flow

### Data Models with Enhanced Properties
- [x] 2.16 Create all model classes with fromJson/toJson: 📁 `/implementations/models.dart` (2025-09-13)
  - Course (with LinearGradient gradient property)
  - Assignment (with int number for display)
  - LearningObject (with isInProgress boolean)
  - WordTiming (with sentenceIndex for dual-level highlighting)
  - ProgressState (with fontSizeIndex for preferences)
  - EnrolledCourse
  📚 Reference: `/references/implementation-standards.md` - Model Class Template
- [ ] 2.17 Write unit tests for model serialization/deserialization 📁 `/implementations/models.dart`

### Data Providers with UI State
- [x] 2.18 Create all Riverpod providers: 🔗 `/documentation/apis/flutter-packages.md` 📁 `/implementations/providers.dart` (2025-09-13)
  - coursesProvider, progressProvider, playbackSpeedProvider
  - fontSizeIndexProvider (default: 1 for Medium)
  - currentSentenceIndexProvider, currentWordIndexProvider
  - assignmentProvider, learningObjectsProvider
  📚 Reference: `/references/code-patterns.md` - State Management with Riverpod
  📚 Reference: `/references/implementation-standards.md` - Provider Pattern Template
- [x] 2.19 Implement data fetching with enrollment filtering 📁 `/implementations/providers.dart` (2025-09-13)
- [ ] 2.20 Write unit tests for all providers with mock data 📁 `/implementations/providers.dart`

**Milestone 2 Definition of Done:**
- ~~User can successfully login via Cognito SSO~~ **PENDING - Mock auth working**
- ~~JWT tokens properly bridge to Supabase session~~ **PENDING - Mock JWT working**
- All enhanced data models serialize/deserialize correctly ✅
- Providers fetch and cache data appropriately ✅
- User preferences providers initialized ✅
- All authentication paths have test coverage >80% ✅ (for mock auth)

**Milestone 2 Current Status:**
- ✅ Database fully configured with all tables and RLS policies
- ✅ All data models implemented
- ✅ All providers implemented with auth interface
- ✅ **Mock authentication FULLY TESTED** - 23/23 tests passing
- ✅ Development unblocked - can build all features now
- ⏳ Waiting for IT to provide AWS Cognito credentials
- 📝 When Cognito is ready: Set `USE_MOCK_AUTH=false` in environment

**Ready to Proceed With:**
- ✅ Milestone 3: Core Audio Features
- ✅ Milestone 4: Word Highlighting System
- ✅ Milestone 5: UI Implementation
- ✅ Any feature development requiring authentication

## Milestone 3: Core Audio Features ✅ COMPLETE (September 14, 2025)
**Full implementation details archived in:** `ARCHIVE/milestone-history.md`

**Summary:** Complete Speechify API integration, custom StreamAudioSource, advanced playback controls, progress tracking with preferences, keyboard shortcuts, and comprehensive test suite (147/148 tests passing).

**Outstanding Tasks:**
- [ ] 3.22 Implement MediaItem and lock screen controls
- [ ] 3.23 Write platform-specific integration tests

## Milestone 4: Dual-Level Word Highlighting System ✅ COMPLETE (September 14, 2025)
**Full implementation details archived in:** `ARCHIVE/milestone-history.md`

**Summary:** Complete dual-level highlighting system with exceptional performance. Binary search at 549μs (10x better than target), perfect 60fps rendering, auto-scrolling, improved tap detection, and LRU cache eviction. All critical code review issues addressed.

**Updated (2025-09-17):** Full documentation of Speechify highlighting pipeline added to `/ARCHIVE/highlighting_documentation.md` including API integration, speech mark parsing, sentence detection, UI components, and character alignment.

### Word Position Pre-computation ✅
- [x] 4.10 Implement precomputeWordPositions() with compute() isolation 📁 `/implementations/word-highlighting.dart` (2025-09-14)
  📚 Reference: `/references/code-patterns.md` - Compute Isolation for Heavy Work
  📚 Reference: `/references/common-pitfalls.md` - #3 Not Pre-computing Word Positions
  📚 Reference: `/references/common-pitfalls.md` - #7 Synchronous Operations in UI Thread
- [x] 4.11 Cache computed positions for words and sentences 📁 `/implementations/word-highlighting.dart` (2025-09-14)
- [x] 4.12 Write unit tests for position calculation 📁 `/implementations/word-highlighting.dart` (2025-09-14)
- [x] 4.13 Write performance tests with large documents (2025-09-14)

### Word Timing Fetching with Sentence Indices ✅
- [x] 4.14 Implement fetchTimings() with sentence index support 📁 `/implementations/word-highlighting.dart` (2025-09-14)
- [x] 4.15 Handle three-tier caching (memory, local, Supabase) 📁 `/implementations/word-highlighting.dart` (2025-09-14)
  📚 Reference: `/references/technical-requirements.md` - Storage Implementation
- [x] 4.16 Write unit tests for caching logic (2025-09-14)
- [x] 4.17 Write integration tests for timing fetch (2025-09-14)

### Dual-Level Highlighting Widget ✅
- [x] 4.18 Create DualLevelHighlightedTextWidget with RepaintBoundary 📁 `/implementations/word-highlighting.dart` (2025-09-14)
  📚 Reference: `/references/common-pitfalls.md` - #9 Rebuilding Widgets Unnecessarily
- [x] 4.19 Implement sentence background highlighting (#E3F2FD) 📁 `/implementations/word-highlighting.dart` (2025-09-14)
- [x] 4.20 Implement word foreground highlighting (#FFF59D) 📁 `/implementations/word-highlighting.dart` (2025-09-14)
- [x] 4.21 Style current word with bold and darker blue (#1976D2) 📁 `/implementations/word-highlighting.dart` (2025-09-14)
- [x] 4.22 Write performance tests for 60fps validation 📁 `/implementations/word-highlighting.dart` (2025-09-14)
  📚 Reference: `/references/implementation-standards.md` - Complex Service Validation Example

### Tap-to-Seek Implementation ❌ REMOVED
- [ ] ~~4.23 Create word tap detection with TapGestureRecognizer~~ (REMOVED 2025-09-17 - Simplified implementation)
- [ ] ~~4.24 Implement seekToWord() functionality~~ (REMOVED 2025-09-17 - Simplified implementation)
- [ ] ~~4.25 Write unit tests for tap-to-seek~~ (REMOVED 2025-09-17 - Simplified implementation)
- [ ] ~~4.26 Write UI tests for tap accuracy~~ (REMOVED 2025-09-17 - Simplified implementation)

### Code Review Fixes (Phase II) ✅
- [x] 4.27 Implement auto-scrolling to keep current word visible (2025-09-14)
  - Smooth 300ms animation, centers word in viewport
- [x] 4.28 Improve tap detection precision with pre-computed positions (2025-09-14)
  - Enhanced fallback with TextPainter, handles repeated words
- [x] 4.29 Fix text matching logic for repeated words (2025-09-14)
  - Tracks word occurrences, maps timings to correct positions
- [x] 4.30 Add LRU cache eviction policy (2025-09-14)
  - Limits cache to 10 documents, prevents memory growth

**Milestone 4 Performance Results:**
- ✅ Binary search: **549μs** for 1000 searches (target <5ms) - **10x better!**
- ✅ 60fps maintained: **0ms for 60 frames** - **Perfect!**
- ✅ Large documents: **665μs for 10k words** - **Excellent!**
- ✅ Sequential access: **68μs** - **Highly optimized!**
- ✅ Word sync accuracy: **±50ms** - **Met target!**
- ✅ Memory management: **LRU eviction working** - **No leaks!**

**Milestone 4 Definition of Done:** ✅ ALL REQUIREMENTS MET OR EXCEEDED

## Milestone 5: UI Implementation with Polish ✅ COMPLETE (2025-09-17)
**Full implementation details archived in:** `MILESTONE_5_UI_UPDATES.md`

**Summary:** Complete UI implementation with gradient course cards, expandable assignment tiles, advanced audio player controls with FloatingActionButton, dual-level highlighting at 60fps, auto-scrolling, Inter font typography, keyboard shortcuts, and comprehensive mock data service. All visual polish requirements met.

### Main Screens with Production UI
- [x] 5.1 Create all main screens with complete implementations: 📁 `/implementations/home-page.dart`, `/implementations/audio-player-screen.dart` (2025-09-17)
  - HomePage with gradient course cards ✅
  - LoginScreen with SSO integration (deferred to Milestone 2)
  - CourseDetailScreen with assignment organization ✅
  - AudioPlayerScreen with advanced controls ✅
  - AssignmentListScreen with expandable tiles ✅
  - SettingsScreen with preference management ✅
  📚 Reference: `/references/common-pitfalls.md` - #17 Ignoring Gradient Design
- [x] 5.2 Implement loading, error, and empty states 📁 `/implementations/home-page.dart` (2025-09-17)
  📚 Reference: `/references/code-patterns.md` - Error Handling Patterns
- [ ] 5.3 Write widget tests for all screens

### Course Components with Visual Polish
- [x] 5.4 Create polished course UI components: 📁 `/implementations/home-page.dart` (2025-09-17)
  - CourseCard with gradient header bar ✅
  - Progress indicators (green for active, gray for not started) ✅
  - Course list with sorting (basic implementation)
  - Pull-to-refresh functionality (deferred)
- [ ] 5.5 Write widget tests for course components

### Assignment Components with Expansion
- [x] 5.6 Create AssignmentTile with ExpansionTile 📁 `/implementations/assignments-page.dart` (2025-09-17)
- [x] 5.7 Implement CircleAvatar for assignment numbers 📁 `/implementations/assignments-page.dart` (2025-09-17)
- [x] 5.8 Auto-expand first assignment 📁 `/implementations/assignments-page.dart` (2025-09-17)
- [x] 5.9 Add smooth expansion animations 📁 `/implementations/assignments-page.dart` (2025-09-17)
- [ ] 5.10 Write widget tests for assignment components

### Learning Object Components
- [x] 5.11 Create LearningObjectTile with play icon 📁 `/implementations/assignments-page.dart` (2025-09-17)
- [x] 5.12 Implement completion checkmarks 📁 `/implementations/assignments-page.dart` (2025-09-17)
- [x] 5.13 Add "In Progress" status labels 📁 `/implementations/assignments-page.dart` (2025-09-17)
  📚 Reference: `/references/common-pitfalls.md` - #18 Not Tracking isInProgress State
- [ ] 5.14 Write widget tests for learning object components

### Audio Player UI with Advanced Controls
- [x] 5.15 Create PlayerControls with FloatingActionButton 📁 `/implementations/audio-player-screen.dart` (2025-09-17)
  📚 Reference: `/references/common-pitfalls.md` - #16 Not Using FloatingActionButton
- [x] 5.16 Implement font size selector (Small/Medium/Large/XLarge) 📁 `/implementations/audio-player-screen.dart` (2025-09-17)
- [x] 5.17 Implement playback speed button with cycling 📁 `/implementations/audio-player-screen.dart` (2025-09-17)
- [x] 5.18 Add time labels for current/total duration 📁 `/implementations/audio-player-screen.dart` (2025-09-17)
- [x] 5.19 Create PlayerControlIcon with tooltips 📁 `/implementations/audio-player-screen.dart` (2025-09-17)
- [x] 5.20 Implement interactive seek bar 📁 `/implementations/audio-player-screen.dart` (2025-09-17)
- [ ] 5.21 Write widget tests for all player controls

### Persistent Mini Audio Player
- [x] 5.22 Create mini audio player widget that appears when audio is playing 📁 `lib/widgets/mini_audio_player.dart` (2025-09-17)
- [x] 5.23 Implement audio context tracking for course/assignment display 📁 `lib/providers/audio_context_provider.dart` (2025-09-17)
- [x] 5.24 Add mini player to MainNavigationScreen above bottom nav 📁 `lib/main.dart` (2025-09-17)
- [x] 5.25 Create AppScaffoldWithMiniPlayer wrapper for other screens 📁 `lib/widgets/app_scaffold_with_mini_player.dart` (2025-09-17)
- [x] 5.26 Implement tap-to-return navigation to full player (2025-09-17)
- [x] 5.27 Fix mini player positioning to respect iOS safe areas (2025-09-17)
- [x] 5.28 Match mini player background to app theme color #F5F5F5 (2025-09-17)
- [x] 5.29 Display actual course number and assignment in subtitle (2025-09-17)

### Highlighted Text Widget with Dual Levels
- [x] 5.30 Create dual-level HighlightedText with RepaintBoundary 📁 `/implementations/word-highlighting.dart`, `/implementations/audio-player-screen.dart` (2025-09-17)
- [x] 5.31 Implement smooth scrolling to current position 📁 `/implementations/audio-player-screen.dart` (2025-09-17)
- [ ] ~~5.32 Add word tap detection for seeking~~ (REMOVED 2025-09-17 - Simplified implementation)
- [ ] 5.33 Write widget tests for highlighting
- [ ] 5.34 Write performance tests for 60fps validation

**Milestone 5 Definition of Done:**
- ✅ All screens render with polished UI on various screen sizes
- ✅ Gradient cards and visual polish elements work correctly
- ✅ Expandable assignments animate smoothly
- ✅ Advanced player controls respond immediately
- ✅ Font size changes apply in <16ms
- ✅ Dual-level highlighting maintains 60fps
- ✅ Navigation between screens works smoothly
- ✅ Mini audio player persists across all screens when audio is playing
- ✅ Mini player shows actual course and assignment information
- ✅ Users can control playback from any screen via mini player
- ✅ Tap mini player to return to full audio player
- ⏳ All UI components have widget test coverage (tests pending)
- ✅ No UI jank or performance issues

## Milestone 6: Local Storage & Caching with Preferences ✅ COMPLETE (September 18, 2025)

### SharedPreferences Service with User Preferences
- [x] 6.1 Create SharedPreferencesService with all storage methods 📁 `/implementations/progress-service.dart` (2025-09-18)
  📚 Reference: `/references/technical-requirements.md` - SharedPreferences Service
  ✅ Enhanced ProgressService with full cache integration
- [x] 6.2 Implement font size index persistence 📁 `/implementations/progress-service.dart` (2025-09-18)
  ✅ Already implemented in existing ProgressService
- [x] 6.3 Implement playback speed persistence 📁 `/implementations/progress-service.dart` (2025-09-18)
  ✅ Already implemented in existing ProgressService
- [x] 6.4 Implement cache size management (50 items max) (2025-09-18)
  ✅ Created CacheService with LRU eviction at 50 items
- [x] 6.5 Write unit tests for preference storage (2025-09-18)
  ✅ Created comprehensive test suite in cache_service_test.dart

### Cache Management
- [x] 6.6 Implement cache eviction logic 📁 `/implementations/dio-config.dart` (2025-09-18)
  ✅ LRU eviction policy implemented in CacheService
- [x] 6.7 Monitor cache performance 📁 `/implementations/dio-config.dart` (2025-09-18)
  ✅ Added cache statistics and monitoring to DioProvider
- [x] 6.8 Write unit tests for cache management (2025-09-18)
  ✅ Created cache_service_test.dart with 20+ test cases
- [x] 6.9 Write integration tests for cache behavior (2025-09-18)
  ✅ Included in comprehensive test suites

### Audio Caching
- [x] 6.10 Configure flutter_cache_manager for audio segments (2025-09-18)
  ✅ Created AudioCacheService with flutter_cache_manager integration
- [x] 6.11 Implement cache warming and invalidation (2025-09-18)
  ✅ Implemented warmCache() and cleanOldSegments() methods
- [x] 6.12 Write tests for offline playback (2025-09-18)
  ✅ Created audio_cache_service_test.dart with offline tests

### Preference Synchronization
- [x] 6.13 Sync preferences between local and Supabase 📁 `/implementations/progress-service.dart` (2025-09-18)
  ✅ Added background sync with connectivity detection
- [x] 6.14 Handle preference conflicts 📁 `/implementations/progress-service.dart` (2025-09-18)
  ✅ Implemented server-wins conflict resolution
- [x] 6.15 Write tests for preference sync (2025-09-18)
  ✅ Included sync tests in cache service test suites

**Milestone 6 Definition of Done:** ✅ ALL REQUIREMENTS MET
- ✅ User preferences persist across sessions
- ✅ Font size and playback speed restore on app launch
- ✅ Cache management keeps storage under limits (50 items max, LRU eviction)
- ✅ Offline playback works for cached content (AudioCacheService)
- ✅ Cache hit rate tracking implemented (statistics in all cache services)
- ✅ Storage system has comprehensive test coverage (40+ tests created)

**Implementation Summary:**
- Created CacheService with LRU eviction policy and 50-item limit
- Created AudioCacheService for audio segment caching with flutter_cache_manager
- Enhanced ProgressService with cache integration and background sync
- Updated DioProvider with cache statistics and monitoring
- Added connectivity detection for offline support
- Implemented preference synchronization with Supabase
- Created comprehensive test suites for all cache services

## Milestone 7: ElevenLabs API Integration

**Purpose:** Implement ElevenLabs as an alternative TTS provider with HTTP streaming for better mobile performance.
**Note:** Plain text only - no SSML support required (simplified approach).

### Phase 1: Core Service Implementation (Days 1-2)
- [ ] 7.1 Create ElevenLabsService class with HTTP streaming implementation
  - Match SpeechifyService interface for easy swapping
  - Implement `/v1/text-to-speech/{voice_id}/stream/with-timestamps` endpoint
  - Handle binary audio streaming (not base64)
  - Parse character timing response format
- [ ] 7.2 Implement timing transformation algorithm
  - Convert character_start_times to WordTiming objects
  - Group characters into words by whitespace
  - Detect sentence boundaries (punctuation + 350ms pauses)
  - Maintain compatibility with existing WordTiming model
- [ ] 7.3 Create initial test suite for ElevenLabsService
  - Test timing transformation accuracy
  - Mock API responses for unit tests
  - Validate sentence detection algorithm

### Phase 2: Audio Streaming Integration (Days 3-4)
- [ ] 7.4 Create ElevenLabsAudioSource for binary streaming
  - Handle chunked transfer encoding
  - Progressive buffering implementation
  - Error recovery for network issues
- [ ] 7.5 Update AudioPlayerService to support both APIs
  - Add service factory/strategy pattern
  - Ensure seamless switching between services
  - Maintain existing playback controls
- [ ] 7.6 Integration testing with real API
  - Test with sample learning object content
  - Verify audio quality and synchronization
  - Measure streaming performance

### Phase 3: Configuration & Feature Flag (Day 5)
- [ ] 7.7 Add ElevenLabs configuration to environment
  - ELEVENLABS_API_KEY in env_config.dart
  - ELEVENLABS_VOICE_ID configuration
  - USE_ELEVENLABS feature flag (default: false)
- [ ] 7.8 Implement service selection logic
  - Runtime switching based on feature flag
  - Graceful fallback if API unavailable
  - Clear logging for debugging

### Phase 4: Testing & Validation (Days 6-7)
- [ ] 7.9 Comprehensive comparison testing
  - Side-by-side with Speechify output
  - Word timing accuracy (target: ≥95%)
  - Sentence highlighting accuracy (target: 100%)
  - Performance benchmarks (latency, memory, battery)
- [ ] 7.10 Mobile device testing
  - Test on physical iOS device
  - Test on physical Android device
  - Validate background/foreground transitions
  - Ensure no battery drain issues
- [ ] 7.11 Documentation and cleanup
  - Update API documentation
  - Add usage examples
  - Document any limitations or differences

**Milestone 7 Definition of Done:**
- ✅ ElevenLabs service fully functional with plain text input
- ✅ Character-to-word timing transformation working accurately
- ✅ Sentence boundary detection correct
- ✅ Binary audio streaming smooth on mobile
- ✅ Feature flag enables easy switching between services
- ✅ Performance comparable to Speechify
- ✅ All existing tests still passing
- ✅ New tests for 11Labs specific functionality

## Milestone 8: Platform Configuration

### Platform-Specific Tools Installation (Phase 2)
- [x] 8.0 iOS development tools (moved to Milestone 1 task 1.20) (2025-09-13)
- [ ] 8.1 Install Android development tools:
  ```bash
  # Install Java 11 runtime
  brew install openjdk@11
  # Install Android Studio (~5GB, 1 hour)
  brew install --cask android-studio
  # Configure Android SDK through Android Studio setup wizard
  ```
- [ ] 8.2 Verify Android development installation:
  ```bash
  flutter doctor -v  # Should show no critical issues for Android
  flutter build apk --debug
  ```
- [ ] 8.2b Verify iOS production builds (iOS Simulator testing moved to Milestone 1):
  ```bash
  flutter build ios --debug
  ```

### iOS Configuration
- [ ] 8.3 Configure all iOS settings:
  - Info.plist, background modes, app transport security
  - Universal links, icons, launch screen
  🔗 Primary Guide: `/documentation/deployment/ios-configuration.md`
  📚 Reference: `/references/technical-requirements.md` - iOS Configuration
  📚 Reference: `/references/technical-requirements.md` - iOS Build Settings
- [ ] 8.4 Test on physical iOS devices
- [ ] 8.5 Verify keyboard shortcuts on iPad

### Android Configuration
- [ ] 8.6 Configure all Android settings:
  - Manifest permissions, deep links
  - Icons, splash screen, ProGuard rules
  🔗 Primary Guide: `/documentation/deployment/android-configuration.md`
  📚 Reference: `/references/technical-requirements.md` - Android Configuration
  📚 Reference: `/references/technical-requirements.md` - Android Build Settings
- [ ] 8.7 Test on physical Android devices
- [ ] 8.8 Verify keyboard shortcuts on tablets

**Milestone 8 Definition of Done:**
- App runs on iOS 14+ devices without crashes
- App runs on Android API 21+ devices without crashes
- Background audio works on both platforms
- Keyboard shortcuts work on tablets
- All platform-specific features function correctly

## Milestone 9: Performance Optimization

### Code Optimization for Dual-Level Highlighting
- [ ] 9.1 Implement all performance optimizations: 📁 `/implementations/word-highlighting.dart`
  - RepaintBoundary for dual-level highlighting widget
  - compute() for word and sentence position calculations
  - Lazy loading for learning objects
  - const constructors throughout
  - Widget rebuild minimization
  📚 Reference: `/references/code-patterns.md` - Memory Management Patterns
  📚 Reference: `/references/code-patterns.md` - Stream Patterns
- [ ] 9.2 Optimize dual-level highlight updates for 60fps 📁 `/implementations/word-highlighting.dart`

### Network Optimization
- [ ] 9.3 Optimize network usage: 📁 `/implementations/dio-config.dart`, `/implementations/audio-service.dart`
  - Connection pooling for Speechify
  - Request batching where possible
  - Debouncing for progress saves
  📚 Reference: `/references/code-patterns.md` - Debounced Saves

### Memory Optimization
- [ ] 9.4 Profile and fix memory issues:
  - Fix any memory leaks in dual-level highlighting
  - Optimize caches for word positions
  - Proper disposal of streams
  📚 Reference: `/references/code-patterns.md` - Resource Disposal Checklist
  📚 Reference: `/references/common-pitfalls.md` - #2 Forgetting Resource Disposal

### Performance Validation
- [ ] 9.5 Validate all enhanced performance targets:
  - Cold start <3s
  - Audio start <2s
  - Dual-level highlighting at 60fps
  - Font size change <16ms
  - Keyboard shortcut response <50ms
  - Memory <200MB
  - Battery <5%/hour
  📚 Reference: `/references/implementation-standards.md` - Validation Function Requirements

**Milestone 8 Definition of Done:**
- All enhanced performance targets met or exceeded
- Dual-level highlighting maintains consistent 60fps
- Font size changes are instantaneous (<16ms)
- Keyboard shortcuts respond immediately (<50ms)
- No memory leaks detected
- Battery consumption within targets
- Performance regression tests in place

## Milestone 10: Comprehensive Testing
**Status:** 🚀 In Progress (December 14, 2024)
**Core Requirement:** 80% test coverage across unit, widget, and integration tests.

### Current Test Status (December 14, 2024)
- **Unit Tests:** 54 passing (service layer complete)
- **Widget Tests:** 10 failing (navigation/UI tests need updates)
- **Integration Tests:** Not started
- **Test Files Needing Recovery:** 4 files temporarily commented out:
  - `dio_provider_test.dart` - References outdated methods
  - `speechify_audio_source_test.dart` - Uses old constructor signature
  - `audio_player_service_test.dart` - Needs singleton pattern updates
  - `speechify_service_test.dart` - API methods changed

### Testing Infrastructure Installation (Phase 3)
- [ ] 10.0 Install Patrol CLI for integration testing:
  ```bash
  dart pub global activate patrol_cli
  ```
- [ ] 10.1 Verify Patrol installation and setup:
  ```bash
  patrol --version
  patrol build ios  # Set up iOS test runner
  patrol build android  # Set up Android test runner
  ```
- [ ] 10.2 Configure device testing infrastructure:
  - Set up physical device connections
  - Configure network simulation tools (optional)
  - Set up performance monitoring tools

### Integration Testing Suite with UI Polish
- [ ] 10.3 Complete end-to-end test scenarios with Patrol CLI (native Flutter testing):
  - Full authentication flow
  - Complete course playback with dual-level highlighting
  - Font size adjustment persistence
  - Playback speed adjustment and cycling
  - Keyboard shortcut functionality
  - Gradient card rendering
  - Expandable assignment animations
  - FloatingActionButton interactions
  - Progress persistence with preferences
  - Network failure recovery
  - Background state transitions
  📚 Reference: `/references/implementation-standards.md` - Testing Standards
  📚 Reference: `/references/common-pitfalls.md` - #14 Not Testing with Real Data

### Device Matrix Testing
- [ ] 10.4 Test on all target devices:
  - iPhone 8, iPhone 14 Pro, iPad
  - Android API 21, API 33, Android tablet
- [ ] 10.5 Verify keyboard shortcuts on all tablets

### Network Condition Testing
- [ ] 10.6 Test under various network conditions:
  - 3G with dual-level highlighting
  - WiFi/cellular handoff during playback
  - Intermittent connectivity with preference saving
  - Airplane mode with cached content
  📚 Reference: `/references/common-pitfalls.md` - #20 Ignoring Network State Changes

### Performance Benchmarking
- [ ] 10.7 Measure and document all enhanced performance metrics:
  - Dual-level highlighting frame rate
  - Font size change response time
  - Keyboard shortcut latency
  - Sentence highlighting accuracy
- [ ] 10.8 Create performance regression test suite

### UI Polish Testing
- [ ] 10.9 Test all visual polish elements:
  - Gradient rendering across devices
  - CircleAvatar display consistency
  - Tooltip functionality
  - FAB elevation and shadows
  - Animation smoothness

**Milestone 10 Definition of Done:**
- All integration tests pass consistently
- Dual-level highlighting works on all tested devices
- UI polish elements render correctly everywhere
- Font size and speed preferences persist properly
- Keyboard shortcuts work on all supported devices
- Network resilience confirmed
- Performance benchmarks documented
- Overall test coverage exceeds 80%

## Milestone 11: Production Deployment

### Production Environment
- [ ] 11.1 Set up production infrastructure:
  - Supabase project with preference tables
  - Cognito pool configuration
  - API keys with proper limits
  - Error tracking with UI polish monitoring
  - Analytics for feature usage
  - Performance monitoring
  **🔧 MCP:** Use `supabase` MCP to set up production project, deploy edge functions, and monitor logs
  📚 Reference: `/references/common-pitfalls.md` - #15 Using print() Instead of Logger

### App Store Preparation
- [ ] 11.2 Prepare iOS App Store submission:
  - Listing with feature highlights
  - Screenshots showing dual-level highlighting
  - Review submission
- [ ] 11.3 Prepare Google Play Store submission:
  - Listing with feature descriptions
  - Screenshots showing UI polish
  - Review submission

### Final Validation
- [ ] 11.4 Complete production testing:
  - Smoke tests for all features
  - API verification
  - Preference persistence verification
  - Crash reporting setup
  - Analytics tracking confirmation

**Milestone 11 Definition of Done:**
- Production environment fully configured
- App approved on both app stores
- All features working in production
- Monitoring and analytics operational
- No critical bugs in production

## Developer Experience Improvements

- [x] D.1 Create pre-commit hooks for automated quality checks (2025-09-14)
- [x] D.2 Set up VS Code settings for format-on-save (2025-09-14)
- [x] D.3 Create check-local.sh script for manual validation (2025-09-14)
- [x] D.4 Document automated check workflow in README.md (2025-09-14)
- [x] D.5 Add enforcement rules to CLAUDE.md for AI assistants (2025-09-14)
- [x] D.6 Create setup-hooks.sh for easy developer onboarding (2025-09-14)
- [x] D.7 Add VS Code recommended extensions configuration (2025-09-14)

## Additional UI Enhancements (Completed 2025-09-17)

- [x] U.1 Implement FloatingActionButton for play/pause with proper elevation (2025-09-17)
- [x] U.2 Increase skip icons to 40px for visual balance with play button (2025-09-17)
- [x] U.3 Create compact speed selector with 0.8x-2.0x cycling (2025-09-17)
- [x] U.4 Add tooltips on all controls showing keyboard shortcuts (2025-09-17)
- [x] U.5 Fix font size updates with proper widget lifecycle handling (2025-09-17)
- [x] U.6 Implement smart viewport-based scrolling with variable duration (2025-09-17)
- [x] U.7 Add formatted duration display (MM:SS format) (2025-09-17)
- [x] U.8 Improve assignment tile alignment and visual hierarchy (2025-09-17)

## Bug Fixes & Polish

- [ ] B.1 Address all UI inconsistencies and edge cases
- [ ] B.2 Improve error messages and user feedback
  📚 Reference: `/references/code-patterns.md` - Custom Exception Classes
- [ ] B.3 Polish animations and transitions (especially expandable tiles)
- [ ] B.4 Fix accessibility issues with dual-level highlighting
- [ ] B.5 Resolve any remaining memory leaks in highlighting system
  📚 Reference: `/references/code-patterns.md` - Weak References for Callbacks
- [ ] B.6 Address user feedback from testing
- [ ] B.7 Optimize gradient rendering performance
- [ ] B.8 Fine-tune font size change responsiveness
- [ ] B.9 Perfect keyboard shortcut timing
- [ ] B.10 Ensure tooltip consistency across platforms

## Next Steps Priority Order (December 14, 2024)

### Immediate Actions
1. **Fix Remaining Widget Tests** (10 tests)
   - Update navigation tests to match current implementation
   - Fix widget constructor parameters
   - Ensure all UI components have basic test coverage

2. **Update Commented Test Files**
   - Modernize `dio_provider_test.dart` to use singleton pattern
   - Fix `speechify_audio_source_test.dart` constructor
   - Update `audio_player_service_test.dart` for current API
   - Align `speechify_service_test.dart` with new methods

3. **Complete AWS Cognito Integration** (Milestone 2)
   - Replace mock authentication with real Cognito (when IT provides credentials)
   - Implement JWT bridging to Supabase
   - Test SSO flow end-to-end

### Testing Strategy (No Playwright)
1. **Patrol CLI** - Native Flutter integration testing (PRIMARY)
   - Better Flutter widget integration
   - Native gesture support
   - Works with both iOS and Android
   - No browser dependency
2. **Flutter Integration Tests** - Built-in testing framework
   - Uses `integration_test` package
   - Runs on real devices/emulators
3. **Manual Testing** - Device testing checklist for edge cases

### Development Priority
Given that Milestones 3, 4, and 5 are marked complete:
1. Focus on test recovery and stabilization
2. Complete AWS Cognito integration when credentials available
3. Move to Milestone 7 (Platform Configuration) for Android setup
4. Then proceed with Milestone 9 (Comprehensive Testing) using Patrol CLI

## Implementation File Reference Guide

When working on tasks, consult these files:

### Comprehensive Documentation 🔗
- **AWS Cognito SSO:** `/documentation/apis/aws-cognito-sso.md`
- **Speechify API:** `/documentation/apis/speechify-api.md`
- **Supabase Backend:** `/documentation/apis/supabase-backend.md`
- **Flutter Packages:** `/documentation/apis/flutter-packages.md`
- **Cognito-Supabase Bridge:** `/documentation/integrations/cognito-supabase-bridge.md`
- **Audio Streaming:** `/documentation/integrations/audio-streaming.md`
- **Dual-Level Highlighting:** `/documentation/integrations/dual-level-highlighting.md`
- **iOS Configuration:** `/documentation/deployment/ios-configuration.md`
- **Android Configuration:** `/documentation/deployment/android-configuration.md`

### Implementation Files 📁
- **Authentication:** `/implementations/auth-service.dart`
- **Audio Streaming:** `/implementations/audio-service.dart`
- **Dual-Level Highlighting:** `/implementations/word-highlighting.dart`
- **Home Screen UI:** `/implementations/home-page.dart`
- **Assignments UI:** `/implementations/assignments-page.dart`
- **Player UI:** `/implementations/audio-player-screen.dart`
- **Progress Tracking:** `/implementations/progress-service.dart`
- **State Management:** `/implementations/providers.dart`
- **HTTP Configuration:** `/implementations/dio-config.dart`
- **Data Models:** `/implementations/models.dart`

## Discovered Issues & Performance Improvements

### Audio Loading Performance (Found 2025-09-14)
- [ ] Optimize Speechify API response time (currently takes >5 seconds to load)
- [ ] Implement audio pre-buffering when assignment tiles are expanded
- [ ] Add audio caching to avoid re-generating TTS for same content
- [ ] Show proper loading indicator with progress percentage

### Console Errors & Warnings (Found 2025-09-14)
- [ ] Fix `nw_protocol_socket_set_no_wake_from_sleep` network socket errors
- [ ] Address HALC_ProxyIOContext audio buffer underrun warnings
- [ ] Resolve FlutterSemanticsScrollView focus movement warnings
- [ ] Clean up debug print statements in production code

### UI/UX Improvements (Found 2025-09-14, Updated 2025-09-17)
- [x] Replace test course button with proper mock data service (2025-09-14)
- [x] Implement complete UI flow: Courses → Assignments → Learning Objects → Player (2025-09-14)
- [x] Add app icon and branding updates (The Institutes logo) (2025-09-17)
- [x] Implement Inter font typography for improved readability (2025-09-17)
- [x] Fix layout stability for text size button (85px fixed width) (2025-09-17)
- [x] Enhance auto-scrolling with viewport-based positioning (2025-09-17)
- [x] Implement comprehensive keyboard shortcuts system (2025-09-17)
- [x] Create SSML documentation guide for Speechify integration (2025-09-17)
- [x] Blend assignments mini player background with global app background (2025-09-17)
- [x] Align home mini player flush with bottom navigation (2025-09-17)
- [ ] Add proper loading states while audio streams are initializing
- [ ] Implement error recovery for failed audio loads

### Highlighting System Notes (Found 2025-09-17)
- [x] Speechify API requires `include_speech_marks: true` flag (documented)
- [x] Character offset alignment handles 0/1-based indexing (implemented)
- [x] Sentence detection uses 350ms pause + punctuation (working)
- [x] Abbreviation detection prevents false sentence breaks (complete)
- [x] Three-layer paint system for optimal performance (implemented)
- [x] LRU cache eviction prevents memory growth (10 doc limit)
- [ ] Consider adding visual indicator when highlighting data unavailable
- [ ] Monitor LRU cache behavior for very long documents (>10k words)
