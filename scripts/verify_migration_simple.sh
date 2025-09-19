#!/bin/bash

# Simple verification script for the migration using Supabase REST API

echo ""
echo "=== Supabase Migration Verification ==="
echo ""

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ Error: .env file not found"
    exit 1
fi

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ Error: Missing Supabase credentials in .env"
    exit 1
fi

echo "1. Checking new tables..."

# Check download_progress table
response=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/download_progress?limit=1" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")

if [[ "$response" == *"[]"* ]] || [[ "$response" == *"download_progress"* ]]; then
    echo "   ✓ download_progress table exists"
else
    echo "   ❌ download_progress table not found"
fi

# Check course_downloads table
response=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/course_downloads?limit=1" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")

if [[ "$response" == *"[]"* ]] || [[ "$response" == *"course_downloads"* ]]; then
    echo "   ✓ course_downloads table exists"
else
    echo "   ❌ course_downloads table not found"
fi

echo ""
echo "2. Checking learning_objects table updates..."

# Check for our test learning object with new columns
response=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/learning_objects?id=eq.63ad7b78-0970-4265-a4fe-51f3fee39d5f&select=id,title,audio_url,content_url,timing_url,file_version,download_status" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")

if [[ "$response" == *"audio_url"* ]] && [[ "$response" == *"content_url"* ]] && [[ "$response" == *"timing_url"* ]]; then
    echo "   ✓ New columns added to learning_objects table"
    echo ""
    echo "3. Test learning object CDN URLs:"
    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
else
    echo "   ❌ New columns not found in learning_objects table"
fi

echo ""
echo "✅ Migration verification complete!"
echo ""
echo "Next steps:"
echo "1. Storage buckets still need to be created (if using Supabase Storage)"
echo "2. Pre-processed content needs to be generated and uploaded"
echo "3. CourseDownloadService can now fetch CDN URLs from the database"