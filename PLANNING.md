# Streaming Audio Learning Platform - Technical Planning

## Document Overview

This planning document defines the architecture, technology decisions, and strategic approach for the Streaming Audio Learning Platform. It works in conjunction with:
- **CLAUDE.md**: Streamlined development guide with critical instructions and quick reference
- **TASKS.md**: Detailed task breakdown with completion tracking and implementation references
- **`/implementations/`**: Production-ready reference implementations for all major components
- **`/references/`**: Detailed technical documentation:
  - `code-patterns.md`: Async/await, state management, lifecycle patterns
  - `implementation-standards.md`: Service patterns, validation functions, testing templates
  - `technical-requirements.md`: Dio config, network resilience, platform setup
  - `common-pitfalls.md`: Critical mistakes to avoid with solutions

## Implementation File Structure

The project uses a modular implementation approach:
```
/implementations/
├── audio-player-screen.dart   # Complete player UI with dual-level highlighting
├── audio-service.dart          # Speechify API and audio streaming
├── word-highlighting.dart      # Dual-level highlighting system
├── home-page.dart             # Home screen with gradient cards
├── assignments-page.dart       # Expandable assignment tiles
├── auth-service.dart          # AWS Cognito SSO bridge
├── progress-service.dart       # Progress tracking with preferences
├── providers/                  # Modularized Riverpod state management (Sept 2025)
│   ├── providers.dart         # Barrel export for backward compatibility
│   ├── auth_providers.dart    # Authentication state
│   ├── course_providers.dart  # Course data providers
│   ├── audio_providers.dart   # Audio playback & highlighting (CRITICAL)
│   ├── ui_providers.dart      # Font size & speed preferences (CRITICAL)
│   └── progress_providers.dart # Progress tracking
├── dio-config.dart            # HTTP client configuration
└── models.dart                # Data model definitions

/references/
├── code-patterns.md           # Reusable code patterns and best practices
├── implementation-standards.md # Documentation and validation requirements
├── technical-requirements.md  # Platform and configuration specifics
└── common-pitfalls.md         # Critical mistakes and their solutions
```

These implementations provide tested, production-ready code that should be referenced when building the corresponding features. The reference documentation provides deeper technical guidance for complex implementations.

## Project Vision

The Audio Learning Platform delivers a Flutter-based mobile application that plays pre-downloaded educational content with synchronized dual-level word and sentence highlighting for insurance professionals consuming course material offline.

**Core Value Proposition:**
- Transform written course content into consumable audio format
- Enable learning during commutes, travel, and downtime
- Provide synchronized dual-level read-along for better comprehension and retention
- Track progress to resume where users left off
- Offer customizable reading experience with font size preferences

**Target Users:** Insurance professionals and executives who need to complete continuing education requirements while managing busy schedules. The platform enables productive learning during previously unutilized time such as commutes, travel, or exercise, turning downtime into professional development opportunities.

## Architecture Decisions

### Three-Tier Architecture

The system implements a clean separation of concerns across four primary layers:

1. **Authentication Layer (AWS Cognito)**
   - Provides enterprise SSO authentication
   - Generates JWT tokens for session management
   - Integrates with existing organizational identity providers
   - Handles token refresh and session lifecycle
   - **Reference Implementation:** `/implementations/auth-service.dart`
   - **Technical Details:** `/references/technical-requirements.md`

2. **Backend Layer (Supabase)**
   - PostgreSQL database with Row Level Security (RLS)
   - Automatic filtering of expired course enrollments
   - Real-time subscriptions via WebSocket
   - JWT validation for Cognito tokens
   - Storage of user preferences (font size, playback speed)
   - Hosted on Supabase Cloud for scalability
   - **Reference Models:** `/implementations/models.dart`

