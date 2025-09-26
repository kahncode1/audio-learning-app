#!/usr/bin/env python3
"""
Upload preprocessed learning object data to Supabase.

This script uploads the enhanced JSON output from process_elevenlabs_complete.py
to the Supabase learning_objects table, including the O(1) lookup tables.
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Optional
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

class SupabaseUploader:
    def __init__(self):
        """Initialize Supabase client."""
        url = os.environ.get('SUPABASE_URL')
        key = os.environ.get('SUPABASE_ANON_KEY')

        if not url or not key:
            raise ValueError("SUPABASE_URL and SUPABASE_ANON_KEY must be set in environment")

        self.client: Client = create_client(url, key)
        print(f"✅ Connected to Supabase: {url}")

    def upload_audio_file(self, audio_file_path: str, learning_object_id: str) -> tuple[str, int]:
        """
        Upload audio file to Supabase Storage.

        Returns:
            Tuple of (public_url, file_size_bytes)
        """
        import os

        # Get file size
        file_size = os.path.getsize(audio_file_path)

        # Upload to course-audio bucket with proper path structure
        bucket_name = 'course-audio'
        # Create a clean filename from the original file
        import os.path
        base_name = os.path.basename(audio_file_path).replace(' ', '-').lower()
        if not base_name.endswith('.mp3'):
            base_name = f'{learning_object_id}.mp3'
        # Build the path structure: courses/{course}/assignments/{assignment}/{filename}
        # Default to CPCU 500 and Risk Management for now
        file_name = f'courses/CPCU 500/assignments/Risk Management/{base_name}'

        with open(audio_file_path, 'rb') as f:
            result = self.client.storage.from_(bucket_name).upload(
                path=file_name,
                file=f,
                file_options={"content-type": "audio/mpeg", "upsert": "true"}
            )

        # Get public URL
        public_url = self.client.storage.from_(bucket_name).get_public_url(file_name)

        print(f"✅ Uploaded audio file to Storage")
        print(f"   Bucket: {bucket_name}")
        print(f"   Path: {file_name}")
        print(f"   URL: {public_url}")
        print(f"   Size: {file_size:,} bytes")

        return public_url, file_size

    def upload_learning_object(
        self,
        learning_object_id: str,
        enhanced_json_path: str,
        assignment_id: str,
        title: str,
        order_index: int,
        audio_file_path: Optional[str] = None,
        lookup_json_path: Optional[str] = None
    ) -> Dict:
        """
        Upload a learning object with enhanced timing data.
        Lookup tables are stored separately in Supabase Storage.

        Args:
            learning_object_id: UUID of the learning object
            enhanced_json_path: Path to the enhanced JSON from preprocessing
            assignment_id: UUID of the parent assignment
            title: Title of the learning object
            order_index: Order within the assignment
            audio_url: Optional audio file URL (Supabase Storage)
            lookup_json_path: Optional path to separate lookup JSON file

        Returns:
            The created/updated learning object record
        """
        # Load the enhanced JSON
        with open(enhanced_json_path, 'r') as f:
            enhanced_data = json.load(f)

        # Extract timing data (without lookup table now)
        timing = enhanced_data.get('timing', {})

        # Create words JSONB structure (new schema)
        words_data = {
            'words': timing.get('words', []),
            'sentences': timing.get('sentences', []),
            'totalDurationMs': timing.get('total_duration_ms', 0),
            'createdAt': enhanced_data.get('metadata', {}).get('generated_at', '')
        }

        # Add lookup table to words_data if provided
        if lookup_json_path and os.path.exists(lookup_json_path):
            with open(lookup_json_path, 'r') as f:
                lookup_data = json.load(f)

            # Add the lookup table to words_data
            words_data['lookupTable'] = lookup_data

            print(f"   ✅ Lookup table: {len(lookup_data.get('lookup', []))} entries")
            print(f"      Interval: {lookup_data.get('interval', 0)}ms")
            print(f"      Coverage: 0-{lookup_data.get('totalDurationMs', 0)}ms")

        # Upload audio file if provided (skip if RLS blocks it)
        audio_url = None
        audio_size_bytes = 0
        if audio_file_path and os.path.exists(audio_file_path):
            try:
                audio_url, audio_size_bytes = self.upload_audio_file(audio_file_path, learning_object_id)
            except Exception as e:
                print(f"⚠️ Could not upload audio to Storage (RLS policy): {e}")
                print(f"   Using fallback URL for audio file")
                # Use a fallback URL pointing to the expected location
                # Use the course-audio bucket path
                import os.path
                base_name = os.path.basename(audio_file_path).replace(' ', '-').lower()
                if not base_name.endswith('.mp3'):
                    base_name = f'{learning_object_id}.mp3'
                audio_url = f"https://cmjdciktvfxiyapdseqn.supabase.co/storage/v1/object/public/course-audio/courses/CPCU 500/assignments/Risk Management/{base_name}"
                audio_size_bytes = os.path.getsize(audio_file_path)

        # Prepare the record with all required fields
        record = {
            'id': learning_object_id,
            'assignment_id': assignment_id,
            'course_id': 'e3d85ff7-cb25-4702-b2ba-813e8a24f16d',  # Test course ID
            'title': title,
            'display_text': enhanced_data.get('display_text', ''),
            'order_index': order_index,
            'total_duration_ms': timing.get('total_duration_ms', 0),
            'words': words_data,  # JSONB field with embedded lookup table
            'sentences': timing.get('sentences', []),  # Separate sentence timings field
            'metadata': enhanced_data.get('metadata', {}),
            'paragraphs': enhanced_data.get('paragraphs', []),
            'headers': enhanced_data.get('headers', []),
            'formatting': enhanced_data.get('formatting', {}),
            'audio_url': audio_url or '',  # Required field
            'audio_size_bytes': audio_size_bytes,  # Required field
            'audio_format': 'mp3',
            'audio_codec': 'mp3_128',
            'content_version': '1.0',  # New versioning column
            'preprocessing_source': 'elevenlabs-complete-with-paragraphs'  # Track preprocessing source
        }

        # Upload to Supabase (upsert to handle updates)
        result = self.client.table('learning_objects').upsert(record).execute()

        print(f"✅ Uploaded learning object: {title}")
        print(f"   ID: {learning_object_id}")
        print(f"   Words: {enhanced_data.get('metadata', {}).get('word_count', 0)}")
        print(f"   Duration: {record['total_duration_ms']}ms")

        return result.data[0] if result.data else None

    def verify_lookup_table(self, learning_object_id: str) -> bool:
        """
        Verify that a learning object has a lookup table in Supabase.

        Args:
            learning_object_id: UUID of the learning object to check

        Returns:
            True if lookup table exists, False otherwise
        """
        result = self.client.table('learning_objects').select('words').eq('id', learning_object_id).execute()

        if result.data and len(result.data) > 0:
            words_data = result.data[0].get('words', {})
            has_lookup = 'lookupTable' in words_data and words_data['lookupTable'] is not None

            if has_lookup:
                lookup = words_data['lookupTable']
                print(f"✅ Verified lookup table for {learning_object_id}")
                print(f"   Entries: {len(lookup.get('lookup', []))}")
                print(f"   Version: {lookup.get('version', 'unknown')}")
            else:
                print(f"❌ No lookup table found for {learning_object_id}")

            return has_lookup

        return False


def main():
    """Main function to upload preprocessed data to Supabase."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Upload preprocessed learning object data to Supabase'
    )
    parser.add_argument(
        'enhanced_json',
        help='Path to enhanced JSON file from preprocessing'
    )
    parser.add_argument(
        '--id',
        required=True,
        help='Learning object UUID'
    )
    parser.add_argument(
        '--assignment-id',
        required=True,
        help='Assignment UUID'
    )
    parser.add_argument(
        '--title',
        required=True,
        help='Learning object title'
    )
    parser.add_argument(
        '--order',
        type=int,
        default=0,
        help='Order index within assignment'
    )
    parser.add_argument(
        '--audio-file',
        help='Path to local audio file to upload (optional)'
    )
    parser.add_argument(
        '--lookup-json',
        help='Path to separate lookup JSON file (optional)'
    )
    parser.add_argument(
        '--verify-only',
        action='store_true',
        help='Only verify if lookup table exists'
    )

    args = parser.parse_args()

    # Initialize uploader
    uploader = SupabaseUploader()

    if args.verify_only:
        # Just verify the lookup table exists
        has_lookup = uploader.verify_lookup_table(args.id)
        sys.exit(0 if has_lookup else 1)
    else:
        # Upload the learning object
        result = uploader.upload_learning_object(
            learning_object_id=args.id,
            enhanced_json_path=args.enhanced_json,
            assignment_id=args.assignment_id,
            title=args.title,
            order_index=args.order,
            audio_file_path=args.audio_file,
            lookup_json_path=args.lookup_json
        )

        if result:
            print("\n✅ Upload successful!")

            # Verify the lookup table was saved
            uploader.verify_lookup_table(args.id)
        else:
            print("\n❌ Upload failed!")
            sys.exit(1)


if __name__ == '__main__':
    main()