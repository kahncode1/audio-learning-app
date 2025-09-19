-- Migration: Download-First Architecture
-- Phase 3: Supabase Integration
-- Date: 2025-09-18
-- Description: Update schema to support pre-processed audio downloads instead of real-time TTS

-- ============================================================================
-- PART 1: Add new columns to learning_objects for download architecture
-- ============================================================================

-- Add download-related columns to learning_objects table
ALTER TABLE public.learning_objects
ADD COLUMN IF NOT EXISTS audio_url TEXT,              -- CDN URL for MP3 file
ADD COLUMN IF NOT EXISTS content_url TEXT,            -- CDN URL for content.json
ADD COLUMN IF NOT EXISTS timing_url TEXT,             -- CDN URL for timing.json
ADD COLUMN IF NOT EXISTS file_version INTEGER DEFAULT 1,  -- Version tracking for cache invalidation
ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT,     -- Total size of all files for this LO
ADD COLUMN IF NOT EXISTS checksum TEXT;               -- MD5/SHA256 for integrity verification

-- Add columns for tracking local download status (app-side tracking)
ALTER TABLE public.learning_objects
ADD COLUMN IF NOT EXISTS download_status TEXT DEFAULT 'pending'
  CHECK (download_status IN ('pending', 'downloading', 'completed', 'failed', 'not_available')),
ADD COLUMN IF NOT EXISTS last_download_attempt TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS download_error_message TEXT;

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_learning_objects_download_status
  ON public.learning_objects(download_status);
CREATE INDEX IF NOT EXISTS idx_learning_objects_file_version
  ON public.learning_objects(file_version);

-- ============================================================================
-- PART 2: Create download_progress table for user-specific tracking
-- ============================================================================

-- Drop table if exists (for clean migration)
DROP TABLE IF EXISTS public.download_progress CASCADE;

-- Create download progress tracking table
CREATE TABLE public.download_progress (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  learning_object_id UUID REFERENCES public.learning_objects(id) ON DELETE CASCADE,
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,  -- Denormalized for easier querying

  -- Download status tracking
  download_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (download_status IN ('pending', 'queued', 'downloading', 'completed', 'failed', 'cancelled')),
  progress_percentage INTEGER DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),

  -- File tracking
  files_completed INTEGER DEFAULT 0,
  total_files INTEGER DEFAULT 3,  -- audio, content, timing
  bytes_downloaded BIGINT DEFAULT 0,
  total_bytes BIGINT,

  -- Error handling
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,
  error_message TEXT,
  error_code TEXT,

  -- Timestamps
  queued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Ensure one download record per user per learning object
  UNIQUE(user_id, learning_object_id),

  -- Additional constraints
  CHECK (files_completed <= total_files),
  CHECK (bytes_downloaded <= total_bytes OR total_bytes IS NULL)
);

-- Create indexes for efficient queries
CREATE INDEX idx_download_progress_user_id ON public.download_progress(user_id);
CREATE INDEX idx_download_progress_learning_object_id ON public.download_progress(learning_object_id);
CREATE INDEX idx_download_progress_course_id ON public.download_progress(course_id);
CREATE INDEX idx_download_progress_status ON public.download_progress(download_status);
CREATE INDEX idx_download_progress_user_status ON public.download_progress(user_id, download_status);
CREATE INDEX idx_download_progress_user_course ON public.download_progress(user_id, course_id);

-- ============================================================================
-- PART 3: Create course_downloads table for course-level tracking
-- ============================================================================

DROP TABLE IF EXISTS public.course_downloads CASCADE;

CREATE TABLE public.course_downloads (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id UUID REFERENCES public.courses(id) ON DELETE CASCADE,

  -- Overall course download status
  download_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (download_status IN ('pending', 'downloading', 'completed', 'failed', 'partial')),

  -- Progress tracking
  learning_objects_completed INTEGER DEFAULT 0,
  total_learning_objects INTEGER NOT NULL,
  total_size_bytes BIGINT,
  downloaded_bytes BIGINT DEFAULT 0,

  -- Settings
  wifi_only BOOLEAN DEFAULT true,
  auto_retry BOOLEAN DEFAULT true,

  -- Timestamps
  initiated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  -- Ensure one download per user per course
  UNIQUE(user_id, course_id)
);

CREATE INDEX idx_course_downloads_user_id ON public.course_downloads(user_id);
CREATE INDEX idx_course_downloads_course_id ON public.course_downloads(course_id);
CREATE INDEX idx_course_downloads_status ON public.course_downloads(download_status);

-- ============================================================================
-- PART 4: Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE public.download_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_downloads ENABLE ROW LEVEL SECURITY;

