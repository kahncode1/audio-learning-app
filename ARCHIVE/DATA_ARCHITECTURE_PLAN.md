# Data Architecture Plan: Preprocessing → Database → App

## Overview
Complete data flow architecture from preprocessing pipeline through Supabase database to Flutter app, with perfect alignment and no abstraction layers.

### Schema Simplifications (December 2024)
To maintain focus on MVP functionality, the following fields were removed:
- **courses table**: Removed `category`, `difficulty_level`, `tags`, `is_featured`, `is_published` (can be added later as needed)
- **learning_objects table**: Removed `processing_status`, `processing_error`, `processed_at`, `content_hash` (preprocessing happens before DB insertion)
- **download_cache table**: Removed `last_verified_at`, `current_version` (simplified version tracking)
- **Added**: `external_course_id` to courses table for external system integration

## 1. Data Flow Architecture

```
ElevenLabs API → Python Preprocessing → Supabase DB → Flutter App
                                     ↓
                              CDN (Audio Files)
```

## 2. Supabase Database Schema

### 2.1 courses table (NEW)
```sql
CREATE TABLE public.courses (
  -- Primary key
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Course identification
  external_course_id INTEGER UNIQUE,            -- External system reference ID
  course_number TEXT NOT NULL UNIQUE,           -- e.g., "INS-101"
  title TEXT NOT NULL,                          -- e.g., "Insurance Fundamentals"
  description TEXT,                              -- Course description

  -- Course metrics
  total_learning_objects INTEGER DEFAULT 0,     -- Count of all LOs in course
  total_assignments INTEGER DEFAULT 0,          -- Count of assignments
  estimated_duration_ms BIGINT DEFAULT 0,       -- Total duration in milliseconds

  -- Display
  thumbnail_url TEXT,                            -- Course thumbnail image
  order_index INTEGER NOT NULL DEFAULT 0,       -- Display order in course list

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_courses_course_number ON public.courses(course_number);
CREATE INDEX idx_courses_external_id ON public.courses(external_course_id);
CREATE INDEX idx_courses_order_index ON public.courses(order_index);
```

### 2.2 assignments table (UPDATED)
```sql
CREATE TABLE public.assignments (
  -- Primary key
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Relationships
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,

  -- Assignment identification
  assignment_number INTEGER NOT NULL,           -- e.g., 1, 2, 3
  title TEXT NOT NULL,                          -- Assignment title
  description TEXT,                              -- Assignment description

  -- Metrics
  learning_object_count INTEGER DEFAULT 0,      -- Number of LOs in assignment
  total_duration_ms BIGINT DEFAULT 0,          -- Total duration of all LOs

  -- Display
  order_index INTEGER NOT NULL DEFAULT 0,       -- Display order within course

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  UNIQUE(course_id, assignment_number)
);

-- Indexes
CREATE INDEX idx_assignments_course_id ON public.assignments(course_id);
CREATE INDEX idx_assignments_order_index ON public.assignments(course_id, order_index);
```

