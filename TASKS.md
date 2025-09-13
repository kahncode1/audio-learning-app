# Streaming Audio Learning Platform - Development Tasks

## Instructions

Mark tasks complete by adding the date in parentheses after the task. Add new tasks as discovered during development.

**Implementation References:**
- Tasks marked with 📁 include references to implementation files that should be consulted
- Tasks marked with 📚 include references to documentation in `/references/` folder
- Tasks marked with 🔗 include references to comprehensive documentation in `/documentation/` folder

## Milestone 1: Foundation

### Core Development Environment Setup (Phase 1)
- [x] 1.0 Install Homebrew package manager (2025-09-13)
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
- [x] 1.1 Install Flutter SDK and Dart SDK via Homebrew (2025-09-13)
  ```bash
  brew install flutter
  ```
- [x] 1.2 Add Flutter to PATH in shell profile and verify installation (2025-09-13)
  ```bash
  flutter doctor
  ```
- [x] 1.3 Install core project dependencies (2025-09-13)
  ```bash
  flutter pub get
  ```
- [x] 1.4 Verify core development environment (2025-09-13)
  ```bash
  flutter analyze && flutter test
  ```

### Project Setup
- [x] 1.5 Initialize Flutter project with name "audio_learning_app" (2025-09-13)
- [x] 1.6 Set up Git repository and .gitignore file (2025-09-13)
- [x] 1.7 Create project folder structure (lib/services, lib/models, lib/screens, lib/widgets, lib/providers) (2025-09-13)
  📚 Reference: `/references/implementation-standards.md` - Service Implementation Pattern
- [x] 1.8 Configure environment variables file for API keys (2025-09-13)
  📚 Reference: `/references/common-pitfalls.md` - #11 Hardcoding API Endpoints or Keys
- [x] 1.9 Create README.md with setup instructions (2025-09-13)
- [ ] 1.10 Set up CI/CD pipeline configuration files
- [x] 1.11 Set up VS Code or Android Studio with Flutter extensions (basic - platform-specific setup deferred to Milestone 7) (2025-09-13)

### Package Installation
- [x] 1.12 Add all required packages to pubspec.yaml and run flutter pub get: (2025-09-13) 🔗 `/documentation/apis/flutter-packages.md`
  - Core: riverpod (^2.4.9), flutter_riverpod (^2.4.9)
  - Audio: just_audio (^0.9.36), just_audio_background (^0.0.1-beta.11), audio_session (^0.1.18)
  - Auth: amplify_flutter (^2.0.0), amplify_auth_cognito (^2.0.0)
  - Backend: supabase_flutter (^2.3.0)
  - HTTP: dio (^5.4.0), dio_cache_interceptor (^3.5.0)
  - Network: connectivity_plus (^5.0.2)
  - Streams: rxdart (^0.27.7), stream_transform (^2.1.0)
  - Storage: shared_preferences (^2.2.2), flutter_secure_storage (^9.0.0), flutter_cache_manager (^3.3.1)
  - UI: percent_indicator (^4.2.3)
  - Testing: mocktail (^1.0.1), patrol (^3.3.0)

