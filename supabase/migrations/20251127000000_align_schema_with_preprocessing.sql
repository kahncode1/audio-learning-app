-- Migration: Align database schema with preprocessing script output
-- Date: 2025-11-27
-- Purpose: Rename columns to match preprocessing output and add lookup table tracking

-- Step 1: Rename timing columns to match preprocessing script output
ALTER TABLE learning_objects
RENAME COLUMN word_timings TO words;

ALTER TABLE learning_objects
RENAME COLUMN sentence_timings TO sentences;

-- Step 2: Add new columns for lookup table tracking and versioning
ALTER TABLE learning_objects
ADD COLUMN IF NOT EXISTS lookup_table_url text NULL,
ADD COLUMN IF NOT EXISTS content_version text DEFAULT '1.0',
ADD COLUMN IF NOT EXISTS preprocessing_source text DEFAULT 'elevenlabs-complete-with-paragraphs';

-- Step 3: Add comment explaining the structure
COMMENT ON COLUMN learning_objects.words IS 'Array of word timing objects from preprocessing';
COMMENT ON COLUMN learning_objects.sentences IS 'Array of sentence timing objects from preprocessing';
COMMENT ON COLUMN learning_objects.lookup_table_url IS 'URL to the separate lookup.json file in Supabase Storage';
COMMENT ON COLUMN learning_objects.content_version IS 'Version of the preprocessing format';
COMMENT ON COLUMN learning_objects.preprocessing_source IS 'Source preprocessing script used';

-- Note: The lookup table itself is stored as a separate file in Supabase Storage
-- at the path: /audio-files/{learning_object_id}/lookup.json
-- This keeps the database lean while providing O(1) position lookups for 60fps highlighting