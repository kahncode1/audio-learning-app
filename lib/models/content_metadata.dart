/// Content Metadata and Formatting Models
///
/// Purpose: Supporting models for LearningObject content structure
/// Dependencies: None
///
/// Status: ✅ Created for DATA_ARCHITECTURE_PLAN (Phase 3)
///   - Direct JSONB field mapping with snake_case
///   - Aligns with preprocessing pipeline output
///
/// Usage:
///   final formatting = ContentFormatting.fromJson(jsonData);
///   final metadata = ContentMetadata.fromJson(jsonData);

/// Content formatting preferences from JSONB
class ContentFormatting {
  final bool boldHeaders;
  final bool paragraphSpacing;

  ContentFormatting({
    this.boldHeaders = false,
    this.paragraphSpacing = true,
  });

  factory ContentFormatting.fromJson(Map<String, dynamic> json) {
    return ContentFormatting(
      boldHeaders: json['bold_headers'] as bool? ?? false,
      paragraphSpacing: json['paragraph_spacing'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bold_headers': boldHeaders,
      'paragraph_spacing': paragraphSpacing,
    };
  }
}

/// Content metadata from JSONB
class ContentMetadata {
  final int wordCount;
  final int characterCount;
  final String estimatedReadingTime;
  final String language;

  ContentMetadata({
    required this.wordCount,
    required this.characterCount,
    required this.estimatedReadingTime,
    required this.language,
  });

  factory ContentMetadata.fromJson(Map<String, dynamic> json) {
    return ContentMetadata(
      // Handle both snake_case and camelCase for backward compatibility
      wordCount: (json['word_count'] ?? json['wordCount'] ?? 0) as int,
      characterCount: (json['character_count'] ?? json['characterCount'] ?? 0) as int,
      estimatedReadingTime: (json['estimated_reading_time'] ?? json['estimatedReadingTime'] ?? '0 min') as String,
      language: (json['language'] ?? 'en') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word_count': wordCount,
      'character_count': characterCount,
      'estimated_reading_time': estimatedReadingTime,
      'language': language,
    };
  }
}
