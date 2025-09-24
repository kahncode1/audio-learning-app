#!/usr/bin/env python3
"""
Update learning object in Supabase with correctly formatted snake_case data
"""

import os
import json
from supabase import create_client, Client

# Supabase configuration
url = os.getenv('SUPABASE_URL', 'https://knzzxtibhloupqoazbdc.supabase.co')
key = os.getenv('SUPABASE_KEY', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtuenp4dGliaGxvdXBxb2F6YmRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA3NDIwODEsImV4cCI6MjA0NjMxODA4MX0.0GTx5s1vsOhGQpjgLxLaoaE9wmRPE9REfNOcWrk3HOM')

# Create client
supabase: Client = create_client(url, key)

# Learning object ID to update
learning_object_id = 'd00b7474-4d67-4a38-b8aa-0cf0622460c1'

# Read the processed content
with open('db_update.json', 'r') as f:
    db_fields = json.load(f)

# Update the learning object
try:
    response = supabase.table('learning_objects').update(db_fields).eq('id', learning_object_id).execute()

    if response.data:
        print(f"✅ Successfully updated learning object: {learning_object_id}")
        print(f"   Word timings: {len(db_fields['word_timings'])}")
        print(f"   Sentence timings: {len(db_fields['sentence_timings'])}")
        print(f"   Duration: {db_fields['total_duration_ms']/1000:.1f} seconds")
    else:
        print(f"❌ No data returned from update")

except Exception as e:
    print(f"❌ Error updating learning object: {e}")