-- Migration: Data Migration from Test Content
-- Date: 2025-01-23
-- Description: Migrates existing test data to new schema with proper snake_case JSONB fields

-- ============================================================================
-- PART 1: Create test user if not exists
-- ============================================================================

-- Ensure we have a test user in auth.users
INSERT INTO auth.users (
  id,
  email,
  raw_user_meta_data,
  created_at,
  updated_at,
  email_confirmed_at,
  role,
  aud,
  confirmation_sent_at
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  'test@example.com',
  '{"full_name": "Test User"}'::jsonb,
  NOW(),
  NOW(),
  NOW(),
  'authenticated',
  'authenticated',
  NOW()
) ON CONFLICT (id) DO UPDATE
SET
  email = EXCLUDED.email,
  updated_at = NOW();

-- ============================================================================
-- PART 2: Insert comprehensive test course data
-- ============================================================================

-- Insert main test course (Insurance Fundamentals)
INSERT INTO public.courses (
  id,
  external_course_id,
  course_number,
  title,
  description,
  thumbnail_url,
  order_index,
  created_at,
  updated_at
)
VALUES (
  '550e8400-e29b-41d4-a716-446655440001',
  10001,
  'INS-101',
  'Insurance Fundamentals',
  'Learn how insurance facilitates key societal activities and risk management',
  'https://cdn.example.com/courses/ins-101/thumb.jpg',
  1,
  NOW(),
  NOW()
) ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description,
  updated_at = NOW();

-- Insert second test course
INSERT INTO public.courses (
  id,
  external_course_id,
  course_number,
  title,
  description,
  thumbnail_url,
  order_index
)
VALUES (
  '550e8400-e29b-41d4-a716-446655440002',
  10002,
  'INS-201',
  'Claims Management',
  'Advanced techniques in insurance claims processing and management',
  'https://cdn.example.com/courses/ins-201/thumb.jpg',
  2
) ON CONFLICT (id) DO UPDATE
SET
  title = EXCLUDED.title,
  description = EXCLUDED.description;

-- ============================================================================
-- PART 3: Insert assignments
-- ============================================================================

-- Assignment 1 for INS-101
INSERT INTO public.assignments (
  id,
  course_id,
  assignment_number,
  title,
  description,
  order_index
)
VALUES (
  '660e8400-e29b-41d4-a716-446655440101',
  '550e8400-e29b-41d4-a716-446655440001',
  1,
  'Understanding Risk and Insurance',
  'Explore how insurance transforms risk and supports society',
  1
) ON CONFLICT (id) DO NOTHING;

-- Assignment 2 for INS-101
INSERT INTO public.assignments (
  id,
  course_id,
  assignment_number,
  title,
  description,
  order_index
)
VALUES (
  '660e8400-e29b-41d4-a716-446655440102',
  '550e8400-e29b-41d4-a716-446655440001',
  2,
  'Case Reserve Methods',
  'Learn different approaches to establishing case reserves',
  2
) ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- PART 4: Insert learning object with complete snake_case JSONB structure
-- ============================================================================

