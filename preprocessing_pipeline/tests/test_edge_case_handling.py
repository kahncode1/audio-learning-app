#!/usr/bin/env python3
"""
Test script for edge case handling in preprocessing pipeline

This script demonstrates how the enhanced sentence detection handles various
edge cases in text processing.
"""

import json
from edge_case_handlers import EdgeCaseHandlers


def test_edge_case_detection():
    """Test edge case detection on sample text"""

    # Initialize handlers
    handlers = EdgeCaseHandlers()

    # Test texts with various edge cases
    test_cases = [
        {
            "name": "Colon List",
            "text": "Examples of technology include: Telematics Wearables IoT sensors Smartphones",
            "expected": "Should split list items"
        },
        {
            "name": "Abbreviations",
            "text": "Dr. Smith works at Example Inc. on Main St. at 3:30 p.m.",
            "expected": "Should not break at abbreviation periods"
        },
        {
            "name": "Numbered List",
            "text": "The process has three steps: 1. Collection 2. Analysis 3. Implementation",
            "expected": "Should separate numbered items"
        },
        {
            "name": "Mathematical",
            "text": "The formula E = mc² shows that energy equals mass times the speed of light squared. The ratio is 3:1.",
            "expected": "Should preserve equations and ratios"
        },
        {
            "name": "Quotations",
            "text": 'She said, "This is important." John replied, "I understand."',
            "expected": "Should handle quoted text appropriately"
        },
        {
            "name": "Special Punctuation",
            "text": "Well... I'm not sure. The solution—if there is one—requires thought.",
            "expected": "Should handle ellipses and em dashes"
        }
    ]

    print("=" * 60)
    print("EDGE CASE DETECTION TEST")
    print("=" * 60)

    for test_case in test_cases:
        print(f"\n📝 Test: {test_case['name']}")
        print(f"   Text: {test_case['text']}")

        # Detect structures
        structures = handlers.detect_structures(test_case['text'])

        if structures:
            print(f"   ✅ Detected {len(structures)} structure(s):")
            for struct in structures:
                print(f"      - {struct.type.value}: '{struct.content}'")
        else:
            print("   ⚠️ No special structures detected")

        print(f"   Expected: {test_case['expected']}")

    print("\n" + "=" * 60)


def test_sentence_breaking():
    """Test sentence breaking logic"""

    handlers = EdgeCaseHandlers()

    test_sentences = [
        ("This ends with a period.", True, "Normal sentence"),
        ("Dr. Smith is here", False, "Abbreviation - Dr."),
        ("Visit www.example.com for info", False, "URL with dots"),
        ("The ratio is 3:1 today", False, "Ratio colon"),
        ("Here's a list:", True, "List introduction"),
        ("Well... maybe", False, "Ellipsis"),
        ("Really?!", True, "Multiple punctuation"),
        ("The time is 3:30 p.m. now", False, "Time format"),
    ]

    print("\nSENTENCE BREAKING TEST")
    print("=" * 60)

    for text, should_break, description in test_sentences:
        # Check if sentence should break
        last_char = text[-1] if text else ''

        # Simple check based on last character
        breaks = False
        if last_char in '.!?':
            # Check for abbreviation
            words = text.split()
            if words:
                last_word = words[-1]
                if not handlers.is_abbreviation(last_word):
                    breaks = True
        elif last_char == ':':
            # Check if it's a list introduction
            if text.endswith('list:') or text.endswith('following:') or text.endswith('include:'):
                breaks = True

        status = "✅" if breaks == should_break else "❌"
        print(f"{status} '{text}' - {description}")
        print(f"   Expected break: {should_break}, Got: {breaks}")

    print("=" * 60)


def test_abbreviation_database():
    """Test abbreviation recognition"""

    handlers = EdgeCaseHandlers()

    test_abbrevs = [
        ("Dr.", True),
        ("Mr.", True),
        ("Inc.", True),
        ("U.S.A.", True),
        ("etc.", True),
        ("random.", False),
        ("end.", False),
        ("Ph.D.", True),
        ("a.m.", True),
        ("St.", True),  # Street
    ]

    print("\nABBREVIATION RECOGNITION TEST")
    print("=" * 60)

    for word, is_abbrev in test_abbrevs:
        result = handlers.is_abbreviation(word)
        status = "✅" if result == is_abbrev else "❌"
        print(f"{status} '{word}' - Expected: {is_abbrev}, Got: {result}")

    print("=" * 60)


def main():
    """Run all tests"""
    print("\n🧪 TESTING EDGE CASE HANDLING\n")

    test_edge_case_detection()
    test_sentence_breaking()
    test_abbreviation_database()

    print("\n✅ All tests completed!")
    print("\nNote: This demonstrates the edge case detection capabilities.")
    print("The actual preprocessing will use these to improve sentence segmentation.")


if __name__ == "__main__":
    main()