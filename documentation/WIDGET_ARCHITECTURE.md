# Widget Architecture Documentation

## Overview
This document describes the widget architecture of the Audio Learning Platform, focusing on component organization, reusability, and testing strategies.

## Directory Structure

```
lib/
├── widgets/
│   ├── player/                    # Audio player components
│   │   ├── player_controls_widget.dart    # Playback controls
│   │   ├── audio_progress_bar.dart        # Seek bar with time display
│   │   ├── fullscreen_controller.dart     # Fullscreen mode management
│   │   └── highlighted_text_display.dart  # Text highlighting widget
│   ├── simplified_dual_level_highlighted_text.dart  # Main highlighting widget
│   ├── optimized_highlight_painter.dart   # Custom painter for highlights
│   └── mini_audio_player.dart            # Bottom navigation player
├── screens/
│   ├── enhanced_audio_player_screen.dart  # Main player screen
│   ├── assignments_screen.dart            # Assignment list
│   └── home_screen.dart                   # Home/course list
```

## Component Architecture

### Player Widget Hierarchy

```
EnhancedAudioPlayerScreen
├── AppBar (conditional based on fullscreen)
├── SimplifiedDualLevelHighlightedText
│   ├── OptimizedHighlightPainter (CustomPainter)
│   └── TextPainter (managed internally)
├── AudioProgressBar
│   ├── Slider (seek functionality)
│   └── Time labels (current/remaining)
└── PlayerControlsWidget
    ├── Speed control button
    ├── Skip backward button (30s)
    ├── Play/Pause FloatingActionButton
    ├── Skip forward button (30s)
    └── Font size control button
```

### Fullscreen Management

The `FullscreenController` class manages fullscreen transitions:

- **Auto-enter**: After 3 seconds of playback with no interaction
- **Exit trigger**: Tap on content area or user interaction with controls
- **System UI**: Manages SystemChrome.setEnabledSystemUIMode
- **Timer management**: Automatic cleanup and restart logic

## Component Responsibilities

### PlayerControlsWidget
**Purpose**: Reusable audio player control interface

**Responsibilities**:
- Play/pause toggle
- Speed adjustment (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 1.75x, 2.0x)
- Skip forward/backward (30 seconds)
- Font size cycling (Small, Medium, Large)
- Interaction callbacks for fullscreen timer management

**State Management**:
- Streams from AudioPlayerServiceLocal for playback state
- ProgressService for font size persistence
- Callback pattern for parent widget communication

### AudioProgressBar
**Purpose**: Interactive seek bar with time display

**Responsibilities**:
- Display current position and total duration
- Interactive seeking via slider
- Time formatting (MM:SS or H:MM:SS)
- Stream-based position updates

**Performance**:
- Efficient stream subscriptions
- Graceful error handling for stream failures
- Proper cleanup on disposal

### SimplifiedDualLevelHighlightedText
**Purpose**: High-performance dual-level text highlighting

**Features**:
- Word-level highlighting (current word)
- Sentence-level highlighting (current sentence)
- 60fps performance target
- TextBox caching for efficiency
- Auto-scroll to keep current word visible

**Architecture**:
- Separated painting logic (OptimizedHighlightPainter)
- LRU cache for TextBox calculations (100-item limit)
- Binary search for word position lookup (<1ms)

### OptimizedHighlightPainter
**Purpose**: Custom painter for efficient text highlighting

**Optimization Strategies**:
- Three-layer paint system (background → sentence → word)
- Single immutable TextPainter
- Cached TextBox calculations with LRU eviction
- Direct character position lookups
- Optimized shouldRepaint logic

## State Management Patterns

### Service Singletons
```dart
// Audio control
final audioService = AudioPlayerServiceLocal.instance;

// Progress tracking
final progressService = await ProgressService.getInstance();

// Word timing
final timingService = WordTimingServiceSimplified.instance;
```

### Stream-Based Updates
```dart
// Position updates
StreamBuilder<Duration>(
  stream: audioService.positionStream,
  builder: (context, snapshot) => // UI update
)

// Playing state
StreamBuilder<bool>(
  stream: audioService.isPlayingStream,
  builder: (context, snapshot) => // UI update
)
```

