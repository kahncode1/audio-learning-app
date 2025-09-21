#!/usr/bin/env python3
"""
Process ElevenLabs JSON with Original Text Support (v2)

This enhanced version uses ElevenLabs character positions to extract
properly punctuated text from the original content, while still using
ElevenLabs as the single source of truth for all timing data.
"""

import json
import re
from pathlib import Path
from typing import List, Dict, Tuple, Any, Optional


class ElevenLabsProcessorV2:
    """Enhanced processor that uses original text for accurate punctuation"""

    # Common abbreviations that don't end sentences
    ABBREVIATIONS = {
        'Mr.', 'Mrs.', 'Dr.', 'Ms.', 'Prof.', 'Sr.', 'Jr.',
        'Inc.', 'Corp.', 'Co.', 'Ltd.', 'LLC.', 'Ph.D.', 'M.D.',
        'B.A.', 'B.S.', 'M.A.', 'M.S.', 'U.S.', 'U.K.',
        'a.m.', 'p.m.', 'i.e.', 'e.g.', 'etc.', 'vs.'
    }

    def __init__(self, raw_json_path: str, original_content_path: str = None, output_dir: str = None):
        """
        Initialize processor with ElevenLabs data and optional original content

        Args:
            raw_json_path: Path to ElevenLabs raw_response.json
            original_content_path: Optional path to original content JSON
            output_dir: Optional output directory
        """
        self.raw_json_path = Path(raw_json_path)
        self.output_dir = Path(output_dir) if output_dir else self.raw_json_path.parent

        # Load ElevenLabs data
        with open(self.raw_json_path, 'r') as f:
            self.raw_data = json.load(f)

        # Extract speech marks
        self.speech_marks = self._extract_speech_marks()

        # Load original content if provided
        self.original_text = None
        self.original_paragraphs = None
        if original_content_path:
            with open(original_content_path, 'r') as f:
                original_data = json.load(f)
                self.original_text = original_data.get('full_text', '')
                self.original_paragraphs = original_data.get('paragraphs', [])
                print(f"📚 Loaded original content ({len(self.original_text)} characters)")

    def _extract_speech_marks(self) -> List[Dict]:
        """Extract and clean speech marks from raw data"""
        speech_marks = []

        if 'speech_marks' in self.raw_data:
            marks = self.raw_data['speech_marks']

            # Handle both dict format and nested structure
            if isinstance(marks, dict) and 'chunks' in marks:
                for chunk in marks['chunks']:
                    if chunk.get('type') == 'word':
                        speech_marks.append(chunk)
            elif isinstance(marks, list):
                speech_marks = [m for m in marks if m.get('type') == 'word']

        # Sort by character position
        return sorted(speech_marks, key=lambda x: x.get('start', 0))

    def reconstruct_text(self) -> str:
        """
        Reconstruct text using original if available, otherwise from speech marks

        Returns:
            Complete reconstructed text with proper punctuation
        """
        if self.original_text:
            # Use character positions to validate and extract from original
            return self._extract_from_original()
        else:
            # Fallback to basic reconstruction
            return self._basic_reconstruction()

    def _extract_from_original(self) -> str:
        """
        Extract text using ElevenLabs positions from original text

        Returns:
            Text with proper punctuation from original
        """
        if not self.speech_marks or not self.original_text:
            return ""

        reconstructed_parts = []
        last_end = 0

        for mark in self.speech_marks:
            char_start = mark.get('start', 0)
            char_end = mark.get('end', char_start)

            # Extract the exact text segment including punctuation
            if char_end <= len(self.original_text):
                # Check if we need to include text between words (spaces, punctuation)
                if char_start > last_end:
                    # Include the gap (spaces, punctuation) between words
                    gap_text = self.original_text[last_end:char_start]
                    reconstructed_parts.append(gap_text)

                # Extract the word itself with any attached punctuation
                word_with_punct = self.original_text[char_start:char_end]
                reconstructed_parts.append(word_with_punct)

                last_end = char_end

        # Add any remaining text after the last word
        if last_end < len(self.original_text):
            reconstructed_parts.append(self.original_text[last_end:])

        return ''.join(reconstructed_parts).strip()

    def _basic_reconstruction(self) -> str:
        """
        Basic text reconstruction when no original is available

        Returns:
            Basic reconstructed text without punctuation
        """
        if not self.speech_marks:
            return ""

        words = []
        for mark in self.speech_marks:
            word = mark.get('value', '')
            if word:
                words.append(word)

        return ' '.join(words)

    def extract_word_with_punctuation(self, mark: Dict) -> str:
        """
        Extract word with its associated punctuation from original text

        Args:
            mark: Speech mark dictionary

        Returns:
            Word with punctuation if available
        """
        if not self.original_text:
            return mark.get('value', '')

        char_start = mark.get('start', 0)
        char_end = mark.get('end', char_start)

        # Look ahead for punctuation
        extended_end = char_end
        while extended_end < len(self.original_text):
            next_char = self.original_text[extended_end]
            if next_char in '.,!?;:)"\']':
                extended_end += 1
            else:
                break

        return self.original_text[char_start:extended_end]

    def detect_sentences(self, text: str) -> None:
        """
        Enhanced sentence detection using original text patterns

        Args:
            text: The reconstructed text
        """
        sentence_index = 0

        for i, mark in enumerate(self.speech_marks):
            mark['sentence_index'] = sentence_index

            # Get word with punctuation
            word_with_punct = self.extract_word_with_punctuation(mark)

            # Check for sentence-ending punctuation
            ends_with_punct = bool(re.search(r'[.!?]$', word_with_punct))

            if ends_with_punct:
                # Check if it's an abbreviation
                if not any(word_with_punct.rstrip('.').endswith(abbr.rstrip('.'))
                          for abbr in self.ABBREVIATIONS):
                    # Additional checks
                    if i + 1 < len(self.speech_marks):
                        next_mark = self.speech_marks[i + 1]
                        time_gap = next_mark.get('start_time', 0) - mark.get('end_time', 0)

                        # Next word check
                        next_word = self.extract_word_with_punctuation(next_mark)
                        next_caps = next_word and next_word[0].isupper()

                        # Sentence break conditions
                        if time_gap > 350 or next_caps:
                            sentence_index += 1
                    else:
                        sentence_index += 1

            # Check for large timing gaps
            elif i + 1 < len(self.speech_marks):
                next_mark = self.speech_marks[i + 1]
                time_gap = next_mark.get('start_time', 0) - mark.get('end_time', 0)

                if time_gap > 500:
                    sentence_index += 1

    def detect_paragraphs(self, text: str) -> List[str]:
        """
        Enhanced paragraph detection using original structure if available

        Args:
            text: The reconstructed text

        Returns:
            List of paragraph strings
        """
        # Use original paragraphs if available
        if self.original_paragraphs:
            return self.original_paragraphs

        # Otherwise, use timing-based detection
        paragraphs = []
        current_paragraph_words = []
        last_end_time = 0

        for mark in self.speech_marks:
            start_time = mark.get('start_time', 0)

            # Large timing gap indicates paragraph break
            if last_end_time > 0 and (start_time - last_end_time) > 1000:
                if current_paragraph_words:
                    para_text = ' '.join(current_paragraph_words)
                    paragraphs.append(para_text.strip())
                    current_paragraph_words = []

            word_with_punct = self.extract_word_with_punctuation(mark)
            current_paragraph_words.append(word_with_punct)
            last_end_time = mark.get('end_time', start_time)

        # Add final paragraph
        if current_paragraph_words:
            para_text = ' '.join(current_paragraph_words)
            paragraphs.append(para_text.strip())

        return paragraphs if paragraphs else [text]

    def detect_headers(self, paragraphs: List[str]) -> List[str]:
        """
        Detect headers from paragraphs

        Args:
            paragraphs: List of paragraph strings

        Returns:
            List of detected headers
        """
        headers = []

        # Known section headers from the content
        known_headers = [
            "The Effect of Insurance",
            "Perception versus Reality",
            "Fueling Negative Perceptions",
            "What Do You Know?",
            "Making Citizens and Society More Resilient",
            "The Risk Consulting Role",
            "Assessing a Customer's Risks",
            'The Rise of "Predict and Prevent"',
            "Summary",
            "Glossary"
        ]

        for para in paragraphs:
            # Check against known headers
            for known_header in known_headers:
                if known_header in para:
                    headers.append(known_header)
                    break

            # Also check for short paragraphs that might be headers
            words = para.split()
            if len(words) <= 8:
                if (para.istitle() or
                    para.isupper() or
                    para.endswith(':') or
                    para.endswith('?')):
                    if para not in headers:
                        headers.append(para.rstrip(':'))

        return headers

    def generate_sentences_data(self, text: str) -> List[Dict]:
        """
        Generate sentence-level timing data

        Args:
            text: The reconstructed text

        Returns:
            List of sentence timing objects
        """
        sentences = []
        current_sentence_words = []
        current_sentence_index = -1

        for mark in self.speech_marks:
            sentence_index = mark.get('sentence_index', 0)

            # Start new sentence
            if sentence_index != current_sentence_index:
                # Save previous sentence
                if current_sentence_words:
                    # Build sentence text with punctuation
                    sentence_parts = []
                    for w in current_sentence_words:
                        word_with_punct = self.extract_word_with_punctuation(w)
                        sentence_parts.append(word_with_punct)

                    sentence_text = ' '.join(sentence_parts)

                    # Find character positions
                    char_start = text.find(sentence_text)
                    char_end = char_start + len(sentence_text) if char_start >= 0 else -1

                    sentences.append({
                        'text': sentence_text,
                        'startMs': current_sentence_words[0].get('start_time', 0),
                        'endMs': current_sentence_words[-1].get('end_time', 0),
                        'wordStartIndex': self.speech_marks.index(current_sentence_words[0]),
                        'wordEndIndex': self.speech_marks.index(current_sentence_words[-1]),
                        'charStart': char_start,
                        'charEnd': char_end
                    })

                current_sentence_words = []
                current_sentence_index = sentence_index

            current_sentence_words.append(mark)

        # Add final sentence
        if current_sentence_words:
            sentence_parts = []
            for w in current_sentence_words:
                word_with_punct = self.extract_word_with_punctuation(w)
                sentence_parts.append(word_with_punct)

            sentence_text = ' '.join(sentence_parts)
            char_start = text.find(sentence_text)
            char_end = char_start + len(sentence_text) if char_start >= 0 else -1

            sentences.append({
                'text': sentence_text,
                'startMs': current_sentence_words[0].get('start_time', 0),
                'endMs': current_sentence_words[-1].get('end_time', 0),
                'wordStartIndex': self.speech_marks.index(current_sentence_words[0]),
                'wordEndIndex': self.speech_marks.index(current_sentence_words[-1]),
                'charStart': char_start,
                'charEnd': char_end
            })

        return sentences

    def generate_words_data(self) -> List[Dict]:
        """
        Generate word-level timing data

        Returns:
            List of word timing objects
        """
        words = []

        for mark in self.speech_marks:
            # Use word with punctuation if original text is available
            display_word = self.extract_word_with_punctuation(mark)

            words.append({
                'word': display_word,
                'startMs': mark.get('start_time', 0),
                'endMs': mark.get('end_time', 0),
                'sentenceIndex': mark.get('sentence_index', 0),
                'charStart': mark.get('start', 0),
                'charEnd': mark.get('end', 0)
            })

        return words

    def calculate_metadata(self, text: str, words: List[Dict]) -> Dict:
        """
        Calculate metadata for the content

        Args:
            text: The full text
            words: Word timing data

        Returns:
            Metadata dictionary
        """
        word_count = len(words)
        char_count = len(text)

        # Estimate reading time
        reading_minutes = max(1, word_count // 200)

        if reading_minutes == 1:
            reading_time = "1 minute"
        else:
            reading_time = f"{reading_minutes} minutes"

        return {
            'wordCount': word_count,
            'characterCount': char_count,
            'estimatedReadingTime': reading_time,
            'language': 'en'
        }

    def process(self) -> Dict:
        """
        Main processing function

        Returns:
            Complete app-ready JSON structure
        """
        print("🎙️ Processing ElevenLabs content (v2)...")
        print(f"📄 ElevenLabs: {self.raw_json_path}")
        if self.original_text:
            print(f"📝 Using original text for punctuation")

        # Step 1: Reconstruct text
        print("📝 Reconstructing text...")
        full_text = self.reconstruct_text()
        print(f"   ✅ Reconstructed {len(full_text)} characters")

        # Step 2: Detect sentences
        print("🔍 Detecting sentence boundaries...")
        self.detect_sentences(full_text)
        max_sentence = max((m.get('sentence_index', 0) for m in self.speech_marks), default=0)
        print(f"   ✅ Found {max_sentence + 1} sentences")

        # Step 3: Detect paragraphs
        print("📄 Detecting paragraph structure...")
        paragraphs = self.detect_paragraphs(full_text)
        print(f"   ✅ Found {len(paragraphs)} paragraphs")

        # Step 4: Detect headers
        print("📌 Identifying headers...")
        headers = self.detect_headers(paragraphs)
        print(f"   ✅ Found {len(headers)} headers")

        # Step 5: Generate timing data
        print("⏱️ Generating timing data...")
        words = self.generate_words_data()
        sentences = self.generate_sentences_data(full_text)
        total_duration = max((w['endMs'] for w in words), default=0)
        print(f"   ✅ {len(words)} words, {len(sentences)} sentences")
        print(f"   ⏱️ Total duration: {total_duration/1000:.1f} seconds")

        # Step 6: Calculate metadata
        metadata = self.calculate_metadata(full_text, words)

        # Step 7: Build complete JSON structure
        app_json = {
            'version': '2.0',
            'source': 'elevenlabs_with_original',
            'displayText': full_text,
            'paragraphs': paragraphs,
            'headers': headers,
            'formatting': {
                'boldHeaders': len(headers) > 0,
                'paragraphSpacing': True
            },
            'metadata': metadata,
            'timing': {
                'words': words,
                'sentences': sentences,
                'totalDurationMs': total_duration
            }
        }

        return app_json

    def save(self, app_json: Dict, output_filename: str = 'content.json'):
        """
        Save processed JSON to file

        Args:
            app_json: The processed JSON data
            output_filename: Name of output file
        """
        output_path = self.output_dir / output_filename

        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(app_json, f, indent=2, ensure_ascii=False)

        print(f"\n✅ Saved to: {output_path}")

        # Show summary
        print("\n📊 Summary:")
        print(f"   Words: {app_json['metadata']['wordCount']}")
        print(f"   Characters: {app_json['metadata']['characterCount']}")
        print(f"   Paragraphs: {len(app_json['paragraphs'])}")
        print(f"   Headers: {len(app_json['headers'])}")
        print(f"   Sentences: {len(app_json['timing']['sentences'])}")
        print(f"   Duration: {app_json['timing']['totalDurationMs']/1000:.1f}s")
        print(f"   Reading time: {app_json['metadata']['estimatedReadingTime']}")


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Process ElevenLabs JSON with original text support'
    )
    parser.add_argument(
        'elevenlabs',
        help='Path to ElevenLabs raw_response.json'
    )
    parser.add_argument(
        '-c', '--content',
        help='Path to original content JSON (for proper punctuation)'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output directory'
    )
    parser.add_argument(
        '-f', '--filename',
        default='content.json',
        help='Output filename (default: content.json)'
    )

    args = parser.parse_args()

    # Process the content
    processor = ElevenLabsProcessorV2(
        args.elevenlabs,
        args.content,
        args.output
    )
    app_json = processor.process()
    processor.save(app_json, args.filename)


if __name__ == '__main__':
    import sys

    if len(sys.argv) == 1:
        # Default test processing
        elevenlabs_path = 'assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/raw_response.json'
        content_path = 'Test_LO_Content/original_content.json'

        if Path(elevenlabs_path).exists():
            print("🧪 Running enhanced test processing...")
            print("=" * 50)

            # Check if content file exists
            if Path(content_path).exists():
                processor = ElevenLabsProcessorV2(elevenlabs_path, content_path)
            else:
                print("⚠️ Original content not found, processing without punctuation")
                processor = ElevenLabsProcessorV2(elevenlabs_path)

            app_json = processor.process()
            processor.save(app_json, 'content_enhanced.json')
            print("\n🎉 Enhanced processing complete!")
        else:
            print("❌ Test files not found.")
            print("Usage: python process_elevenlabs_content_v2.py <elevenlabs.json> [-c content.json] [-o output_dir]")
    else:
        main()