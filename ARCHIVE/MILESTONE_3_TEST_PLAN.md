# Milestone 3: Core Audio Features - Comprehensive Testing Plan

## 📋 Executive Summary

This plan outlines the complete testing strategy for Milestone 3 (Core Audio Features) of the Audio Learning Platform. The plan addresses current compilation errors, establishes web testing as the primary platform, and includes a systematic approach to fix iOS Simulator issues after web validation.

## 🚨 Current Blockers & Solutions

### 1. Compilation Errors (Must Fix First)
- **Error 1:** `lib/models/word_timing.dart:215` - Null safety issue with tuple access
  - Fix: Add null check before accessing `$2` property
- **Error 2:** `lib/providers/providers.dart:57` - Undefined 'name' parameter
  - Fix: Correct the provider definition syntax

### 2. Platform Testing Issues
- **iOS Simulator:** Available but currently not working (will fix in Phase 5)
- **Web:** Chrome is available but web support not enabled for project
- **Solution:** Enable web support as primary testing platform first

## 🎯 Complete Testing Strategy

### Phase 1: Fix Environment (30 mins)

#### 1.1 Fix Compilation Errors
- Fix null safety in `word_timing.dart` line 215
- Fix provider syntax in `providers.dart` line 57
- Remove unused imports and fix warnings

#### 1.2 Enable Web Support
```bash
flutter config --enable-web
flutter create . --platforms=web
```

#### 1.3 Verify App Runs
- Test on web: `flutter run -d chrome`
- Access TestSpeechifyScreen to verify API configuration

### Phase 2: Test Speechify API on Web (1 hour)

#### 2.1 Manual API Testing
- Navigate to Test Speechify screen via web browser
- Verify API key loads from environment
- Test audio generation with sample text
- Monitor network requests in Chrome DevTools

#### 2.2 Integration Testing
- Test streaming audio playback
- Verify word timing data retrieval
- Test error handling for API failures
- Confirm audio plays in browser

### Phase 3: Write Missing Unit Tests (3 hours)

#### Task 3.3: DioProvider Tests
- Test exponential backoff (1s, 2s, 4s)
- Test interceptor chain order
- Test singleton pattern enforcement
- Test connection pooling

#### Task 3.6: SpeechifyService Tests
- Mock API responses
- Test SSML processing
- Test error handling
- Test voice/speed parameters

#### Task 3.11: Audio Streaming Tests
- Test StreamAudioSource implementation
- Test Range header support
- Test buffering logic
- Test connection recovery

#### Task 3.14: AudioPlayerService Tests
- Test play/pause functionality
- Test skip controls (±30s)
- Test speed adjustment (0.8x-2.0x)
- Test position monitoring

#### Task 3.19: Progress Service Tests
- Test debounced saving (5s intervals)
- Test font size persistence
- Test playback speed persistence
- Test conflict resolution

#### Task 3.27: Performance Tests
- Measure keyboard shortcut response time
- Target: < 50ms for spacebar play/pause
- Target: < 50ms for arrow key skip

### Phase 4: Validate on Web (30 mins)

#### 4.1 Full Feature Testing
- Test complete audio playback flow
- Verify all UI components render correctly
- Test keyboard shortcuts in browser
- Validate progress saving

#### 4.2 Performance Validation
- Check memory usage in Chrome DevTools
- Monitor network requests
- Verify no memory leaks
- Confirm smooth playback

### Phase 5: Fix iOS Simulator Environment (1.5 hours)

#### Step 1: Clean iOS Environment
```bash
# Clean all Flutter artifacts
flutter clean
rm -rf ios/Pods
rm ios/Podfile.lock

# Clean Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Reset iOS Simulator
xcrun simctl erase all
```

#### Step 2: Rebuild iOS Dependencies
```bash
# Reinstall Flutter packages
flutter pub get

# Regenerate iOS project files
cd ios
pod deintegrate
pod cache clean --all
pod install
cd ..
```

#### Step 3: Configure Code Signing
```bash
# Open Xcode to configure signing
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select Runner target
# 2. Go to Signing & Capabilities
# 3. Enable "Automatically manage signing"
# 4. Select a development team (or use Personal Team)
```

