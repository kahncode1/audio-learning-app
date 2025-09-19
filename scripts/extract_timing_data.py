#!/usr/bin/env python3
"""
Extract timing data from Speechify API response and create proper timing.json
"""

import json
from pathlib import Path

def main():
    # Load raw response
    raw_file = Path('assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/raw_response.json')

    with open(raw_file, 'r') as f:
        data = json.load(f)

    # Extract words and sentences from speech_marks
    words = []
    sentences = []

    if 'speech_marks' in data and isinstance(data['speech_marks'], dict):
        speech_data = data['speech_marks']

        # Extract words from chunks
        if 'chunks' in speech_data:
            for chunk in speech_data['chunks']:
                if chunk.get('type') == 'word':
                    # Skip punctuation-only "words"
                    if chunk['value'] in [',', '.', '!', '?']:
                        continue
                    words.append({
                        'word': chunk['value'],
                        'startMs': chunk['start_time'],
                        'endMs': chunk['end_time'],
                        'charStart': chunk['start'],
                        'charEnd': chunk['end']
                    })

        # Create sentences based on the full text structure
        sentence_texts = [
            'Understanding Case Reserve Management in Insurance Claims Processing.',
            'A case reserve represents the estimated amount of money an insurance company expects to pay for a claim.',
            'This critical financial tool serves multiple purposes in the claims management process, from regulatory compliance to strategic planning and accurate financial reporting.',
            'When an insurance claim is first reported, adjusters must quickly assess the potential financial exposure.'
        ]

        # Map sentences to word indices
        word_idx = 0
        for sent_text in sentence_texts:
            sent_words = len(sent_text.split())
            if word_idx < len(words):
                start_idx = word_idx
                end_idx = min(word_idx + sent_words - 1, len(words) - 1)

                sentences.append({
                    'text': sent_text,
                    'startMs': words[start_idx]['startMs'] if start_idx < len(words) else 0,
                    'endMs': words[end_idx]['endMs'] if end_idx < len(words) else 0,
                    'wordStartIndex': start_idx,
                    'wordEndIndex': end_idx,
                    'charStart': 0,  # Will be calculated based on actual text position
                    'charEnd': 0
                })

                word_idx = end_idx + 1

    # Create timing.json
    timing_data = {
        'version': '1.0',
        'words': words,
        'sentences': sentences,
        'totalDurationMs': words[-1]['endMs'] if words else 0
    }

    # Save timing.json
    output_dir = Path('assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f')
    with open(output_dir / 'timing.json', 'w') as f:
        json.dump(timing_data, f, indent=2)

    print(f'✅ Created timing.json with {len(words)} words and {len(sentences)} sentences')
    print(f'   Total duration: {timing_data["totalDurationMs"]/1000:.1f} seconds')

if __name__ == '__main__':
    main()