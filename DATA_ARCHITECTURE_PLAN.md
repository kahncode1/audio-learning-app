# Data Architecture Plan: Preprocessing → Database → App

## Overview
Complete data flow architecture from preprocessing pipeline through Supabase database to Flutter app, with perfect alignment and no abstraction layers.

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
  course_number TEXT NOT NULL UNIQUE,           -- e.g., "INS-101"
  title TEXT NOT NULL,                          -- e.g., "Insurance Fundamentals"
  description TEXT,                              -- Course description

  -- Course metrics
  total_learning_objects INTEGER DEFAULT 0,     -- Count of all LOs in course
  total_assignments INTEGER DEFAULT 0,          -- Count of assignments
  estimated_duration_ms BIGINT DEFAULT 0,       -- Total duration in milliseconds

  -- Categorization
  category TEXT,                                -- e.g., "Insurance", "Finance", "Risk Management"
  difficulty_level TEXT,                        -- e.g., "Beginner", "Intermediate", "Advanced"
  tags JSONB,                                    -- Array of tags for search/filtering

  -- Display
  thumbnail_url TEXT,                            -- Course thumbnail image
  order_index INTEGER NOT NULL DEFAULT 0,       -- Display order in course list
  is_featured BOOLEAN DEFAULT false,            -- Featured course flag
  is_published BOOLEAN DEFAULT true,            -- Published/draft status

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CHECK (difficulty_level IN ('Beginner', 'Intermediate', 'Advanced', 'Expert'))
);

-- Indexes
CREATE INDEX idx_courses_course_number ON public.courses(course_number);
CREATE INDEX idx_courses_category ON public.courses(category);
CREATE INDEX idx_courses_is_featured ON public.courses(is_featured);
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
    "boldHeaders": false,
    "paragraphSpacing": true
  }'::jsonb,
  metadata JSONB NOT NULL,                      -- {
                                                --   "wordCount": 2347,
                                                --   "characterCount": 15407,
                                                --   "estimatedReadingTime": "11 minutes",
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
                                                --   "wordStartIndex": 0,
                                                --   "wordEndIndex": 3,
                                                --   "char_start": 0,
                                                --   "char_end": 23
                                                -- }
  total_duration_ms BIGINT NOT NULL,            -- Total audio duration

  -- Audio file information
  audio_url TEXT NOT NULL,                      -- CDN URL for MP3 file
  audio_size_bytes BIGINT NOT NULL,             -- Size of audio file
  audio_format TEXT DEFAULT 'mp3',              -- Audio format

  -- Version control
  file_version INTEGER DEFAULT 1,               -- Version for cache invalidation
  content_hash TEXT,                            -- SHA256 hash of content for integrity

  -- Processing status
  processing_status TEXT DEFAULT 'completed',   -- 'pending', 'processing', 'completed', 'failed'
  processing_error TEXT,                        -- Error message if processing failed
  processed_at TIMESTAMPTZ,                     -- When processing completed

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Constraints
  CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed'))
);

-- Indexes
CREATE INDEX idx_learning_objects_assignment_id ON public.learning_objects(assignment_id);
CREATE INDEX idx_learning_objects_course_id ON public.learning_objects(course_id);
CREATE INDEX idx_learning_objects_order_index ON public.learning_objects(assignment_id, order_index);
CREATE INDEX idx_learning_objects_processing_status ON public.learning_objects(processing_status);
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
  current_version INTEGER,                      -- Current version in DB
  needs_update BOOLEAN DEFAULT false,          -- True if newer version available

  -- File tracking
  audio_downloaded BOOLEAN DEFAULT false,
  content_downloaded BOOLEAN DEFAULT false,
  audio_file_size BIGINT,

  -- Timestamps
  download_started_at TIMESTAMPTZ,
  download_completed_at TIMESTAMPTZ,
  last_verified_at TIMESTAMPTZ,

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
  final String courseNumber;
  final String title;
  final String? description;
  final int totalLearningObjects;
  final int totalAssignments;
  final int estimatedDurationMs;
  final String? category;
  final String? difficultyLevel;
  final List<String>? tags;
  final String? thumbnailUrl;
  final int orderIndex;
  final bool isFeatured;
  final bool isPublished;
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
  final String? contentHash;

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
  final bool boldHeaders;
  final bool paragraphSpacing;
}

class ContentMetadata {
  final int wordCount;
  final int characterCount;
  final String estimatedReadingTime;
  final String language;
}

class SentenceTiming {
  final String text;
  final int startMs;
  final int endMs;
  final int sentenceIndex;
  final int wordStartIndex;
  final int wordEndIndex;
  final int charStart;
  final int charEnd;
}

class WordTiming {
  final String word;
  final int startMs;
  final int endMs;
  final int charStart;
  final int charEnd;
  final int sentenceIndex;
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
  formatting = '{"boldHeaders": false, "paragraphSpacing": true}'::jsonb,
  metadata = jsonb_build_object(
    'wordCount', 0,  -- Will be calculated
    'characterCount', length(plain_text),
    'estimatedReadingTime', '0 minutes',
    'language', 'en'
  )
WHERE display_text IS NULL;
```

## 6. Benefits & Outcomes

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

### User Experience
- **Offline support**: Complete data downloaded
- **Progress sync**: Seamless across devices
- **Fast navigation**: Course structure cached
- **Reliable playback**: CDN-hosted audio

## 7. Testing Strategy

### Unit Tests
- Model serialization/deserialization
- Timing calculations
- Progress tracking

### Integration Tests
- Preprocessing → DB flow
- DB → Flutter sync
- Offline/online switching

### Performance Tests
- 60fps highlighting verification
- Memory usage monitoring
- Download speed optimization

## 8. Next Steps

1. **Review and approve this plan**
2. **Create development database**
3. **Write migration scripts**
4. **Update preprocessing pipeline**
5. **Begin Flutter implementation**

## Appendix: Sample Data

### Sample Course JSON
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "course_number": "INS-101",
  "title": "Insurance Fundamentals",
  "description": "Introduction to insurance principles and practices",
  "total_learning_objects": 45,
  "total_assignments": 12,
  "estimated_duration_ms": 10800000,
  "category": "Insurance",
  "difficulty_level": "Beginner",
  "tags": ["insurance", "risk management", "fundamentals"],
  "thumbnail_url": "https://cdn.example.com/courses/ins-101/thumb.jpg",
  "order_index": 1,
  "is_featured": true
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
    "boldHeaders": false,
    "paragraphSpacing": true
  },
  "metadata": {
    "wordCount": 2347,
    "characterCount": 15407,
    "estimatedReadingTime": "11 minutes",
    "language": "en"
  },
  "word_timings": [...],
  "sentence_timings": [...],
  "total_duration_ms": 660000,
  "audio_url": "https://cdn.example.com/audio/63ad7b78.mp3",
  "audio_size_bytes": 5242880,
  "file_version": 1
}
```