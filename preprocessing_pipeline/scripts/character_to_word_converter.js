#!/usr/bin/env node

/**
 * Character to Word Converter
 * Transforms ElevenLabs character timing data into word-level timing data
 */

const fs = require('fs');
const path = require('path');

/**
 * Check if a character is whitespace
 */
function isWhitespace(char) {
  return char === ' ' || char === '\t' || char === '\n' || char === '\r';
}

/**
 * Convert character-level timings to word-level timings
 * @param {Array<string>} characters - Array of individual characters
 * @param {Array<number>} timings - Array of character start times in seconds
 * @param {string} displayText - The original text for character position mapping
 * @returns {Array} Array of word timing objects
 */
function convertCharactersToWords(characters, timings, displayText) {
  const words = [];
  let currentWord = '';
  let wordStartTime = 0;
  let wordStartCharIndex = 0;
  let displayTextIndex = 0;

  console.log(`Processing ${characters.length} characters...`);

  for (let i = 0; i < characters.length; i++) {
    const char = characters[i];
    const time = timings[i] * 1000; // Convert to milliseconds

    if (isWhitespace(char)) {
      // End current word if it exists
      if (currentWord.length > 0) {
        // Calculate end time: use current time or next non-whitespace char time
        let endTime = time;
        // Look ahead for next non-whitespace character
        for (let j = i + 1; j < characters.length; j++) {
          if (!isWhitespace(characters[j])) {
            endTime = timings[j] * 1000;
            break;
          }
        }

        words.push({
          word: currentWord,
          startMs: Math.round(wordStartTime),
          endMs: Math.round(endTime),
          charStart: wordStartCharIndex,
          charEnd: wordStartCharIndex + currentWord.length
        });

        // Update display text index
        displayTextIndex = wordStartCharIndex + currentWord.length;
        currentWord = '';
      }

      // Skip whitespace and update display text index
      displayTextIndex++;

      // Find next non-whitespace character for next word start
      while (i + 1 < characters.length && isWhitespace(characters[i + 1])) {
        i++;
        displayTextIndex++;
      }

      if (i + 1 < characters.length) {
        wordStartTime = timings[i + 1] * 1000;
        wordStartCharIndex = displayTextIndex;
      }
    } else {
      // Add character to current word
      if (currentWord.length === 0) {
        wordStartTime = time;
        wordStartCharIndex = displayTextIndex;
      }
      currentWord += char;
    }
  }

  // Handle final word
  if (currentWord.length > 0) {
    words.push({
      word: currentWord,
      startMs: Math.round(wordStartTime),
      endMs: Math.round(timings[timings.length - 1] * 1000 + 500), // Add 500ms buffer for last word
      charStart: wordStartCharIndex,
      charEnd: wordStartCharIndex + currentWord.length
    });
  }

  console.log(`Converted to ${words.length} words`);
  return words;
}

/**
 * Process ElevenLabs JSON file
 */
function processElevenLabsFile(inputPath, displayText) {
  console.log(`Reading ElevenLabs file: ${inputPath}`);

  const data = JSON.parse(fs.readFileSync(inputPath, 'utf8'));

  if (!data.alignment) {
    throw new Error('No alignment data found in input file');
  }

  const { characters, character_start_times_seconds } = data.alignment;

  if (!characters || !character_start_times_seconds) {
    throw new Error('Missing required alignment data');
  }

  console.log(`Found ${characters.length} characters with timing data`);

  const words = convertCharactersToWords(
    characters,
    character_start_times_seconds,
    displayText
  );

  // Validate and log some sample words
  console.log('\nFirst 5 words:');
  words.slice(0, 5).forEach(word => {
    console.log(`  "${word.word}" - ${word.startMs}ms to ${word.endMs}ms (chars ${word.charStart}-${word.charEnd})`);
  });

  console.log('\nLast 5 words:');
  words.slice(-5).forEach(word => {
    console.log(`  "${word.word}" - ${word.startMs}ms to ${word.endMs}ms (chars ${word.charStart}-${word.charEnd})`);
  });

  return words;
}

/**
 * Main function for standalone execution
 */
function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    console.log('Usage: node character_to_word_converter.js <elevenlabs.json> <text.md> [output.json]');
    process.exit(1);
  }

  const inputPath = args[0];
  const textPath = args[1];
  const outputPath = args[2] || 'words_output.json';

  try {
    // Read the display text (we'll need this for proper character position mapping)
    console.log(`Reading text file: ${textPath}`);
    const displayText = fs.readFileSync(textPath, 'utf8');

    // Process the ElevenLabs file
    const words = processElevenLabsFile(inputPath, displayText);

    // Save output
    const output = {
      words: words,
      totalWords: words.length,
      totalDurationMs: words[words.length - 1].endMs
    };

    fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));
    console.log(`\nOutput saved to: ${outputPath}`);
    console.log(`Total words: ${output.totalWords}`);
    console.log(`Total duration: ${(output.totalDurationMs / 1000).toFixed(2)} seconds`);

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// Export for use in other scripts
module.exports = {
  convertCharactersToWords,
  processElevenLabsFile
};

// Run if called directly
if (require.main === module) {
  main();
}