# Phase 4: Service Structure Backup
Generated: September 23, 2025

## Critical Service Architecture (DO NOT BREAK)

### Download Services Structure
```
/services/
├── course_download_service.dart (733 lines) - LEGACY BUT USED BY SCREENS
├── course_download_service_refactored.dart (unused - SAFE TO DELETE)
└── download/
    ├── course_download_api_service.dart (492 lines) - PRIMARY DOWNLOAD SERVICE
    ├── download_progress_tracker.dart - Progress tracking
    ├── download_queue_manager.dart - Queue management
    ├── file_system_manager.dart - File operations
    └── network_downloader.dart - Network operations
```

### Audio Services Structure
```
/services/
├── audio_cache_service.dart (460 lines) - Audio caching
├── audio_handler.dart - Audio session handling
├── audio_player_service_local.dart (622 lines) - PRIMARY AUDIO SERVICE (SINGLETON)
└── word_timing_service_simplified.dart (456 lines) - Timing synchronization
```

### Database Services Structure
```
/services/
├── database/
│   └── local_database_service.dart (575 lines) - PRIMARY DATABASE (SQLITE)
├── sync/
│   └── data_sync_service.dart (457 lines) - Supabase sync
├── local_content_service.dart (635 lines) - Content management
├── progress_service.dart (569 lines) - Progress tracking
├── user_progress_service.dart - User progress
└── user_settings_service.dart - Settings management
```

### Provider Structure
```
/providers/
├── audio_context_provider.dart - Audio context state
├── audio_providers.dart - Audio state (WITH autoDispose)
├── auth_providers.dart - Authentication
├── course_providers.dart - Course state
├── database_providers.dart - Database operations (WITH autoDispose)
├── progress_providers.dart - Progress state
├── providers.dart - Main export file
├── theme_provider.dart - Theme state
└── ui_providers.dart - UI state
```

## Service Dependencies Map

### CourseDownloadApiService Dependencies
- **Used by**: database_providers.dart (courseDownloadApiServiceProvider)
- **Depends on**:
  - NetworkDownloader
  - FileSystemManager
  - DownloadQueueManager
  - DownloadProgressTracker
  - Supabase client
  - LocalContentService

### CourseDownloadService (LEGACY) Dependencies
- **Used by**:
  - DownloadProgressScreen
  - CdnDownloadTestScreen
- **Status**: Needs migration to CourseDownloadApiService

### LocalDatabaseService Dependencies
- **Used by**: Multiple providers
- **Critical for**: Offline-first functionality
- **Tables**: courses, assignments, learning_objects, user_progress, etc.

### AudioPlayerServiceLocal Dependencies
- **Singleton pattern**: MUST maintain
- **Used by**: Audio providers, screens
- **Critical for**: Audio playback pipeline

## Import Analysis

### Most Imported Services
1. LocalDatabaseService - 10+ imports
2. AudioPlayerServiceLocal - 8+ imports
3. CourseDownloadApiService - 3 imports
4. LocalContentService - 5+ imports

### Unused Files (Safe to Delete)
- course_download_service_refactored.dart - 0 imports

## Provider Dependency Chain

```
User Action
    ↓
Screen/Widget
    ↓
Provider (with autoDispose)
    ↓
Service Layer
    ↓
Database/Network
```

## Critical Paths (DO NOT BREAK)

### Download Path
```
HomePage → Download Button →
downloadCourseProvider →
CourseDownloadApiService →
Supabase Storage CDN →
FileSystemManager →
LocalDatabaseService
```

### Audio Playback Path
```
LearningObjectScreen →
AudioPlayerServiceLocal (singleton) →
LocalContentService →
Local MP3 file →
WordTimingServiceSimplified →
SimplifiedDualLevelHighlightedText
```

### Sync Path
```
DataSyncService →
LocalDatabaseService ↔ Supabase
(Bidirectional with conflict resolution)
```

## Files Over 400 Lines (Need Splitting)

1. enhanced_audio_player_screen.dart - 795 lines
2. course_download_service.dart - 733 lines
3. simplified_dual_level_highlighted_text.dart - 694 lines
4. local_content_service.dart - 635 lines
5. audio_player_service_local.dart - 622 lines
6. local_database_service.dart - 575 lines
7. progress_service.dart - 569 lines

## Test Coverage Status

- ✅ download_models_test.dart - PASSING
- ✅ course_download_service_test.dart - PASSING
- ⚠️ download_architecture_integration_test.dart - SharedPreferences issue
- ✅ Performance benchmarks - PASSING

---

This backup document serves as a reference point before Phase 4 refactoring begins.