### 2.3 learning_objects table (REDESIGNED)
```sql
CREATE TABLE public.learning_objects (
  -- Primary key
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Relationships
  assignment_id UUID NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,  -- Denormalized for query efficiency

  -- Identification
  title TEXT NOT NULL,                          -- LO title
  order_index INTEGER NOT NULL DEFAULT 0,       -- Display order within assignment

  -- Content from preprocessing (stored directly)
  display_text TEXT NOT NULL,                   -- Full text with \n for paragraphs
  paragraphs JSONB NOT NULL,                    -- Array of paragraph strings
  headers JSONB DEFAULT '[]'::jsonb,            -- Array of detected headers
  formatting JSONB DEFAULT '{                   -- Display formatting
    "bold_headers": false,
    "paragraph_spacing": true
  }'::jsonb,
  metadata JSONB NOT NULL,                      -- {
                                                --   "word_count": 2347,
                                                --   "character_count": 15407,
                                                --   "estimated_reading_time": "11 minutes",
                                                --   "language": "en"
                                                -- }

  -- Timing data from preprocessing
  word_timings JSONB NOT NULL,                  -- Array of {
                                                --   "word": "The",
                                                --   "start_ms": 0,
                                                --   "end_ms": 116,
                                                --   "char_start": 0,
                                                --   "char_end": 3,
                                                --   "sentence_index": 0
                                                -- }
  sentence_timings JSONB NOT NULL,              -- Array of {
                                                --   "text": "The objective is clear.",
                                                --   "start_ms": 0,
                                                --   "end_ms": 1500,
                                                --   "sentence_index": 0,
                                                --   "word_start_index": 0,
                                                --   "word_end_index": 3,
                                                --   "char_start": 0,
                                                --   "char_end": 23
                                                -- }
  total_duration_ms BIGINT NOT NULL,            -- Total audio duration

  -- Audio file information
  audio_url TEXT NOT NULL,                      -- CDN URL for MP3 file
  audio_size_bytes BIGINT NOT NULL,             -- Size of audio file
  audio_format TEXT DEFAULT 'mp3',              -- Audio format
  audio_codec TEXT DEFAULT 'mp3_128',           -- Audio codec details
  local_file_path TEXT,                         -- Local cache path for offline

  -- Version control
  file_version INTEGER DEFAULT 1,               -- Version for cache invalidation

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_learning_objects_assignment_id ON public.learning_objects(assignment_id);
CREATE INDEX idx_learning_objects_course_id ON public.learning_objects(course_id);
CREATE INDEX idx_learning_objects_order_index ON public.learning_objects(assignment_id, order_index);
```

### 2.4 user_progress table (ENHANCED)
```sql
CREATE TABLE public.user_progress (
  -- Primary key
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Relationships
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learning_object_id UUID NOT NULL REFERENCES public.learning_objects(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,     -- Denormalized
  assignment_id UUID NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE, -- Denormalized

  -- Completion status
  is_completed BOOLEAN DEFAULT false,
  is_in_progress BOOLEAN DEFAULT false,
  completion_percentage INTEGER DEFAULT 0 CHECK (completion_percentage >= 0 AND completion_percentage <= 100),

  -- Playback position
  current_position_ms BIGINT DEFAULT 0,         -- Current playback position
  last_word_index INTEGER DEFAULT -1,           -- Last highlighted word index
  last_sentence_index INTEGER DEFAULT -1,       -- Last highlighted sentence index

  -- Timestamps
  started_at TIMESTAMPTZ,                       -- First time played
  last_played_at TIMESTAMPTZ,                   -- Most recent play time
  completed_at TIMESTAMPTZ,                     -- Completion timestamp

  -- Usage metrics
  play_count INTEGER DEFAULT 0,                 -- Number of times played
  total_play_time_ms BIGINT DEFAULT 0,         -- Total time spent playing

  -- Settings
  playback_speed DECIMAL(3,2) DEFAULT 1.0,     -- User's preferred speed for this LO

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  UNIQUE(user_id, learning_object_id),
  CHECK (playback_speed >= 0.5 AND playback_speed <= 3.0)
);

-- Indexes
CREATE INDEX idx_user_progress_user_id ON public.user_progress(user_id);
CREATE INDEX idx_user_progress_learning_object_id ON public.user_progress(learning_object_id);
CREATE INDEX idx_user_progress_user_course ON public.user_progress(user_id, course_id);
CREATE INDEX idx_user_progress_user_assignment ON public.user_progress(user_id, assignment_id);
CREATE INDEX idx_user_progress_completion ON public.user_progress(user_id, is_completed);
```

### 2.5 user_course_progress table (NEW - Aggregated progress)
```sql
CREATE TABLE public.user_course_progress (
  -- Primary key
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Relationships
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,

  -- Progress metrics
  completed_learning_objects INTEGER DEFAULT 0,
  total_learning_objects INTEGER NOT NULL,
  completion_percentage INTEGER DEFAULT 0 CHECK (completion_percentage >= 0 AND completion_percentage <= 100),

  -- Time tracking
  total_time_spent_ms BIGINT DEFAULT 0,
  last_accessed_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,

  -- Current position
  last_learning_object_id UUID REFERENCES public.learning_objects(id),
  last_assignment_id UUID REFERENCES public.assignments(id),

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  UNIQUE(user_id, course_id)
);

-- Indexes
CREATE INDEX idx_user_course_progress_user_id ON public.user_course_progress(user_id);
CREATE INDEX idx_user_course_progress_course_id ON public.user_course_progress(course_id);
```

