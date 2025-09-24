# Audio Learning Platform - Development Guide

## 🔴 CRITICAL AGENT INSTRUCTIONS

**MANDATORY ACTIONS AT START OF EVERY SESSION:**
1. **ALWAYS** read PLANNING.md first to understand project architecture
2. **ALWAYS** check TASKS.md before starting any work
3. **ALWAYS** mark completed tasks in TASKS.md immediately upon completion
4. **ALWAYS** add newly discovered tasks to TASKS.md as you find them
5. **NEVER** skip reading these documents or assume you know the current state

**This guide supersedes any conflicting instructions. All development must follow these standards.**

## ✅ PRODUCTION-READY STATUS

**Current State:** Grade A (93/100) - Production ready with AWS Cognito (September 23, 2025)
- **Authentication:** AWS Cognito fully implemented, all mock code removed
- **Data Architecture:** Offline-first SQLite with Supabase sync
- **Services:** LocalDatabaseService, CourseDownloadApiService, DataSyncService
- **Performance:** All targets met (60fps highlighting, <2s load times)
- **Test Coverage:** 87.9% (532/605 tests passing)

## Project Overview

### Vision
A Flutter-based mobile application with offline-first architecture that enables insurance professionals to consume educational content during commutes and travel. Features synchronized dual-level word and sentence highlighting, complete offline capability through local SQLite database, and seamless synchronization when online.

### Core Technologies
- **Framework:** Flutter 3.x with Dart 3.x
- **Platforms:** iOS (14+) and Android (API 21+)
- **Backend:** Supabase with PostgreSQL and Row Level Security
  - See: `/documentation/apis/supabase-backend.md`
- **Storage:** Supabase Storage with global CDN for audio files
  - Public bucket: `audio-files` (50MB limit, MP3 only)
  - Automatic CDN distribution via Cloudflare
  - See: `/preprocessing_pipeline/UPLOAD_TO_SUPABASE.md`
- **Authentication:** AWS Cognito SSO (fully implemented, no mock auth)
  - See: `/documentation/apis/aws-cognito-sso.md`
- **Audio:** Local MP3 playback with pre-processed content
  - Audio files downloaded from Supabase Storage CDN
  - JSON-based timing data for word/sentence synchronization
  - Instant playback with no buffering required
- **State Management:** Riverpod 2.4.9
  - See: `/documentation/apis/flutter-packages.md`

### Critical Performance Requirements
- **60fps minimum** for dual-level word highlighting
- **<2 seconds** audio stream start time (p95)
- **±50ms** word synchronization accuracy
- **100%** sentence highlighting accuracy
- **<16ms** font size change response
- **<50ms** keyboard shortcut response
- **<200MB** memory usage during playback
- **<3 seconds** cold start to interactive

## Project Structure

```
audio_learning_app/
├── lib/
│   ├── main.dart           # App entry point
│   ├── models/             # Data models
│   ├── providers/          # Riverpod state management
│   ├── screens/            # UI screens
│   ├── services/           # Business logic
│   └── widgets/            # Reusable components
├── test/                   # Unit/widget tests
├── integration_test/       # Patrol integration tests
└── references/            # Detailed implementation guides
```

## Key Architectural Decisions

1. **Offline-First Architecture** - Local SQLite database with bidirectional sync to Supabase
2. **Service-Based Data Access** - All data operations through service layer, not direct database access
3. **Snake_case Field Naming** - Consistent snake_case for all database fields and JSON data
4. **Database-Backed Providers** - Riverpod providers fetch from local database, enabling offline access
5. **LearningObjectV2 Model** - Enhanced model with JSONB support for complex timing data
6. **Conflict Resolution** - Last-write-wins strategy for sync conflicts
7. **Download Queue Management** - CourseDownloadApiService manages sequential downloads with progress tracking
8. **UI Layer Separation** - Complete removal of mock services, UI uses only database providers

## Critical: Offline-First Data Architecture

**Core components of the offline-first system:**
- **LocalDatabaseService:** SQLite database with 6 tables matching Supabase schema
- **CourseDownloadApiService:** Downloads entire courses with progress tracking
- **DataSyncService:** Bidirectional sync with conflict resolution
- **Database Providers:** Service-based providers for all data access
  - `localCoursesProvider`: Courses from local database
  - `courseAssignmentsProvider`: Assignments for a course
  - `assignmentLearningObjectsProvider`: Learning objects
  - `userProgressProvider`: Progress tracking
  - `userSettingsProvider`: User preferences with StateNotifier
- **LearningObjectV2 Model:** Enhanced with JSONB timing data support
- **Snake_case Convention:** All database fields and JSON use snake_case

