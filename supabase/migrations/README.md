# Database Migrations

## Migration: 20251127000000_align_schema_with_preprocessing.sql

### Purpose
Aligns the database schema with the preprocessing script output by:
1. Renaming `word_timings` → `words`
2. Renaming `sentence_timings` → `sentences`
3. Adding `lookup_table_url` column for tracking separate lookup.json files
4. Adding versioning columns (`content_version`, `preprocessing_source`)

### How to Apply

#### Option 1: Via Supabase Dashboard
1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `20251127000000_align_schema_with_preprocessing.sql`
4. Click "Run" to execute the migration

#### Option 2: Via Supabase CLI (if linked)
```bash
# First link your project (one-time setup)
npx supabase link --project-ref <your-project-ref>

# Then push the migration
npx supabase db push
```

### Impact on App
After applying this migration, the app services will need to be updated to use the new column names:
- `word_timings` → `words`
- `sentence_timings` → `sentences`

The lookup table will be stored separately in Supabase Storage at:
`/audio-files/{learning_object_id}/lookup.json`

### Rollback
If needed, you can rollback with:
```sql
ALTER TABLE learning_objects RENAME COLUMN words TO word_timings;
ALTER TABLE learning_objects RENAME COLUMN sentences TO sentence_timings;
ALTER TABLE learning_objects DROP COLUMN IF EXISTS lookup_table_url;
ALTER TABLE learning_objects DROP COLUMN IF EXISTS content_version;
ALTER TABLE learning_objects DROP COLUMN IF EXISTS preprocessing_source;
```