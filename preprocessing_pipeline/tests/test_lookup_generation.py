#!/usr/bin/env python3
"""Test the lookup table generation in preprocessing"""

import json
import sys
sys.path.insert(0, '/Users/kahnja/audio-learning-app/preprocessing_pipeline')

from process_elevenlabs_complete import ElevenLabsCompleteProcessor

# Create a simple test case
test_data = {
    "characters": [
        {"character": "T", "start_time_ms": 0, "duration_ms": 100},
        {"character": "h", "start_time_ms": 100, "duration_ms": 100},
        {"character": "e", "start_time_ms": 200, "duration_ms": 100},
        {"character": " ", "start_time_ms": 300, "duration_ms": 50},
        {"character": "t", "start_time_ms": 350, "duration_ms": 100},
        {"character": "e", "start_time_ms": 450, "duration_ms": 100},
        {"character": "s", "start_time_ms": 550, "duration_ms": 100},
        {"character": "t", "start_time_ms": 650, "duration_ms": 100},
        {"character": ".", "start_time_ms": 750, "duration_ms": 50},
        {"character": " ", "start_time_ms": 800, "duration_ms": 200},
        {"character": "W", "start_time_ms": 1000, "duration_ms": 100},
        {"character": "o", "start_time_ms": 1100, "duration_ms": 100},
        {"character": "r", "start_time_ms": 1200, "duration_ms": 100},
        {"character": "k", "start_time_ms": 1300, "duration_ms": 100},
        {"character": "s", "start_time_ms": 1400, "duration_ms": 100},
        {"character": ".", "start_time_ms": 1500, "duration_ms": 100},
    ]
}

# Save test data
with open('/tmp/test_elevenlabs.json', 'w') as f:
    json.dump(test_data, f)

# Process it
print("=" * 60)
print("Testing Lookup Table Generation")
print("=" * 60)

processor = ElevenLabsCompleteProcessor('/tmp/test_elevenlabs.json')
result = processor.process()

# Check if lookup table was generated
if 'timing' in result and 'lookup_table' in result['timing']:
    lookup = result['timing']['lookup_table']
    print(f"\n✅ Lookup table generated successfully!")
    print(f"   Version: {lookup['version']}")
    print(f"   Interval: {lookup['interval']}ms")
    print(f"   Total duration: {lookup['totalDurationMs']}ms")
    print(f"   Entries: {len(lookup['lookup'])}")

    # Show first 10 entries
    print("\n   First 10 entries:")
    for i, entry in enumerate(lookup['lookup'][:10]):
        time_ms = i * lookup['interval']
        print(f"     {time_ms:4d}ms: word[{entry[0]:2d}], sentence[{entry[1]:2d}]")

    # Save full result
    with open('/tmp/test_with_lookup.json', 'w') as f:
        json.dump(result, f, indent=2)
    print(f"\n   Full result saved to: /tmp/test_with_lookup.json")
else:
    print("❌ Lookup table not found in output!")
    print(f"   Keys in timing: {result.get('timing', {}).keys()}")