-- Main test learning object with full content
INSERT INTO public.learning_objects (
  id,
  assignment_id,
  course_id,
  title,
  order_index,
  display_text,
  paragraphs,
  headers,
  formatting,
  metadata,
  word_timings,
  sentence_timings,
  total_duration_ms,
  audio_url,
  audio_size_bytes,
  audio_format,
  audio_codec,
  file_version
)
VALUES (
  '63ad7b78-0970-4265-a4fe-51f3fee39d5f',
  '660e8400-e29b-41d4-a716-446655440101',
  '550e8400-e29b-41d4-a716-446655440001',
  'How Insurance Facilitates Society',
  1,
  -- Display text with paragraph breaks
  E'The objective of this lesson is to illustrate how insurance facilitates key societal activities.\nLet''s begin.\nInsurance is a vital component of an individual''s or organization''s approach to managing risk.',

  -- Paragraphs array
  '[
    "The objective of this lesson is to illustrate how insurance facilitates key societal activities.",
    "Let''s begin.",
    "Insurance is a vital component of an individual''s or organization''s approach to managing risk."
  ]'::jsonb,

  -- Headers array
  '["The Effect of Insurance", "Perception versus Reality", "What Do You Know?"]'::jsonb,

  -- Formatting preferences
  '{"bold_headers": false, "paragraph_spacing": true}'::jsonb,

  -- Metadata with snake_case fields
  '{
    "word_count": 2347,
    "character_count": 15407,
    "estimated_reading_time": "11 minutes",
    "language": "en"
  }'::jsonb,

  -- Word timings with snake_case fields
  '[
    {"word": "The", "start_ms": 0, "end_ms": 250, "char_start": 0, "char_end": 3, "sentence_index": 0},
    {"word": "objective", "start_ms": 250, "end_ms": 750, "char_start": 4, "char_end": 13, "sentence_index": 0},
    {"word": "of", "start_ms": 750, "end_ms": 900, "char_start": 14, "char_end": 16, "sentence_index": 0},
    {"word": "this", "start_ms": 900, "end_ms": 1150, "char_start": 17, "char_end": 21, "sentence_index": 0},
    {"word": "lesson", "start_ms": 1150, "end_ms": 1500, "char_start": 22, "char_end": 28, "sentence_index": 0},
    {"word": "is", "start_ms": 1500, "end_ms": 1650, "char_start": 29, "char_end": 31, "sentence_index": 0},
    {"word": "to", "start_ms": 1650, "end_ms": 1800, "char_start": 32, "char_end": 34, "sentence_index": 0},
    {"word": "illustrate", "start_ms": 1800, "end_ms": 2300, "char_start": 35, "char_end": 45, "sentence_index": 0},
    {"word": "how", "start_ms": 2300, "end_ms": 2500, "char_start": 46, "char_end": 49, "sentence_index": 0},
    {"word": "insurance", "start_ms": 2500, "end_ms": 3000, "char_start": 50, "char_end": 59, "sentence_index": 0},
    {"word": "facilitates", "start_ms": 3000, "end_ms": 3500, "char_start": 60, "char_end": 71, "sentence_index": 0},
    {"word": "key", "start_ms": 3500, "end_ms": 3750, "char_start": 72, "char_end": 75, "sentence_index": 0},
    {"word": "societal", "start_ms": 3750, "end_ms": 4250, "char_start": 76, "char_end": 84, "sentence_index": 0},
    {"word": "activities.", "start_ms": 4250, "end_ms": 4750, "char_start": 85, "char_end": 96, "sentence_index": 0},
    {"word": "Let''s", "start_ms": 5000, "end_ms": 5250, "char_start": 97, "char_end": 102, "sentence_index": 1},
    {"word": "begin.", "start_ms": 5250, "end_ms": 5750, "char_start": 103, "char_end": 109, "sentence_index": 1}
  ]'::jsonb,

  -- Sentence timings with snake_case fields
  '[
    {
      "text": "The objective of this lesson is to illustrate how insurance facilitates key societal activities.",
      "start_ms": 0,
      "end_ms": 4875,
      "sentence_index": 0,
      "word_start_index": 0,
      "word_end_index": 13,
      "char_start": 0,
      "char_end": 96
    },
    {
      "text": "Let''s begin.",
      "start_ms": 4875,
      "end_ms": 5875,
      "sentence_index": 1,
      "word_start_index": 14,
      "word_end_index": 15,
      "char_start": 97,
      "char_end": 109
    }
  ]'::jsonb,

  26300, -- total_duration_ms (26.3 seconds)
  'https://cdn.example.com/audio/63ad7b78-0970-4265-a4fe-51f3fee39d5f.mp3',
  2500000, -- 2.5MB
  'mp3',
  'mp3_128',
  1
) ON CONFLICT (id) DO UPDATE
SET
  assignment_id = EXCLUDED.assignment_id,
  course_id = EXCLUDED.course_id,
  display_text = EXCLUDED.display_text,
  paragraphs = EXCLUDED.paragraphs,
  headers = EXCLUDED.headers,
  formatting = EXCLUDED.formatting,
  metadata = EXCLUDED.metadata,
  word_timings = EXCLUDED.word_timings,
  sentence_timings = EXCLUDED.sentence_timings,
  total_duration_ms = EXCLUDED.total_duration_ms,
  audio_url = EXCLUDED.audio_url,
  updated_at = NOW();

