#!/usr/bin/env python3
"""
Convert markdown content to JSON format for use with ElevenLabs preprocessing
"""

import json
import re
from pathlib import Path


def parse_markdown_to_json(markdown_path: str) -> dict:
    """
    Parse markdown file to structured JSON

    Args:
        markdown_path: Path to markdown file

    Returns:
        Dictionary with structured content
    """
    with open(markdown_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # Join all lines to get full text
    full_text = ''.join(lines)

    # Parse into paragraphs (separated by blank lines or special formatting)
    paragraphs = []
    current_paragraph = []

    for line in lines:
        line = line.strip()

        if not line:
            # Empty line indicates paragraph break
            if current_paragraph:
                paragraphs.append(' '.join(current_paragraph))
                current_paragraph = []
        else:
            current_paragraph.append(line)

    # Add final paragraph if exists
    if current_paragraph:
        paragraphs.append(' '.join(current_paragraph))

    # Identify headers (lines that appear to be section titles)
    headers = []
    for para in paragraphs:
        # Common header patterns
        if (len(para.split()) <= 8 and
            (para.endswith(':') or
             para[0].isupper() and not para.endswith('.') or
             any(keyword in para for keyword in ['The Effect', 'Perception', 'Making', 'The Risk', 'Assessing', 'Summary', 'Glossary']))):
            headers.append(para.rstrip(':'))

    # Identify list items
    list_items = []
    for para in paragraphs:
        # Standalone short items that might be list elements
        if len(para.split()) <= 3 and para[0].isupper() and not para.endswith('.'):
            if para not in headers:
                list_items.append(para)

    # Calculate metadata
    word_count = len(full_text.split())
    char_count = len(full_text)
    reading_time = f"{max(1, word_count // 200)} minutes"

    return {
        "version": "1.0",
        "source": "markdown",
        "full_text": full_text,
        "paragraphs": paragraphs,
        "headers": headers,
        "list_items": list_items,
        "metadata": {
            "word_count": word_count,
            "character_count": char_count,
            "estimated_reading_time": reading_time,
            "language": "en"
        }
    }


def main():
    """Main conversion function"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Convert markdown to JSON for ElevenLabs preprocessing'
    )
    parser.add_argument(
        'input',
        help='Path to markdown file'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output JSON file path'
    )

    args = parser.parse_args()

    # Parse markdown
    print(f"📄 Reading markdown: {args.input}")
    content_json = parse_markdown_to_json(args.input)

    # Determine output path
    if args.output:
        output_path = args.output
    else:
        # Same directory as input, with .json extension
        input_path = Path(args.input)
        output_path = input_path.with_suffix('.json')

    # Save JSON
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(content_json, f, indent=2, ensure_ascii=False)

    print(f"✅ Saved JSON to: {output_path}")

    # Print summary
    print("\n📊 Content Summary:")
    print(f"   Paragraphs: {len(content_json['paragraphs'])}")
    print(f"   Headers: {len(content_json['headers'])}")
    print(f"   List items: {len(content_json['list_items'])}")
    print(f"   Total words: {content_json['metadata']['word_count']}")
    print(f"   Total characters: {content_json['metadata']['character_count']}")


if __name__ == '__main__':
    import sys

    if len(sys.argv) == 1:
        # Default test processing
        test_input = 'Test_LO_Content/Risk Management and Insurance in Action.md'

        if Path(test_input).exists():
            print("🧪 Running test conversion...")
            print("=" * 50)
            content_json = parse_markdown_to_json(test_input)

            # Save to Test_LO_Content directory
            output_path = 'Test_LO_Content/original_content.json'
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(content_json, f, indent=2, ensure_ascii=False)

            print(f"✅ Saved to: {output_path}")
            print(f"\n📊 Summary:")
            print(f"   Paragraphs: {len(content_json['paragraphs'])}")
            print(f"   Headers: {len(content_json['headers'])}")
            print(f"   Words: {content_json['metadata']['word_count']}")
        else:
            print("❌ Test file not found.")
            print("Usage: python convert_markdown_to_json.py <input.md> [-o output.json]")
    else:
        main()