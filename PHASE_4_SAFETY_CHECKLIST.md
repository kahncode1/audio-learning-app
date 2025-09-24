# Phase 4: Architecture Improvements - Safety Checklist

## 🔴 CRITICAL: DO NOT BREAK
1. **Supabase Integration**
   - Row Level Security (RLS)
   - Storage CDN for audio files
   - Database sync with LocalDatabaseService

2. **Download Architecture**
   - CourseDownloadApiService (actively used)
   - Sequential download queue management
   - Progress tracking and reporting
   - Local file storage in documents directory

3. **Offline-First Functionality**
   - LocalDatabaseService with SQLite
   - DataSyncService bidirectional sync
   - Conflict resolution (last-write-wins)

4. **Audio Playback Pipeline**
   - AudioPlayerServiceLocal (singleton)
   - WordTimingServiceSimplified
   - SimplifiedDualLevelHighlightedText widget

## 📊 Service Dependency Analysis

### Active Download Services
- ✅ **CourseDownloadApiService** - ACTIVELY USED
  - Used by: database_providers.dart
  - Location: /services/download/course_download_api_service.dart
  - Status: CRITICAL - DO NOT MODIFY WITHOUT TESTING

- ⚠️ **CourseDownloadService** - LEGACY BUT STILL USED
  - Used by: DownloadProgressScreen, CdnDownloadTestScreen
  - Location: /services/course_download_service.dart
  - Status: NEEDS CAREFUL MIGRATION

- ❌ **CourseDownloadServiceRefactored** - UNUSED
  - Used by: NONE
  - Location: /services/course_download_service_refactored.dart
  - Status: SAFE TO DELETE

### Provider Dependencies
- localCoursesProvider → LocalDatabaseService
- courseAssignmentsProvider → LocalDatabaseService
- assignmentLearningObjectsProvider → LocalDatabaseService
- userProgressProvider → UserProgressService → LocalDatabaseService
- downloadProgressProvider → CourseDownloadApiService

## ✅ Safe Refactoring Targets

### 1. Unused Files (Safe to Remove)
- course_download_service_refactored.dart (0 imports)

### 2. UI Components (Safe to Split)
- EnhancedAudioPlayerScreen (795 lines)
  - Extract: PlayerControlsWidget
  - Extract: AudioProgressBar
  - Extract: FullscreenController
  - Keep: Core screen logic and state management

### 3. Widget Extraction (Safe)
- SimplifiedDualLevelHighlightedText
  - Extract: OptimizedHighlightPainter class
  - Extract: TextBox caching logic
  - Keep: Main widget logic

### 4. Model Organization (Safe)
- download_models.dart (472 lines)
  - Already well-organized, just needs file splitting

## ⚠️ Risky Refactoring Targets

### Services Requiring Extreme Caution
1. **LocalDatabaseService** - Core of offline-first architecture
2. **CourseDownloadApiService** - Active download management
3. **AudioPlayerServiceLocal** - Singleton audio playback
4. **DataSyncService** - Supabase sync logic

### Provider Refactoring Risks
- Breaking autoDispose patterns we just added
- Creating circular dependencies
- Breaking existing family provider parameters

## 🔧 Safe Refactoring Strategy

### Phase 4A: Zero-Risk Changes (Start Here)
1. Delete unused course_download_service_refactored.dart
2. Extract UI widgets from screens (no logic changes)
3. Split model files along clear boundaries
4. Add comprehensive tests for critical paths

### Phase 4B: Low-Risk Service Updates
1. Create interfaces for services (add abstraction layer)
2. Extract helper classes from large services
3. Consolidate duplicate logic with careful testing

### Phase 4C: Medium-Risk Architecture Changes
1. Migrate screens from old CourseDownloadService to CourseDownloadApiService
2. Consolidate provider files (with extensive testing)
3. Optimize rebuild patterns

## 🧪 Testing Requirements Before Each Change

### Before ANY Service Modification
```bash
# Run full test suite
flutter test

# Test download functionality
flutter test test/services/course_download_service_test.dart
flutter test test/services/download_service_integration_test.dart

# Test offline functionality
flutter test test/services/offline_functionality_test.dart
flutter test test/services/local_services_validation_test.dart
```

### After Each Change
1. Run unit tests for modified service
2. Run integration tests for download flow
3. Manual test: Download a course
4. Manual test: Play audio with highlighting
5. Manual test: Offline mode functionality

## 📝 Documentation Requirements

For each refactored file:
1. Preserve ALL existing documentation headers
2. Update import paths if files are moved
3. Document any API changes
4. Add migration notes for deprecated code

## 🚨 Red Flags - STOP If You See These

1. Any change to database schema
2. Any change to Supabase configuration
3. Any change to download queue logic
4. Any change to singleton patterns
5. Any circular dependency warnings
6. Test failures after refactoring

## ✓ Green Flags - Safe to Proceed

1. All tests passing
2. No import errors
3. Download still works
4. Audio playback works
5. Highlighting works
6. Offline mode works

## Recommended Execution Order

1. **START**: Create comprehensive test for CourseDownloadApiService
2. Delete unused refactored service file
3. Extract UI widgets (PlayerControls, ProgressBar, etc.)
4. Split download_models.dart by model type
5. Extract OptimizedHighlightPainter to separate file
6. **CHECKPOINT**: Full testing and validation
7. Create service interfaces
8. Migrate DownloadProgressScreen to use CourseDownloadApiService
9. **CHECKPOINT**: Full testing and validation
10. Consolidate providers (carefully)
11. **FINAL**: Complete test suite and manual validation

---

Remember: It's better to make small, safe changes than risk breaking critical functionality.