### 2.6 download_cache table (NEW - Track local downloads)
```sql
CREATE TABLE public.download_cache (
  -- Primary key
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Relationships
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  learning_object_id UUID NOT NULL REFERENCES public.learning_objects(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,

  -- Download status
  download_status TEXT DEFAULT 'pending',       -- 'pending', 'downloading', 'completed', 'failed'
  download_progress INTEGER DEFAULT 0,          -- 0-100 percentage

  -- Version tracking
  downloaded_version INTEGER,                   -- Version of downloaded content
  needs_update BOOLEAN DEFAULT false,          -- True if newer version available

  -- File tracking
  audio_downloaded BOOLEAN DEFAULT false,
  content_downloaded BOOLEAN DEFAULT false,
  audio_file_size BIGINT,

  -- Timestamps
  download_started_at TIMESTAMPTZ,
  download_completed_at TIMESTAMPTZ,

  -- Error handling
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  UNIQUE(user_id, learning_object_id),
  CHECK (download_status IN ('pending', 'downloading', 'completed', 'failed', 'cancelled'))
);

-- Indexes
CREATE INDEX idx_download_cache_user_id ON public.download_cache(user_id);
CREATE INDEX idx_download_cache_course_id ON public.download_cache(course_id);
CREATE INDEX idx_download_cache_status ON public.download_cache(download_status);
CREATE INDEX idx_download_cache_needs_update ON public.download_cache(needs_update);
```

## 3. Flutter Model Definitions (Direct DB Mapping)

### 3.1 Course Model
```dart
class Course {
  final String id;
  final int? externalCourseId;        // External system reference
  final String courseNumber;
  final String title;
  final String? description;
  final int totalLearningObjects;
  final int totalAssignments;
  final int estimatedDurationMs;
  final String? thumbnailUrl;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed property
  String get estimatedDuration => _formatDuration(estimatedDurationMs);
}
```

### 3.2 Assignment Model
```dart
class Assignment {
  final String id;
  final String courseId;
  final int assignmentNumber;
  final String title;
  final String? description;
  final int learningObjectCount;
  final int totalDurationMs;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### 3.3 LearningObject Model (Aligned)
```dart
class LearningObject {
  final String id;
  final String assignmentId;
  final String courseId;
  final String title;
  final int orderIndex;

  // Content fields (direct from DB)
  final String displayText;
  final List<String> paragraphs;
  final List<String> headers;
  final ContentFormatting formatting;
  final ContentMetadata metadata;

  // Timing fields (direct from DB)
  final List<WordTiming> wordTimings;
  final List<SentenceTiming> sentenceTimings;
  final int totalDurationMs;

  // Audio fields
  final String audioUrl;
  final int audioSizeBytes;
  final String audioFormat;

  // Version control
  final int fileVersion;

  // Progress fields (from user_progress join)
  final bool isCompleted;
  final bool isInProgress;
  final int currentPositionMs;
  final int lastWordIndex;
  final int lastSentenceIndex;
  final double playbackSpeed;
}
```

### 3.4 Supporting Models
```dart
class ContentFormatting {
  final bool boldHeaders;      // From JSON: bold_headers
  final bool paragraphSpacing;  // From JSON: paragraph_spacing
}

class ContentMetadata {
  final int wordCount;              // From JSON: word_count
  final int characterCount;         // From JSON: character_count
  final String estimatedReadingTime; // From JSON: estimated_reading_time
  final String language;            // From JSON: language
}

class SentenceTiming {
  final String text;               // From JSON: text
  final int startMs;               // From JSON: start_ms
  final int endMs;                 // From JSON: end_ms
  final int sentenceIndex;         // From JSON: sentence_index
  final int wordStartIndex;        // From JSON: word_start_index
  final int wordEndIndex;          // From JSON: word_end_index
  final int charStart;             // From JSON: char_start
  final int charEnd;               // From JSON: char_end
}

