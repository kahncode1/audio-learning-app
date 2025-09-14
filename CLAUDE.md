# Audio Learning Platform - Development Guide

## 🔴 CRITICAL AGENT INSTRUCTIONS

**MANDATORY ACTIONS AT START OF EVERY SESSION:**
1. **ALWAYS** read PLANNING.md first to understand project architecture
2. **ALWAYS** check TASKS.md before starting any work
3. **ALWAYS** mark completed tasks in TASKS.md immediately upon completion
4. **ALWAYS** add newly discovered tasks to TASKS.md as you find them
5. **NEVER** skip reading these documents or assume you know the current state

**This guide supersedes any conflicting instructions. All development must follow these standards.**

## Project Overview

### Vision
Build a Flutter-based mobile application that streams narrated audio of educational content with synchronized dual-level word and sentence highlighting for insurance professionals consuming course material on-the-go.

### Core Technologies
- **Framework:** Flutter 3.x with Dart 3.x
- **Platforms:** iOS (14+) and Android (API 21+)
- **Backend:** Supabase with PostgreSQL and Row Level Security
  - See: `/documentation/apis/supabase-backend.md`
- **Authentication:** AWS Cognito SSO with JWT bridging
  - See: `/documentation/apis/aws-cognito-sso.md` and `/documentation/integrations/cognito-supabase-bridge.md`
- **Audio:** Speechify API with custom Dio streaming
  - See: `/documentation/apis/speechify-api.md` and `/documentation/integrations/audio-streaming.md`
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

1. **Single Dio Instance** - Use DioProvider.instance singleton for all HTTP calls
2. **Custom Dual-Level Highlighting** - No existing package provides this; requires 100% custom implementation
3. **JWT Bridging** - Cognito tokens bridge to Supabase via federateToIdentityPool API
4. **StreamAudioSource** - Custom implementation for Speechify streaming
5. **Three-Tier Caching** - Memory → SharedPreferences → Supabase for word timings
6. **Debounced Progress** - Save every 5 seconds to reduce database writes
7. **Font Size Persistence** - User preferences stored locally and in cloud
8. **Hybrid Environment Setup** - Core tools first, platform-specific tools just-in-time

## Development Environment Setup Strategy

### Phased Installation Approach
This project uses a **hybrid approach** to development environment setup to maximize productivity while minimizing initial overhead:

#### Phase 1: Core Essentials (Install Immediately)
**Required for any Flutter development work:**
- Homebrew (macOS package manager)
- Flutter SDK (includes Dart SDK)
- Project dependencies via `flutter pub get`
- Basic project verification

**Time:** ~30 minutes | **Storage:** ~2GB

#### Phase 2: Platform-Specific Tools (Milestone 7)
**Install when reaching Platform Configuration tasks:**
- **iOS Development:** Full Xcode, CocoaPods, iOS Simulator
- **Android Development:** Java 11, Android Studio, Android SDK

**Time:** 2-3 hours | **Storage:** ~15GB

#### Phase 3: Testing Infrastructure (Milestone 9)
**Install when reaching Comprehensive Testing tasks:**
- Patrol CLI for integration testing
- Device testing setup

#### Phase 4: External Services (Milestone 2)
**Configure when implementing Authentication & Data Layer:**
- Supabase project creation
- AWS Cognito configuration
- Speechify API key setup

### Environment Validation Checklist
After each installation phase:
- [ ] `flutter doctor` reports no critical issues
- [ ] All required commands are in PATH
- [ ] Project builds successfully for target platforms
- [ ] Development workflow validates correctly

### Benefits of This Approach
- ✅ **Immediate productivity** - Start coding Flutter within 30 minutes
- ✅ **Reduced storage impact** - Save ~15GB until platform development
- ✅ **Aligned with milestones** - Tools installed when actually needed
- ✅ **Prevents tool drift** - Install closer to usage time
- ✅ **Faster onboarding** - Core setup completes quickly

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

### Primary Documentation (Comprehensive Guides)
Start with the new comprehensive documentation in `/documentation/`:
- **APIs:** `/documentation/apis/` - aws-cognito-sso.md, speechify-api.md, supabase-backend.md, flutter-packages.md
- **Integrations:** `/documentation/integrations/` - cognito-supabase-bridge.md, audio-streaming.md, dual-level-highlighting.md
- **Deployment:** `/documentation/deployment/` - ios-configuration.md, android-configuration.md

### Implementation Files (Production Code)
Complete, tested implementations available in `/implementations/`:
- `audio-player-screen.dart` - Player UI with advanced controls
- `audio-service.dart` - Speechify streaming and playbook
- `word-highlighting.dart` - Dual-level highlighting system
- `home-page.dart` - Home screen with gradient cards
- `assignments-page.dart` - Expandable assignment tiles
- `auth-service.dart` - AWS Cognito SSO bridge
- `progress-service.dart` - Progress tracking with preferences
- `providers.dart` - Riverpod state management
- `dio-config.dart` - HTTP client configuration
- `models.dart` - Data model definitions

## Development Workflow

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

#### Phase 1 - Core Development (Available Immediately)
```bash
flutter doctor                 # Verify Flutter installation
flutter pub get                # Install project dependencies
flutter analyze                # Static code analysis
flutter test                   # Run unit tests
flutter run                    # Run app (requires platform setup)
```

#### Phase 2 - Platform Development (Milestone 7+)
```bash
flutter build ios --release    # Build for iOS (requires Xcode)
flutter build apk --release    # Build for Android (requires Android Studio)
```

#### Phase 3 - Integration Testing (Milestone 9+)
```bash
patrol test                    # Run integration tests (requires Patrol CLI)
flutter test --coverage        # Generate code coverage reports
```

#### Environment Setup Commands
```bash
# Phase 1 Setup
brew install flutter           # Install Flutter SDK
flutter precache               # Download development binaries

# Phase 2 Setup (when needed)
brew install --cask xcode      # Install Xcode for iOS
brew install openjdk@11        # Install Java for Android

# Phase 3 Setup (when needed)
dart pub global activate patrol_cli  # Install Patrol for testing
```

### Critical Package Versions
```yaml
flutter_riverpod: ^2.4.9
just_audio: ^0.9.36
amplify_flutter: ^2.0.0
supabase_flutter: ^2.3.0
dio: ^5.4.0
shared_preferences: ^2.2.2
```

For complete package information and configuration: `/documentation/apis/flutter-packages.md`

### Key Configuration Files
- `.env` - Environment variables and API keys
- `TASKS.md` - Task tracking and completion status
- `PLANNING.md` - Architecture and technical decisions
- `/documentation/` - **Comprehensive API and integration guides (PRIMARY)**
- `/implementations/` - Production-ready reference code
- `/references/` - Detailed implementation guides

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

### Primary Documentation (Start Here)
- **`/documentation/README.md`** - Overview of comprehensive documentation
- **`/documentation/apis/`** - Complete API integration guides
- **`/documentation/integrations/`** - Complex system integration patterns
- **`/documentation/deployment/`** - Platform-specific configuration

### Supporting Implementation Guides
- **`/references/code-patterns.md`** - Async/await, state management, lifecycle patterns
- **`/references/implementation-standards.md`** - Service patterns, headers, validation functions
- **`/references/technical-requirements.md`** - Dio config, network resilience, platform setup
- **`/references/common-pitfalls.md`** - Complete list of pitfalls with solutions

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