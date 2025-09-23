-- Migration: Add user_settings table
-- Purpose: Create user_settings table that was missing from initial migration
-- Date: 2025-09-23

-- Create user_settings table
CREATE TABLE IF NOT EXISTS public.user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Theme settings
  theme_name TEXT DEFAULT 'light' CHECK (theme_name IN ('light', 'dark')),
  theme_settings JSONB DEFAULT '{}'::jsonb,

  -- User preferences (JSONB)
  preferences JSONB DEFAULT '{
    "font_size": 16.0,
    "auto_play": true,
    "default_playback_speed": 1.0,
    "word_highlight_color": "#FFEB3B",
    "sentence_highlight_color": "#FFE0B2"
  }'::jsonb,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure one settings per user
  UNIQUE(user_id)
);

-- Create indexes
CREATE INDEX idx_user_settings_user_id ON public.user_settings(user_id);

-- Enable RLS
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only view their own settings
CREATE POLICY "Users can view own settings"
  ON public.user_settings
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can update their own settings
CREATE POLICY "Users can update own settings"
  ON public.user_settings
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can insert their own settings
CREATE POLICY "Users can insert own settings"
  ON public.user_settings
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Create update trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_user_settings_updated_at
  BEFORE UPDATE ON public.user_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Also create user_course_enrollments table (referenced in services but not in database)
CREATE TABLE IF NOT EXISTS public.user_course_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure unique enrollment per user-course pair
  UNIQUE(user_id, course_id)
);

-- Create indexes
CREATE INDEX idx_user_course_enrollments_user_id ON public.user_course_enrollments(user_id);
CREATE INDEX idx_user_course_enrollments_course_id ON public.user_course_enrollments(course_id);

-- Enable RLS
ALTER TABLE public.user_course_enrollments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for enrollments
-- Users can view their own enrollments
CREATE POLICY "Users can view own enrollments"
  ON public.user_course_enrollments
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can create their own enrollments
CREATE POLICY "Users can create own enrollments"
  ON public.user_course_enrollments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own enrollments
CREATE POLICY "Users can update own enrollments"
  ON public.user_course_enrollments
  FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own enrollments
CREATE POLICY "Users can delete own enrollments"
  ON public.user_course_enrollments
  FOR DELETE
  USING (auth.uid() = user_id);

-- Create update trigger for enrollments
CREATE TRIGGER update_user_course_enrollments_updated_at
  BEFORE UPDATE ON public.user_course_enrollments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Add comment to tables
COMMENT ON TABLE public.user_settings IS 'User preferences and settings with JSONB storage';
COMMENT ON TABLE public.user_course_enrollments IS 'Track user course enrollments';

-- Insert default settings for existing test user if needed
INSERT INTO public.user_settings (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM public.user_settings)
ON CONFLICT (user_id) DO NOTHING;