class WordTiming {
  final String word;               // From JSON: word
  final int startMs;               // From JSON: start_ms
  final int endMs;                 // From JSON: end_ms
  final int charStart;             // From JSON: char_start
  final int charEnd;               // From JSON: char_end
  final int sentenceIndex;         // From JSON: sentence_index

  // JSON parsing constructor
  factory WordTiming.fromJson(Map<String, dynamic> json) {
    return WordTiming(
      word: json['word'],
      startMs: json['start_ms'],       // MUST be snake_case
      endMs: json['end_ms'],           // MUST be snake_case
      charStart: json['char_start'],   // MUST be snake_case
      charEnd: json['char_end'],       // MUST be snake_case
      sentenceIndex: json['sentence_index'], // MUST be snake_case
    );
  }
}
```

## 4. Implementation Phases

### Phase 1: Database Migration (Week 1)
1. Create new tables in development environment
2. Migrate existing data to new schema
3. Create RLS policies for all tables
4. Test queries and performance

### Phase 2: Preprocessing Pipeline Update (Week 1-2)
1. Update Python scripts to output DB-aligned JSON
2. Create Supabase upload script
3. Process test content through pipeline
4. Upload to CDN and database

### Phase 3: Flutter Model Updates (Week 2)
1. Create new model files matching DB schema
2. Update JSON parsing to handle new structure
3. Remove abstraction layers
4. Update services to use new models

### Phase 4: Service Integration (Week 2-3)
1. Update LocalContentService for new schema
2. Simplify WordTimingServiceSimplified
3. Remove runtime sentence detection
4. Test end-to-end data flow

### Phase 5: Download & Sync (Week 3)
1. Implement course-level download
2. Create local SQLite schema
3. Build sync mechanism
4. Test offline functionality

### Phase 6: Refactored Services Alignment (Week 4)
**Goal:** Update ALL refactored services from codebase improvement to use new data structures

#### 6.1 Download Services (lib/services/download/)
**Priority: Critical - blocks offline functionality**

1. **download_queue_manager.dart:**
   - Update from `LearningObject` to `LearningObjectV2`
   - Align DownloadTask model with new database schema
   - Update queue building logic for new course/assignment structure
   - Maintain queue state with new learning object IDs

2. **file_system_manager.dart:**
   - Update file paths for new data structure
   - Handle JSONB timing files (word_timings, sentence_timings)
   - Support new audio metadata fields (audio_size_bytes, audio_format, file_version)
   - Implement versioning support for content updates

3. **network_downloader.dart:**
   - Update to fetch from new CDN structure
   - Handle new audio_url format from database
   - Support file versioning for incremental updates
   - Implement retry logic for new file types

4. **download_progress_tracker.dart:**
   - Track using new learning object IDs from database
   - Update progress calculations with new metrics
   - Integrate with UserProgressService for unified tracking
   - Support course-level and assignment-level progress

5. **course_download_service_refactored.dart:**
   - Use new CourseService for course data
   - Use LearningObjectService for content fetching
   - Integrate with UserProgressService for tracking
   - Coordinate with all refactored download services

#### 6.2 Highlighting Services (lib/services/highlighting/)
**Priority: High - affects playback experience**

1. **highlight_calculator.dart:**
   - Update to use new WordTiming/SentenceTiming models
   - Use snake_case field names from JSONB (start_ms, end_ms, etc.)
   - Ensure continuous coverage validation
   - Maintain binary search optimization with new models

2. **text_painting_service.dart:**
   - Align with new LearningObjectV2 content structure
   - Support new formatting JSONB fields (bold_headers, paragraph_spacing)
   - Handle paragraphs array from database
   - Apply display_text with proper paragraph breaks

3. **scroll_animation_controller.dart:**
   - Update for new timing structures
   - Use new sentence boundary detection with continuous coverage
   - Support word_start_index and word_end_index from sentence timings

#### 6.3 Player Widgets (lib/widgets/player/)
**Priority: Medium - UI refinement**

1. **highlighted_text_display.dart:**
   - Use LearningObjectV2 model throughout
   - Display content using new structure (paragraphs, headers)
   - Apply JSONB formatting preferences
   - Handle metadata display (word_count, estimated_reading_time)

2. **player_controls_widget.dart:**
   - Integrate with UserProgressService for position tracking
   - Use UserSettingsService for preferences (font_size, playback_speed)
   - Handle playback_speed from user settings
   - Update progress with last_word_index and last_sentence_index

3. **keyboard_shortcut_handler.dart:**
   - Update navigation with new progress tracking
   - Support new learning object structure for navigation
   - Integrate with UserProgressService for position updates

4. **fullscreen_controller.dart:**
   - Align with new display_text structure
   - Support new formatting options from JSONB
   - Handle theme settings from UserSettingsService

### Phase 7: UI Layer Updates (Week 4-5)
**Goal:** Update all UI components to use the newly aligned services

#### 7.1 Files to Delete
1. `lib/services/mock_data_service.dart` - Obsolete mock service
2. `lib/providers/mock_data_provider.dart` - Obsolete mock providers
3. `lib/models/learning_object.dart` - Old model (replaced by learning_object_v2.dart)
4. Remove all mock authentication bypass code

#### 7.2 Provider Updates
1. **Create new service-based providers:**
   - `user_settings_provider.dart` - Wraps UserSettingsService
   - `user_progress_provider.dart` - Wraps UserProgressService
   - `course_provider.dart` - Wraps CourseService
   - `assignment_provider.dart` - Wraps AssignmentService
   - `learning_object_provider.dart` - Wraps LearningObjectService

2. **Update existing providers:**
   - Remove all mockCourseProvider references
   - Remove hardcoded test course IDs
   - Remove mock bypass logic
   - Add proper loading and error states

#### 7.3 Screen Updates
1. **home_screen.dart:**
   - Remove mockCourseProvider usage
   - Use CourseService via provider
   - Display enrolled courses with real metrics
   - Show course progress from UserProgressService

2. **assignments_screen.dart:**
   - Use new Assignment model with metrics
   - Display learningObjectCount and formattedDuration
   - Show completion percentages from UserProgressService
   - Remove mock data references

3. **course_detail_screen.dart:**
   - Display totalAssignments, totalLearningObjects
   - Show estimatedDuration formatted
   - Display real-time progress updates
   - Use gradient colors from course model

4. **enhanced_audio_player_screen.dart:**
   - Update to use LearningObjectV2 model
   - Use new word/sentence timing structures
   - Integrate UserProgressService for tracking
   - Apply user settings (font size, highlight colors)

5. **settings_screen.dart:**
   - Connect to UserSettingsService
   - Enable real preference updates
   - Sync local and cloud settings
   - Add theme toggle functionality

#### 7.4 Widget Updates
1. **CourseCard widget:**
   - Display new course metrics
   - Show enrollment status
   - Display progress percentage

2. **AssignmentTile widget:**
   - Show learning object count badge
   - Display total duration
   - Show completion status

3. **Progress indicators:**
   - Use real UserProgress data
   - Show accurate percentages
   - Update in real-time

### Phase 8: Testing & Validation (Week 5)
**Goal:** Comprehensive testing of the complete new architecture

#### 8.1 Integration Tests
1. **Complete data flow tests:**
   - Database → Services → Providers → UI
   - Test all CRUD operations
   - Verify data consistency

2. **Download service tests:**
   - Test course download with new models
   - Verify file system operations
   - Test offline playback

3. **Highlighting tests:**
   - Verify continuous coverage
   - Test binary search performance
   - Validate 60fps rendering

#### 8.2 Performance Tests
1. **JSONB parsing performance:**
   - Large word timing arrays (1000+ words)
   - Complex nested structures
   - Memory usage monitoring

2. **UI responsiveness:**
   - Screen transition performance
   - List scrolling with many items
   - Real-time highlighting at 60fps

3. **Download performance:**
   - Parallel download efficiency
   - Queue management under load
   - Storage optimization

#### 8.3 End-to-End Tests
1. **User journey tests:**
   - Login → Course selection → Download → Playback
   - Progress tracking accuracy
   - Settings persistence

2. **Offline capability:**
   - Full offline playback
   - Progress sync on reconnection
   - Settings cache behavior

### Implementation Order Summary

1. **Week 3: Phase 5** - Download & Sync infrastructure
2. **Week 4: Phase 6** - Update all refactored services
3. **Week 4-5: Phase 7** - Update UI layer
4. **Week 5: Phase 8** - Testing & validation

### Key Benefits of This Order
- ✅ **Services ready first:** UI has stable foundation to build on
- ✅ **Single UI update:** Avoid multiple rounds of UI changes
- ✅ **Independent testing:** Test services before UI integration
- ✅ **Cleaner migration:** Less risk of breaking changes
- ✅ **Better debugging:** Issues isolated to specific layers

## 5. Migration SQL Scripts

### 5.1 Create Tables Script
```sql
-- Run all CREATE TABLE statements from section 2

