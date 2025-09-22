#!/usr/bin/env python3
"""
Process complete ElevenLabs character-level timing data to word-level timing

This script handles the full ElevenLabs JSON format with character-level timing
and converts it to word-level timing with enhanced sentence detection that properly
handles edge cases like lists, abbreviations, quotations, and mathematical expressions.

Version: 2.0 - Now includes comprehensive edge case handling
"""

import json
import re
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from edge_case_handlers import EdgeCaseHandlers, StructureType


class ElevenLabsCompleteProcessor:
    """Process complete ElevenLabs character-level timing to word-level"""

    def __init__(self, elevenlabs_path: str, original_content_path: Optional[str] = None, config: Dict = None):
        """
        Initialize processor

        Args:
            elevenlabs_path: Path to ElevenLabs JSON with character timing
            original_content_path: Optional path to original content for verification
            config: Optional configuration for edge case handling
        """
        self.elevenlabs_path = elevenlabs_path
        self.original_content_path = original_content_path
        self.config = config or {}

        # Initialize edge case handlers
        self.edge_handlers = EdgeCaseHandlers(config)

        # Load ElevenLabs data
        with open(elevenlabs_path, 'r', encoding='utf-8') as f:
            self.elevenlabs_data = json.load(f)

        # Load original content if provided
        self.original_content = None
        if original_content_path:
            with open(original_content_path, 'r', encoding='utf-8') as f:
                self.original_content = json.load(f)

        # Extract alignment data
        self.alignment = self.elevenlabs_data.get('alignment', {})
        self.characters = self.alignment.get('characters', [])
        self.start_times = self.alignment.get('character_start_times_seconds', [])
        self.end_times = self.alignment.get('character_end_times_seconds', [])

        print(f"📊 Loaded ElevenLabs data:")
        print(f"   Characters: {len(self.characters)}")
        print(f"   Start times: {len(self.start_times)}")
        print(f"   End times: {len(self.end_times)}")

    def reconstruct_text(self) -> str:
        """Reconstruct full text from character array"""
        return ''.join(self.characters)

    def extract_words_with_timing(self) -> List[Dict]:
        """Convert character-level timing to word-level timing"""
        words = []
        current_word = []
        word_start_time = None
        word_start_char = 0
        char_position = 0

        for i, char in enumerate(self.characters):
            if char.strip():  # Non-whitespace character
                if word_start_time is None:
                    word_start_time = self.start_times[i]
                    word_start_char = char_position
                current_word.append(char)
            else:  # Whitespace
                if current_word:
                    # End of word
                    word_text = ''.join(current_word)
                    word_end_time = self.end_times[i - 1] if i > 0 else self.end_times[i]

                    words.append({
                        'word': word_text,
                        'start_ms': int(word_start_time * 1000) if word_start_time else 0,
                        'end_ms': int(word_end_time * 1000) if word_end_time else 0,
                        'char_start': word_start_char,
                        'char_end': char_position,
                        'sentence_index': 0  # Will be updated later
                    })

                    current_word = []
                    word_start_time = None

            char_position += 1

        # Add last word if exists
        if current_word:
            word_text = ''.join(current_word)
            word_end_time = self.end_times[-1]

            words.append({
                'word': word_text,
                'start_ms': int(word_start_time * 1000) if word_start_time else 0,
                'end_ms': int(word_end_time * 1000) if word_end_time else 0,
                'char_start': word_start_char,
                'char_end': char_position,
                'sentence_index': 0
            })

        return words

    def detect_sentences(self, words: List[Dict], text: str) -> List[Dict]:
        """Detect sentence boundaries and create sentence timing with edge case handling"""
        # Use enhanced detection if enabled
        if self.config.get('use_enhanced_detection', True):
            # Detect special structures in the text
            structures = self.edge_handlers.detect_structures(text)

            # Apply enhanced sentence detection
            sentences = self.edge_handlers.apply_enhanced_sentence_detection(
                words, text, structures
            )
        else:
            # Fallback to original simple detection
            sentences = self._simple_sentence_detection(words, text)

        return sentences

    def _simple_sentence_detection(self, words: List[Dict], text: str) -> List[Dict]:
        """Original simple sentence detection logic"""
        sentences = []
        current_sentence_words = []
        current_sentence_start = 0
        sentence_index = 0

        for i, word in enumerate(words):
            current_sentence_words.append(word)
            word['sentence_index'] = sentence_index

            # Check if word ends with sentence-ending punctuation
            word_text = word['word']
            if any(word_text.endswith(p) for p in ['.', '!', '?']):
                # Handle special cases like "Dr." or "Mr."
                if not (len(word_text) <= 4 and '.' in word_text and
                       i + 1 < len(words) and words[i + 1]['word'][0].islower()):

                    # Create sentence
                    sentence_text = text[current_sentence_start:word['char_end'] + 1].strip()

                    sentences.append({
                        'text': sentence_text,
                        'start_ms': current_sentence_words[0]['start_ms'],
                        'end_ms': word['end_ms'],
                        'sentence_index': sentence_index,
                        'wordStartIndex': i - len(current_sentence_words) + 1,
                        'wordEndIndex': i,
                        'char_start': current_sentence_start,
                        'char_end': word['char_end']
                    })

                    # Reset for next sentence
                    current_sentence_words = []
                    current_sentence_start = word['char_end'] + 1
                    sentence_index += 1

        # Add remaining words as final sentence if any
        if current_sentence_words:
            sentence_text = text[current_sentence_start:].strip()
            sentences.append({
                'text': sentence_text,
                'start_ms': current_sentence_words[0]['start_ms'],
                'end_ms': current_sentence_words[-1]['end_ms'],
                'sentence_index': sentence_index,
                'wordStartIndex': len(words) - len(current_sentence_words),
                'wordEndIndex': len(words) - 1,
                'char_start': current_sentence_start,
                'char_end': len(text) - 1
            })

        return sentences

    def extract_paragraphs(self, text: str) -> List[str]:
        """Extract paragraphs from text - preserve from original if available"""
        # If we have original content with paragraph breaks, use those
        if self.original_content and 'full_text' in self.original_content:
            original_text = self.original_content['full_text']
            # Split on newlines to get paragraphs
            paragraphs = [p.strip() for p in original_text.split('\n') if p.strip()]
            if paragraphs:
                return paragraphs

        # Fallback: Split on double newlines or single newlines
        paragraphs = []
        current_para = []

        lines = text.split('\n')
        for line in lines:
            line = line.strip()
            if line:
                current_para.append(line)
            elif current_para:
                paragraphs.append(' '.join(current_para))
                current_para = []

        if current_para:
            paragraphs.append(' '.join(current_para))

        # If no paragraphs found, treat entire text as one paragraph
        if not paragraphs:
            paragraphs = [text.strip()]

        return paragraphs

    def extract_headers(self, text: str) -> List[str]:
        """Extract potential headers from text"""
        headers = []
        lines = text.split('\n')

        for line in lines:
            line = line.strip()
            # Heuristic: short lines that might be headers
            if line and len(line.split()) <= 8:
                if (line.endswith(':') or
                    (line[0].isupper() and not line.endswith('.')) or
                    any(keyword in line for keyword in [
                        'Summary', 'Introduction', 'Conclusion',
                        'Overview', 'Background', 'Glossary'
                    ])):
                    headers.append(line.rstrip(':'))

        return list(set(headers))  # Remove duplicates

    def ensure_continuous_sentence_coverage(self, words: List[Dict], sentences: List[Dict]) -> Tuple[List[Dict], List[Dict]]:
        """Ensure every word has a valid sentence index and sentences have no gaps"""
        if not sentences or not words:
            return words, sentences

        # Extend each sentence's time boundaries to eliminate gaps
        for i in range(len(sentences)):
            if i < len(sentences) - 1:
                # Extend current sentence end to next sentence start
                next_sentence_start = sentences[i + 1]['start_ms']
                current_sentence_end = sentences[i]['end_ms']

                # Find the midpoint between sentences
                midpoint = (current_sentence_end + next_sentence_start) // 2

                # Extend current sentence to midpoint
                sentences[i]['end_ms'] = midpoint
                # Start next sentence from midpoint
                sentences[i + 1]['start_ms'] = midpoint

        # Now assign words to sentences based on the extended boundaries
        for word in words:
            word_mid = (word['start_ms'] + word['end_ms']) // 2

            # Find which sentence this word belongs to
            assigned = False
            for i, sentence in enumerate(sentences):
                if sentence['start_ms'] <= word_mid <= sentence['end_ms']:
                    word['sentence_index'] = i
                    assigned = True
                    break

            # If word falls outside all sentences (shouldn't happen after extension)
            # assign it to the nearest sentence
            if not assigned:
                if word_mid < sentences[0]['start_ms']:
                    word['sentence_index'] = 0
                elif word_mid > sentences[-1]['end_ms']:
                    word['sentence_index'] = len(sentences) - 1
                else:
                    # Find nearest sentence
                    min_distance = float('inf')
                    nearest_idx = 0
                    for i, sentence in enumerate(sentences):
                        distance = min(
                            abs(word_mid - sentence['start_ms']),
                            abs(word_mid - sentence['end_ms'])
                        )
                        if distance < min_distance:
                            min_distance = distance
                            nearest_idx = i
                    word['sentence_index'] = nearest_idx

        # Verify no word has sentence_index = -1
        for word in words:
            if 'sentence_index' not in word or word['sentence_index'] < 0:
                print(f"⚠️ Word '{word['word']}' at {word['start_ms']}ms had invalid sentence index, fixing...")
                # Assign to sentence 0 as fallback
                word['sentence_index'] = 0

        return words, sentences

    def process(self) -> Dict:
        """Process ElevenLabs data and create enhanced content JSON"""
        # Reconstruct text
        full_text = self.reconstruct_text()

        # Extract words with timing
        words = self.extract_words_with_timing()

        # Detect sentences
        sentences = self.detect_sentences(words, full_text)

        # Post-process to ensure continuous sentence coverage
        words, sentences = self.ensure_continuous_sentence_coverage(words, sentences)

        # Extract paragraphs
        paragraphs = self.extract_paragraphs(full_text)

        # Extract headers
        headers = self.extract_headers(full_text)

        # Create display text with paragraph breaks preserved
        # If we have original content with paragraphs, use its formatting
        if self.original_content and 'full_text' in self.original_content:
            display_text = self.original_content['full_text']
        else:
            # Join paragraphs with double newlines for display
            display_text = '\n\n'.join(paragraphs) if paragraphs else full_text

        # Calculate total duration
        total_duration_ms = int(self.end_times[-1] * 1000) if self.end_times else 0

        # Build enhanced content JSON
        content = {
            "version": "1.0",
            "source": "elevenlabs-complete",
            "displayText": display_text,
            "paragraphs": paragraphs,
            "headers": headers,
            "formatting": {
                "boldHeaders": False,
                "paragraphSpacing": True
            },
            "metadata": {
                "wordCount": len(words),
                "characterCount": len(full_text),
                "estimatedReadingTime": f"{max(1, len(words) // 200)} minutes",
                "language": "en"
            },
            "timing": {
                "words": words,
                "sentences": sentences,
                "totalDurationMs": total_duration_ms
            }
        }

        return content

    def save(self, output_path: str):
        """Process and save enhanced content"""
        content = self.process()

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(content, f, indent=2, ensure_ascii=False)

        print(f"\n✅ Saved enhanced content to: {output_path}")
        print(f"\n📊 Summary:")
        print(f"   Text: {content['metadata']['characterCount']} characters")
        print(f"   Words: {len(content['timing']['words'])}")
        print(f"   Sentences: {len(content['timing']['sentences'])}")
        print(f"   Paragraphs: {len(content['paragraphs'])}")
        print(f"   Duration: {content['timing']['totalDurationMs'] / 1000:.1f} seconds")
        print(f"   Duration: {content['timing']['totalDurationMs'] / 60000:.1f} minutes")

        # Verify against original if provided
        if self.original_content:
            orig_text = self.original_content.get('full_text', '')
            if orig_text.strip() == content['displayText'].strip():
                print("\n✅ Text matches original content perfectly!")
            else:
                print(f"\n⚠️ Text differs from original:")
                print(f"   Original: {len(orig_text)} chars")
                print(f"   Processed: {len(content['displayText'])} chars")


