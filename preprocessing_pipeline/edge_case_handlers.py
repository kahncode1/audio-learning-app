"""
Edge Case Handlers for Audio Learning App Preprocessing Pipeline

This module provides comprehensive handling for various text formatting edge cases
during sentence detection and segmentation for synchronized highlighting.

Edge cases handled:
- Lists (numbered, bulleted, colon-introduced)
- Quotations and dialog
- Mathematical expressions and calculations
- Special punctuation (ellipses, em dashes)
- Abbreviations and titles
- URLs and email addresses
- Structural elements (headers, captions)
"""

import re
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass
from enum import Enum


class StructureType(Enum):
    """Types of special structures in text"""
    COLON_LIST = "colon_list"
    NUMBERED_LIST = "numbered_list"
    BULLETED_LIST = "bulleted_list"
    LETTERED_LIST = "lettered_list"
    QUOTATION = "quotation"
    DIALOG = "dialog"
    EQUATION = "equation"
    CODE_BLOCK = "code_block"
    HEADER = "header"
    URL = "url"
    EMAIL = "email"
    ABBREVIATION = "abbreviation"


@dataclass
class TextStructure:
    """Represents a special text structure"""
    type: StructureType
    start_pos: int
    end_pos: int
    content: str
    metadata: Dict = None