3. **Content Delivery (Pre-processed Files)**
   - Pre-generated MP3 audio files
   - JSON-based word and sentence timing data
   - Content metadata and display text
   - Stored locally after initial download
   - **Reference Implementation:** `/services/local_content_service.dart`
   - **Architecture Guide:** `/DOWNLOAD_ARCHITECTURE_PLAN.md`

4. **Mobile Application (Flutter)**
   - Cross-platform iOS and Android clients
   - Reactive state management with Riverpod
   - Custom audio streaming implementation
   - Dual-level word and sentence highlighting synchronization
   - Advanced playback controls with keyboard shortcuts
   - Persistent user preferences
   - **Package Guide:** `/documentation/apis/flutter-packages.md`
   - **Highlighting Guide:** `/documentation/integrations/dual-level-highlighting.md`
   - **Platform Config:** `/documentation/deployment/ios-configuration.md` and `/documentation/deployment/android-configuration.md`
   - **Reference Implementations:** All files in `/implementations/`
   - **Code Patterns:** `/references/code-patterns.md`

### Data Flow

1. **Authentication:** User logs in via AWS Cognito SSO → Flutter receives ID token → Creates Supabase session through JWT bridging
2. **Content Loading:** Flutter fetches authorized courses/learning objects from Supabase (backend automatically filters expired content via RLS)
3. **Content Loading:** Flutter loads pre-downloaded MP3 files and timing data from local storage → Instant playback with no buffering
4. **Progress Tracking:** Flutter saves position, font size, and playback speed to Supabase every 5 seconds using debounced updates → Caches locally with SharedPreferences
5. **Highlighting Sync:** Word timings with sentence indices enable dual-level highlighting → Binary search for current word → Sentence tracking for context

### Critical Architectural Decisions