def main():
    """Main function to process ElevenLabs complete data"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Process complete ElevenLabs character-level timing data with enhanced edge case handling'
    )
    parser.add_argument(
        'elevenlabs_json',
        help='Path to ElevenLabs JSON with character timing'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output path for enhanced JSON (default: *_complete.json)'
    )
    parser.add_argument(
        '-c', '--original-content',
        help='Path to original content JSON for formatting preservation'
    )
    parser.add_argument(
        '--config',
        default='config.json',
        help='Path to configuration file for edge case handling (default: config.json)'
    )

    args = parser.parse_args()

    # Determine output path
    if args.output:
        output_path = args.output
    else:
        input_path = Path(args.elevenlabs_json)
        output_path = input_path.parent / f"{input_path.stem}_enhanced.json"

    # Load configuration if provided
    config = {}
    if args.config and Path(args.config).exists():
        with open(args.config, 'r') as f:
            config = json.load(f)
            print(f"📋 Loaded configuration from: {args.config}")

    # Process
    processor = ElevenLabsCompleteProcessor(
        args.elevenlabs_json,
        args.original_content,
        config
    )
    processor.save(str(output_path))


if __name__ == '__main__':
    import sys

    if len(sys.argv) == 1:
        # Default test processing
        print("🧪 Running test processing with complete ElevenLabs data...")
        print("=" * 50)

        processor = ElevenLabsCompleteProcessor(
            'Test_LO_Content/Risk Management and Insurance in Action.json',
            'Test_LO_Content/original_content.json'
        )

        output_path = 'assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/content_complete.json'
        processor.save(output_path)
    else:
        main()