-- Second learning object for testing
INSERT INTO public.learning_objects (
  id,
  assignment_id,
  course_id,
  title,
  order_index,
  display_text,
  paragraphs,
  headers,
  formatting,
  metadata,
  word_timings,
  sentence_timings,
  total_duration_ms,
  audio_url,
  audio_size_bytes
)
VALUES (
  '63ad7b78-0970-4265-a4fe-51f3fee39d60',
  '660e8400-e29b-41d4-a716-446655440102',
  '550e8400-e29b-41d4-a716-446655440001',
  'Establishing Case Reserves',
  1,
  E'A case reserve is an estimate of the amount of money required to settle a claim.',
  '["A case reserve is an estimate of the amount of money required to settle a claim."]'::jsonb,
  '[]'::jsonb,
  '{"bold_headers": false, "paragraph_spacing": true}'::jsonb,
  '{
    "word_count": 15,
    "character_count": 82,
    "estimated_reading_time": "1 minute",
    "language": "en"
  }'::jsonb,
  '[
    {"word": "A", "start_ms": 0, "end_ms": 100, "char_start": 0, "char_end": 1, "sentence_index": 0},
    {"word": "case", "start_ms": 100, "end_ms": 400, "char_start": 2, "char_end": 6, "sentence_index": 0},
    {"word": "reserve", "start_ms": 400, "end_ms": 800, "char_start": 7, "char_end": 14, "sentence_index": 0}
  ]'::jsonb,
  '[
    {
      "text": "A case reserve is an estimate of the amount of money required to settle a claim.",
      "start_ms": 0,
      "end_ms": 3000,
      "sentence_index": 0,
      "word_start_index": 0,
      "word_end_index": 14,
      "char_start": 0,
      "char_end": 82
    }
  ]'::jsonb,
  3000,
  'https://cdn.example.com/audio/case-reserves.mp3',
  500000
) ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- PART 5: Create enrollments for test user
-- ============================================================================

INSERT INTO public.enrollments (
  user_id,
  course_id,
  enrolled_at,
  expires_at,
  is_active
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  '550e8400-e29b-41d4-a716-446655440001',
  NOW(),
  NOW() + INTERVAL '1 year',
  true
) ON CONFLICT (user_id, course_id) DO UPDATE
SET
  expires_at = NOW() + INTERVAL '1 year',
  is_active = true,
  updated_at = NOW();

INSERT INTO public.enrollments (
  user_id,
  course_id,
  enrolled_at,
  expires_at,
  is_active
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  '550e8400-e29b-41d4-a716-446655440002',
  NOW(),
  NOW() + INTERVAL '1 year',
  true
) ON CONFLICT (user_id, course_id) DO NOTHING;

-- ============================================================================
-- PART 6: Create sample progress records
-- ============================================================================

-- Add progress for the main learning object
INSERT INTO public.user_progress (
  user_id,
  learning_object_id,
  course_id,
  assignment_id,
  is_completed,
  is_in_progress,
  completion_percentage,
  current_position_ms,
  last_word_index,
  last_sentence_index,
  started_at,
  last_played_at,
  play_count,
  total_play_time_ms,
  playback_speed
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  '63ad7b78-0970-4265-a4fe-51f3fee39d5f',
  '550e8400-e29b-41d4-a716-446655440001',
  '660e8400-e29b-41d4-a716-446655440101',
  false,
  true,
  45,
  11835,
  8,
  0,
  NOW() - INTERVAL '2 days',
  NOW() - INTERVAL '1 day',
  3,
  35000,
  1.0
) ON CONFLICT (user_id, learning_object_id) DO UPDATE
SET
  current_position_ms = EXCLUDED.current_position_ms,
  last_word_index = EXCLUDED.last_word_index,
  last_sentence_index = EXCLUDED.last_sentence_index,
  last_played_at = NOW(),
  updated_at = NOW();