- **Supabase Selection:** Chosen for real-time capabilities, built-in Row Level Security, automatic JWT validation, and seamless PostgreSQL integration
- **Download-First Architecture:** Pre-processed content eliminates runtime TTS costs, enables offline playback, and simplifies codebase by 40%
- **AWS Cognito:** Leverages existing enterprise SSO infrastructure, provides secure token management
- **Dual-Level Word Highlighting Implementation:** No existing Flutter packages provide synchronized dual-level (sentence + word) highlighting - requires 100% custom development (see `/implementations/word-highlighting.dart` and `/references/common-pitfalls.md` #5)
- **Flutter Framework:** Enables single codebase for iOS and Android, reducing development and maintenance costs
- **Font Size Persistence:** User preferences stored both locally and in cloud for consistent experience across sessions (see `/implementations/progress-service.dart`)
- **Dio Singleton Pattern:** Single HTTP client instance with proper interceptor chain (see `/implementations/dio-config.dart` and `/references/common-pitfalls.md` #1)

## Technology Stack

### Frontend Framework
- **Flutter 3.x with Dart 3.x** - Cross-platform mobile development framework providing native performance

### State Management
- **riverpod: ^2.4.9** - Reactive caching and data-binding framework with compile-time safety
- **flutter_riverpod: ^2.4.9** - Flutter integration providing widget rebuilding and provider composition
- **Package Guide:** `/documentation/apis/flutter-packages.md`
- **Reference Implementation:** `/lib/providers/` - Modularized architecture (Sept 2025)
  - **auth_providers.dart** - Authentication and user state
  - **course_providers.dart** - Course, assignment, learning object data
  - **audio_providers.dart** - Audio playback and highlighting state (CRITICAL)
  - **ui_providers.dart** - Font size and playback speed preferences (CRITICAL)
  - **progress_providers.dart** - Progress tracking and synchronization
- **Patterns:** `/references/code-patterns.md` - State Management with Riverpod

### Audio Core
- **just_audio: ^0.9.36** - Main audio player with StreamAudioSource support for custom streaming
- **just_audio_background: ^0.0.1-beta.11** - Background playback wrapper for iOS and Android
- **audio_session: ^0.1.18** - Audio session configuration and system audio focus management
- **Reference Implementation:** `/implementations/audio-service.dart`

### Authentication
- **amplify_flutter: ^2.0.0** - Official AWS SDK with comprehensive Cognito support
- **amplify_auth_cognito: ^2.0.0** - Cognito plugin with federateToIdentityPool API and automatic token refresh
- **Comprehensive Guide:** `/documentation/apis/aws-cognito-sso.md`
- **Integration Guide:** `/documentation/integrations/cognito-supabase-bridge.md`
- **Reference Implementation:** `/implementations/auth-service.dart`
- **Token Handling:** `/references/common-pitfalls.md` #13

### Backend
- **Supabase Cloud** - Managed PostgreSQL with Row Level Security and real-time subscriptions
- **supabase_flutter: ^2.3.0** - Supabase client providing database queries and real-time listeners
- **Comprehensive Guide:** `/documentation/apis/supabase-backend.md`

### Content Delivery System

#### Pre-processed Content Files
- **Downloaded on first login** - All course materials cached locally
  - **Audio Files:** MP3 format, ~1MB per minute
  - **Timing Data:** JSON files with word/sentence boundaries
  - **Content Metadata:** Display text and course information
  - **File Structure:** `learning_object_id/audio.mp3`, `content.json`, `timing.json`
- **Benefits:**
  - 100% cost reduction (no runtime TTS API calls)
  - Instant playback with no buffering
  - Complete offline capability
  - Simplified codebase (~40% reduction)
- **Implementation Guides:**
  - **Architecture:** `/DOWNLOAD_ARCHITECTURE_PLAN.md`
  - **Preprocessing Pipeline:** `/preprocessing_pipeline/` - Complete ElevenLabs to JSON conversion
  - **CDN Setup:** `/SUPABASE_CDN_SETUP.md`
  - **Service Implementation:** `/services/local_content_service.dart`

#### Preprocessing Pipeline (New Approach)
- **Location:** `/preprocessing_pipeline/`
- **Purpose:** Convert ElevenLabs character-level timing to word/sentence format
- **Key Components:**
  - `process_elevenlabs_complete.py` - Main conversion script
  - `README.md` - Complete overview and workflow
  - `SCHEMA.md` - JSON schema documentation
  - `USAGE.md` - Step-by-step usage guide
- **Critical Requirements:**
  - **Snake_case field naming** - All timing fields must use snake_case (not camelCase)
  - **Continuous sentence coverage** - No gaps between sentences for smooth highlighting
  - **Paragraph preservation** - Original content structure maintained in displayText
- **Output Format:** Single `content.json` with all timing and display data

### HTTP & Network
- **dio: ^5.4.0** - Advanced HTTP client with interceptors for streaming and retry logic
- **dio_cache_interceptor: ^3.5.0** - Response caching to reduce API calls and improve performance
- **connectivity_plus: ^5.0.2** - Network state detection for offline handling
- **Reference Configuration:** `/implementations/dio-config.dart`
- **Singleton Pattern:** `/references/technical-requirements.md` - Dio Configuration

### Stream Processing
- **rxdart: ^0.27.7** - Reactive extensions for audio/highlight synchronization
- **stream_transform: ^2.1.0** - Stream utilities for debouncing and throttling updates
- **Patterns:** `/references/code-patterns.md` - Stream Patterns

### Local Storage
- **shared_preferences: ^2.2.2** - Lightweight key-value storage for settings, preferences, and cache
- **flutter_secure_storage: ^9.0.0** - Encrypted storage for sensitive tokens (optional)
- **flutter_cache_manager: ^3.3.1** - Audio segment caching for offline support
- **Reference Implementation:** `/implementations/progress-service.dart`
- **Storage Details:** `/references/technical-requirements.md` - Storage Implementation

### UI Components
- **percent_indicator: ^4.2.3** - Visual progress indicators for courses and playback
- **Custom Components** - FloatingActionButton for play/pause, gradient cards, expandable tiles
- **Reference Implementations:** `/implementations/home-page.dart`, `/implementations/assignments-page.dart`, `/implementations/audio-player-screen.dart`
- **UI Patterns:** `/references/common-pitfalls.md` #16, #17

### Testing
- **mocktail: ^1.0.1** - Null-safety mocking without code generation
- **patrol: ^3.3.0** - Integration testing with native interaction support
- **flutter_test: sdk: flutter** - Core Flutter testing framework
- **Testing Standards:** `/references/implementation-standards.md` - Testing Standards

## Required Tools and Dependencies

### Development Environment
- **Flutter SDK:** Version 3.x or higher (stable channel)
- **Dart SDK:** Version 3.x or higher (included with Flutter)
- **IDE Options:**
  - Android Studio with Flutter/Dart plugins
  - VS Code with Flutter and Dart extensions
- **Git:** Version control for source code management

### Platform-Specific Requirements

**iOS Development:**
- Xcode 14 or higher
- macOS for building and testing
- iOS 14+ deployment target
- Apple Developer account for device testing
- CocoaPods for dependency management
- **Comprehensive Guide:** `/documentation/deployment/ios-configuration.md`
- **Configuration:** `/references/technical-requirements.md` - iOS Configuration

**Android Development:**
- Android Studio with SDK tools
- Android API 21+ (Lollipop) minimum
- Java 11 or higher
- Gradle build system
- Android device or emulator for testing
- **Comprehensive Guide:** `/documentation/deployment/android-configuration.md`
- **Configuration:** `/references/technical-requirements.md` - Android Configuration

### Backend Infrastructure
- **Supabase Project:** Configured with required tables and RLS policies
- **AWS Cognito:** User pool and identity pool with SSO configuration
- **Speechify Account:** API key with sufficient quota for TTS requests

### Testing Infrastructure
- **Patrol CLI:** For running integration tests
- **Physical Devices:** iPhone and Android phones for real-world testing
- **Network Tools:** Charles Proxy or similar for API debugging
- **Device Farm:** Optional for automated device testing

### Critical Package Versions
All packages must use the exact versions specified in the Technology Stack section to ensure compatibility and prevent version conflicts. These versions have been tested together and are known to work reliably.

## Development Environment Setup

This project uses a **phased installation approach** aligned with development milestones to maximize productivity while minimizing initial overhead.

**See:** `ARCHIVE/installation-history.md` for complete setup guides, commands, and validation checklists.

## Technology Stack Rationale

Key technology selections with current implementations:
- **Amplify Flutter:** AWS Cognito integration (`/implementations/auth-service.dart`)
- **just_audio:** Custom streaming for Speechify (`/implementations/audio-service.dart`)
- **Dio:** HTTP client with interceptors (`/implementations/dio-config.dart`)
- **Riverpod:** State management (`/implementations/providers.dart`)
- **Custom Highlighting:** Dual-level word/sentence sync (`/implementations/word-highlighting.dart`)

**See:** `ARCHIVE/technology-decisions.md` for detailed selection rationale and alternatives considered.

## Data Model Architecture

### Core Entities

**Course** (see `/implementations/models.dart`)
- Represents educational content packages
- Contains course number, title, and assignments
- Tracks overall completion percentage
- Links to user enrollments with expiration dates
- Includes gradient configuration for visual design

**Assignment** (see `/implementations/models.dart`)
- Organizational units within courses
- Maintains display number (1, 2, 3...) for user interface
- Maintains order for sequential learning
- Groups related learning objects
- Tracks completion at assignment level

**LearningObject** (see `/implementations/models.dart`)
- Individual content pieces (chapters, sections)
- References pre-downloaded audio and timing files
- Stores cached word timings with sentence indices
- Tracks user progress (isCompleted, isInProgress)
- Stores last playback position

**WordTiming** (see `/implementations/models.dart`)
- Synchronization data for dual-level highlighting
- Maps words to time positions (startMs, endMs)
- Groups words by sentences (sentenceIndex)
- Cached locally and in database
- Enables both word and sentence highlighting

**ProgressState** (see `/implementations/models.dart`)
- User's current position in content
- Playback speed preferences
- Font size index (Small/Medium/Large/XLarge)
- Last update timestamp
- Completion and in-progress status

### Database Schema Design Principles
- **Row Level Security:** All user data protected by RLS policies
- **Automatic Filtering:** Expired enrollments filtered at database level
- **JSON Storage:** Word timings with sentence indices stored as JSONB for flexibility
- **Referential Integrity:** Foreign keys maintain data consistency
- **Indexed Queries:** Performance optimization for common queries
- **Preference Storage:** User settings persisted for cross-device sync

### Progress Tracking Approach (see `/implementations/progress-service.dart`)
- **Debounced Saves:** Updates every 5 seconds to reduce database writes
- **Dual Storage:** Progress saved to both Supabase and local storage
- **Conflict Resolution:** Server state takes precedence on conflicts
- **Resume Logic:** Automatically continues from last position
- **Preference Persistence:** Font size and playback speed saved with progress
- **Patterns:** See `/references/code-patterns.md` - Debounced Saves

### Caching Strategy
- **Three-Level Cache:** Memory → SharedPreferences → Supabase
- **Word Timing Cache:** Pre-computed positions with sentence indices stored locally
- **Audio Segments:** flutter_cache_manager for offline playback
- **API Responses:** dio_cache_interceptor for reduced API calls
- **Cache Eviction:** Automatic cleanup when exceeding 50 items
- **Preference Cache:** Font size and speed cached for instant access
- **Implementation Details:** See `/implementations/dio-config.dart` for cache configuration

## Performance Architecture

### Response Time Targets
- **App Cold Start:** <3 seconds to interactive state
- **Audio Stream Start:** <2 seconds (p95) with automatic retry
- **Progress Save:** <500ms with debouncing
- **Dual-Level Word Highlighting:** 60fps minimum (16ms per frame)
- **Word Sync Accuracy:** ±50ms alignment with audio
- **Sentence Sync Accuracy:** 100% accuracy for context highlighting
- **Font Size Change:** <16ms response time
- **Keyboard Shortcut Response:** <50ms for all shortcuts

### Resource Usage Constraints
- **Memory:** <200MB typical usage during playback
- **Battery:** <5% per hour of continuous playback
- **Network:** Adaptive bitrate based on connection quality
- **Storage:** <100MB app size plus cache

### Audio Playback Strategy (see `/services/audio_player_service_local.dart`)
- **Instant Start:** Local MP3 files play immediately
- **No Buffering:** Complete file available locally
- **Seek Performance:** Instant seeking to any position
- **Memory Efficient:** Audio player handles file streaming
- **Offline Ready:** No network required after download

### Optimization Techniques (see `/implementations/word-highlighting.dart`)
- **RepaintBoundary:** Isolate dual-level highlighting widget repaints
- **compute() Function:** Offload word position calculations to isolate
- **Binary Search:** O(log n) complexity for word position lookup
- **Position Caching:** Pre-computed word and sentence positions in memory
- **Throttled Updates:** 16ms intervals for 60fps performance
- **Lazy Loading:** Load content as needed rather than upfront
- **Connection Pooling:** Reuse HTTP connections for Speechify
- **Dual-Level Optimization:** Separate streams for word and sentence updates
- **Patterns:** See `/references/code-patterns.md` for all performance patterns

## UI/UX Architecture

### Visual Design System
- **Material Design:** Following Material 2 guidelines with custom enhancements
- **Primary Color:** #2196F3 (Blue) for consistency across the app
- **Gradient Cards:** Dynamic gradients for course differentiation (see `/implementations/home-page.dart`)
- **Elevation Strategy:** Cards with 2-4dp elevation for depth
- **Common Mistakes:** See `/references/common-pitfalls.md` #16, #17 for UI patterns

### Advanced Player Controls (see `/implementations/audio-player-screen.dart`)
- **FloatingActionButton:** Central play/pause control with elevated design
- **Font Size Selector:** Small/Medium/Large/XLarge options with persistent storage
- **Playback Speed:** 0.8x to 2.0x in 0.25x increments with cycling
- **Skip Controls:** 30-second forward/backward with tooltip hints
- **Time Labels:** Current and total duration display
- **Seek Bar:** Interactive progress with immediate response

### Dual-Level Highlighting (see `/implementations/word-highlighting.dart`)
- **Sentence Background:** Light blue (#E3F2FD) for reading context
- **Word Foreground:** Yellow (#FFF59D) for current word
- **Active Word Style:** Darker blue text (#1976D2) with bold weight
- **Smooth Transitions:** 60fps updates for seamless experience

### Content Organization (see `/implementations/assignments-page.dart`)
- **Expandable Assignments:** First assignment auto-expanded
- **CircleAvatar Numbers:** Visual assignment numbering
- **Progress Indicators:** Green for active, gray for not started
- **Completion Badges:** Check circles for completed items
- **In-Progress Labels:** Clear status communication

### Keyboard Navigation (see `/implementations/audio-player-screen.dart`)
- **Spacebar:** Play/pause toggle
- **Left Arrow:** Skip backward 30 seconds
- **Right Arrow:** Skip forward 30 seconds
- **Focus Management:** Automatic focus on player screen
- **Platform Support:** See `/references/common-pitfalls.md` #19

## Security Architecture

### Authentication Flow (see `/implementations/auth-service.dart`)
1. User initiates login → redirected to Cognito SSO
2. Enterprise credentials validated by identity provider
3. Cognito issues JWT tokens (ID, access, refresh)
4. Flutter stores tokens securely (SharedPreferences or flutter_secure_storage)
5. Tokens bridged to create Supabase session
6. Automatic refresh before expiration
- **Token Management:** See `/references/common-pitfalls.md` #13

### Data Protection Measures
- **Row Level Security:** PostgreSQL RLS policies enforce access control
- **HTTPS Only:** All API communications encrypted in transit
- **Token Encryption:** Sensitive tokens stored with encryption
- **No Local Sensitive Data:** Only non-sensitive cache and preferences stored locally
- **Session Timeout:** 24-hour maximum session duration
- **Preference Security:** Font size and speed are non-sensitive, stored in plain text

### Content Security Approach
- **Signed URLs:** Time-limited URLs for audio streams
- **Rate Limiting:** API call throttling to prevent abuse
- **User Validation:** Each request validates user authorization
- **Secure API Keys:** Environment variables for sensitive configuration
- **Cache Invalidation:** Automatic cleanup of expired content
- **Best Practices:** See `/references/common-pitfalls.md` #11

## Development Approach

### Milestone-Based Development
The project follows a milestone-based approach with clear deliverables and quality gates. Each milestone builds upon the previous, with integrated testing throughout. Refer to TASKS.md for detailed task breakdown, completion tracking, and implementation file references.

### Implementation Reference Strategy
- **Production-Ready Code:** All implementations in `/implementations/` are tested and ready for use
- **Validation Functions:** Each implementation includes validation to verify correctness
- **Task-Specific Guidance:** TASKS.md includes 📁 markers pointing to relevant implementations
- **Code Reuse:** Use implementations as templates, adapting as needed for specific requirements
- **Documentation Support:** Reference documentation in `/references/` provides patterns and standards

### Testing Strategy
- **Test-Driven Development:** Unit tests created alongside each service implementation
- **Integration Testing:** Comprehensive end-to-end scenarios with Patrol
- **Performance Testing:** Continuous validation of performance targets
- **UI Testing:** Verification of all visual polish elements
- **Device Testing:** Cross-platform verification on physical devices
- **Network Resilience:** Testing under various network conditions
- **Validation Functions:** Each implementation file includes self-validation
- **Standards:** See `/references/implementation-standards.md` for testing templates

### Quality Assurance
- **Code Reviews:** All code reviewed before merging
- **Automated Testing:** CI/CD pipeline runs tests on every commit
- **Performance Monitoring:** Continuous tracking of key metrics
- **Error Tracking:** Crash reporting and error monitoring in production
- **User Feedback:** Beta testing with target user group
- **Implementation Validation:** Run validation functions before marking tasks complete
- **Common Issues:** Review `/references/common-pitfalls.md` during development

## Key Implementation Priorities

### Phase 1: Core Functionality
1. Authentication system with Cognito-Supabase bridge (see `/implementations/auth-service.dart`)
2. Basic audio streaming from Speechify API (see `/implementations/audio-service.dart`)
3. Course browsing and selection (see `/implementations/home-page.dart`)
4. Simple playback controls

### Phase 2: Advanced Features
1. Dual-level word and sentence highlighting synchronization (see `/implementations/word-highlighting.dart`)
2. Progress tracking with font size persistence (see `/implementations/progress-service.dart`)
3. Background playback support
4. Offline caching
5. Advanced player controls with keyboard shortcuts (see `/implementations/audio-player-screen.dart`)

### Phase 3: Polish and Optimization
1. Performance optimization for 60fps highlighting
2. UI polish with gradients and animations (see `/implementations/home-page.dart`, `/implementations/assignments-page.dart`)
3. Font size adjustment with <16ms response
4. Comprehensive error handling
5. Production deployment

## Feature Specifications

### Dual-Level Highlighting System
**Technical Implementation:**
- **API Integration:** Speechify returns word timings via `include_speech_marks: true`
- **Parsing:** Handles nested sentence chunks or flat word lists
- **Sentence Inference:** 350ms pause detection + terminal punctuation with abbreviation protection
- **UI Widget:** SimplifiedDualLevelHighlightedText with OptimizedHighlightPainter
- **Three-Layer Paint:** Sentence background (#E3F2FD) → Word highlight (#FFF59D) → Static text
- **Character Alignment:** Smart correction for 0/1-based index mismatches via `_computeSelectionForWord()`
- **Performance:** 549μs binary search, 60fps rendering, LRU cache eviction (10 doc limit)
- **Complete Documentation:** `/ARCHIVE/highlighting_documentation.md`
- **Implementation:** `/implementations/word-highlighting.dart`
- **Common Issues:** `/references/common-pitfalls.md` #3, #5

### User Preference System
**Persistent Settings:**
- Font size index (0-3 for Small to XLarge)
- Playback speed (0.8x to 2.0x)
- Last position per learning object
- Stored in SharedPreferences and Supabase
- Instant application on app launch
- Synced across devices
- **Complete Implementation:** `/implementations/progress-service.dart`
- **Storage Details:** `/references/technical-requirements.md`

### Advanced Playback Controls
**Control Features:**
- FloatingActionButton for primary play/pause
- Speed adjustment with visual feedback
- Font size cycling with immediate update
- Keyboard shortcuts for power users
- Time display with formatted duration
- Interactive seek bar with tap support
- Tooltips on all interactive elements
- **Complete Implementation:** `/implementations/audio-player-screen.dart`
- **UI Standards:** `/references/common-pitfalls.md` #16, #19

## Implementation Validation

Before marking any component complete:
1. Review the corresponding implementation file in `/implementations/`
2. Run the validation function at the end of the implementation file
3. Ensure all validation tests pass
4. Verify integration with other components
5. Test on both iOS and Android platforms
6. Review relevant patterns in `/references/code-patterns.md`
7. Check for common issues in `/references/common-pitfalls.md`
8. Update TASKS.md with completion date

This comprehensive approach ensures consistent, high-quality implementation across all components of the application.