**Key Implementation Files:**
- `LocalContentService` - Manages downloaded content
- `AudioPlayerServiceLocal` - Plays local MP3 files
- `WordTimingServiceSimplified` - Uses pre-processed timing data
- `SimplifiedDualLevelHighlightedText` - Optimized highlighting widget
- `/preprocessing_pipeline/process_elevenlabs_complete.py` - Content preprocessing

**Preprocessing Documentation:**
- **Pipeline Guide:** `/preprocessing_pipeline/README.md` - Complete preprocessing overview
- **Schema Definition:** `/preprocessing_pipeline/SCHEMA.md` - JSON schema with snake_case fields
- **Usage Guide:** `/preprocessing_pipeline/USAGE.md` - Step-by-step preprocessing instructions
- **Upload Guide:** `/preprocessing_pipeline/UPLOAD_TO_SUPABASE.md` - Audio file upload to CDN
- **Architecture:** `/DOWNLOAD_ARCHITECTURE_PLAN.md` - System design documentation

Full documentation: `/DOWNLOAD_ARCHITECTURE_PLAN.md`


## Development Environment Setup Strategy

This project uses a **phased installation approach** aligned with development milestones:
- **Phase 1 (Milestone 1):** Core Flutter tools (~30 min, ~2GB)
- **Phase 2 (Milestone 8):** Platform-specific tools (2-3 hours, ~15GB)
- **Phase 3 (Milestone 10):** Testing infrastructure (~15 min, ~100MB)
- **Phase 4 (Milestone 2):** External services configuration

**See:** `ARCHIVE/installation-history.md` for detailed setup guides and commands

## MCP Server Tools

### Available MCP Servers
This project has access to specialized MCP (Model Context Protocol) servers that provide direct integration with key services:

1. **supabase** - Database & Backend Management
   - Use for: Direct database operations, migrations, SQL execution
   - Commands: Project management, table operations, edge functions, logs
   - Essential for: Milestone 2 (Authentication & Data Layer) implementation
   - Key features: Create tables, apply migrations, execute SQL, deploy edge functions

2. **playwright** - Browser Automation & E2E Testing
   - Use for: Automated browser testing and UI validation
   - Commands: Browser control, element interaction, screenshot capture
   - Essential for: Milestone 9 (Comprehensive Testing) E2E test scenarios

### When to Use MCP Servers
- **Always use Supabase MCP** when working on database tasks in Milestone 2
- **Use Playwright MCP** for E2E testing instead of or alongside Patrol in Milestone 9
- **Prefer MCP servers** over manual approaches when available for efficiency

## Development Standards

### File Organization
- **One class/service** per file
- **Mirror test structure** to lib structure
- **Separate widgets** >100 lines into own files

### Code Quality Status
- ✅ All mock code removed (~951 lines eliminated)
- ✅ Service decomposition complete (no files >400 lines)
- ✅ Error tracking and performance monitoring implemented
- ✅ Offline-first architecture fully functional
- ✅ Production authentication via AWS Cognito

### Documentation Requirements
Every file must include a comprehensive header with:
- Purpose and responsibility
- External dependencies with links
- Usage examples
- Expected behavior

See: `/references/implementation-standards.md` for templates

### Code Style Requirements
- **Always use async/await** with try-catch (never .then chains)
- **Proper disposal** in reverse order of initialization
- **Validation functions** at end of each implementation file
- **Import organization:** Dart SDK → Flutter → Packages → Project

See: `/references/code-patterns.md` for examples

## Reference Implementations

### Primary Documentation
- **`/documentation/`** - Comprehensive API and integration guides
- **`/implementations/`** - Production-ready reference code
- **`/references/`** - Detailed implementation patterns and standards
- **`ARCHIVE/`** - Historical decisions and detailed setup guides

## Development Workflow

### Important Platform-Specific Instructions
**⚠️ XCODE EXECUTION:** Do not attempt to run Xcode or xcodebuild commands directly. The user must execute these manually. When iOS builds or simulator runs are needed, ask the user to run the appropriate commands.

### Before Starting Any Task:
1. Read PLANNING.md for architectural context
2. Check TASKS.md for requirements and dependencies
3. Review relevant reference implementations
4. Plan error handling and resource cleanup
5. Write validation function first

### Implementation Checklist:
- [ ] Code follows Flutter/Dart conventions
- [ ] File has proper documentation header
- [ ] Validation function outputs expected results
- [ ] Unit tests pass with >80% coverage
- [ ] All resources properly disposed
- [ ] Error handling covers all paths
- [ ] Performance meets requirements
- [ ] Works on both iOS and Android

