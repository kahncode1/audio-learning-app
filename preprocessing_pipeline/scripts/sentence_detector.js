#!/usr/bin/env node

/**
 * Sentence Detector
 * Detects sentence boundaries using punctuation and timing gaps
 */

const fs = require('fs');

// Configuration
const SENTENCE_GAP_THRESHOLD_MS = 350; // Default threshold for sentence breaks
const SENTENCE_ENDINGS = ['.', '!', '?'];
const ABBREVIATIONS = [
  'Mr', 'Mrs', 'Dr', 'Prof', 'Inc', 'Corp', 'Ltd', 'Co',
  'Jr', 'Sr', 'Ph.D', 'M.D', 'B.A', 'M.A', 'B.S', 'M.S',
  'vs', 'etc', 'i.e', 'e.g', 'cf', 'al', 'St', 'Ave'
];

/**
 * Check if a word is likely an abbreviation
 */
function isAbbreviation(word) {
  // Remove the period from the word for checking
  const wordWithoutPeriod = word.replace(/\.$/, '');

  // Check if it's a known abbreviation
  if (ABBREVIATIONS.some(abbr => wordWithoutPeriod === abbr || wordWithoutPeriod === abbr.replace('.', ''))) {
    return true;
  }

  // Check for patterns that suggest abbreviation
  // Single capital letter followed by period (e.g., "A.")
  if (/^[A-Z]\.$/.test(word)) {
    return true;
  }

  // All caps with periods (e.g., "U.S.A.")
  if (/^[A-Z\.]+\.$/.test(word)) {
    return true;
  }

  return false;
}

/**
 * Check if a word ends with sentence-ending punctuation
 */
function hasSentenceEndingPunctuation(word) {
  return SENTENCE_ENDINGS.some(punct => word.endsWith(punct));
}

/**
 * Detect sentences from word array
 * @param {Array} words - Array of word objects with timing data
 * @param {Object} options - Configuration options
 * @returns {Array} Array of sentence objects
 */
function detectSentences(words, options = {}) {
  const gapThreshold = options.gapThreshold || SENTENCE_GAP_THRESHOLD_MS;
  const sentences = [];
  let currentSentence = null;
  let sentenceIndex = 0;

  console.log(`Detecting sentences from ${words.length} words (gap threshold: ${gapThreshold}ms)`);

  for (let i = 0; i < words.length; i++) {
    const word = words[i];

    // Start new sentence if needed
    if (!currentSentence) {
      currentSentence = {
        text: '',
        startMs: word.startMs,
        endMs: 0,
        wordStartIndex: i,
        wordEndIndex: i,
        charStart: word.charStart,
        charEnd: word.charEnd,
        sentenceIndex: sentenceIndex
      };
    }

    // Add word to sentence
    currentSentence.text += (currentSentence.text ? ' ' : '') + word.word;
    currentSentence.endMs = word.endMs;
    currentSentence.wordEndIndex = i;
    currentSentence.charEnd = word.charEnd;

    // Mark word with sentence index
    word.sentenceIndex = sentenceIndex;

    // Check for sentence boundary
    let shouldEndSentence = false;

    if (hasSentenceEndingPunctuation(word.word) && !isAbbreviation(word.word)) {
      // Has ending punctuation and is not an abbreviation

      if (i === words.length - 1) {
        // Last word - end sentence
        shouldEndSentence = true;
      } else {
        // Check timing gap to next word
        const nextWord = words[i + 1];
        const gap = nextWord.startMs - word.endMs;

        if (gap >= gapThreshold) {
          // Sufficient gap - end sentence
          shouldEndSentence = true;
        } else if (nextWord.word && /^[A-Z]/.test(nextWord.word)) {
          // Next word starts with capital letter - likely new sentence
          shouldEndSentence = true;
        }
      }
    }

    // Also check for very long gaps even without punctuation
    if (!shouldEndSentence && i < words.length - 1) {
      const nextWord = words[i + 1];
      const gap = nextWord.startMs - word.endMs;

      if (gap >= gapThreshold * 3) {
        // Very long gap (3x threshold) - probably a sentence boundary
        shouldEndSentence = true;
      }
    }

    if (shouldEndSentence) {
      // Save current sentence
      sentences.push({
        text: currentSentence.text,
        startMs: currentSentence.startMs,
        endMs: currentSentence.endMs,
        wordStartIndex: currentSentence.wordStartIndex,
        wordEndIndex: currentSentence.wordEndIndex,
        charStart: currentSentence.charStart,
        charEnd: currentSentence.charEnd
      });

      // Reset for next sentence
      currentSentence = null;
      sentenceIndex++;
    }
  }

  // Handle final sentence if not closed
  if (currentSentence && currentSentence.text) {
    sentences.push({
      text: currentSentence.text,
      startMs: currentSentence.startMs,
      endMs: currentSentence.endMs,
      wordStartIndex: currentSentence.wordStartIndex,
      wordEndIndex: currentSentence.wordEndIndex,
      charStart: currentSentence.charStart,
      charEnd: currentSentence.charEnd
    });
  }

  console.log(`Detected ${sentences.length} sentences`);
  return { sentences, wordsWithSentences: words };
}

/**
 * Main function for standalone execution
 */
function main() {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    console.log('Usage: node sentence_detector.js <words.json> [output.json] [--gap-threshold=350]');
    process.exit(1);
  }

  const inputPath = args[0];
  const outputPath = args[1] || 'sentences_output.json';

  // Parse options
  const options = {};
  args.forEach(arg => {
    if (arg.startsWith('--gap-threshold=')) {
      options.gapThreshold = parseInt(arg.split('=')[1]);
    }
  });

  try {
    // Read words data
    console.log(`Reading words file: ${inputPath}`);
    const data = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
    const words = data.words || data;

    // Detect sentences
    const result = detectSentences(words, options);

    // Log sample sentences
    console.log('\nFirst 3 sentences:');
    result.sentences.slice(0, 3).forEach((sentence, i) => {
      console.log(`  ${i + 1}. "${sentence.text.substring(0, 50)}${sentence.text.length > 50 ? '...' : ''}" (${sentence.wordEndIndex - sentence.wordStartIndex + 1} words)`);
    });

    console.log('\nLast 3 sentences:');
    result.sentences.slice(-3).forEach((sentence, i) => {
      console.log(`  ${result.sentences.length - 2 + i}. "${sentence.text.substring(0, 50)}${sentence.text.length > 50 ? '...' : ''}" (${sentence.wordEndIndex - sentence.wordStartIndex + 1} words)`);
    });

    // Save output
    const output = {
      sentences: result.sentences,
      wordsWithSentenceIndices: result.wordsWithSentences,
      totalSentences: result.sentences.length,
      totalWords: words.length
    };

    fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
    console.log(`\nOutput saved to: ${outputPath}`);
    console.log(`Total sentences: ${output.totalSentences}`);
    console.log(`Average words per sentence: ${(output.totalWords / output.totalSentences).toFixed(1)}`);

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// Export for use in other scripts
module.exports = {
  detectSentences,
  isAbbreviation
};

// Run if called directly
if (require.main === module) {
  main();
}