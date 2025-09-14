-- Insert test data for Case Reserve Lesson
-- This script creates a test course, assignment, and learning object with the SSML content

-- Insert a test user if not exists
INSERT INTO users (id, email, full_name, created_at, updated_at)
VALUES (
  gen_random_uuid(),
  'test@example.com',
  'Test User',
  NOW(),
  NOW()
) ON CONFLICT (email) DO NOTHING;

-- Get the user ID
DO $$
DECLARE
  v_user_id UUID;
  v_course_id UUID;
  v_enrollment_id UUID;
  v_assignment_id UUID;
  v_learning_object_id UUID;
BEGIN
  -- Get or create user
  SELECT id INTO v_user_id FROM users WHERE email = 'test@example.com';

  -- Create course
  v_course_id := gen_random_uuid();
  INSERT INTO courses (id, title, description, gradient_start_color, gradient_end_color, created_at, updated_at)
  VALUES (
    v_course_id,
    'Insurance Case Management',
    'Learn about establishing and managing case reserves in insurance claims',
    '#2196F3',
    '#1976D2',
    NOW(),
    NOW()
  ) ON CONFLICT (id) DO NOTHING;

  -- Create enrollment
  v_enrollment_id := gen_random_uuid();
  INSERT INTO enrollments (id, user_id, course_id, status, enrolled_at, expires_at)
  VALUES (
    v_enrollment_id,
    v_user_id,
    v_course_id,
    'active',
    NOW(),
    NOW() + INTERVAL '1 year'
  ) ON CONFLICT (id) DO NOTHING;

  -- Create assignment
  v_assignment_id := gen_random_uuid();
  INSERT INTO assignments (id, course_id, title, description, assignment_number, created_at, updated_at)
  VALUES (
    v_assignment_id,
    v_course_id,
    'Establishing a Case Reserve',
    'Learn the different methods of setting case reserves and when to use each one',
    1,
    NOW(),
    NOW()
  ) ON CONFLICT (id) DO NOTHING;

  -- Create learning object with SSML content
  v_learning_object_id := gen_random_uuid();
  INSERT INTO learning_objects (
    id,
    assignment_id,
    title,
    content_type,
    ssml_content,
    plain_text,
    order_index,
    created_at,
    updated_at
  ) VALUES (
    v_learning_object_id,
    v_assignment_id,
  'Establishing a Case Reserve',
  'ssml',
  $$<?xml version="1.0" encoding="UTF-8"?>
<speak>
  <prosody rate="95%">
    <!-- Title Section -->
    <speechify:style emotion="neutral">
      <emphasis level="strong">Establishing a Case Reserve</emphasis>
      <break time="1.5s"/>

      <!-- Objective -->
      <emphasis level="moderate">Objective:</emphasis>
      <break time="500ms"/>
      Determine which case reserve method is appropriate for a claim.
      <break time="2s"/>

      <!-- Introduction -->
      If a claims representative doesn't set accurate case reserves, it could affect the financial health of the insurer for which he or she works.
      <break time="800ms"/>
      In extreme cases, <emphasis level="moderate">inaccurate reserving</emphasis> could cause insolvency.
      <break time="1.5s"/>

      Insurers can establish reserves on claims using any of several different methods.
      <break time="700ms"/>
      However, reserving errors can occur if these methods are used inappropriately,
      <break time="500ms"/>
      such as when misusing a subjective individual case method results in the need to repeatedly raise the reserve amount.
      <break time="2s"/>

      <!-- Interactive Question -->
      <emphasis level="strong">What Do You Know?</emphasis>
      <break time="1s"/>
      Which one of the following methods of setting claim reserves relies most heavily on the subjective judgment of the claims rep?
      <break time="1.5s"/>

      Option A: <break time="300ms"/> The individual case method
      <break time="800ms"/>
      Option B: <break time="300ms"/> The formula method
      <break time="800ms"/>
      Option C: <break time="300ms"/> The expert system method
      <break time="800ms"/>
      Option D: <break time="300ms"/> The average value method
      <break time="2s"/>

      <emphasis level="moderate">The correct answer is:</emphasis>
      <break time="500ms"/>
      Of these methods, the individual case method relies most heavily on the subjective judgment of the claims rep.
      <break time="2.5s"/>
    </speechify:style>
  </prosody>
</speak>$$,
  $$Establishing a Case Reserve

Objective: Determine which case reserve method is appropriate for a claim.

If a claims representative doesn't set accurate case reserves, it could affect the financial health of the insurer for which he or she works. In extreme cases, inaccurate reserving could cause insolvency.

Insurers can establish reserves on claims using any of several different methods. However, reserving errors can occur if these methods are used inappropriately, such as when misusing a subjective individual case method results in the need to repeatedly raise the reserve amount.

What Do You Know?
Which one of the following methods of setting claim reserves relies most heavily on the subjective judgment of the claims rep?

Option A: The individual case method
Option B: The formula method
Option C: The expert system method
Option D: The average value method

The correct answer is: Of these methods, the individual case method relies most heavily on the subjective judgment of the claims rep.$$,
    1,
    NOW(),
    NOW()
  ) ON CONFLICT (id) DO NOTHING;

  -- Insert initial progress record
  INSERT INTO progress (
    id,
    user_id,
    learning_object_id,
    is_completed,
    is_in_progress,
    current_position_ms,
    font_size_index,
    playback_speed,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_user_id,
    v_learning_object_id,
    false,
    false,
    0,
    1,
    1.0,
    NOW()
  ) ON CONFLICT (id) DO NOTHING;

  -- Output the created IDs for reference
  RAISE NOTICE 'Test data created successfully';
  RAISE NOTICE 'User ID: %', v_user_id;
  RAISE NOTICE 'Course ID: %', v_course_id;
  RAISE NOTICE 'Assignment ID: %', v_assignment_id;
  RAISE NOTICE 'Learning Object ID: %', v_learning_object_id;
END $$;