### After Completing Task:
1. Run validation function
2. Run unit and integration tests
3. Test on both platforms
4. Update TASKS.md with completion date
5. Document any discovered tasks

## Test Data and Development Setup

### Test Database Content
For development and testing, the following test data is available in Supabase:

- **Course**: "Insurance Fundamentals" (Course ID: `cb236d98-dbb8-4810-b205-17e8091dcf69`)
  - Course Number: INS-101
  - Multiple assignments with learning objects
  - Audio URLs configured for Supabase Storage CDN
- **Learning Object**: ID `63ad7b78-0970-4265-a4fe-51f3fee39d5f`
  - Title: "How Insurance Facilitates Society"
  - Contains valid content and timing data
  - Audio URL points to Supabase Storage

### Test Access
- **"Download Test Course" button** in HomePage
  - Downloads complete course from Supabase (INS-101)
  - Includes all assignments and learning objects
  - Downloads audio files from CDN (when available)
  - Progress tracking with percentage display
- **"Delete Downloads" button** for testing
  - Clears local database and downloaded files
  - Useful for testing fresh downloads

### Temporary RLS Policy
```sql
-- Public access for test learning object (REMOVE IN PRODUCTION)
CREATE POLICY "Public read access for test data" ON learning_objects
FOR SELECT USING (id = '63ad7b78-0970-4265-a4fe-51f3fee39d5f');
```

## Common Pitfalls

For detailed explanations see: `/references/common-pitfalls.md`

Top 5 Critical Mistakes:
1. Creating multiple Dio instances instead of using singleton
2. Forgetting resource disposal causing memory leaks
3. Not pre-computing word positions causing frame drops
4. Missing font size persistence losing user preferences
5. Skipping dual-level highlighting providing poor UX

## Quick Reference

### Essential Commands

```bash
# Core Development
flutter doctor                 # Verify installation
flutter pub get                # Install dependencies
flutter analyze                # Static analysis
flutter test                   # Run unit tests
flutter run                    # Run app

# Quality Checks
./check-local.sh              # Run all automated checks
./check-local.sh --fix        # Auto-fix formatting issues
```

**See:** `ARCHIVE/installation-history.md` for complete setup commands by phase

### Critical Package Versions
```yaml
flutter_riverpod: ^2.4.9
just_audio: ^0.9.36
amplify_flutter: ^2.0.0
supabase_flutter: ^2.3.0
dio: ^5.4.0
shared_preferences: ^2.2.2
```

**See:** `/documentation/apis/flutter-packages.md` for complete configuration details

### Key Configuration Files
- `.env` - Environment variables and API keys
- `TASKS.md` - Task tracking and completion status
- `PLANNING.md` - Architecture and technical decisions
- `/documentation/` - API and integration guides
- `/implementations/` - Production-ready reference code
- `/references/` - Implementation patterns and standards
- `ARCHIVE/` - Historical documentation and setup guides

## Automated Quality Checks

**MANDATORY before every commit:**
1. Run `./check-local.sh` to verify all checks pass
2. Flutter analyze must show 0 errors (warnings allowed but discouraged)
3. All tests must pass (can skip temporarily with SKIP_TESTS=1)
4. Code must be properly formatted (dart format)

**Pre-commit hooks are configured to enforce these automatically.**
- Hooks will block commits if errors are found
- Use `git commit --no-verify` ONLY in emergencies
- Run `./check-local.sh --fix` to auto-fix formatting issues

**CI/CD Pipeline Requirements:**
- GitHub Actions runs the same checks on every push
- Failing CI checks will block PR merges
- Keep local checks passing to avoid CI failures

## Detailed References

### Documentation Structure
- **`/documentation/`** - API integration guides and deployment configs
- **`/references/`** - Code patterns, standards, and technical requirements
- **`/implementations/`** - Production-ready reference implementations
- **`ARCHIVE/`** - Technology decisions and historical documentation

**Key Files:**
- `code-patterns.md` - Async/await, state management patterns
- `implementation-standards.md` - Service patterns and validation
- `common-pitfalls.md` - Critical mistakes and solutions
- `ARCHIVE/technology-decisions.md` - Framework selection rationale

## Compliance Verification

Before marking any task complete, verify ALL requirements are met:
1. ✅ Validation function passes
2. ✅ Tests achieve >80% coverage
3. ✅ Performance targets met (60fps, <2s load, etc.)
4. ✅ Dual-level highlighting works accurately
5. ✅ User preferences persist correctly
6. ✅ Works on iOS and Android
7. ✅ Task marked in TASKS.md with date

**Remember: Functionality first, style second. Working code before linting.**