### Core Navigation Structure (No External Dependencies)
- [x] 1.13 Create MainApp widget with MaterialApp and Material 2 theme (#2196F3 primary) (2025-09-13) 📁 `/implementations/home-page.dart`
- [x] 1.14 Implement basic navigation routes and bottom navigation structure (2025-09-13) 📁 `/implementations/home-page.dart`
- [x] 1.15 Create all placeholder screens (Splash, Home, Course, Player, Settings) (2025-09-13) 📁 `/implementations/home-page.dart`, `/implementations/audio-player-screen.dart`
- [x] 1.16 Write widget tests for navigation flow (2025-09-13)
  📚 Reference: `/references/implementation-standards.md` - Testing Standards

### Basic Testing Setup (Core Only)
- [x] 1.17 Set up basic Mocktail configuration for unit tests (2025-09-13)
- [x] 1.18 Create test folder structure and utilities (2025-09-13)
  📚 Reference: `/references/implementation-standards.md` - Unit Test Template
- [x] 1.19 Configure code coverage and create smoke tests (2025-09-13)
- [ ] 1.20 Note: Patrol CLI installation deferred to Milestone 9 (Comprehensive Testing)

**Milestone 1 Definition of Done:**
- Core development environment fully functional (Flutter, Dart, Homebrew)
- All Flutter packages installed without version conflicts (`flutter pub get` successful)
- `flutter doctor` reports no critical issues for core development
- Basic navigation between placeholder screens works (no external services)
- Unit test infrastructure runs successfully
- Project can be analyzed and tested with `flutter analyze` and `flutter test`
- **Note:** Platform builds (iOS/Android), external services (Supabase/Cognito), and integration testing deferred to later milestones

## Milestone 2: Authentication & Data Layer

### External Services Setup (Phase 4)
- [ ] 2.0 Create Supabase project and configure environment variables 🔗 `/documentation/apis/supabase-backend.md`
- [ ] 2.1 Create all database tables with enhanced schemas: 🔗 `/documentation/apis/supabase-backend.md`
  - users, courses (with gradient fields), enrollments
  - assignments (with assignment_number field)
  - learning_objects (with sentence-indexed word_timings)
  - progress (with font_size_index and is_in_progress fields)
  📚 Reference: `/references/common-pitfalls.md` - #12 Direct String Queries to Supabase
- [ ] 2.2 Implement all RLS policies: 🔗 `/documentation/apis/supabase-backend.md`
  - "Users see their active enrollments"
  - Progress table RLS with preference protection
  - Learning objects RLS
- [ ] 2.3 Configure Supabase JWT validation for Cognito tokens 🔗 `/documentation/integrations/cognito-supabase-bridge.md`
- [ ] 2.4 Set up real-time subscriptions and create performance indexes 🔗 `/documentation/apis/supabase-backend.md`
- [ ] 2.5 Test database connections and queries with sample data
- [ ] 2.6 Write unit tests for database operations
  📚 Reference: `/references/implementation-standards.md` - Testing Standards

### Amplify Configuration
- [ ] 2.7 Configure Amplify with Cognito user pool and identity pool 🔗 `/documentation/apis/aws-cognito-sso.md` 📁 `/implementations/auth-service.dart`
- [ ] 2.8 Set up SSO provider settings and test initialization 🔗 `/documentation/apis/aws-cognito-sso.md` 📁 `/implementations/auth-service.dart`
- [ ] 2.9 Write unit tests for Amplify configuration 📁 `/implementations/auth-service.dart`

### AuthService Implementation
- [ ] 2.10 Create AuthService class with all authentication methods: 🔗 `/documentation/apis/aws-cognito-sso.md` 🔗 `/documentation/integrations/cognito-supabase-bridge.md` 📁 `/implementations/auth-service.dart`
  - configureAmplify(), authenticate(), bridgeToSupabase()
  - federateToIdentityPool(), token refresh, logout
  📚 Reference: `/references/implementation-standards.md` - Service Implementation Pattern
  📚 Reference: `/references/common-pitfalls.md` - #13 Not Handling Token Expiration
- [ ] 2.11 Implement session caching with SharedPreferences 📁 `/implementations/auth-service.dart`
  📚 Reference: `/references/technical-requirements.md` - SharedPreferences Service
- [ ] 2.12 Create auth state provider with Riverpod 🔗 `/documentation/apis/flutter-packages.md` 📁 `/implementations/providers.dart`
  📚 Reference: `/references/code-patterns.md` - Provider Pattern
- [ ] 2.13 Add biometric unlock support (optional)
- [ ] 2.14 Write comprehensive unit tests for AuthService 📁 `/implementations/auth-service.dart`
  📚 Reference: `/references/implementation-standards.md` - Unit Test Template
- [ ] 2.15 Write integration tests for complete auth flow

### Data Models with Enhanced Properties
- [ ] 2.16 Create all model classes with fromJson/toJson: 📁 `/implementations/models.dart`
  - Course (with LinearGradient gradient property)
  - Assignment (with int number for display)
  - LearningObject (with isInProgress boolean)
  - WordTiming (with sentenceIndex for dual-level highlighting)
  - ProgressState (with fontSizeIndex for preferences)
  - EnrolledCourse
  📚 Reference: `/references/implementation-standards.md` - Model Class Template
- [ ] 2.17 Write unit tests for model serialization/deserialization 📁 `/implementations/models.dart`

### Data Providers with UI State
- [ ] 2.18 Create all Riverpod providers: 🔗 `/documentation/apis/flutter-packages.md` 📁 `/implementations/providers.dart`
  - coursesProvider, progressProvider, playbackSpeedProvider
  - fontSizeIndexProvider (default: 1 for Medium)
  - currentSentenceIndexProvider, currentWordIndexProvider
  - assignmentProvider, learningObjectsProvider
  📚 Reference: `/references/code-patterns.md` - State Management with Riverpod
  📚 Reference: `/references/implementation-standards.md` - Provider Pattern Template
- [ ] 2.19 Implement data fetching with enrollment filtering 📁 `/implementations/providers.dart`
- [ ] 2.20 Write unit tests for all providers with mock data 📁 `/implementations/providers.dart`

**Milestone 2 Definition of Done:**
- User can successfully login via Cognito SSO
- JWT tokens properly bridge to Supabase session
- All enhanced data models serialize/deserialize correctly
- Providers fetch and cache data appropriately
- User preferences providers initialized
- All authentication paths have test coverage >80%

## Milestone 3: Core Audio Features

### Dio Configuration
- [ ] 3.1 Create DioProvider with configured interceptors: 📁 `/implementations/dio-config.dart`
  - Authentication, cache, custom retry, logging (debug only)
  📚 Reference: `/references/technical-requirements.md` - Dio Configuration (MANDATORY SINGLE INSTANCE)
  📚 Reference: `/references/common-pitfalls.md` - #1 Creating Multiple Dio Instances
  📚 Reference: `/references/common-pitfalls.md` - #6 Placing Retry Interceptor Before Other Interceptors
- [ ] 3.2 Implement exponential backoff logic (1s, 2s, 4s) 📁 `/implementations/dio-config.dart`
  📚 Reference: `/references/technical-requirements.md` - Retry Interceptor Implementation
- [ ] 3.3 Write unit tests for retry mechanism and interceptors 📁 `/implementations/dio-config.dart`

### SpeechifyService
- [ ] 3.4 Create SpeechifyService with API integration 🔗 `/documentation/apis/speechify-api.md` 📁 `/implementations/audio-service.dart`
  📚 Reference: `/references/technical-requirements.md` - Connection Pooling for Speechify
- [ ] 3.5 Configure connection pooling and error handling 🔗 `/documentation/integrations/audio-streaming.md` 📁 `/implementations/audio-service.dart`
  📚 Reference: `/references/common-pitfalls.md` - #8 Skipping Connection Pooling
- [ ] 3.6 Write unit tests for SpeechifyService 📁 `/implementations/audio-service.dart`
- [ ] 3.7 Write integration tests with actual API calls

### StreamAudioSource Implementation
- [ ] 3.8 Create SpeechifyAudioSource extending StreamAudioSource 🔗 `/documentation/integrations/audio-streaming.md` 📁 `/implementations/audio-service.dart`
- [ ] 3.9 Implement request() method with Range header support 🔗 `/documentation/integrations/audio-streaming.md` 📁 `/implementations/audio-service.dart`
- [ ] 3.10 Handle stream errors and connection issues 📁 `/implementations/audio-service.dart`
  📚 Reference: `/references/code-patterns.md` - Error Handling Patterns
- [ ] 3.11 Write unit tests for audio streaming
- [ ] 3.12 Write integration tests with various network conditions

### Audio Player Setup with Advanced Controls
- [ ] 3.13 Create AudioPlayerService with enhanced playback functionality: 📁 `/implementations/audio-service.dart`
  - Play/pause with FAB control support
  - Skip controls (30-second forward/backward)
  - Speed adjustment (0.8x to 2.0x in 0.25x increments)
  - Position monitoring with time labels
  - Audio focus and interruption handling
  📚 Reference: `/references/implementation-standards.md` - Service Implementation Pattern
  📚 Reference: `/references/common-pitfalls.md` - #16 Not Using FloatingActionButton for Play
- [ ] 3.14 Write unit tests for AudioPlayerService 📁 `/implementations/audio-service.dart`
- [ ] 3.15 Write integration tests for playback scenarios

### Progress Tracking with Preferences
- [ ] 3.16 Implement debounced progress saving (5 second intervals) 📁 `/implementations/progress-service.dart`
  📚 Reference: `/references/code-patterns.md` - Debounced Saves
- [ ] 3.17 Save font size index and playback speed with progress 📁 `/implementations/progress-service.dart`
  📚 Reference: `/references/technical-requirements.md` - Storage Implementation
  📚 Reference: `/references/common-pitfalls.md` - #4 Missing Font Size Persistence
- [ ] 3.18 Handle progress sync conflicts and resume logic 📁 `/implementations/progress-service.dart`
- [ ] 3.19 Write unit tests for preference persistence 📁 `/implementations/progress-service.dart`
- [ ] 3.20 Write integration tests for save/resume functionality

### Background Playback
- [ ] 3.21 Configure iOS and Android for background audio
  📚 Reference: `/references/technical-requirements.md` - Platform Configuration
- [ ] 3.22 Implement MediaItem and lock screen controls
- [ ] 3.23 Write platform-specific integration tests

### Keyboard Shortcuts Implementation
- [ ] 3.24 Implement keyboard listener on player screen 📁 `/implementations/audio-player-screen.dart`
  📚 Reference: `/references/common-pitfalls.md` - #19 Missing Keyboard Shortcuts
- [ ] 3.25 Add spacebar for play/pause toggle 📁 `/implementations/audio-player-screen.dart`
- [ ] 3.26 Add arrow keys for 30-second skip 📁 `/implementations/audio-player-screen.dart`
- [ ] 3.27 Test keyboard response time (<50ms)

**Milestone 3 Definition of Done:**
- Audio streams from Speechify API successfully
- Advanced playback controls work (play, pause, skip, speed, font size)
- Progress saves and resumes correctly with preferences
- Background playback works on both platforms
- Keyboard shortcuts respond within 50ms
- Audio features have test coverage >80%

## Milestone 4: Dual-Level Word Highlighting System

### Word Timing Service with Sentence Support
- [ ] 4.1 Create WordTimingService with dual-level position tracking 🔗 `/documentation/integrations/dual-level-highlighting.md` 📁 `/implementations/word-highlighting.dart`
  📚 Reference: `/references/common-pitfalls.md` - #5 Single-Level Highlighting Only
- [ ] 4.2 Implement separate streams for word and sentence indices 🔗 `/documentation/integrations/dual-level-highlighting.md` 📁 `/implementations/word-highlighting.dart`
  📚 Reference: `/references/code-patterns.md` - Throttled Updates for Performance
- [ ] 4.3 Implement throttled streams (16ms intervals for 60fps) 🔗 `/documentation/integrations/dual-level-highlighting.md` 📁 `/implementations/word-highlighting.dart`
- [ ] 4.4 Write unit tests for dual-level timing service 📁 `/implementations/word-highlighting.dart`

### Binary Search Implementation
- [ ] 4.5 Implement binary search for word position (O(log n)) 📁 `/implementations/word-highlighting.dart`
- [ ] 4.6 Implement sentence index lookup 📁 `/implementations/word-highlighting.dart`
- [ ] 4.7 Create cache lookup mechanism for both levels 📁 `/implementations/word-highlighting.dart`
- [ ] 4.8 Write unit tests for search algorithms 📁 `/implementations/word-highlighting.dart`
- [ ] 4.9 Write performance benchmarks 📁 `/implementations/word-highlighting.dart`

### Word Position Pre-computation
- [ ] 4.10 Implement precomputeWordPositions() with compute() isolation 📁 `/implementations/word-highlighting.dart`
  📚 Reference: `/references/code-patterns.md` - Compute Isolation for Heavy Work
  📚 Reference: `/references/common-pitfalls.md` - #3 Not Pre-computing Word Positions
  📚 Reference: `/references/common-pitfalls.md` - #7 Synchronous Operations in UI Thread
- [ ] 4.11 Cache computed positions for words and sentences 📁 `/implementations/word-highlighting.dart`
- [ ] 4.12 Write unit tests for position calculation 📁 `/implementations/word-highlighting.dart`
- [ ] 4.13 Write performance tests with large documents

### Word Timing Fetching with Sentence Indices
- [ ] 4.14 Implement fetchTimings() with sentence index support 📁 `/implementations/word-highlighting.dart`
- [ ] 4.15 Handle three-tier caching (memory, local, Supabase) 📁 `/implementations/word-highlighting.dart`
  📚 Reference: `/references/technical-requirements.md` - Storage Implementation
- [ ] 4.16 Write unit tests for caching logic
- [ ] 4.17 Write integration tests for timing fetch

### Dual-Level Highlighting Widget
- [ ] 4.18 Create DualLevelHighlightedTextWidget with RepaintBoundary 📁 `/implementations/word-highlighting.dart`
  📚 Reference: `/references/common-pitfalls.md` - #9 Rebuilding Widgets Unnecessarily
- [ ] 4.19 Implement sentence background highlighting (#E3F2FD) 📁 `/implementations/word-highlighting.dart`
- [ ] 4.20 Implement word foreground highlighting (#FFF59D) 📁 `/implementations/word-highlighting.dart`
- [ ] 4.21 Style current word with bold and darker blue (#1976D2) 📁 `/implementations/word-highlighting.dart`
- [ ] 4.22 Write performance tests for 60fps validation 📁 `/implementations/word-highlighting.dart`
  📚 Reference: `/references/implementation-standards.md` - Complex Service Validation Example

### Tap-to-Seek Implementation
- [ ] 4.23 Create word tap detection with TapGestureRecognizer 📁 `/implementations/word-highlighting.dart`, `/implementations/audio-player-screen.dart`
- [ ] 4.24 Implement seekToWord() functionality 📁 `/implementations/audio-player-screen.dart`
- [ ] 4.25 Write unit tests for tap-to-seek
- [ ] 4.26 Write UI tests for tap accuracy

**Milestone 4 Definition of Done:**
- Dual-level highlighting synchronizes within ±50ms accuracy
- Sentence highlighting provides reading context at 100% accuracy
- Performance maintains 60fps during dual-level highlighting
- Binary search completes in <5ms for 10,000 words
- Tap-to-seek works accurately across all devices
- Highlighting system has test coverage >80%

## Milestone 5: UI Implementation with Polish

### Main Screens with Production UI
- [ ] 5.1 Create all main screens with complete implementations: 📁 `/implementations/home-page.dart`, `/implementations/audio-player-screen.dart`
  - HomePage with gradient course cards
  - LoginScreen with SSO integration
  - CourseDetailScreen with assignment organization
  - AudioPlayerScreen with advanced controls
  - AssignmentListScreen with expandable tiles
  - SettingsScreen with preference management
  📚 Reference: `/references/common-pitfalls.md` - #17 Ignoring Gradient Design
- [ ] 5.2 Implement loading, error, and empty states 📁 `/implementations/home-page.dart`
  📚 Reference: `/references/code-patterns.md` - Error Handling Patterns
- [ ] 5.3 Write widget tests for all screens

### Course Components with Visual Polish
- [ ] 5.4 Create polished course UI components: 📁 `/implementations/home-page.dart`
  - CourseCard with gradient header bar
  - Progress indicators (green for active, gray for not started)
  - Course list with sorting
  - Pull-to-refresh functionality
- [ ] 5.5 Write widget tests for course components

### Assignment Components with Expansion
- [ ] 5.6 Create AssignmentTile with ExpansionTile 📁 `/implementations/assignments-page.dart`
- [ ] 5.7 Implement CircleAvatar for assignment numbers 📁 `/implementations/assignments-page.dart`
- [ ] 5.8 Auto-expand first assignment 📁 `/implementations/assignments-page.dart`
- [ ] 5.9 Add smooth expansion animations 📁 `/implementations/assignments-page.dart`
- [ ] 5.10 Write widget tests for assignment components

### Learning Object Components
- [ ] 5.11 Create LearningObjectTile with play icon 📁 `/implementations/assignments-page.dart`
- [ ] 5.12 Implement completion checkmarks 📁 `/implementations/assignments-page.dart`
- [ ] 5.13 Add "In Progress" status labels 📁 `/implementations/assignments-page.dart`
  📚 Reference: `/references/common-pitfalls.md` - #18 Not Tracking isInProgress State
- [ ] 5.14 Write widget tests for learning object components

### Audio Player UI with Advanced Controls
- [ ] 5.15 Create PlayerControls with FloatingActionButton 📁 `/implementations/audio-player-screen.dart`
  📚 Reference: `/references/common-pitfalls.md` - #16 Not Using FloatingActionButton
- [ ] 5.16 Implement font size selector (Small/Medium/Large/XLarge) 📁 `/implementations/audio-player-screen.dart`
- [ ] 5.17 Implement playback speed button with cycling 📁 `/implementations/audio-player-screen.dart`
- [ ] 5.18 Add time labels for current/total duration 📁 `/implementations/audio-player-screen.dart`
- [ ] 5.19 Create PlayerControlIcon with tooltips 📁 `/implementations/audio-player-screen.dart`
- [ ] 5.20 Implement interactive seek bar 📁 `/implementations/audio-player-screen.dart`
- [ ] 5.21 Write widget tests for all player controls

### Highlighted Text Widget with Dual Levels
- [ ] 5.22 Create dual-level HighlightedText with RepaintBoundary 📁 `/implementations/word-highlighting.dart`, `/implementations/audio-player-screen.dart`
- [ ] 5.23 Implement smooth scrolling to current position 📁 `/implementations/audio-player-screen.dart`
- [ ] 5.24 Add word tap detection for seeking 📁 `/implementations/audio-player-screen.dart`
- [ ] 5.25 Write widget tests for highlighting
- [ ] 5.26 Write performance tests for 60fps validation

**Milestone 5 Definition of Done:**
- All screens render with polished UI on various screen sizes
- Gradient cards and visual polish elements work correctly
- Expandable assignments animate smoothly
- Advanced player controls respond immediately
- Font size changes apply in <16ms
- Dual-level highlighting maintains 60fps
- Navigation between screens works smoothly
- All UI components have widget test coverage
- No UI jank or performance issues

## Milestone 6: Local Storage & Caching with Preferences

### SharedPreferences Service with User Preferences
- [ ] 6.1 Create SharedPreferencesService with all storage methods 📁 `/implementations/progress-service.dart`
  📚 Reference: `/references/technical-requirements.md` - SharedPreferences Service
- [ ] 6.2 Implement font size index persistence 📁 `/implementations/progress-service.dart`
- [ ] 6.3 Implement playback speed persistence 📁 `/implementations/progress-service.dart`
- [ ] 6.4 Implement cache size management (50 items max)
- [ ] 6.5 Write unit tests for preference storage

### Cache Management
- [ ] 6.6 Implement cache eviction logic 📁 `/implementations/dio-config.dart`
- [ ] 6.7 Monitor cache performance 📁 `/implementations/dio-config.dart`
- [ ] 6.8 Write unit tests for cache management
- [ ] 6.9 Write integration tests for cache behavior

### Audio Caching
- [ ] 6.10 Configure flutter_cache_manager for audio segments
- [ ] 6.11 Implement cache warming and invalidation
- [ ] 6.12 Write tests for offline playback

### Preference Synchronization
- [ ] 6.13 Sync preferences between local and Supabase 📁 `/implementations/progress-service.dart`
- [ ] 6.14 Handle preference conflicts 📁 `/implementations/progress-service.dart`
- [ ] 6.15 Write tests for preference sync

**Milestone 6 Definition of Done:**
- User preferences persist across sessions
- Font size and playback speed restore on app launch
- Cache management keeps storage under limits
- Offline playback works for cached content
- Cache hit rate exceeds 70% for repeated content
- Storage system has test coverage >80%

## Milestone 7: Platform Configuration

### Platform-Specific Tools Installation (Phase 2)
- [ ] 7.0 Install iOS development tools:
  ```bash
  # Install Xcode from Mac App Store (~10GB, 1-2 hours)
  # Accept license and install additional components
  sudo xcodebuild -license accept
  xcodebuild -runFirstLaunch
  # Install CocoaPods
  brew install cocoapods
  ```
- [ ] 7.1 Install Android development tools:
  ```bash
  # Install Java 11 runtime
  brew install openjdk@11
  # Install Android Studio (~5GB, 1 hour)
  brew install --cask android-studio
  # Configure Android SDK through Android Studio setup wizard
  ```
- [ ] 7.2 Verify platform-specific installations:
  ```bash
  flutter doctor -v  # Should show no critical issues for iOS/Android
  flutter build ios --debug
  flutter build apk --debug
  ```

### iOS Configuration
- [ ] 7.3 Configure all iOS settings:
  - Info.plist, background modes, app transport security
  - Universal links, icons, launch screen
  🔗 Primary Guide: `/documentation/deployment/ios-configuration.md`
  📚 Reference: `/references/technical-requirements.md` - iOS Configuration
  📚 Reference: `/references/technical-requirements.md` - iOS Build Settings
- [ ] 7.4 Test on physical iOS devices
- [ ] 7.5 Verify keyboard shortcuts on iPad

### Android Configuration
- [ ] 7.6 Configure all Android settings:
  - Manifest permissions, deep links
  - Icons, splash screen, ProGuard rules
  🔗 Primary Guide: `/documentation/deployment/android-configuration.md`
  📚 Reference: `/references/technical-requirements.md` - Android Configuration
  📚 Reference: `/references/technical-requirements.md` - Android Build Settings
- [ ] 7.7 Test on physical Android devices
- [ ] 7.8 Verify keyboard shortcuts on tablets

**Milestone 7 Definition of Done:**
- App runs on iOS 14+ devices without crashes
- App runs on Android API 21+ devices without crashes
- Background audio works on both platforms
- Keyboard shortcuts work on tablets
- All platform-specific features function correctly

## Milestone 8: Performance Optimization

### Code Optimization for Dual-Level Highlighting
- [ ] 8.1 Implement all performance optimizations: 📁 `/implementations/word-highlighting.dart`
  - RepaintBoundary for dual-level highlighting widget
  - compute() for word and sentence position calculations
  - Lazy loading for learning objects
  - const constructors throughout
  - Widget rebuild minimization
  📚 Reference: `/references/code-patterns.md` - Memory Management Patterns
  📚 Reference: `/references/code-patterns.md` - Stream Patterns
- [ ] 8.2 Optimize dual-level highlight updates for 60fps 📁 `/implementations/word-highlighting.dart`

### Network Optimization
- [ ] 8.3 Optimize network usage: 📁 `/implementations/dio-config.dart`, `/implementations/audio-service.dart`
  - Connection pooling for Speechify
  - Request batching where possible
  - Debouncing for progress saves
  📚 Reference: `/references/code-patterns.md` - Debounced Saves

### Memory Optimization
- [ ] 8.4 Profile and fix memory issues:
  - Fix any memory leaks in dual-level highlighting
  - Optimize caches for word positions
  - Proper disposal of streams
  📚 Reference: `/references/code-patterns.md` - Resource Disposal Checklist
  📚 Reference: `/references/common-pitfalls.md` - #2 Forgetting Resource Disposal

### Performance Validation
- [ ] 8.5 Validate all enhanced performance targets:
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

## Milestone 9: Comprehensive Testing

### Testing Infrastructure Installation (Phase 3)
- [ ] 9.0 Install Patrol CLI for integration testing:
  ```bash
  dart pub global activate patrol_cli
  ```
- [ ] 9.1 Verify Patrol installation and setup:
  ```bash
  patrol --version
  patrol build ios  # Set up iOS test runner
  patrol build android  # Set up Android test runner
  ```
- [ ] 9.2 Configure device testing infrastructure:
  - Set up physical device connections
  - Configure network simulation tools (optional)
  - Set up performance monitoring tools

### Integration Testing Suite with UI Polish
- [ ] 9.3 Complete end-to-end test scenarios with Patrol:
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
- [ ] 9.4 Test on all target devices:
  - iPhone 8, iPhone 14 Pro, iPad
  - Android API 21, API 33, Android tablet
- [ ] 9.5 Verify keyboard shortcuts on all tablets

### Network Condition Testing
- [ ] 9.6 Test under various network conditions:
  - 3G with dual-level highlighting
  - WiFi/cellular handoff during playback
  - Intermittent connectivity with preference saving
  - Airplane mode with cached content
  📚 Reference: `/references/common-pitfalls.md` - #20 Ignoring Network State Changes

### Performance Benchmarking
- [ ] 9.7 Measure and document all enhanced performance metrics:
  - Dual-level highlighting frame rate
  - Font size change response time
  - Keyboard shortcut latency
  - Sentence highlighting accuracy
- [ ] 9.8 Create performance regression test suite

### UI Polish Testing
- [ ] 9.9 Test all visual polish elements:
  - Gradient rendering across devices
  - CircleAvatar display consistency
  - Tooltip functionality
  - FAB elevation and shadows
  - Animation smoothness

**Milestone 9 Definition of Done:**
- All integration tests pass consistently
- Dual-level highlighting works on all tested devices
- UI polish elements render correctly everywhere
- Font size and speed preferences persist properly
- Keyboard shortcuts work on all supported devices
- Network resilience confirmed
- Performance benchmarks documented
- Overall test coverage exceeds 80%

## Milestone 10: Production Deployment

### Production Environment
- [ ] 10.1 Set up production infrastructure:
  - Supabase project with preference tables
  - Cognito pool configuration
  - API keys with proper limits
  - Error tracking with UI polish monitoring
  - Analytics for feature usage
  - Performance monitoring
  📚 Reference: `/references/common-pitfalls.md` - #15 Using print() Instead of Logger

### App Store Preparation
- [ ] 10.2 Prepare iOS App Store submission:
  - Listing with feature highlights
  - Screenshots showing dual-level highlighting
  - Review submission
- [ ] 10.3 Prepare Google Play Store submission:
  - Listing with feature descriptions
  - Screenshots showing UI polish
  - Review submission

### Final Validation
- [ ] 10.4 Complete production testing:
  - Smoke tests for all features
  - API verification
  - Preference persistence verification
  - Crash reporting setup
  - Analytics tracking confirmation

**Milestone 10 Definition of Done:**
- Production environment fully configured
- App approved on both app stores
- All features working in production
- Monitoring and analytics operational
- No critical bugs in production

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