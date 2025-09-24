
UPDATE learning_objects 
SET 
  metadata = '{"word_count": 2347, "character_count": 15407, "estimated_reading_time": "11 minutes", "language": "en"}'::jsonb,
  updated_at = NOW()
WHERE id = 'd00b7474-4d67-4a38-b8aa-0cf0622460c1'
RETURNING id, title;
