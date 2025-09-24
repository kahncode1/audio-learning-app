/// User Settings Model
///
/// Purpose: Stores user preferences and settings
/// Dependencies: None
///
/// Status: ✅ Created for DATA_ARCHITECTURE_PLAN (Phase 3)
///   - Direct database mapping from user_settings table
///   - Stores JSONB preferences and theme settings
///
/// Usage:
///   final settings = UserSettings.fromJson(jsonData);
///   final fontSize = settings.getFontSize();

class UserSettings {
  final String id;
  final String userId;

  // Theme settings
  final String themeName;
  final Map<String, dynamic> themeSettings;

  // User preferences (JSONB)
  final Map<String, dynamic> preferences;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings({
    required this.id,
    required this.userId,
    this.themeName = 'light',
    Map<String, dynamic>? themeSettings,
    Map<String, dynamic>? preferences,
    required this.createdAt,
    required this.updatedAt,
  })  : themeSettings = themeSettings ?? {},
        preferences = preferences ?? {};

  /// Get font size preference
  double getFontSize() {
    return (preferences['font_size'] as num?)?.toDouble() ?? 16.0;
  }

  /// Get auto-play preference
  bool getAutoPlay() {
    return preferences['auto_play'] as bool? ?? true;
  }

  /// Get default playback speed
  double getDefaultPlaybackSpeed() {
    return (preferences['default_playback_speed'] as num?)?.toDouble() ?? 1.0;
  }

  /// Get highlight color for words
  String getWordHighlightColor() {
    return preferences['word_highlight_color'] as String? ?? '#FFEB3B';
  }

  /// Get highlight color for sentences
  String getSentenceHighlightColor() {
    return preferences['sentence_highlight_color'] as String? ?? '#FFE0B2';
  }

  /// Check if dark mode is enabled
  bool get isDarkMode => themeName == 'dark';

  /// Creates UserSettings from JSON map
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      themeName: json['theme_name'] as String? ?? 'light',
      themeSettings: Map<String, dynamic>.from(json['theme_settings'] ?? {}),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Converts UserSettings to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'theme_name': themeName,
      'theme_settings': themeSettings,
      'preferences': preferences,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with updated fields
  UserSettings copyWith({
    String? id,
    String? userId,
    String? themeName,
    Map<String, dynamic>? themeSettings,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      themeName: themeName ?? this.themeName,
      themeSettings: themeSettings ?? this.themeSettings,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Update a specific preference
  UserSettings updatePreference(String key, dynamic value) {
    final newPreferences = Map<String, dynamic>.from(preferences);
    newPreferences[key] = value;
    return copyWith(preferences: newPreferences);
  }

  /// Update font size
  UserSettings updateFontSize(double fontSize) {
    return updatePreference('font_size', fontSize);
  }

  /// Update auto-play setting
  UserSettings updateAutoPlay(bool autoPlay) {
    return updatePreference('auto_play', autoPlay);
  }

  /// Update default playback speed
  UserSettings updateDefaultPlaybackSpeed(double speed) {
    return updatePreference('default_playback_speed', speed);
  }

  /// Toggle theme between light and dark
  UserSettings toggleTheme() {
    return copyWith(themeName: isDarkMode ? 'light' : 'dark');
  }

  @override
  String toString() {
    return 'UserSettings(id: $id, theme: $themeName, fontSize: ${getFontSize()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSettings && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Validation function to verify UserSettings model implementation
void validateUserSettingsModel() {
  // Test JSON parsing with preferences
  final testJson = {
    'id': 'settings-123',
    'user_id': 'user-456',
    'theme_name': 'dark',
    'theme_settings': {
      'primary_color': '#2196F3',
      'accent_color': '#FF5722',
    },
    'preferences': {
      'font_size': 18.0,
      'auto_play': false,
      'default_playback_speed': 1.5,
      'word_highlight_color': '#FFFF00',
      'sentence_highlight_color': '#FFE082',
    },
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-02T00:00:00Z',
  };

  final settings = UserSettings.fromJson(testJson);
  assert(settings.id == 'settings-123');
  assert(settings.userId == 'user-456');
  assert(settings.themeName == 'dark');
  assert(settings.isDarkMode == true);
  assert(settings.getFontSize() == 18.0);
  assert(settings.getAutoPlay() == false);
  assert(settings.getDefaultPlaybackSpeed() == 1.5);
  assert(settings.getWordHighlightColor() == '#FFFF00');
  assert(settings.getSentenceHighlightColor() == '#FFE082');

  // Test theme settings
  assert(settings.themeSettings['primary_color'] == '#2196F3');
  assert(settings.themeSettings['accent_color'] == '#FF5722');

  // Test serialization
  final json = settings.toJson();
  assert(json['id'] == 'settings-123');
  assert(json['theme_name'] == 'dark');
  assert((json['preferences'] as Map)['font_size'] == 18.0);

  // Test preference updates
  final updatedSettings = settings
      .updateFontSize(20.0)
      .updateAutoPlay(true)
      .updateDefaultPlaybackSpeed(2.0);
  assert(updatedSettings.getFontSize() == 20.0);
  assert(updatedSettings.getAutoPlay() == true);
  assert(updatedSettings.getDefaultPlaybackSpeed() == 2.0);

  // Test theme toggle
  final toggledSettings = settings.toggleTheme();
  assert(toggledSettings.themeName == 'light');
  assert(toggledSettings.isDarkMode == false);

  // Test defaults for missing preferences
  final minimalJson = {
    'id': 'settings-789',
    'user_id': 'user-000',
    'created_at': '2024-01-01T00:00:00Z',
    'updated_at': '2024-01-01T00:00:00Z',
  };

  final defaultSettings = UserSettings.fromJson(minimalJson);
  assert(defaultSettings.themeName == 'light');
  assert(defaultSettings.getFontSize() == 16.0);
  assert(defaultSettings.getAutoPlay() == true);
  assert(defaultSettings.getDefaultPlaybackSpeed() == 1.0);
  assert(defaultSettings.getWordHighlightColor() == '#FFEB3B');
}