### Callback Pattern
```dart
// Parent-child communication
PlayerControlsWidget(
  onInteraction: () {
    // Handle user interaction
    _restartFullscreenTimer();
  },
)
```

## Testing Strategy

### Unit Testing
Each widget has comprehensive unit tests covering:
- Widget rendering and layout
- User interaction handling
- Stream subscription behavior
- Error handling scenarios
- Theme adaptation (light/dark mode)

### Mock Strategy
Using `mocktail` for mock generation:
```dart
class MockAudioPlayerServiceLocal extends Mock
    implements AudioPlayerServiceLocal {}

// Setup mock behavior
when(() => mockService.isPlayingStream)
    .thenAnswer((_) => Stream.value(false));
```

### Test Coverage Goals
- **Target**: 95% line coverage
- **Focus Areas**:
  - User interactions (taps, drags)
  - Stream updates and error handling
  - Timer logic and lifecycle
  - Theme and style variations

## Performance Considerations

### Highlighting Performance
- **Binary search**: <1μs average lookup time
- **TextBox caching**: 10x speedup for sequential access
- **Paint optimization**: Single TextPainter, never modified during paint
- **Frame budget**: Maintaining 60fps (16ms per frame)

### Memory Management
- **LRU cache**: Limited to 100 TextBox entries
- **Stream disposal**: Proper cleanup in dispose methods
- **Timer cleanup**: Automatic cancellation on disposal
- **Provider autoDispose**: Prevents memory leaks in Riverpod

### Scroll Performance
- **Smart scrolling**: Only scrolls when word exits reading zone (20-40% from top)
- **Smooth animation**: Cubic easing with duration based on distance
- **Debounced updates**: Prevents excessive scroll calls

## Best Practices

### Widget Design Principles
1. **Single Responsibility**: Each widget has one clear purpose
2. **Composition over Inheritance**: Small, composable widgets
3. **Immutable State**: Use final fields where possible
4. **Proper Disposal**: Always clean up resources

### Code Organization
1. **Documentation Headers**: Purpose, dependencies, and usage
2. **Consistent Naming**: Descriptive widget and method names
3. **Error Handling**: Graceful degradation on failures
4. **Test Coverage**: Comprehensive unit tests for each widget

### Performance Guidelines
1. **Minimize Rebuilds**: Use const constructors where possible
2. **Stream Management**: Proper subscription and disposal
3. **Efficient Painting**: Cache expensive calculations
4. **Lazy Initialization**: Defer work until needed

## Migration Guide

### From Monolithic to Modular
When refactoring large widgets:

1. **Identify Responsibilities**: List all features and group related ones
2. **Extract Components**: Create separate widgets for each group
3. **Define Interfaces**: Use callbacks or streams for communication
4. **Update Imports**: Fix import paths in dependent files
5. **Write Tests**: Create comprehensive tests for new widgets
6. **Verify Performance**: Ensure no regression in responsiveness

### Adding New Player Features
To add new player functionality:

1. **Determine Scope**: Is it a control, display, or behavior?
2. **Create Widget**: New file in appropriate directory
3. **Define Interface**: Props, callbacks, and streams needed
4. **Implement Logic**: Keep business logic in services
5. **Add Tests**: Cover all scenarios and edge cases
6. **Update Documentation**: Add to this architecture guide

## Future Improvements

### Planned Enhancements
- **Gesture Support**: Swipe gestures for seeking
- **Animation Polish**: Smooth transitions between states
- **Accessibility**: Screen reader support and keyboard navigation
- **Customization**: User-defined control layouts

### Technical Debt
- **Test Coverage**: Increase to 95% across all widgets
- **Documentation**: Add inline examples for complex widgets
- **Performance Monitoring**: Add metrics collection
- **Error Recovery**: Implement retry mechanisms for stream failures

## Conclusion

The widget architecture prioritizes:
- **Modularity**: Small, focused, reusable components
- **Performance**: Optimized rendering and state management
- **Testability**: Comprehensive test coverage and mocking
- **Maintainability**: Clear separation of concerns

This architecture enables rapid feature development while maintaining code quality and performance standards.