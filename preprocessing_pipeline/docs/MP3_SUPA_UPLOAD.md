# Uploading Audio Files to Supabase Storage

## Overview

After preprocessing audio files, they need to be uploaded to Supabase Storage for CDN delivery. This guide explains how to upload the processed MP3 files to the configured storage bucket.

## Storage Configuration

- **Bucket Name**: `audio-files`
- **Type**: Public (for CDN performance)
- **Max File Size**: 50MB
- **Allowed Formats**: MP3 only
- **CDN**: Automatically enabled via Supabase global CDN

## File Naming Convention

Audio files must follow this exact naming pattern:

```
{learning_object_id}.mp3
```

Example: `63ad7b78-0970-4265-a4fe-51f3fee39d5f.mp3`

## Directory Structure in Storage

Files should be organized by course ID:

```
audio-files/
├── {course_id}/
│   ├── {learning_object_id_1}.mp3
│   ├── {learning_object_id_2}.mp3
│   └── {learning_object_id_3}.mp3
```

Example path: `audio-files/cb236d98-dbb8-4810-b205-17e8091dcf69/63ad7b78-0970-4265-a4fe-51f3fee39d5f.mp3`

## Upload Methods

### Method 1: Supabase Dashboard (Manual)

1. Go to https://supabase.com/dashboard
2. Select the "Course Audio" project
3. Navigate to Storage → audio-files bucket
4. Create folder with course ID as name
5. Upload MP3 files to the appropriate course folder
6. Files will be immediately available via CDN

### Method 2: Supabase CLI

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Upload a single file
supabase storage cp ./processed_audio/{learning_object_id}.mp3 \
  audio-files/{course_id}/{learning_object_id}.mp3 \
  --project-ref cmjdciktvfxiyapdseqn

