#!/usr/bin/env python3
"""Test the lookup table generation in preprocessing"""

import json
import sys
sys.path.insert(0, '/Users/kahnja/audio-learning-app/preprocessing_pipeline')

from process_elevenlabs_complete import ElevenLabsCompleteProcessor

# Create a test case with correct structure
test_data = {
    "alignment": {
        "characters": ["T", "h", "e", " ", "t", "e", "s", "t", ".", " ", "W", "o", "r", "k", "s", "."],
        "character_start_times_seconds": [0.0, 0.1, 0.2, 0.3, 0.35, 0.45, 0.55, 0.65, 0.75, 0.8, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5],
        "character_end_times_seconds": [0.1, 0.2, 0.3, 0.35, 0.45, 0.55, 0.65, 0.75, 0.8, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6]
    }
}

# Save test data
with open('/tmp/test_elevenlabs_v2.json', 'w') as f:
    json.dump(test_data, f)

# Process it
print("=" * 60)
print("Testing Lookup Table Generation")
print("=" * 60)

processor = ElevenLabsCompleteProcessor('/tmp/test_elevenlabs_v2.json')
result = processor.process()

# Check if lookup table was generated
if 'timing' in result and 'lookup_table' in result['timing']:
    lookup = result['timing']['lookup_table']
    print(f"\n✅ Lookup table generated successfully!")
    print(f"   Version: {lookup['version']}")
    print(f"   Interval: {lookup['interval']}ms")
    print(f"   Total duration: {lookup['totalDurationMs']}ms")
    print(f"   Entries: {len(lookup['lookup'])}")

    # Show some entries
    print("\n   Sample entries (every 100ms):")
    for i in range(0, min(len(lookup['lookup']), 160), 10):
        time_ms = i * lookup['interval']
        entry = lookup['lookup'][i]
        print(f"     {time_ms:4d}ms: word[{entry[0]:2d}], sentence[{entry[1]:2d}]")

    # Verify the words
    words = result['timing']['words']
    print(f"\n   Words extracted: {len(words)}")
    for i, word in enumerate(words):
        print(f"     Word {i}: '{word['word']}' @ {word['start_ms']}-{word['end_ms']}ms")

    # Save full result
    with open('/tmp/test_with_lookup_v2.json', 'w') as f:
        json.dump(result, f, indent=2)
    print(f"\n   Full result saved to: /tmp/test_with_lookup_v2.json")
else:
    print("❌ Lookup table not found in output!")
    print(f"   Keys in timing: {result.get('timing', {}).keys()}")