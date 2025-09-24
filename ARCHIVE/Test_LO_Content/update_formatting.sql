UPDATE learning_objects 
SET 
  formatting = '{"bold_headers": false, "paragraph_spacing": true}'::jsonb,
  updated_at = NOW()
WHERE id = 'd00b7474-4d67-4a38-b8aa-0cf0622460c1'
RETURNING id;