# Upload all files for a course
supabase storage cp ./processed_audio/*.mp3 \
  audio-files/{course_id}/ \
  --project-ref cmjdciktvfxiyapdseqn
```

### Method 3: Programmatic Upload (Python)

```python
from supabase import create_client, Client
import os

# Initialize Supabase client
url = "https://cmjdciktvfxiyapdseqn.supabase.co"
key = "YOUR_SUPABASE_ANON_KEY"  # Get from project settings
supabase: Client = create_client(url, key)

def upload_audio_file(course_id: str, learning_object_id: str, audio_file_path: str):
    """Upload an audio file to Supabase Storage"""

    # Read the audio file
    with open(audio_file_path, 'rb') as f:
        audio_data = f.read()

    # Upload to storage
    storage_path = f"{course_id}/{learning_object_id}.mp3"

    response = supabase.storage.from_('audio-files').upload(
        path=storage_path,
        file=audio_data,
        file_options={"content-type": "audio/mpeg"}
    )

    if response.error:
        print(f"Error uploading {learning_object_id}: {response.error}")
        return None

    # Get public URL
    public_url = supabase.storage.from_('audio-files').get_public_url(storage_path)
    print(f"Uploaded: {public_url}")
    return public_url

# Example usage
course_id = "cb236d98-dbb8-4810-b205-17e8091dcf69"
learning_object_id = "63ad7b78-0970-4265-a4fe-51f3fee39d5f"
audio_file = f"./processed_audio/{learning_object_id}.mp3"

upload_audio_file(course_id, learning_object_id, audio_file)
```

### Method 4: Batch Upload Script (Python)

```python
import os
import json
from pathlib import Path
from supabase import create_client, Client

# Configuration
SUPABASE_URL = "https://cmjdciktvfxiyapdseqn.supabase.co"
SUPABASE_KEY = "YOUR_SUPABASE_ANON_KEY"  # Get from project settings
PROCESSED_AUDIO_DIR = "./processed_audio"
MANIFEST_FILE = "./processing_manifest.json"  # Contains course and LO mappings

def batch_upload_course_audio():
    """Upload all processed audio files for a course"""

    # Initialize Supabase client
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    # Load manifest (should be created during preprocessing)
    with open(MANIFEST_FILE, 'r') as f:
        manifest = json.load(f)

    course_id = manifest['course_id']
    learning_objects = manifest['learning_objects']

    successful_uploads = []
    failed_uploads = []

    for lo in learning_objects:
        lo_id = lo['id']
        audio_file_path = Path(PROCESSED_AUDIO_DIR) / f"{lo_id}.mp3"

        if not audio_file_path.exists():
            print(f"⚠️ Audio file not found: {audio_file_path}")
            failed_uploads.append(lo_id)
            continue

        try:
            # Read audio file
            with open(audio_file_path, 'rb') as f:
                audio_data = f.read()

            # Check file size (50MB limit)
            file_size_mb = len(audio_data) / (1024 * 1024)
            if file_size_mb > 50:
                print(f"⚠️ File too large ({file_size_mb:.1f}MB): {lo_id}")
                failed_uploads.append(lo_id)
                continue

            # Upload to Supabase Storage
            storage_path = f"{course_id}/{lo_id}.mp3"
            response = supabase.storage.from_('audio-files').upload(
                path=storage_path,
                file=audio_data,
                file_options={"content-type": "audio/mpeg"}
            )

            if response.error:
                print(f"❌ Failed to upload {lo_id}: {response.error}")
                failed_uploads.append(lo_id)
            else:
                public_url = supabase.storage.from_('audio-files').get_public_url(storage_path)
                print(f"✅ Uploaded {lo_id}")
                successful_uploads.append({
                    'learning_object_id': lo_id,
                    'storage_path': storage_path,
                    'public_url': public_url,
                    'file_size_mb': file_size_mb
                })

        except Exception as e:
            print(f"❌ Error uploading {lo_id}: {str(e)}")
            failed_uploads.append(lo_id)

    # Save upload report
    report = {
        'course_id': course_id,
        'total_learning_objects': len(learning_objects),
        'successful_uploads': len(successful_uploads),
        'failed_uploads': len(failed_uploads),
        'uploads': successful_uploads,
        'failures': failed_uploads
    }

    with open('upload_report.json', 'w') as f:
        json.dump(report, f, indent=2)

    print(f"\n📊 Upload Summary:")
    print(f"  Total: {len(learning_objects)}")
    print(f"  Success: {len(successful_uploads)}")
    print(f"  Failed: {len(failed_uploads)}")
    print(f"  Report saved to: upload_report.json")

if __name__ == "__main__":
    batch_upload_course_audio()
```

## URL Format

Once uploaded, files are accessible at:

```
https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/audio-files/{course_id}/{learning_object_id}.mp3
```

## Verification

After uploading, verify files are accessible:

```bash
# Test file access
curl -I "https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/audio-files/{course_id}/{learning_object_id}.mp3"

# Should return HTTP 200 OK with Content-Type: audio/mpeg
```

## Integration with Preprocessing Pipeline

Add this upload step to your preprocessing workflow:

1. Process audio files with ElevenLabs TTS
2. Save as MP3 with learning_object_id as filename
3. Create manifest.json with course and LO mappings
4. Run batch upload script
5. Verify uploads and save report
6. Database audio_url fields are already configured to use these URLs

## Troubleshooting

### Common Issues:

- **File too large**: Ensure MP3s are under 50MB
- **Wrong format**: Only MP3 files are accepted
- **404 errors**: Check file naming matches learning_object_id exactly
- **Permission denied**: Ensure you have valid Supabase credentials

### Getting Credentials:

1. Go to https://supabase.com/dashboard
2. Select "Course Audio" project
3. Go to Settings → API
4. Copy the `anon` public key for uploads

## Notes

- Files are immediately available via CDN after upload
- No additional CDN configuration needed
- Public bucket allows direct streaming without authentication
- Supabase automatically handles caching and global distribution