-- Add RLS policies
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_objects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_course_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.download_cache ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (example for user_progress)
CREATE POLICY "Users can view own progress"
  ON public.user_progress
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own progress"
  ON public.user_progress
  FOR UPDATE
  USING (auth.uid() = user_id);
```

### 5.2 Data Migration Script
```sql
-- Migrate existing learning_objects data
UPDATE public.learning_objects
SET
  display_text = plain_text,
  paragraphs = '[]'::jsonb,  -- Will be populated by preprocessing
  headers = '[]'::jsonb,
  formatting = '{"bold_headers": false, "paragraph_spacing": true}'::jsonb,
  metadata = jsonb_build_object(
    'word_count', 0,  -- Will be calculated
    'character_count', length(plain_text),
    'estimated_reading_time', '0 minutes',
    'language', 'en'
  )
WHERE display_text IS NULL;
```

## 6. Critical Field Naming Conventions

### IMPORTANT: Snake_case Requirements
All JSON fields throughout the system MUST use snake_case to ensure compatibility:

#### Preprocessing Output (snake_case) ✅
- `start_ms`, `end_ms`, `char_start`, `char_end`, `sentence_index`
- `word_start_index`, `word_end_index`, `total_duration_ms`
- `bold_headers`, `paragraph_spacing`, `word_count`, `character_count`
- `estimated_reading_time`, `display_text`

#### Database Storage (snake_case) ✅
- All JSONB fields must maintain snake_case from preprocessing
- Column names use snake_case (PostgreSQL convention)
- No conversion needed between layers

#### Flutter App Parsing (expects snake_case) ✅
```dart
// Flutter JSON parsing expects snake_case:
WordTiming.fromJson(json) {
  startMs = json['start_ms'];     // NOT json['startMs']
  endMs = json['end_ms'];         // NOT json['endMs']
  charStart = json['char_start']; // NOT json['charStart']
}

