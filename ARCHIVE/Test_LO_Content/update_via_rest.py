#!/usr/bin/env python3
"""
Update learning object via Supabase REST API with complete preprocessed data
"""

import json
import requests

# Supabase configuration
SUPABASE_URL = "https://cmjdciktvfxiyapdseqn.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNtamRjaWt0dmZ4aXlhcGRzZXFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc3ODAwODAsImV4cCI6MjA3MzM1NjA4MH0.qIhF8LgDnm6OrlnhNWNJziNc6OopUu0qCYtgJhXouB8"

# Learning object ID
LEARNING_OBJECT_ID = "d00b7474-4d67-4a38-b8aa-0cf0622460c1"

# Read the processed data
with open('db_update.json', 'r') as f:
    data = json.load(f)

# Prepare the update payload
update_payload = {
    'display_text': data['display_text'],
    'paragraphs': data['paragraphs'],
    'headers': data['headers'],
    'formatting': data['formatting'],
    'metadata': data['metadata'],
    'word_timings': data['word_timings'],
    'sentence_timings': data['sentence_timings'],
    'total_duration_ms': data['total_duration_ms']
}

# Update via REST API
url = f"{SUPABASE_URL}/rest/v1/learning_objects?id=eq.{LEARNING_OBJECT_ID}"
headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

print(f"Updating learning object {LEARNING_OBJECT_ID}...")
print(f"  Display text: {len(data['display_text'])} chars")
print(f"  Paragraphs: {len(data['paragraphs'])}")
print(f"  Word timings: {len(data['word_timings'])}")
print(f"  Sentence timings: {len(data['sentence_timings'])}")
print(f"  Duration: {data['total_duration_ms']/1000:.1f} seconds")

response = requests.patch(url, json=update_payload, headers=headers)

if response.status_code == 200:
    print("\n✅ Successfully updated learning object!")
    result = response.json()
    if result:
        print(f"   ID: {result[0]['id']}")
        print(f"   Title: {result[0]['title']}")
else:
    print(f"\n❌ Failed to update: {response.status_code}")
    print(f"   Response: {response.text}")