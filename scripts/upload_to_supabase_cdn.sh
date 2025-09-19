#!/bin/bash

# Script to upload test content to Supabase Storage via REST API
# Usage: ./scripts/upload_to_supabase_cdn.sh

# Configuration
SUPABASE_URL="https://cmjdciktvfxiyapdseqn.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtamRjaWt0dmZ4aXlhcGRzZXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjYyODU5MzcsImV4cCI6MjA0MTg2MTkzN30.qI37kGFa7p9WRC0G3F8oUdN1604OXZ0l1wVlZsLRmLo"

# File paths
LEARNING_OBJECT_ID="63ad7b78-0970-4265-a4fe-51f3fee39d5f"
COURSE_ID="INS-101"
BASE_PATH="assets/test_content/learning_objects/$LEARNING_OBJECT_ID"

echo "🚀 Uploading test content to Supabase Storage CDN"
echo ""

# Function to upload a file
upload_file() {
    local bucket=$1
    local file_path=$2
    local storage_path=$3
    local content_type=$4

    echo "📤 Uploading $file_path to $bucket/$storage_path..."

    # Check if file exists
    if [ ! -f "$file_path" ]; then
        echo "   ❌ File not found: $file_path"
        return 1
    fi

    # Get file size
    file_size=$(ls -lh "$file_path" | awk '{print $5}')
    echo "   File size: $file_size"

    # Upload file to Supabase Storage
    response=$(curl -X POST \
        -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
        -H "Content-Type: $content_type" \
        -H "x-upsert: true" \
        --data-binary "@$file_path" \
        "${SUPABASE_URL}/storage/v1/object/$bucket/$storage_path" \
        -s -w "\nHTTP_STATUS:%{http_code}")

    # Extract HTTP status
    http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
    body=$(echo "$response" | grep -v "HTTP_STATUS:")

    if [ "$http_status" = "200" ] || [ "$http_status" = "201" ]; then
        echo "   ✅ Upload successful"
        echo "   🌐 Public URL: ${SUPABASE_URL}/storage/v1/object/public/$bucket/$storage_path"
    else
        echo "   ❌ Upload failed with status $http_status"
        echo "   Response: $body"
        return 1
    fi

    echo ""
}

# Upload audio file
upload_file "course-audio" \
    "$BASE_PATH/audio.mp3" \
    "$COURSE_ID/$LEARNING_OBJECT_ID/audio.mp3" \
    "audio/mpeg"

# Upload content JSON
upload_file "course-content" \
    "$BASE_PATH/content.json" \
    "$COURSE_ID/$LEARNING_OBJECT_ID/content.json" \
    "application/json"

# Upload timing JSON
upload_file "course-timing" \
    "$BASE_PATH/timing.json" \
    "$COURSE_ID/$LEARNING_OBJECT_ID/timing.json" \
    "application/json"

echo "✅ All files uploaded successfully!"
echo ""
echo "📍 CDN URLs for uploaded files:"
echo ""
echo "Audio URL:"
echo "  ${SUPABASE_URL}/storage/v1/object/public/course-audio/$COURSE_ID/$LEARNING_OBJECT_ID/audio.mp3"
echo ""
echo "Content URL:"
echo "  ${SUPABASE_URL}/storage/v1/object/public/course-content/$COURSE_ID/$LEARNING_OBJECT_ID/content.json"
echo ""
echo "Timing URL:"
echo "  ${SUPABASE_URL}/storage/v1/object/public/course-timing/$COURSE_ID/$LEARNING_OBJECT_ID/timing.json"
echo ""
echo "📝 Next step: Update the database with these CDN URLs"