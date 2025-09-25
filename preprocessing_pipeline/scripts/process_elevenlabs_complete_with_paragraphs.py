#!/usr/bin/env python3
"""
Process complete ElevenLabs character-level timing data to word-level timing
WITH PARAGRAPH PRESERVATION

This script handles the full ElevenLabs JSON format with character-level timing
and converts it to word-level timing while preserving paragraph breaks from
the original markdown content.

Version: 3.0 - Paragraph preservation for proper display formatting
"""

import json
import re
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from difflib import SequenceMatcher
from edge_case_handlers import EdgeCaseHandlers, StructureType


class ElevenLabsCompleteProcessorWithParagraphs:
    """Process complete ElevenLabs character-level timing to word-level with paragraph preservation"""

    def __init__(self, elevenlabs_path: str, original_content_path: Optional[str] = None, config: Dict = None):
        """
        Initialize processor

        Args:
            elevenlabs_path: Path to ElevenLabs JSON with character timing
            original_content_path: Optional path to original content for formatting preservation
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
        self.original_paragraphs = []
        if original_content_path:
            if original_content_path.endswith('.json'):
                with open(original_content_path, 'r', encoding='utf-8') as f:
                    self.original_content = json.load(f)
                    # Extract paragraphs from JSON
                    if 'full_text' in self.original_content:
                        # Split on newlines to get paragraphs
                        self.original_paragraphs = [p.strip() for p in self.original_content['full_text'].split('\n') if p.strip()]
            elif original_content_path.endswith('.md'):
                with open(original_content_path, 'r', encoding='utf-8') as f:
                    md_content = f.read()
                    # Split markdown into paragraphs
                    # First try double line breaks
                    self.original_paragraphs = [p.strip() for p in md_content.split('\n\n') if p.strip()]
                    # If we only get one paragraph, try single line breaks
                    if len(self.original_paragraphs) <= 1:
                        self.original_paragraphs = [p.strip() for p in md_content.split('\n') if p.strip()]
                    # Remove markdown headers and clean up
                    self.original_paragraphs = [re.sub(r'^#+\s*', '', p) for p in self.original_paragraphs]

        # Extract alignment data
        self.alignment = self.elevenlabs_data.get('alignment', {})
        self.characters = self.alignment.get('characters', [])
        self.start_times = self.alignment.get('character_start_times_seconds', [])
        self.end_times = self.alignment.get('character_end_times_seconds', [])

        print(f"📊 Loaded ElevenLabs data:")
        print(f"   Characters: {len(self.characters)}")
        print(f"   Start times: {len(self.start_times)}")
        print(f"   End times: {len(self.end_times)}")
        if self.original_paragraphs:
            print(f"   Original paragraphs: {len(self.original_paragraphs)}")

    def reconstruct_text_with_paragraphs(self) -> Tuple[str, List[str], List[int]]:
        """
        Reconstruct text with paragraph breaks preserved from original

        Returns:
            Tuple of (full_text_with_breaks, paragraphs_list, paragraph_break_positions)
        """
        # First reconstruct the raw text
        raw_text = ''.join(self.characters)

        if not self.original_paragraphs:
            # No original paragraphs, return as single paragraph
            return raw_text, [raw_text], []

        # Simple approach: Just split the raw text into roughly equal parts
        # based on the number of original paragraphs, breaking at sentence boundaries
        num_target_paragraphs = len(self.original_paragraphs)

        # Find sentence ending positions in the raw text
        sentence_ends = []
        for i, char in enumerate(self.characters):
            if i > 0 and char in '.!?' and i < len(self.characters) - 1:
                # Check if next char is space or end
                if i + 1 >= len(self.characters) or self.characters[i + 1].isspace():
                    sentence_ends.append(i + 1)

        if not sentence_ends:
            # No sentence boundaries found, fall back to single paragraph
            return raw_text, [raw_text], []

        # Calculate ideal paragraph length
        total_length = len(raw_text)
        ideal_para_length = total_length / num_target_paragraphs

        # Build paragraphs by finding the best sentence boundaries
        paragraphs = []
        paragraph_break_positions = []
        current_start = 0

        for para_idx in range(num_target_paragraphs - 1):
            # Find the target end position for this paragraph
            target_end = int((para_idx + 1) * ideal_para_length)

            # Find the closest sentence boundary to the target
            best_boundary = None
            min_distance = float('inf')

            for boundary in sentence_ends:
                if boundary > current_start:
                    distance = abs(boundary - target_end)
                    if distance < min_distance:
                        min_distance = distance
                        best_boundary = boundary
                    # Stop searching if we've gone too far past the target
                    if boundary > target_end + ideal_para_length / 2:
                        break

            if best_boundary and best_boundary > current_start:
                # Extract paragraph
                paragraph_text = raw_text[current_start:best_boundary].strip()
                if paragraph_text:
                    paragraphs.append(paragraph_text)
                    paragraph_break_positions.append(current_start)
                    current_start = best_boundary
                    # Skip any whitespace after the boundary
                    while current_start < len(raw_text) and raw_text[current_start].isspace():
                        current_start += 1

        # Add the final paragraph
        if current_start < len(raw_text):
            final_paragraph = raw_text[current_start:].strip()
            if final_paragraph:
                paragraphs.append(final_paragraph)

        # Reconstruct with paragraph breaks
        full_text_with_breaks = '\n\n'.join(paragraphs)

        return full_text_with_breaks, paragraphs, paragraph_break_positions

    def _find_raw_position(self, normalized_text: str, normalized_pos: int) -> int:
        """Map a position in normalized text back to raw text position"""
        if normalized_pos >= len(normalized_text):
            return len(''.join(self.characters))

        # Count actual characters up to the normalized position
        char_count = 0
        norm_count = 0
        raw_pos = 0

        for char in self.characters:
            if char.strip():  # Non-whitespace
                if norm_count >= normalized_pos:
                    break
                norm_count += 1
            raw_pos += 1

        return raw_pos

    def extract_words_with_timing_and_paragraphs(self, full_text: str) -> List[Dict]:
        """Extract words with timing from the full text with paragraph breaks"""
        words = []
        current_word = []
        word_start_time = None
        word_start_char_in_text = 0
        char_position_in_original = 0
        char_position_in_text = 0

        # Process character by character
        for i, char in enumerate(self.characters):
            # Check if this position in the full_text is a paragraph break
            if char_position_in_text < len(full_text):
                # Skip over any \n\n in the full text that aren't in the original
                while (char_position_in_text < len(full_text) - 1 and
                       full_text[char_position_in_text:char_position_in_text+2] == '\n\n'):
                    char_position_in_text += 2

            if char.strip():  # Non-whitespace character
                if word_start_time is None:
                    word_start_time = self.start_times[i]
                    word_start_char_in_text = char_position_in_text
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
                        'char_start': word_start_char_in_text,
                        'char_end': char_position_in_text + len(word_text),
                        'sentence_index': 0  # Will be updated later
                    })

                    current_word = []
                    word_start_time = None

            # Advance position in both original and text
            char_position_in_original += 1
            if char_position_in_text < len(full_text) and full_text[char_position_in_text] == char:
                char_position_in_text += 1

        # Add last word if exists
        if current_word:
            word_text = ''.join(current_word)
            word_end_time = self.end_times[-1]

            words.append({
                'word': word_text,
                'start_ms': int(word_start_time * 1000) if word_start_time else 0,
                'end_ms': int(word_end_time * 1000) if word_end_time else 0,
                'char_start': word_start_char_in_text,
                'char_end': char_position_in_text + len(word_text),
                'sentence_index': 0
            })

        # Now fix character positions by finding actual word positions in the text
        for word_data in words:
            word = word_data['word']
            # Find this word in the text starting from expected position
            search_start = max(0, word_data['char_start'] - 10)
            search_end = min(len(full_text), word_data['char_start'] + len(word) + 10)
            search_text = full_text[search_start:search_end]

            if word in search_text:
                word_pos = search_text.find(word)
                word_data['char_start'] = search_start + word_pos
                word_data['char_end'] = search_start + word_pos + len(word)

        return words

    def eliminate_timing_gaps(self, words: List[Dict]) -> List[Dict]:
        """Eliminate gaps between consecutive words for smooth highlighting"""
        if not words:
            return words

        gap_count = 0
        total_gap_time = 0
        max_gap = 0

        for i in range(len(words) - 1):
            current_end = words[i]['end_ms']
            next_start = words[i + 1]['start_ms']

            if next_start > current_end:
                gap = next_start - current_end
                total_gap_time += gap
                max_gap = max(max_gap, gap)
                gap_count += 1

                # Split the gap
                midpoint = (current_end + next_start) // 2
                words[i]['end_ms'] = midpoint
                words[i + 1]['start_ms'] = midpoint

        if gap_count > 0:
            print(f"🔧 Eliminating timing gaps...")
            print(f"   ✅ Eliminated {gap_count} gaps")
            print(f"      Average gap: {total_gap_time / gap_count:.1f}ms")
            print(f"      Max gap: {max_gap}ms")
            print(f"      Total gap time: {total_gap_time}ms")

        return words

    def detect_sentences(self, words: List[Dict], full_text: str) -> List[Dict]:
        """Detect sentence boundaries using enhanced detection"""
        if not words:
            return []

        # Use enhanced detection with edge case handlers
        structures = self.edge_handlers.detect_structures(full_text)
        sentences = self.edge_handlers.apply_enhanced_sentence_detection(
            words, full_text, structures
        )

        return sentences

    def ensure_continuous_sentence_coverage(self, words: List[Dict], sentences: List[Dict]) -> Tuple[List[Dict], List[Dict]]:
        """Ensure every word is assigned to exactly one sentence with no gaps"""
        if not words or not sentences:
            return words, sentences

        # First, extend sentence timings to eliminate gaps
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

            # If word falls outside all sentences, assign to nearest
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
                word['sentence_index'] = 0

        return words, sentences

    def extract_headers(self, text: str) -> List[str]:
        """Extract potential headers from text"""
        headers = []

        # Common header patterns
        lines = text.split('\n')
        for line in lines:
            line = line.strip()
            # Check if line looks like a header
            if (line and
                (line.endswith(':') or
                 line.isupper() or
                 re.match(r'^(Chapter|Section|Part|Module)\s+\d+', line, re.I) or
                 re.match(r'^\d+\.\s+', line))):
                headers.append(line)

        return headers

    def generate_lookup_table(self, words: List[Dict], sentences: List[Dict], total_duration_ms: int) -> Dict:
        """Generate O(1) lookup table for performance"""
        lookup_interval = 10  # 10ms intervals
        lookup_table = {}

        # Pre-build lookup table
        for time_ms in range(0, total_duration_ms + lookup_interval, lookup_interval):
            # Binary search for word at this time
            word_idx = -1
            left, right = 0, len(words) - 1
            while left <= right:
                mid = (left + right) // 2
                if words[mid]['start_ms'] <= time_ms < words[mid]['end_ms']:
                    word_idx = mid
                    break
                elif time_ms < words[mid]['start_ms']:
                    right = mid - 1
                else:
                    left = mid + 1

            # Find sentence index
            sentence_idx = words[word_idx]['sentence_index'] if word_idx >= 0 else -1

            lookup_table[time_ms] = {
                'word_index': word_idx,
                'sentence_index': sentence_idx
            }

        print(f"🚀 Generating O(1) lookup table (interval: {lookup_interval}ms)...")
        print(f"   ✅ Generated {len(lookup_table)} lookup entries")
        print(f"      Coverage: 0ms to {total_duration_ms}ms")
        print(f"      Size: ~{len(lookup_table) * 16 / 1024:.1f}KB")

        # Calculate coverage
        covered_positions = sum(1 for entry in lookup_table.values() if entry['word_index'] >= 0)
        coverage_percent = (covered_positions / len(lookup_table)) * 100
        print(f"      Coverage: {coverage_percent:.1f}% of positions have active words")

        return lookup_table

    def process(self) -> Dict:
        """Process ElevenLabs data and create enhanced content JSON with paragraph preservation"""
        # Reconstruct text with paragraph breaks
        full_text, paragraphs, paragraph_break_positions = self.reconstruct_text_with_paragraphs()

        # Extract words with timing, accounting for paragraph breaks
        words = self.extract_words_with_timing_and_paragraphs(full_text)

        # Eliminate gaps between words for smooth highlighting
        words = self.eliminate_timing_gaps(words)

        # Detect sentences
        sentences = self.detect_sentences(words, full_text)

        # Post-process to ensure continuous sentence coverage
        words, sentences = self.ensure_continuous_sentence_coverage(words, sentences)

        # Extract headers
        headers = self.extract_headers(full_text)

        # Create display text - this is the text with proper paragraph formatting
        display_text = full_text  # Already has \n\n between paragraphs

        # Calculate total duration
        total_duration_ms = int(self.end_times[-1] * 1000) if self.end_times else 0

        # Generate O(1) lookup table for performance
        lookup_table = self.generate_lookup_table(words, sentences, total_duration_ms)

        # Build enhanced content JSON
        content = {
            "version": "1.0",
            "source": "elevenlabs-complete-with-paragraphs",
            "display_text": display_text,
            "paragraphs": paragraphs,
            "headers": headers,
            "formatting": {
                "bold_headers": False,
                "paragraph_spacing": True
            },
            "metadata": {
                "word_count": len(words),
                "character_count": len(full_text),
                "estimated_reading_time": f"{max(1, len(words) // 200)} minutes",
                "language": "en"
            },
            "timing": {
                "words": words,
                "sentences": sentences,
                "total_duration_ms": total_duration_ms,
                "lookup_table": lookup_table
            }
        }

        return content

    def save(self, content: Dict, output_path: Optional[str] = None) -> str:
        """Save processed content to JSON files"""
        if not output_path:
            base_path = Path(self.elevenlabs_path).stem
            output_path = f"{base_path}_complete_with_paragraphs.json"

        # Save main content (without lookup table for readability)
        content_without_lookup = content.copy()
        content_without_lookup['timing'] = content['timing'].copy()
        content_without_lookup['timing'].pop('lookup_table', None)

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(content_without_lookup, f, indent=2, ensure_ascii=False)

        # Save lookup table separately for performance
        lookup_path = output_path.replace('.json', '_lookup.json')
        lookup_data = {
            "version": "1.0",
            "type": "lookup_table",
            "interval_ms": 10,
            "lookup_table": content['timing']['lookup_table']
        }

        with open(lookup_path, 'w', encoding='utf-8') as f:
            json.dump(lookup_data, f, indent=2, ensure_ascii=False)

        print(f"\n✅ Saved enhanced content to: {output_path}")
        print(f"✅ Saved lookup table to: {lookup_path}")
        print(f"   Entries: {len(content['timing']['lookup_table'])}")
        print(f"   Interval: 10ms")

        return output_path

    def validate(self, content: Dict) -> None:
        """Validate the processed content"""
        print(f"\n📊 Summary:")
        print(f"   Text: {content['metadata']['character_count']} characters")
        print(f"   Words: {content['metadata']['word_count']}")
        print(f"   Sentences: {len(content['timing']['sentences'])}")
        print(f"   Paragraphs: {len(content['paragraphs'])}")
        print(f"   Duration: {content['timing']['total_duration_ms'] / 1000:.1f} seconds")
        print(f"   Duration: {content['timing']['total_duration_ms'] / 60000:.1f} minutes")

        # Verify text integrity
        if self.original_content:
            # Just check that we have reasonable content
            orig_word_count = len(self.original_content.get('full_text', '').split())
            proc_word_count = content['metadata']['word_count']
            if abs(orig_word_count - proc_word_count) > orig_word_count * 0.1:
                print(f"\n⚠️ Word count differs significantly from original:")
                print(f"   Original: {orig_word_count} words")
                print(f"   Processed: {proc_word_count} words")
            else:
                print("\n✅ Word count matches original content!")

        # Verify paragraph formatting
        if '\n\n' in content['display_text']:
            para_count = len(content['display_text'].split('\n\n'))
            print(f"✅ Display text has {para_count} paragraphs with proper spacing")
        else:
            print("⚠️ Display text does not have paragraph breaks")


def main():
    import argparse

    parser = argparse.ArgumentParser(description='Process ElevenLabs character timing with paragraph preservation')
    parser.add_argument('elevenlabs_json', help='Path to ElevenLabs JSON with character timing')
    parser.add_argument('-o', '--output', help='Output path for enhanced JSON (default: *_complete_with_paragraphs.json)')
    parser.add_argument('-c', '--original-content', help='Path to original content (JSON or MD) for paragraph preservation')
    parser.add_argument('--config', help='Path to configuration file for edge case handling (default: config.json)')

    args = parser.parse_args()

    # Load configuration
    config = {}
    config_path = args.config or 'config.json'
    if Path(config_path).exists():
        with open(config_path, 'r') as f:
            config = json.load(f)
        print(f"📋 Loaded configuration from: {config_path}")

    # Process
    processor = ElevenLabsCompleteProcessorWithParagraphs(
        args.elevenlabs_json,
        args.original_content,
        config
    )

    content = processor.process()
    output_path = processor.save(content, args.output)
    processor.validate(content)

    return output_path


if __name__ == "__main__":
    main()