SentenceTiming.fromJson(json) {
  wordStartIndex = json['word_start_index']; // NOT json['wordStartIndex']
  wordEndIndex = json['word_end_index'];     // NOT json['wordEndIndex']
}
```

### Field Mapping Reference
| Preprocessing | Database JSONB | Flutter Model Property |
|--------------|----------------|----------------------|
| start_ms | start_ms | startMs |
| end_ms | end_ms | endMs |
| char_start | char_start | charStart |
| char_end | char_end | charEnd |
| sentence_index | sentence_index | sentenceIndex |
| word_start_index | word_start_index | wordStartIndex |
| word_end_index | word_end_index | wordEndIndex |
| total_duration_ms | total_duration_ms | totalDurationMs |
| display_text | display_text | displayText |
| bold_headers | bold_headers | boldHeaders |
| paragraph_spacing | paragraph_spacing | paragraphSpacing |
| word_count | word_count | wordCount |
| character_count | character_count | characterCount |
| estimated_reading_time | estimated_reading_time | estimatedReadingTime |

## 7. Benefits & Outcomes

### Performance Improvements
- **60fps highlighting**: Pre-computed sentence boundaries
- **Instant playback**: No runtime processing
- **Reduced memory**: Direct JSON mapping
- **Faster searches**: Optimized indexes

### Development Benefits
- **No abstraction layers**: Direct DB → Model mapping
- **Single source of truth**: Preprocessing defines all
- **Clear data flow**: Predictable and debuggable
- **Easy updates**: Schema changes flow through
- **Consistent naming**: Snake_case throughout pipeline

### User Experience
- **Offline support**: Complete data downloaded
- **Progress sync**: Seamless across devices
- **Fast navigation**: Course structure cached
- **Reliable playback**: CDN-hosted audio

## 8. Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Timing calculations
- Progress tracking
- Snake_case field parsing

### Integration Tests
- Preprocessing → DB flow
- DB → Flutter sync
- Offline/online switching
- Field name consistency validation

### Performance Tests
- 60fps highlighting verification
- Memory usage monitoring
- Download speed optimization

## 9. Field Validation Checklist

### Required Fields Verification
✓ **Learning Objects Table**
- All timing fields use snake_case in JSONB
- Added `audio_codec` for codec details
- Added `local_file_path` for offline cache
- `word_timings` uses: start_ms, end_ms, char_start, char_end, sentence_index
- `sentence_timings` uses: start_ms, end_ms, word_start_index, word_end_index

✓ **User Progress Table**
- Contains `last_word_index` for highlighting state
- Contains `last_sentence_index` for highlighting state
- All position tracking fields present

✓ **Preprocessing Alignment**
- All output fields documented in SCHEMA.md
- Snake_case used consistently
- No field name transformations needed

✓ **Flutter Model Alignment**
- JSON parsing expects snake_case
- Model properties use camelCase internally
- fromJson() methods handle conversion

## 10. Next Steps

1. **Review and approve this plan**
2. **Verify preprocessing outputs snake_case fields**
3. **Create development database with snake_case JSONB**
4. **Write migration scripts maintaining field naming**
5. **Test end-to-end with sample data**
6. **Begin Flutter implementation**

## Appendix: Sample Data

### Critical Note on Field Names
**ALL JSON fields MUST use snake_case throughout the entire pipeline:**
- Preprocessing generates snake_case
- Database stores snake_case in JSONB
- Flutter expects snake_case when parsing JSON

This is non-negotiable for system compatibility.

### Sample Course JSON
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "external_course_id": 12345,
  "course_number": "INS-101",
  "title": "Insurance Fundamentals",
  "description": "Introduction to insurance principles and practices",
  "total_learning_objects": 45,
  "total_assignments": 12,
  "estimated_duration_ms": 10800000,
  "thumbnail_url": "https://cdn.example.com/courses/ins-101/thumb.jpg",
  "order_index": 1
}
```