-- RLS for download_progress
CREATE POLICY "Users can view own download progress"
  ON public.download_progress
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own download progress"
  ON public.download_progress
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own download progress"
  ON public.download_progress
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own download progress"
  ON public.download_progress
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS for course_downloads
CREATE POLICY "Users can view own course downloads"
  ON public.course_downloads
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own course downloads"
  ON public.course_downloads
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own course downloads"
  ON public.course_downloads
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own course downloads"
  ON public.course_downloads
  FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================================
-- PART 5: Helper Functions
-- ============================================================================

-- Function to get course download statistics
CREATE OR REPLACE FUNCTION get_course_download_stats(p_user_id UUID, p_course_id UUID)
RETURNS TABLE (
  total_objects INTEGER,
  completed_objects INTEGER,
  failed_objects INTEGER,
  pending_objects INTEGER,
  total_bytes BIGINT,
  downloaded_bytes BIGINT,
  progress_percentage INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::INTEGER as total_objects,
    COUNT(*) FILTER (WHERE dp.download_status = 'completed')::INTEGER as completed_objects,
    COUNT(*) FILTER (WHERE dp.download_status = 'failed')::INTEGER as failed_objects,
    COUNT(*) FILTER (WHERE dp.download_status IN ('pending', 'queued'))::INTEGER as pending_objects,
    SUM(lo.file_size_bytes) as total_bytes,
    SUM(CASE WHEN dp.download_status = 'completed' THEN lo.file_size_bytes ELSE dp.bytes_downloaded END) as downloaded_bytes,
    CASE
      WHEN SUM(lo.file_size_bytes) > 0 THEN
        (SUM(CASE WHEN dp.download_status = 'completed' THEN lo.file_size_bytes ELSE dp.bytes_downloaded END) * 100 / SUM(lo.file_size_bytes))::INTEGER
      ELSE 0
    END as progress_percentage
  FROM public.learning_objects lo
  LEFT JOIN public.download_progress dp ON dp.learning_object_id = lo.id AND dp.user_id = p_user_id
  JOIN public.assignments a ON lo.assignment_id = a.id
  WHERE a.course_id = p_course_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 6: Migration of existing data (preserve current content)
-- ============================================================================

-- Update existing learning objects to have pending download status
UPDATE public.learning_objects
SET download_status = 'pending'
WHERE download_status IS NULL;

-- ============================================================================
-- PART 7: Comments for documentation
-- ============================================================================

-- Add table comments
COMMENT ON TABLE public.download_progress IS 'Tracks individual learning object download progress per user';
COMMENT ON TABLE public.course_downloads IS 'Tracks overall course download status per user';

-- Add column comments
COMMENT ON COLUMN public.learning_objects.audio_url IS 'CDN URL for pre-generated MP3 audio file';
COMMENT ON COLUMN public.learning_objects.content_url IS 'CDN URL for content.json containing display text';
COMMENT ON COLUMN public.learning_objects.timing_url IS 'CDN URL for timing.json containing word and sentence timings';
COMMENT ON COLUMN public.learning_objects.file_version IS 'Version number for cache invalidation';
COMMENT ON COLUMN public.learning_objects.download_status IS 'Global download availability status';

COMMENT ON COLUMN public.download_progress.progress_percentage IS 'Download progress from 0-100';
COMMENT ON COLUMN public.download_progress.retry_count IS 'Number of retry attempts for failed downloads';
COMMENT ON COLUMN public.download_progress.course_id IS 'Denormalized course_id for efficient querying';

-- ============================================================================
-- ROLLBACK SCRIPT (commented out - run manually if needed)
-- ============================================================================

/*
-- To rollback this migration:

-- Drop new tables
DROP TABLE IF EXISTS public.download_progress CASCADE;
DROP TABLE IF EXISTS public.course_downloads CASCADE;

-- Remove new columns from learning_objects
ALTER TABLE public.learning_objects
DROP COLUMN IF EXISTS audio_url,
DROP COLUMN IF EXISTS content_url,
DROP COLUMN IF EXISTS timing_url,
DROP COLUMN IF EXISTS file_version,
DROP COLUMN IF EXISTS file_size_bytes,
DROP COLUMN IF EXISTS checksum,
DROP COLUMN IF EXISTS download_status,
DROP COLUMN IF EXISTS last_download_attempt,
DROP COLUMN IF EXISTS download_error_message;

-- Drop indexes
DROP INDEX IF EXISTS idx_learning_objects_download_status;
DROP INDEX IF EXISTS idx_learning_objects_file_version;

-- Drop function
DROP FUNCTION IF EXISTS get_course_download_stats(UUID, UUID);

*/