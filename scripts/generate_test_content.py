#!/usr/bin/env python3
"""
Generate test MP3 and JSON files using Speechify API
"""

import os
import json
import base64
import requests
from pathlib import Path

# Load API key
def load_api_key():
    env_path = Path('.env')
    with open(env_path, 'r') as f:
        for line in f:
            if line.startswith('SPEECHIFY_API_KEY='):
                return line.split('=', 1)[1].strip().strip('"')
    return None

# Test content
test_content = {
    'id': '63ad7b78-0970-4265-a4fe-51f3fee39d5f',
    'text': '''Understanding Case Reserve Management in Insurance Claims Processing. A case reserve represents the estimated amount of money an insurance company expects to pay for a claim. This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting. When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure.''',
    'paragraphs': [
        'Understanding Case Reserve Management in Insurance Claims Processing.',
        'A case reserve represents the estimated amount of money an insurance company expects to pay for a claim.',
        'This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting.',
        'When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure.',
    ]
}

def main():
    print('🎙️ Generating Test Content with Speechify API')
    print('=' * 50)

    api_key = load_api_key()
    print(f'✅ API key loaded')

    # Create directories
    output_dir = Path('assets/test_content/learning_objects') / test_content['id']
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f'📁 Output directory: {output_dir}')

    # Call Speechify API
    print('🌐 Calling Speechify API...')

    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
    }

    payload = {
        'input': test_content['text'],
        'voice_id': 'henry',
        'model': 'simba-turbo',
        'speed': 1.0,
        'include_speech_marks': True,
    }

    response = requests.post(
        'https://api.sws.speechify.com/v1/audio/speech',
        headers=headers,
        json=payload,
        timeout=60
    )

    if response.status_code == 200:
        data = response.json()

        # Save MP3
        if 'audio_data' in data:
            audio_bytes = base64.b64decode(data['audio_data'])
            audio_file = output_dir / 'audio.mp3'
            with open(audio_file, 'wb') as f:
                f.write(audio_bytes)
            print(f'✅ Saved audio.mp3 ({len(audio_bytes):,} bytes)')

        # Create content.json
        content_json = {
            'version': '1.0',
            'displayText': test_content['text'],
            'paragraphs': test_content['paragraphs'],
            'metadata': {
                'wordCount': len(test_content['text'].split()),
                'characterCount': len(test_content['text']),
                'estimatedReadingTime': '30 seconds',
                'language': 'en',
            },
        }

        with open(output_dir / 'content.json', 'w') as f:
            json.dump(content_json, f, indent=2)
        print('✅ Saved content.json')

        # Process timing data
        if 'speech_marks' in data:
            speech_marks = data['speech_marks']
            words = []
            sentences = []

            # Extract words
            for mark in speech_marks:
                # Handle both dict and string formats
                if isinstance(mark, dict) and mark.get('type') == 'word':
                    words.append({
                        'word': mark['value'],
                        'startMs': mark['time'],
                        'endMs': mark.get('end_time', mark['time'] + 200),
                        'charStart': mark.get('start', 0),
                        'charEnd': mark.get('end', 0),
                    })

            # Simple sentence detection
            sentence_texts = [
                'Understanding Case Reserve Management in Insurance Claims Processing.',
                'A case reserve represents the estimated amount of money an insurance company expects to pay for a claim.',
                'This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting.',
                'When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure.',
            ]

            word_idx = 0
            for sent_text in sentence_texts:
                sent_words = sent_text.split()
                if word_idx < len(words):
                    start_idx = word_idx
                    end_idx = min(word_idx + len(sent_words) - 1, len(words) - 1)

                    sentences.append({
                        'text': sent_text,
                        'startMs': words[start_idx]['startMs'] if start_idx < len(words) else 0,
                        'endMs': words[end_idx]['endMs'] if end_idx < len(words) else 0,
                        'wordStartIndex': start_idx,
                        'wordEndIndex': end_idx,
                        'charStart': test_content['text'].find(sent_text),
                        'charEnd': test_content['text'].find(sent_text) + len(sent_text),
                    })

                    word_idx += len(sent_words)

            # Create timing.json
            timing_json = {
                'version': '1.0',
                'words': words,
                'sentences': sentences,
                'totalDurationMs': words[-1]['endMs'] if words else 0,
            }

            with open(output_dir / 'timing.json', 'w') as f:
                json.dump(timing_json, f, indent=2)
            print(f'✅ Saved timing.json ({len(words)} words, {len(sentences)} sentences)')
            print(f'   Duration: {timing_json["totalDurationMs"]/1000:.1f} seconds')

        print(f'\n✅ Test content generated successfully!')
        print(f'📁 Files saved to: {output_dir}')

        # Also save raw response for debugging
        with open(output_dir / 'raw_response.json', 'w') as f:
            json.dump(data, f, indent=2)
        print('📄 Raw API response saved for debugging')

    else:
        print(f'❌ API error: {response.status_code}')
        print(response.text)

if __name__ == '__main__':
    main()