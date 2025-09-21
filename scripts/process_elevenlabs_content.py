#!/usr/bin/env python3
"""
Process ElevenLabs JSON to generate app-ready content JSON

This script takes the raw JSON response from ElevenLabs containing character-level
timing data and generates a single comprehensive JSON file with display text,
timing information, and content structure for the app.
"""

import json
import re
from pathlib import Path
from typing import List, Dict, Tuple, Any


class ElevenLabsProcessor:
    """Process ElevenLabs JSON data into app-ready format"""

    # Common abbreviations that don't end sentences
    ABBREVIATIONS = {
        'Mr.', 'Mrs.', 'Dr.', 'Ms.', 'Prof.', 'Sr.', 'Jr.',
        'Inc.', 'Corp.', 'Co.', 'Ltd.', 'LLC.', 'Ph.D.', 'M.D.',
        'B.A.', 'B.S.', 'M.A.', 'M.S.', 'U.S.', 'U.K.',
        'a.m.', 'p.m.', 'i.e.', 'e.g.', 'etc.', 'vs.'
    }

    def __init__(self, raw_json_path: str, output_dir: str = None):
        """
        Initialize processor with paths

        Args:
            raw_json_path: Path to ElevenLabs raw_response.json
            output_dir: Optional output directory (defaults to same as input)
        """
        self.raw_json_path = Path(raw_json_path)
        self.output_dir = Path(output_dir) if output_dir else self.raw_json_path.parent

        # Load raw data
        with open(self.raw_json_path, 'r') as f:
            self.raw_data = json.load(f)

        # Extract speech marks
        self.speech_marks = self._extract_speech_marks()

    def _extract_speech_marks(self) -> List[Dict]:
        """Extract and clean speech marks from raw data"""
        speech_marks = []

        if 'speech_marks' in self.raw_data:
            marks = self.raw_data['speech_marks']

            # Handle both dict format and nested structure
            if isinstance(marks, dict) and 'chunks' in marks:
                # Extract from chunks structure
                for chunk in marks['chunks']:
                    if chunk.get('type') == 'word':
                        speech_marks.append(chunk)
            elif isinstance(marks, list):
                # Direct list of speech marks
                speech_marks = [m for m in marks if m.get('type') == 'word']

        # Sort by character position for proper reconstruction
        return sorted(speech_marks, key=lambda x: x.get('start', 0))

    def reconstruct_text(self) -> str:
        """
        Reconstruct original text from character positions

        Returns:
            Complete reconstructed text
        """
        if not self.speech_marks:
            return ""

        # Find max character position
        max_pos = max(mark.get('end', 0) for mark in self.speech_marks)

        # Create character array
        text_array = [' '] * (max_pos + 1)

        # Fill in words at their character positions
        for mark in self.speech_marks:
            start = mark.get('start', 0)
            end = mark.get('end', start)
            word = mark.get('value', '')

            # Place each character of the word
            for i, char in enumerate(word):
                if start + i <= end:
                    text_array[start + i] = char

        # Convert array to string and clean up
        text = ''.join(text_array)

        # Clean up multiple spaces
        text = re.sub(r'\s+', ' ', text)

        # Fix spacing around punctuation
        text = re.sub(r'\s+([.,!?;:])', r'\1', text)
        text = re.sub(r'([.,!?;:])\s*', r'\1 ', text)

        return text.strip()

    def detect_sentences(self, text: str) -> None:
        """
        Detect sentence boundaries and add sentence indices to speech marks

        Args:
            text: The reconstructed text for reference
        """
        sentence_index = 0

        for i, mark in enumerate(self.speech_marks):
            # Assign current sentence index
            mark['sentence_index'] = sentence_index

            # Check if this word ends a sentence
            word = mark.get('value', '')

            # Check for sentence-ending punctuation
            ends_with_punct = bool(re.search(r'[.!?]$', word))

            if ends_with_punct:
                # Check if it's an abbreviation
                if not any(word.endswith(abbr.rstrip('.')) for abbr in self.ABBREVIATIONS):
                    # Check timing gap to next word
                    if i + 1 < len(self.speech_marks):
                        next_mark = self.speech_marks[i + 1]
                        time_gap = next_mark.get('start_time', 0) - mark.get('end_time', 0)

                        # Check next word capitalization
                        next_word = next_mark.get('value', '')
                        next_caps = next_word and next_word[0].isupper()

                        # Sentence break if timing gap > 350ms or next word is capitalized
                        if time_gap > 350 or next_caps:
                            sentence_index += 1
                    else:
                        # Last word in text
                        sentence_index += 1

            # Also check for large timing gaps without punctuation
            elif i + 1 < len(self.speech_marks):
                next_mark = self.speech_marks[i + 1]
                time_gap = next_mark.get('start_time', 0) - mark.get('end_time', 0)

                # Very large gap (>500ms) suggests sentence break
                if time_gap > 500:
                    sentence_index += 1

    def detect_paragraphs(self, text: str) -> List[str]:
        """
        Detect paragraph boundaries based on timing and content

        Args:
            text: The reconstructed text

        Returns:
            List of paragraph strings
        """
        paragraphs = []
        current_paragraph_words = []
        last_end_time = 0

        for mark in self.speech_marks:
            start_time = mark.get('start_time', 0)

            # Check for large timing gap indicating paragraph break
            if last_end_time > 0 and (start_time - last_end_time) > 1000:
                # Save current paragraph if not empty
                if current_paragraph_words:
                    para_text = ' '.join(current_paragraph_words)
                    paragraphs.append(para_text)
                    current_paragraph_words = []

            current_paragraph_words.append(mark.get('value', ''))
            last_end_time = mark.get('end_time', start_time)

        # Add final paragraph
        if current_paragraph_words:
            para_text = ' '.join(current_paragraph_words)
            paragraphs.append(para_text)

        # Clean up paragraphs
        cleaned_paragraphs = []
        for para in paragraphs:
            # Clean spacing
            para = re.sub(r'\s+', ' ', para)
            para = re.sub(r'\s+([.,!?;:])', r'\1', para)
            para = para.strip()

            if para:
                cleaned_paragraphs.append(para)

        return cleaned_paragraphs if cleaned_paragraphs else [text]

    def detect_headers(self, paragraphs: List[str]) -> List[str]:
        """
        Detect potential headers from paragraphs

        Args:
            paragraphs: List of paragraph strings

        Returns:
            List of detected headers
        """
        headers = []

        for para in paragraphs:
            words = para.split()

            # Short paragraphs might be headers
            if len(words) <= 8:
                # Check for title case or all caps
                if para.istitle() or para.isupper():
                    headers.append(para)
                # Check for question headers
                elif para.endswith('?'):
                    headers.append(para)
                # Check for colon-ending headers
                elif para.endswith(':'):
                    headers.append(para.rstrip(':'))
                # Check for numbered headers
                elif re.match(r'^\d+\.?\s+', para):
                    headers.append(para)

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
                    sentence_text = ' '.join([w.get('value', '') for w in current_sentence_words])

                    # Find character positions in full text
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
            sentence_text = ' '.join([w.get('value', '') for w in current_sentence_words])
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
        Generate word-level timing data for app

        Returns:
            List of word timing objects
        """
        words = []

        for mark in self.speech_marks:
            words.append({
                'word': mark.get('value', ''),
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

        # Estimate reading time (200 words per minute)
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
        print("🎙️ Processing ElevenLabs content...")
        print(f"📄 Input: {self.raw_json_path}")

        # Step 1: Reconstruct text
        print("📝 Reconstructing original text from character positions...")
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
            'version': '1.0',
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
        description='Process ElevenLabs JSON to app-ready format'
    )
    parser.add_argument(
        'input',
        help='Path to ElevenLabs raw_response.json file'
    )
    parser.add_argument(
        '-o', '--output',
        help='Output directory (defaults to input directory)'
    )
    parser.add_argument(
        '-f', '--filename',
        default='content.json',
        help='Output filename (default: content.json)'
    )

    args = parser.parse_args()

    # Process the content
    processor = ElevenLabsProcessor(args.input, args.output)
    app_json = processor.process()
    processor.save(app_json, args.filename)


if __name__ == '__main__':
    # If no arguments, process test data
    import sys

    if len(sys.argv) == 1:
        # Default test processing
        test_input = 'assets/test_content/learning_objects/63ad7b78-0970-4265-a4fe-51f3fee39d5f/raw_response.json'

        if Path(test_input).exists():
            print("🧪 Running test processing...")
            print("=" * 50)
            processor = ElevenLabsProcessor(test_input)
            app_json = processor.process()
            processor.save(app_json, 'content_new.json')
            print("\n🎉 Test processing complete!")
        else:
            print("❌ Test file not found. Please provide input file path.")
            print("Usage: python process_elevenlabs_content.py <input_json> [-o output_dir]")
    else:
        main()