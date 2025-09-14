#!/usr/bin/env python3
import re

# Read the SSML file
with open('case-reserve-lesson.ssml', 'r') as file:
    content = file.read()

# Remove XML/SSML tags
plain_text = re.sub(r'<[^>]+>', '', content)

# Replace multiple spaces with single space
plain_text = re.sub(r'\s+', ' ', plain_text)

# Clean up the text
plain_text = plain_text.strip()

# Save to file
with open('case-reserve-lesson.txt', 'w') as file:
    file.write(plain_text)

print("Plain text extracted and saved to case-reserve-lesson.txt")
print(f"Length: {len(plain_text)} characters")