#### Step 4: Test iOS Simulator
```bash
# List available simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot "iPhone 16 Plus"

# Run Flutter app
flutter run -d "iPhone 16 Plus"
```

#### Step 5: Troubleshooting iOS Issues
- If simulator won't boot: Restart Mac and try again
- If code signing fails: Use automatic signing with Personal Team
- If build fails: Check `flutter doctor -v` for iOS issues
- If pods fail: Update CocoaPods with `sudo gem install cocoapods`

### Phase 6: Complete iOS Testing (1 hour)

#### 6.1 Repeat Phase 2 Tests on iOS
- Test Speechify API integration
- Verify audio playback
- Test all UI components
- Validate keyboard shortcuts (on iPad simulator)

#### 6.2 iOS-Specific Testing
- Test background audio (Task 3.21)
- Verify audio interruption handling
- Test with Control Center controls
- Validate audio session configuration

#### 6.3 Cross-Platform Validation
- Compare behavior between web and iOS
- Document any platform-specific issues
- Ensure feature parity

## 📊 Success Criteria

### ✅ Phase 1 Complete When:
- No compilation errors
- App runs on web platform
- Can navigate to all screens

### ✅ Phase 2 Complete When:
- Speechify API returns audio stream URL on web
- Audio plays successfully in browser
- Word timings are retrieved

### ✅ Phase 3 Complete When:
- All unit tests pass (80%+ coverage)
- Performance targets met
- Tests are repeatable and stable

### ✅ Phase 4 Complete When:
- All features work correctly on web
- No performance issues detected
- User can complete full audio learning flow

### ✅ Phase 5 Complete When:
- iOS Simulator boots successfully
- App builds without code signing errors
- App launches on iOS Simulator

### ✅ Phase 6 Complete When:
- All features tested on iOS
- Background audio works
- Cross-platform compatibility verified
- All Milestone 3 tasks marked complete in TASKS.md

## 🚀 Implementation Order

1. Fix compilation errors (15 mins)
2. Enable web support (10 mins)
3. Test Speechify API on web (30 mins)
4. Write unit tests in priority order:
   - SpeechifyService (critical path)
   - AudioPlayerService (core functionality)
   - DioProvider (network layer)
   - ProgressService (data persistence)
   - Performance tests (validation)
5. Validate everything on web (30 mins)
6. Fix iOS Simulator environment (1.5 hours)
7. Complete iOS testing (1 hour)
8. Update TASKS.md with completions

## 💡 Key Recommendations

1. **Web First Strategy** - Establish working baseline on web before tackling iOS issues
2. **Mock External Services** - Use mocks for unit tests to avoid API dependencies
3. **Document Platform Differences** - Track any web vs iOS behavioral differences
4. **Incremental Validation** - Test each fix immediately to catch regressions
5. **Performance Monitoring** - Use browser/Xcode tools to track performance

## 📝 Important Notes

- Environment variables are already configured (`.env` file with Speechify API key)
- Mock authentication is working (23/23 tests passing)
- Core audio implementation is complete but untested
- Database and models are ready
- Web testing bypasses iOS code signing issues initially
- iOS testing ensures production readiness for primary platform

## 🔄 Risk Mitigation

- **If web testing fails:** Fall back to macOS desktop app
- **If iOS Simulator persists issues:** Use physical iPhone device
- **If Speechify API fails:** Check API quota and key validity
- **If performance targets not met:** Profile and optimize before moving forward

## 📈 Progress Tracking

Track progress using the TodoWrite tool with the following tasks:
1. Fix compilation errors
2. Enable web support
3. Test Speechify API
4. Write unit tests (Tasks 3.3, 3.6, 3.11, 3.14, 3.19, 3.27)
5. Fix iOS Simulator environment
6. Complete iOS testing
7. Update TASKS.md

## 🎯 Expected Outcomes

Upon completion of this test plan:
- All compilation errors resolved
- Web and iOS platforms both functional
- Speechify API integration validated
- All unit tests written and passing
- Performance targets achieved
- Milestone 3 ready for production

This comprehensive plan ensures we validate everything on web first, then systematically resolve iOS issues for complete cross-platform testing.