### Sample Learning Object JSON (from DB)
```json
{
  "id": "63ad7b78-0970-4265-a4fe-51f3fee39d5f",
  "assignment_id": "assignment-123",
  "course_id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Understanding Risk",
  "display_text": "The objective of this lesson...",
  "paragraphs": ["The objective of this lesson...", "Let's begin..."],
  "headers": [],
  "formatting": {
    "bold_headers": false,
    "paragraph_spacing": true
  },
  "metadata": {
    "word_count": 2347,
    "character_count": 15407,
    "estimated_reading_time": "11 minutes",
    "language": "en"
  },
  "word_timings": [
    {
      "word": "The",
      "start_ms": 0,
      "end_ms": 116,
      "char_start": 0,
      "char_end": 3,
      "sentence_index": 0
    }
    // ... more words
  ],
  "sentence_timings": [
    {
      "text": "The objective of this lesson...",
      "start_ms": 0,
      "end_ms": 1500,
      "sentence_index": 0,
      "word_start_index": 0,
      "word_end_index": 5,
      "char_start": 0,
      "char_end": 32
    }
    // ... more sentences
  ],
  "total_duration_ms": 660000,
  "audio_url": "https://cdn.example.com/audio/63ad7b78.mp3",
  "audio_size_bytes": 5242880,
  "audio_format": "mp3",
  "audio_codec": "mp3_128",
  "file_version": 1
}
```