class EdgeCaseHandlers:
    """Handles edge cases in sentence detection"""

    def __init__(self, config: Dict = None):
        """
        Initialize edge case handlers with configuration

        Args:
            config: Configuration dictionary for customization
        """
        self.config = config or {}
        self.load_abbreviations()
        self.init_patterns()

    def load_abbreviations(self):
        """Load common abbreviations"""
        self.abbreviations = {
            'titles': {'Dr', 'Mr', 'Mrs', 'Ms', 'Prof', 'Sr', 'Jr', 'Rev', 'Gen', 'Col', 'Maj', 'Capt', 'Lt', 'Sgt'},
            'months': {'Jan', 'Feb', 'Mar', 'Apr', 'Jun', 'Jul', 'Aug', 'Sep', 'Sept', 'Oct', 'Nov', 'Dec'},
            'common': {'etc', 'vs', 'eg', 'ie', 'cf', 'al', 'Inc', 'Corp', 'Ltd', 'Co', 'LLC', 'Ph.D', 'M.D', 'B.A', 'M.A', 'B.S', 'M.S'},
            'time': {'a.m', 'p.m', 'A.M', 'P.M'},
            'locations': {'St', 'Ave', 'Rd', 'Blvd', 'Dr', 'Ct', 'Ln', 'Pkwy'},
            'units': {'ft', 'in', 'yd', 'mi', 'km', 'cm', 'mm', 'm', 'kg', 'g', 'lb', 'oz'},
            'countries': {'U.S', 'U.K', 'U.S.A', 'U.K'},
            'organizations': {'NATO', 'UN', 'EU', 'WHO', 'FBI', 'CIA', 'NASA', 'IRS'}
        }

        # Flatten all abbreviations into a single set for quick lookup
        self.all_abbreviations = set()
        for category in self.abbreviations.values():
            self.all_abbreviations.update(category)

    def init_patterns(self):
        """Initialize regex patterns for structure detection"""
        self.patterns = {
            # List patterns
            'colon_list_intro': re.compile(r'([^:]+:)\s*$'),
            'numbered_list': re.compile(r'^(\d+)[.)] '),
            'lettered_list': re.compile(r'^([a-z])[.)] ', re.IGNORECASE),
            'bulleted_list': re.compile(r'^[•·▪▫◦‣⁃\-*+] '),

            # Quotation patterns
            'quote_start': re.compile(r'["\'""'']'),
            'quote_end': re.compile(r'["\'""'']'),
            'dialog_marker': re.compile(r'^([A-Z][a-z]+):\s*["\']'),

            # Mathematical patterns
            'equation': re.compile(r'\b\d+\s*[+\-*/=<>≤≥≠]\s*\d+'),
            'percentage': re.compile(r'\d+\.?\d*%'),
            'ratio': re.compile(r'\d+:\d+'),
            'formula': re.compile(r'[A-Z]\s*=\s*[^.!?]+'),

            # Technical patterns
            'url': re.compile(r'https?://[^\s]+|www\.[^\s]+'),
            'email': re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
            'code_snippet': re.compile(r'(if|while|for|def|function|class)\s*\([^)]*\)\s*{?'),

            # Special punctuation
            'ellipsis': re.compile(r'\.{3,}'),
            'em_dash': re.compile(r'—|--'),
            'multiple_punct': re.compile(r'[!?]{2,}'),

            # Structural elements
            'header': re.compile(r'^(Chapter|Section|Part)\s+\d+[:.]\s*', re.IGNORECASE),
            'figure_caption': re.compile(r'^(Figure|Table|Chart|Graph)\s+\d+[:.]\s*', re.IGNORECASE),
        }

    def detect_structures(self, text: str) -> List[TextStructure]:
        """
        Detect all special structures in the text

        Args:
            text: The text to analyze

        Returns:
            List of detected structures
        """
        structures = []

        # Detect lists
        structures.extend(self.detect_lists(text))

        # Detect quotations
        structures.extend(self.detect_quotations(text))

        # Detect mathematical expressions
        structures.extend(self.detect_mathematical(text))

        # Detect URLs and emails
        structures.extend(self.detect_urls_emails(text))

        # Detect headers and captions
        structures.extend(self.detect_structural_elements(text))

        return structures

    def detect_lists(self, text: str) -> List[TextStructure]:
        """Detect various types of lists in text"""
        structures = []
        lines = text.split('\n')

        for i, line in enumerate(lines):
            # Check for colon-introduced list
            if i > 0 and lines[i-1].endswith(':'):
                # Check if current line starts with capital letter (potential list item)
                if line and line[0].isupper() and not line.endswith('.'):
                    start_pos = sum(len(l) + 1 for l in lines[:i])  # +1 for newlines
                    structures.append(TextStructure(
                        type=StructureType.COLON_LIST,
                        start_pos=start_pos,
                        end_pos=start_pos + len(line),
                        content=line
                    ))

            # Check for numbered list
            if self.patterns['numbered_list'].match(line):
                start_pos = sum(len(l) + 1 for l in lines[:i])
                structures.append(TextStructure(
                    type=StructureType.NUMBERED_LIST,
                    start_pos=start_pos,
                    end_pos=start_pos + len(line),
                    content=line
                ))

            # Check for bulleted list
            if self.patterns['bulleted_list'].match(line):
                start_pos = sum(len(l) + 1 for l in lines[:i])
                structures.append(TextStructure(
                    type=StructureType.BULLETED_LIST,
                    start_pos=start_pos,
                    end_pos=start_pos + len(line),
                    content=line
                ))

            # Check for lettered list
            if self.patterns['lettered_list'].match(line):
                start_pos = sum(len(l) + 1 for l in lines[:i])
                structures.append(TextStructure(
                    type=StructureType.LETTERED_LIST,
                    start_pos=start_pos,
                    end_pos=start_pos + len(line),
                    content=line
                ))

        return structures

    def detect_quotations(self, text: str) -> List[TextStructure]:
        """Detect quotations and dialog in text"""
        structures = []

        # Track quote pairs
        quote_stack = []
        for match in re.finditer(r'["\'""'']', text):
            quote_char = match.group()
            pos = match.start()

            if not quote_stack or quote_char in '["\'""':  # Opening quote
                quote_stack.append((quote_char, pos))
            else:  # Potential closing quote
                if quote_stack:
                    opening_char, start_pos = quote_stack.pop()
                    content = text[start_pos:match.end()]
                    structures.append(TextStructure(
                        type=StructureType.QUOTATION,
                        start_pos=start_pos,
                        end_pos=match.end(),
                        content=content
                    ))

        # Detect dialog markers
        for match in self.patterns['dialog_marker'].finditer(text):
            structures.append(TextStructure(
                type=StructureType.DIALOG,
                start_pos=match.start(),
                end_pos=match.end(),
                content=match.group(),
                metadata={'speaker': match.group(1)}
            ))

        return structures

    def detect_mathematical(self, text: str) -> List[TextStructure]:
        """Detect mathematical expressions and calculations"""
        structures = []

        # Detect equations
        for match in self.patterns['equation'].finditer(text):
            structures.append(TextStructure(
                type=StructureType.EQUATION,
                start_pos=match.start(),
                end_pos=match.end(),
                content=match.group()
            ))

        # Detect formulas
        for match in self.patterns['formula'].finditer(text):
            structures.append(TextStructure(
                type=StructureType.EQUATION,
                start_pos=match.start(),
                end_pos=match.end(),
                content=match.group()
            ))

        return structures

    def detect_urls_emails(self, text: str) -> List[TextStructure]:
        """Detect URLs and email addresses"""
        structures = []

        # Detect URLs
        for match in self.patterns['url'].finditer(text):
            structures.append(TextStructure(
                type=StructureType.URL,
                start_pos=match.start(),
                end_pos=match.end(),
                content=match.group()
            ))

        # Detect emails
        for match in self.patterns['email'].finditer(text):
            structures.append(TextStructure(
                type=StructureType.EMAIL,
                start_pos=match.start(),
                end_pos=match.end(),
                content=match.group()
            ))

        return structures

    def detect_structural_elements(self, text: str) -> List[TextStructure]:
        """Detect headers, captions, and other structural elements"""
        structures = []

        # Detect headers
        for match in self.patterns['header'].finditer(text):
            structures.append(TextStructure(
                type=StructureType.HEADER,
                start_pos=match.start(),
                end_pos=match.end(),
                content=match.group()
            ))

        # Detect figure/table captions
        for match in self.patterns['figure_caption'].finditer(text):
            structures.append(TextStructure(
                type=StructureType.HEADER,
                start_pos=match.start(),
                end_pos=match.end(),
                content=match.group()
            ))

        return structures

    def is_abbreviation(self, word: str, next_word: str = None) -> bool:
        """
        Check if a word ending with period is an abbreviation

        Args:
            word: The word to check
            next_word: The following word for context

        Returns:
            True if it's likely an abbreviation
        """
        if not word.endswith('.'):
            return False

        # Remove the period for checking
        word_without_period = word[:-1]

        # Check if it's in our abbreviation list
        if word_without_period in self.all_abbreviations:
            return True

        # Check for patterns like "U.S.A."
        if re.match(r'^[A-Z](\.[A-Z])+$', word):
            return True

        # Check if next word starts with lowercase (likely continuation)
        if next_word and next_word[0].islower():
            return True

        # Check if it's a single capital letter with period
        if len(word_without_period) == 1 and word_without_period.isupper():
            return True

        return False

    def should_break_at_colon(self, text: str, colon_pos: int) -> bool:
        """
        Determine if a colon should trigger a sentence break

        Args:
            text: The full text
            colon_pos: Position of the colon

        Returns:
            True if sentence should break at colon
        """
        # Check if it's followed by a list
        after_colon = text[colon_pos + 1:].strip()

        # If next content starts with capital letter or number, might be a list
        if after_colon and (after_colon[0].isupper() or after_colon[0].isdigit()):
            # Look for list patterns
            if '\n' in after_colon[:100]:  # Check first 100 chars for newline
                return True

            # Check for inline list (multiple capitalized words)
            words = after_colon.split()[:10]  # Check first 10 words
            cap_words = sum(1 for w in words if w and w[0].isupper())
            if cap_words > 3:  # Multiple capitalized words suggest a list
                return True

        # Check if it's a ratio (don't break)
        if colon_pos > 0 and colon_pos < len(text) - 1:
            if text[colon_pos - 1].isdigit() and text[colon_pos + 1].isdigit():
                return False

        # Check if it's in a time format (don't break)
        time_pattern = re.compile(r'\d{1,2}:\d{2}')
        if time_pattern.match(text[max(0, colon_pos - 2):colon_pos + 3]):
            return False

        return False

    def should_break_at_semicolon(self, text: str, semicolon_pos: int) -> bool:
        """
        Determine if a semicolon should trigger a sentence break

        Args:
            text: The full text
            semicolon_pos: Position of the semicolon

        Returns:
            True if sentence should break at semicolon
        """
        # Generally treat semicolons as sentence boundaries for highlighting
        # unless in special contexts

        # Check if it's within a code snippet
        if self.is_within_code(text, semicolon_pos):
            return False

        # Check if it's within a quotation
        if self.is_within_quotes(text, semicolon_pos):
            return False

        # Default to breaking at semicolon for clearer highlighting
        return True

    def is_within_code(self, text: str, position: int) -> bool:
        """Check if position is within a code snippet"""
        # Simple heuristic: look for code patterns nearby
        context_start = max(0, position - 50)
        context_end = min(len(text), position + 50)
        context = text[context_start:context_end]

        return bool(self.patterns['code_snippet'].search(context))

    def is_within_quotes(self, text: str, position: int) -> bool:
        """Check if position is within quotation marks"""
        # Count quotes before position
        before_text = text[:position]
        quote_count = before_text.count('"') + before_text.count("'")

        # Odd count means we're inside quotes
        return quote_count % 2 == 1

    def split_list_items(self, text: str, structures: List[TextStructure]) -> List[Tuple[str, int, int]]:
        """
        Split text containing lists into individual items

        Args:
            text: The text to split
            structures: Detected structures

        Returns:
            List of (text, start_pos, end_pos) tuples
        """
        segments = []
        last_pos = 0

        for structure in sorted(structures, key=lambda s: s.start_pos):
            if structure.type in [StructureType.COLON_LIST, StructureType.NUMBERED_LIST,
                                  StructureType.BULLETED_LIST, StructureType.LETTERED_LIST]:
                # Add text before list item
                if last_pos < structure.start_pos:
                    segments.append((
                        text[last_pos:structure.start_pos],
                        last_pos,
                        structure.start_pos
                    ))

                # Add list item as separate segment
                segments.append((
                    structure.content,
                    structure.start_pos,
                    structure.end_pos
                ))

                last_pos = structure.end_pos

        # Add remaining text
        if last_pos < len(text):
            segments.append((
                text[last_pos:],
                last_pos,
                len(text)
            ))

        return segments

    def apply_enhanced_sentence_detection(self, words: List[Dict], text: str,
                                         structures: List[TextStructure]) -> List[Dict]:
        """
        Apply enhanced sentence detection considering all edge cases

        Args:
            words: List of word dictionaries with timing
            text: The full text
            structures: Detected special structures

        Returns:
            List of sentence dictionaries
        """
        sentences = []
        current_sentence_words = []
        current_sentence_start = 0
        sentence_index = 0

        # Create structure position lookup for efficiency
        structure_map = {}
        for struct in structures:
            for pos in range(struct.start_pos, struct.end_pos):
                structure_map[pos] = struct

        i = 0
        while i < len(words):
            word = words[i]
            current_sentence_words.append(word)
            word['sentence_index'] = sentence_index

            # Check if we should break sentence after this word
            should_break = False
            break_reason = None

            word_text = word['word']
            word_end_pos = word.get('char_end', 0)

            # Get next word for context
            next_word = words[i + 1]['word'] if i + 1 < len(words) else None

            # Check for sentence-ending punctuation
            if word_text.endswith('.'):
                if not self.is_abbreviation(word_text, next_word):
                    should_break = True
                    break_reason = "period"
            elif word_text.endswith('!') or word_text.endswith('?'):
                if not self.patterns['multiple_punct'].search(word_text):
                    should_break = True
                    break_reason = "exclamation/question"
            elif word_text.endswith(':'):
                if self.should_break_at_colon(text, word_end_pos - 1):
                    should_break = True
                    break_reason = "colon_list"
            elif word_text.endswith(';'):
                if self.should_break_at_semicolon(text, word_end_pos - 1):
                    should_break = True
                    break_reason = "semicolon"

            # Check if we're at a structure boundary
            if word_end_pos in structure_map:
                struct = structure_map[word_end_pos]
                if struct.type in [StructureType.COLON_LIST, StructureType.NUMBERED_LIST,
                                   StructureType.BULLETED_LIST, StructureType.LETTERED_LIST]:
                    should_break = True
                    break_reason = f"list_{struct.type.value}"

            if should_break and current_sentence_words:
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
                    'char_end': word['char_end'],
                    'break_reason': break_reason  # For debugging
                })

                # Reset for next sentence
                current_sentence_words = []
                current_sentence_start = word['char_end'] + 1
                sentence_index += 1

            i += 1

        # Add remaining words as final sentence
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
                'char_end': len(text) - 1,
                'break_reason': 'end_of_text'
            })

        return sentences