-- Add course progress
INSERT INTO public.user_course_progress (
  user_id,
  course_id,
  completed_learning_objects,
  total_learning_objects,
  completion_percentage,
  total_time_spent_ms,
  last_accessed_at,
  started_at,
  last_learning_object_id,
  last_assignment_id
)
VALUES (
  'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
  '550e8400-e29b-41d4-a716-446655440001',
  0,
  2,
  22,
  35000,
  NOW() - INTERVAL '1 day',
  NOW() - INTERVAL '2 days',
  '63ad7b78-0970-4265-a4fe-51f3fee39d5f',
  '660e8400-e29b-41d4-a716-446655440101'
) ON CONFLICT (user_id, course_id) DO UPDATE
SET
  total_time_spent_ms = EXCLUDED.total_time_spent_ms,
  last_accessed_at = NOW(),
  updated_at = NOW();

-- ============================================================================
-- PART 7: Verify data migration
-- ============================================================================

-- This query can be run to verify the migration succeeded
DO $$
DECLARE
  v_course_count INTEGER;
  v_assignment_count INTEGER;
  v_lo_count INTEGER;
  v_word_timing_check BOOLEAN;
  v_sentence_timing_check BOOLEAN;
BEGIN
  -- Count records
  SELECT COUNT(*) INTO v_course_count FROM public.courses;
  SELECT COUNT(*) INTO v_assignment_count FROM public.assignments;
  SELECT COUNT(*) INTO v_lo_count FROM public.learning_objects;

  -- Check JSONB field structure
  SELECT EXISTS (
    SELECT 1 FROM public.learning_objects
    WHERE id = '63ad7b78-0970-4265-a4fe-51f3fee39d5f'
    AND word_timings::text LIKE '%start_ms%'
    AND word_timings::text LIKE '%end_ms%'
    AND word_timings::text LIKE '%char_start%'
    AND word_timings::text LIKE '%char_end%'
    AND word_timings::text LIKE '%sentence_index%'
  ) INTO v_word_timing_check;

  SELECT EXISTS (
    SELECT 1 FROM public.learning_objects
    WHERE id = '63ad7b78-0970-4265-a4fe-51f3fee39d5f'
    AND sentence_timings::text LIKE '%start_ms%'
    AND sentence_timings::text LIKE '%end_ms%'
    AND sentence_timings::text LIKE '%word_start_index%'
    AND sentence_timings::text LIKE '%word_end_index%'
  ) INTO v_sentence_timing_check;

  -- Raise notice with results
  RAISE NOTICE 'Migration Results:';
  RAISE NOTICE '  Courses: %', v_course_count;
  RAISE NOTICE '  Assignments: %', v_assignment_count;
  RAISE NOTICE '  Learning Objects: %', v_lo_count;
  RAISE NOTICE '  Word Timing Fields (snake_case): %', CASE WHEN v_word_timing_check THEN 'OK' ELSE 'FAILED' END;
  RAISE NOTICE '  Sentence Timing Fields (snake_case): %', CASE WHEN v_sentence_timing_check THEN 'OK' ELSE 'FAILED' END;

  -- Raise exception if checks fail
  IF NOT v_word_timing_check OR NOT v_sentence_timing_check THEN
    RAISE EXCEPTION 'Data migration validation failed - snake_case fields not found';
  END IF;
END $$;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- This migration:
-- ✅ Creates test user in auth.users
-- ✅ Inserts courses with enhanced fields
-- ✅ Creates assignments with proper hierarchy
-- ✅ Inserts learning objects with snake_case JSONB fields
-- ✅ Creates enrollments for test user
-- ✅ Adds sample progress records
-- ✅ Validates snake_case field structure