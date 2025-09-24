#!/usr/bin/env python3
"""
Fix the list formatting in the content.json file by:
1. Adding periods to list items in display text
2. Creating separate sentences for each list item
3. Updating word sentence indices
"""

import json
import copy

# Load the current content
with open('assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/content.json', 'r') as f:
    data = json.load(f)

# Create a backup of original data
original_data = copy.deepcopy(data)

# Fix the display text by adding periods to list items
display_text = data['displayText']
fixes = [
    ('Telematics\n', 'Telematics.\n'),
    ('Wearables\n', 'Wearables.\n'),
    ('IoT sensors\n', 'IoT sensors.\n'),
    ('Smartphones\n', 'Smartphones.\n'),
    ('Cloud storage\n', 'Cloud storage.\n'),
    ('Predictive models\n', 'Predictive models.\n'),
    ('Artificial intelligence\n', 'Artificial intelligence.\n'),
]

print("Fixing display text...")
for old, new in fixes:
    if old in display_text:
        display_text = display_text.replace(old, new)
        print(f"  Replaced '{old.strip()}' with '{new.strip()}'")

data['displayText'] = display_text

# Also fix in paragraphs if they exist
for i, para in enumerate(data.get('paragraphs', [])):
    for old, new in fixes:
        if old.strip() in para:
            data['paragraphs'][i] = para.replace(old.strip(), new.strip())

# Now fix the sentence boundaries
sentences = data['timing']['sentences']
words = data['timing']['words']

# Find sentence 102 (the problematic one)
sentence_102 = sentences[102]
print(f"\nOriginal sentence 102: {sentence_102['text'][:50]}...")
print(f"  Duration: {(sentence_102['end_ms'] - sentence_102['start_ms'])/1000:.1f} seconds")

# Create new sentences for each list item
# The list items are words 1995-2005, then "This technology..." starts at 2006
new_sentences = []

# Sentence 102: Telematics.
new_sentences.append({
    "text": "Telematics.",
    "start_ms": 804728,  # End of previous sentence
    "end_ms": 805477,     # End of "Telematics"
    "sentence_index": 102,
    "wordStartIndex": 1995,
    "wordEndIndex": 1995,
    "char_start": 13030,
    "char_end": 13040,
    "break_reason": "period"
})

# Sentence 103: Wearables.
new_sentences.append({
    "text": "Wearables.",
    "start_ms": 805477,
    "end_ms": 806092,
    "sentence_index": 103,
    "wordStartIndex": 1996,
    "wordEndIndex": 1996,
    "char_start": 13041,
    "char_end": 13050,
    "break_reason": "period"
})

# Sentence 104: IoT sensors.
new_sentences.append({
    "text": "IoT sensors.",
    "start_ms": 806092,
    "end_ms": 807706,
    "sentence_index": 104,
    "wordStartIndex": 1997,
    "wordEndIndex": 1998,
    "char_start": 13051,
    "char_end": 13063,
    "break_reason": "period"
})

# Sentence 105: Smartphones.
new_sentences.append({
    "text": "Smartphones.",
    "start_ms": 807706,
    "end_ms": 808542,
    "sentence_index": 105,
    "wordStartIndex": 1999,
    "wordEndIndex": 1999,
    "char_start": 13064,
    "char_end": 13075,
    "break_reason": "period"
})

# Sentence 106: Cloud storage.
new_sentences.append({
    "text": "Cloud storage.",
    "start_ms": 808542,
    "end_ms": 809564,
    "sentence_index": 106,
    "wordStartIndex": 2000,
    "wordEndIndex": 2001,
    "char_start": 13076,
    "char_end": 13089,
    "break_reason": "period"
})

# Sentence 107: Predictive models.
new_sentences.append({
    "text": "Predictive models.",
    "start_ms": 809564,
    "end_ms": 810760,
    "sentence_index": 107,
    "wordStartIndex": 2002,
    "wordEndIndex": 2003,
    "char_start": 13090,
    "char_end": 13107,
    "break_reason": "period"
})

# Sentence 108: Artificial intelligence.
new_sentences.append({
    "text": "Artificial intelligence.",
    "start_ms": 810760,
    "end_ms": 812489,
    "sentence_index": 108,
    "wordStartIndex": 2004,
    "wordEndIndex": 2005,
    "char_start": 13108,
    "char_end": 13131,
    "break_reason": "period"
})

# Sentence 109: This technology is the foundation...
# Find where "This technology" sentence ends
this_tech_end_idx = 2022  # Based on original sentence 102 end
new_sentences.append({
    "text": 'This technology is the foundation of the "predict and prevent" mindset that\'s permeating the insurance value chain.',
    "start_ms": 812489,
    "end_ms": 819513,
    "sentence_index": 109,
    "wordStartIndex": 2006,
    "wordEndIndex": 2022,
    "char_start": 13132,
    "char_end": 13245,
    "break_reason": "period"
})

# Replace sentence 102 with new sentences
print(f"\nReplacing sentence 102 with {len(new_sentences)} new sentences")
sentences[102:103] = new_sentences

# Update all following sentence indices
for i in range(102 + len(new_sentences), len(sentences)):
    sentences[i]['sentence_index'] = i

# Update word sentence indices
print("\nUpdating word sentence indices...")
word_updates = [
    (1995, 1995, 102),  # Telematics
    (1996, 1996, 103),  # Wearables
    (1997, 1998, 104),  # IoT sensors
    (1999, 1999, 105),  # Smartphones
    (2000, 2001, 106),  # Cloud storage
    (2002, 2003, 107),  # Predictive models
    (2004, 2005, 108),  # Artificial intelligence
    (2006, 2022, 109),  # This technology...
]

for start_idx, end_idx, sentence_idx in word_updates:
    for i in range(start_idx, end_idx + 1):
        if i < len(words):
            words[i]['sentence_index'] = sentence_idx
            print(f"  Word {i} ('{words[i]['word']}') -> sentence {sentence_idx}")

# Update all words after index 2022 to have incremented sentence indices
for i in range(2023, len(words)):
    if words[i]['sentence_index'] >= 103:  # Original sentences after 102
        words[i]['sentence_index'] += 7  # We added 7 new sentences

# Add periods to the word text for list items
list_word_indices = [1995, 1996, 1998, 1999, 2001, 2003, 2005]
for idx in list_word_indices:
    if idx < len(words) and not words[idx]['word'].endswith('.'):
        original = words[idx]['word']
        words[idx]['word'] = words[idx]['word'] + '.'
        print(f"\nAdded period to word {idx}: '{original}' -> '{words[idx]['word']}'")

# Save the fixed content
output_file = 'assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/content.json'
with open(output_file, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"\n✅ Fixed content saved to {output_file}")
print(f"   Total sentences: {len(sentences)} (was {len(original_data['timing']['sentences'])})")
print(f"   Added {len(new_sentences) - 1} new sentences for list items")

# Verify the fix
print("\n🔍 Verification:")
for s in sentences[101:110]:
    duration = (s['end_ms'] - s['start_ms']) / 1000
    print(f"   Sentence {s['sentence_index']}: {duration:.1f}s - {s['text'][:50]}...")