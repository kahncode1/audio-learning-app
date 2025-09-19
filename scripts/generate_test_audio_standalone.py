#!/usr/bin/env python3
"""
Standalone script to generate test MP3 files using Speechify API

Usage: python3 scripts/generate_test_audio_standalone.py

This script will:
1. Call Speechify API to generate audio for test content
2. Save MP3 files to assets/test_content/
3. Extract and save word timings
4. Create content.json and timing.json files
"""

import os
import json
import base64
import requests
from pathlib import Path

# Load API key from .env file
def load_api_key():
    env_path = Path('.env')
    if not env_path.exists():
        print("❌ .env file not found. Please create it from .env.example")
        return None

    with open(env_path, 'r') as f:
        for line in f:
            if line.startswith('SPEECHIFY_API_KEY='):
                key = line.split('=', 1)[1].strip()
                if key and key != 'YOUR_ACTUAL_SPEECHIFY_API_KEY_HERE':
                    return key
    return None

# Test content definitions
test_contents = [
    {
        'id': 'test-short',
        'title': 'Short Test - Introduction to Case Reserves',
        'text': 'Understanding Case Reserve Management. A case reserve represents the estimated amount of money an insurance company expects to pay for a claim. This critical financial tool serves multiple purposes in the claims management process. Accurate reserves are essential for regulatory compliance, strategic planning, and financial reporting. Insurance companies rely on precise reserve calculations to maintain solvency and meet their obligations to policyholders.',
        'paragraphs': [
            'Understanding Case Reserve Management.',
            'A case reserve represents the estimated amount of money an insurance company expects to pay for a claim.',
            'This critical financial tool serves multiple purposes in the claims management process.',
            'Accurate reserves are essential for regulatory compliance, strategic planning, and financial reporting.',
            'Insurance companies rely on precise reserve calculations to maintain solvency and meet their obligations to policyholders.',
        ],
    },
    {
        'id': 'test-medium',
        'title': 'Medium Test - Components of Case Reserves',
        'text': '''Case Reserve Components and Calculation Methods. Every case reserve should incorporate multiple elements to ensure accuracy and completeness. The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf. This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases. Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses. These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees. Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle. The timing of payments also affects reserve calculations. A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation. Claims professionals must consider the time value of money, especially for claims that may take years to resolve. Documentation is crucial when setting initial reserves. Adjusters should clearly record their reasoning, the factors considered, and any assumptions made. This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters. Regular review and adjustment of case reserves ensures they remain accurate as claims develop. Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim's complexity and value.''',
        'paragraphs': [
            'Case Reserve Components and Calculation Methods.',
            'Every case reserve should incorporate multiple elements to ensure accuracy and completeness.',
            'The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf.',
            'This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases.',
            'Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses.',
            'These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees.',
            'Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle.',
            'The timing of payments also affects reserve calculations.',
            'A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation.',
            'Claims professionals must consider the time value of money, especially for claims that may take years to resolve.',
            'Documentation is crucial when setting initial reserves.',
            'Adjusters should clearly record their reasoning, the factors considered, and any assumptions made.',
            'This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters.',
            'Regular review and adjustment of case reserves ensures they remain accurate as claims develop.',
            "Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim's complexity and value.",
        ],
    },
    {
        'id': '63ad7b78-0970-4265-a4fe-51f3fee39d5f',
        'title': 'Full Test - Complete Case Reserve Management',
        'text': '''Understanding Case Reserve Management in Insurance Claims Processing. A case reserve represents the estimated amount of money an insurance company expects to pay for a claim. This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting. When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure. This initial evaluation becomes the foundation for the case reserve. The reserve amount includes not only the expected indemnity payment to the claimant but also allocated loss adjustment expenses, legal fees, and expert witness costs that may arise during the claims process. Insurance companies rely on accurate case reserves for several vital business functions. First, reserves directly impact the company's financial statements and must be reported to regulators and shareholders. Second, they influence reinsurance recoveries and treaty arrangements. Third, accurate reserves enable better pricing decisions for future policies. Finally, they provide management with crucial data for strategic planning and capital allocation decisions. Every case reserve should incorporate multiple elements to ensure accuracy and completeness. The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf. This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases. Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses. These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees. Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle. The timing of payments also affects reserve calculations. A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation. Claims professionals must consider the time value of money, especially for claims that may take years to resolve. Establishing accurate initial reserves requires a systematic approach combined with professional judgment. The process begins with a thorough investigation of the claim circumstances, including witness statements, police reports, medical records, and any available surveillance footage. This information provides the factual foundation for the reserve evaluation. Documentation is crucial when setting initial reserves. Adjusters should clearly record their reasoning, the factors considered, and any assumptions made. This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters. Case reserves are not static figures. They require regular review and adjustment as new information emerges and circumstances change. Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim's complexity and value. Thank you for completing this lesson on case reserve management. Remember that effective reserve management remains fundamental to successful claims operations.''',
        'paragraphs': [
            'Understanding Case Reserve Management in Insurance Claims Processing.',
            'A case reserve represents the estimated amount of money an insurance company expects to pay for a claim.',
            'This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting.',
            'When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure.',
            'This initial evaluation becomes the foundation for the case reserve.',
            'The reserve amount includes not only the expected indemnity payment to the claimant but also allocated loss adjustment expenses, legal fees, and expert witness costs that may arise during the claims process.',
            'Insurance companies rely on accurate case reserves for several vital business functions.',
            "First, reserves directly impact the company's financial statements and must be reported to regulators and shareholders.",
            'Second, they influence reinsurance recoveries and treaty arrangements.',
            'Third, accurate reserves enable better pricing decisions for future policies.',
            'Finally, they provide management with crucial data for strategic planning and capital allocation decisions.',
            'Every case reserve should incorporate multiple elements to ensure accuracy and completeness.',
            'The primary component is the estimated indemnity payment, which represents the amount likely to be paid directly to the claimant or on their behalf.',
            'This includes medical expenses, property damage, lost wages, and pain and suffering in applicable cases.',
            'Beyond the indemnity payment, reserves must account for allocated loss adjustment expenses.',
            'These expenses include attorney fees, expert witness costs, court filing fees, investigation expenses, and independent adjuster fees.',
            'Many claims professionals overlook these costs initially, leading to inadequate reserves that require significant adjustments later in the claim lifecycle.',
            'The timing of payments also affects reserve calculations.',
            'A claim expected to settle quickly may require a different reserve approach than one likely to involve lengthy litigation.',
            'Claims professionals must consider the time value of money, especially for claims that may take years to resolve.',
            'Establishing accurate initial reserves requires a systematic approach combined with professional judgment.',
            'The process begins with a thorough investigation of the claim circumstances, including witness statements, police reports, medical records, and any available surveillance footage.',
            'This information provides the factual foundation for the reserve evaluation.',
            'Documentation is crucial when setting initial reserves.',
            'Adjusters should clearly record their reasoning, the factors considered, and any assumptions made.',
            'This documentation proves invaluable during reserve reviews, audits, and when transitioning files between adjusters.',
            'Case reserves are not static figures.',
            'They require regular review and adjustment as new information emerges and circumstances change.',
            "Most insurance companies mandate reserve reviews at specific intervals, such as every 30, 60, or 90 days, depending on the claim's complexity and value.",
            'Thank you for completing this lesson on case reserve management.',
            'Remember that effective reserve management remains fundamental to successful claims operations.',
        ],
    },
]

