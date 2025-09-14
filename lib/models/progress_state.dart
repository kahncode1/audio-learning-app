/// Progress State Model
///
/// Purpose: Tracks user progress and preferences for learning objects
/// Dependencies: None
///
/// Usage:
///   final progress = ProgressState.fromJson(jsonData);
///   final fontSize = progress.fontSizeName;
///
/// Expected behavior:
///   - Stores playback position and completion status
///   - Maintains user preferences (font size, playback speed)
///   - Supports progress synchronization

class ProgressState {
  final String id;
  final String userId;
  final String learningObjectId;
  final int currentPositionMs;
  final bool isCompleted;
  final bool isInProgress;
  final double playbackSpeed;
  final int fontSizeIndex;
  final DateTime lastAccessedAt;
  final DateTime? completedAt;

  // Font size mapping
  static const List<String> fontSizeNames = [
    'Small',
    'Medium',
    'Large',
    'X-Large'
  ];
  static const List<double> fontSizeValues = [14.0, 16.0, 18.0, 20.0];

  ProgressState({
    required this.id,
    required this.userId,
    required this.learningObjectId,
    this.currentPositionMs = 0,
    this.isCompleted = false,
    this.isInProgress = false,
    this.playbackSpeed = 1.0,
    this.fontSizeIndex = 1, // Default to Medium
    required this.lastAccessedAt,
    this.completedAt,
  })  : assert(currentPositionMs >= 0, 'Position must be non-negative'),
        assert(playbackSpeed > 0 && playbackSpeed <= 3.0,
            'Playback speed must be between 0 and 3.0'),
        assert(fontSizeIndex >= 0 && fontSizeIndex < fontSizeNames.length,
            'Font size index must be valid'),
        assert(id.isNotEmpty, 'ID cannot be empty'),
        assert(userId.isNotEmpty, 'User ID cannot be empty'),
        assert(learningObjectId.isNotEmpty, 'Learning object ID cannot be empty');

  /// Get font size name for display
  String get fontSizeName {
    if (fontSizeIndex >= 0 && fontSizeIndex < fontSizeNames.length) {
      return fontSizeNames[fontSizeIndex];
    }
    return fontSizeNames[1]; // Default to Medium
  }

  /// Get font size value for rendering
  double get fontSizeValue {
    if (fontSizeIndex >= 0 && fontSizeIndex < fontSizeValues.length) {
      return fontSizeValues[fontSizeIndex];
    }
    return fontSizeValues[1]; // Default to 16.0
  }

  /// Get formatted playback speed
  String get formattedSpeed => '${playbackSpeed}x';

  /// Calculate progress percentage
  double calculateProgressPercentage(int totalDurationMs) {
    if (totalDurationMs == 0) return 0.0;
    if (isCompleted) return 100.0;
    return (currentPositionMs / totalDurationMs * 100).clamp(0.0, 100.0);
  }

  /// Check if should resume from saved position
  bool get shouldResume => isInProgress && currentPositionMs > 0;

  /// Creates ProgressState from JSON map
  factory ProgressState.fromJson(Map<String, dynamic> json) {
    return ProgressState(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      learningObjectId: json['learning_object_id'] as String,
      currentPositionMs: json['current_position_ms'] as int? ?? 0,
      isCompleted: json['is_completed'] as bool? ?? false,
      isInProgress: json['is_in_progress'] as bool? ?? false,
      playbackSpeed: (json['playback_speed'] as num?)?.toDouble() ?? 1.0,
      fontSizeIndex: json['font_size_index'] as int? ?? 1,
      lastAccessedAt: DateTime.parse(json['last_accessed_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  /// Converts ProgressState to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'learning_object_id': learningObjectId,
      'current_position_ms': currentPositionMs,
      'is_completed': isCompleted,
      'is_in_progress': isInProgress,
      'playback_speed': playbackSpeed,
      'font_size_index': fontSizeIndex,
      'last_accessed_at': lastAccessedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  ProgressState copyWith({
    String? id,
    String? userId,
    String? learningObjectId,
    int? currentPositionMs,
    bool? isCompleted,
    bool? isInProgress,
    double? playbackSpeed,
    int? fontSizeIndex,
    DateTime? lastAccessedAt,
    DateTime? completedAt,
  }) {
    return ProgressState(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      learningObjectId: learningObjectId ?? this.learningObjectId,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      isCompleted: isCompleted ?? this.isCompleted,
      isInProgress: isInProgress ?? this.isInProgress,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      fontSizeIndex: fontSizeIndex ?? this.fontSizeIndex,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Cycle to next font size
  ProgressState cycleToNextFontSize() {
    final nextIndex = (fontSizeIndex + 1) % fontSizeNames.length;
    return copyWith(fontSizeIndex: nextIndex);
  }

  /// Cycle to next playback speed
  ProgressState cycleToNextSpeed() {
    const speeds = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0];
    final currentIndex = speeds.indexOf(playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    return copyWith(playbackSpeed: speeds[nextIndex]);
  }

  /// Mark as completed
  ProgressState markAsCompleted() {
    return copyWith(
      isCompleted: true,
      isInProgress: false,
      completedAt: DateTime.now(),
    );
  }

  /// Update playback position
  ProgressState updatePosition(int positionMs) {
    return copyWith(
      currentPositionMs: positionMs,
      isInProgress: true,
      lastAccessedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ProgressState(id: $id, position: $currentPositionMs, completed: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProgressState && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify ProgressState model implementation
void validateProgressStateModel() {
  // Test JSON parsing
  final testJson = {
    'id': 'progress-123',
    'user_id': 'user-456',
    'learning_object_id': 'lo-789',
    'current_position_ms': 5000,
    'is_completed': false,
    'is_in_progress': true,
    'playback_speed': 1.5,
    'font_size_index': 2,
    'last_accessed_at': '2024-01-01T00:00:00Z',
  };

  final progress = ProgressState.fromJson(testJson);
  assert(progress.id == 'progress-123');
  assert(progress.currentPositionMs == 5000);
  assert(progress.playbackSpeed == 1.5);
  assert(progress.fontSizeIndex == 2);
  assert(progress.fontSizeName == 'Large');
  assert(progress.fontSizeValue == 18.0);
  assert(progress.formattedSpeed == '1.5x');
  assert(progress.shouldResume == true);

  // Test progress calculation
  assert(progress.calculateProgressPercentage(10000) == 50.0);

  // Test font size cycling
  final nextFontSize = progress.cycleToNextFontSize();
  assert(nextFontSize.fontSizeIndex == 3);
  assert(nextFontSize.fontSizeName == 'X-Large');

  // Cycle should wrap around
  final wrappedFontSize = nextFontSize.cycleToNextFontSize();
  assert(wrappedFontSize.fontSizeIndex == 0);
  assert(wrappedFontSize.fontSizeName == 'Small');

  // Test speed cycling
  final nextSpeed = progress.cycleToNextSpeed();
  assert(nextSpeed.playbackSpeed == 1.75);

  // Test completion
  final completed = progress.markAsCompleted();
  assert(completed.isCompleted == true);
  assert(completed.isInProgress == false);
  assert(completed.completedAt != null);

  // Test position update
  final updated = progress.updatePosition(7500);
  assert(updated.currentPositionMs == 7500);
  assert(updated.isInProgress == true);

  // Test serialization
  final json = progress.toJson();
  assert(json['id'] == 'progress-123');
  assert(json['font_size_index'] == 2);
}
