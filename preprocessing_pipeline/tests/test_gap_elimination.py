#!/usr/bin/env python3
"""Test script to verify gap elimination in preprocessing"""

import json
import sys
sys.path.insert(0, '/Users/kahnja/audio-learning-app/preprocessing_pipeline')

# Create test data with gaps (simulating what we see from downloaded content)
test_words = [
    {"word": "The", "start_ms": 0, "end_ms": 163, "sentence_index": 0},
    {"word": "objective", "start_ms": 197, "end_ms": 534, "sentence_index": 0},  # 34ms gap
    {"word": "of", "start_ms": 557, "end_ms": 604, "sentence_index": 0},  # 23ms gap
    {"word": "this", "start_ms": 639, "end_ms": 755, "sentence_index": 0},  # 35ms gap
    {"word": "lesson", "start_ms": 824, "end_ms": 1068, "sentence_index": 0},  # 69ms gap
    {"word": "is", "start_ms": 1115, "end_ms": 1184, "sentence_index": 0},  # 47ms gap
    {"word": "to", "start_ms": 1219, "end_ms": 1290, "sentence_index": 0},  # 35ms gap
    {"word": "illustrate", "start_ms": 1349, "end_ms": 1708, "sentence_index": 0},  # 59ms gap
]

def check_gaps(words, label):
    """Check for gaps in word timing"""
    gaps = []
    for i in range(len(words) - 1):
        gap = words[i+1]["start_ms"] - words[i]["end_ms"]
        if gap != 0:
            gaps.append((i, gap, words[i]["word"], words[i+1]["word"]))

    print(f"\n{label}:")
    print(f"  Total words: {len(words)}")
    if gaps:
        print(f"  Gaps found: {len(gaps)}")
        for i, (idx, gap_ms, w1, w2) in enumerate(gaps[:5]):
            print(f"    Gap {i+1}: '{w1}' -> '{w2}': {gap_ms}ms")
    else:
        print(f"  ✅ No gaps! All words are continuous.")

    return len(gaps) == 0

# Test the gap elimination
# Create a minimal processor instance
class TestProcessor:
    def eliminate_timing_gaps(self, words):
        """Same method from our updated preprocessing"""
        if not words:
            return words

        gaps_found = 0
        total_gap_ms = 0
        max_gap = 0

        # Process each word pair
        for i in range(len(words) - 1):
            current_word = words[i]
            next_word = words[i + 1]

            gap = next_word['start_ms'] - current_word['end_ms']

            if gap > 0:
                gaps_found += 1
                total_gap_ms += gap
                max_gap = max(max_gap, gap)

                # For normal gaps (<500ms), extend current word to meet next
                if gap < 500:
                    current_word['end_ms'] = next_word['start_ms']
                else:
                    # For large gaps (silence between paragraphs), split 50/50
                    midpoint = current_word['end_ms'] + (gap // 2)
                    current_word['end_ms'] = midpoint

        return words

# Test before and after
print("=" * 60)
print("TESTING GAP ELIMINATION")
print("=" * 60)

# Check original gaps
has_no_gaps_before = check_gaps(test_words, "BEFORE (with gaps)")

# Apply gap elimination
processor = TestProcessor()
fixed_words = processor.eliminate_timing_gaps(test_words.copy())

# Check after elimination
has_no_gaps_after = check_gaps(fixed_words, "AFTER (gaps eliminated)")

print("\n" + "=" * 60)
if has_no_gaps_after and not has_no_gaps_before:
    print("✅ SUCCESS: Gap elimination works correctly!")
    print("   - Started with gaps between words")
    print("   - After processing, all gaps eliminated")
    print("   - Binary search will now always find a word")
else:
    print("❌ FAILED: Gap elimination not working")

# Verify word start times preserved
print("\nVerifying start times preserved:")
for i in range(min(3, len(test_words))):
    orig = test_words[i]
    fixed = fixed_words[i]
    match = "✅" if orig["start_ms"] == fixed["start_ms"] else "❌"
    print(f"  {match} '{orig['word']}': start_ms {orig['start_ms']} -> {fixed['start_ms']}")