def main():
    print('🎙️ Speechify Test Audio Generator')
    print('=' * 50)

    # Load API key
    api_key = load_api_key()
    if not api_key:
        print('❌ ERROR: Please set your actual Speechify API key in .env file')
        print('   Edit .env and replace YOUR_ACTUAL_SPEECHIFY_API_KEY_HERE with your key')
        return

    print('✅ API key loaded from .env')

    # API configuration
    base_url = 'https://api.sws.speechify.com'
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Content-Type': 'application/json',
    }

    # Create output directory
    output_dir = Path('assets/test_content/learning_objects')
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f'📁 Output directory: {output_dir}')

    # Process each test content
    for content in test_contents:
        print(f"\n📝 Processing: {content['title']}")
        print(f"   Text length: {len(content['text'])} characters")

        try:
            # Create content directory
            content_dir = output_dir / content['id']
            content_dir.mkdir(parents=True, exist_ok=True)

            # Call Speechify API
            print('   🌐 Calling Speechify API...')

            payload = {
                'input': content['text'],
                'voice_id': 'henry',
                'model': 'simba-turbo',
                'speed': 1.0,
                'include_speech_marks': True,
            }

            response = requests.post(
                f'{base_url}/v1/audio/speech',
                headers=headers,
                json=payload,
                timeout=120
            )

            if response.status_code == 200:
                data = response.json()

                # Save MP3 file
                if 'audio_data' in data:
                    audio_bytes = base64.b64decode(data['audio_data'])
                    audio_file = content_dir / 'audio.mp3'
                    with open(audio_file, 'wb') as f:
                        f.write(audio_bytes)
                    print(f'   ✅ Saved audio.mp3 ({len(audio_bytes)} bytes)')

                # Create content.json
                content_json = {
                    'version': '1.0',
                    'displayText': content['text'],
                    'paragraphs': content['paragraphs'],
                    'metadata': {
                        'wordCount': len(content['text'].split()),
                        'characterCount': len(content['text']),
                        'estimatedReadingTime': f"{len(content['text'].split()) // 200 + 1} minutes",
                        'language': 'en',
                    },
                }

                content_file = content_dir / 'content.json'
                with open(content_file, 'w') as f:
                    json.dump(content_json, f, indent=2)
                print('   ✅ Saved content.json')

                # Process word timings
                if 'speech_marks' in data:
                    speech_marks = data['speech_marks']
                    words = []
                    sentences = []

                    word_index = 0
                    current_sentence_start = 0
                    current_sentence_text = ''
                    sentence_start_ms = 0

                    for mark in speech_marks:
                        if mark.get('type') == 'word':
                            word = {
                                'word': mark['value'],
                                'startMs': mark['time'],
                                'endMs': mark.get('end_time', mark['time'] + 200),
                                'charStart': mark.get('start', 0),
                                'charEnd': mark.get('end', 0),
                            }
                            words.append(word)

                            current_sentence_text += f"{mark['value']} "

                            # Detect sentence boundary
                            if any(mark['value'].endswith(p) for p in ['.', '!', '?']):
                                sentences.append({
                                    'text': current_sentence_text.strip(),
                                    'startMs': sentence_start_ms,
                                    'endMs': mark.get('end_time', mark['time'] + 200),
                                    'wordStartIndex': current_sentence_start,
                                    'wordEndIndex': word_index,
                                    'charStart': words[current_sentence_start]['charStart'] if current_sentence_start < len(words) else 0,
                                    'charEnd': mark.get('end', 0),
                                })

                                current_sentence_start = word_index + 1
                                current_sentence_text = ''
                                sentence_start_ms = mark.get('end_time', mark['time']) + 350

                            word_index += 1

                    # Handle remaining text as final sentence
                    if current_sentence_text.strip():
                        sentences.append({
                            'text': current_sentence_text.strip(),
                            'startMs': sentence_start_ms,
                            'endMs': words[-1]['endMs'] if words else 0,
                            'wordStartIndex': current_sentence_start,
                            'wordEndIndex': len(words) - 1,
                            'charStart': words[current_sentence_start]['charStart'] if current_sentence_start < len(words) else 0,
                            'charEnd': words[-1]['charEnd'] if words else len(content['text']),
                        })

                    # Create timing.json
                    timing_json = {
                        'version': '1.0',
                        'words': words,
                        'sentences': sentences,
                        'totalDurationMs': words[-1]['endMs'] if words else 0,
                    }

                    timing_file = content_dir / 'timing.json'
                    with open(timing_file, 'w') as f:
                        json.dump(timing_json, f, indent=2)
                    print(f'   ✅ Saved timing.json ({len(words)} words, {len(sentences)} sentences)')

                print(f"   ✅ Complete: {content['id']}")
            else:
                print(f'   ❌ API error: {response.status_code}')
                print(f'   Response: {response.text}')

        except Exception as e:
            print(f'   ❌ Error: {e}')

    print('\n✅ Test audio generation complete!')
    print('📁 Files saved to: assets/test_content/learning_objects/')
    print('\n📝 Next steps:')
    print('   1. Update pubspec.yaml to include the assets')
    print('   2. Run flutter pub get')
    print('   3. Test with LocalContentService')

if __name__ == '__main__':
    main()