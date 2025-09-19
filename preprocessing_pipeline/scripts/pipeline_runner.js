#!/usr/bin/env node

/**
 * Complete Pipeline Runner
 * Combines all preprocessing steps to generate app-compatible JSON files
 */

const fs = require('fs');
const path = require('path');
const { processElevenLabsFile } = require('./character_to_word_converter');
const { detectSentences } = require('./sentence_detector');
const { processEnhancedContent } = require('./enhanced_content_processor');

/**
 * Generate final timing.json format compatible with app
 */
function generateTimingJson(words, sentences, totalDurationMs) {
  // Format words for app compatibility - using exact field names expected
  const formattedWords = words.map(word => ({
    word: word.word,
    startMs: word.startMs,
    endMs: word.endMs,
    sentenceIndex: word.sentenceIndex || 0,
    charStart: word.charStart,
    charEnd: word.charEnd
  }));

  // Format sentences for app compatibility - using exact field names expected
  const formattedSentences = sentences.map((sentence, index) => ({
    text: sentence.text,
    startMs: sentence.startMs,
    endMs: sentence.endMs,
    wordStartIndex: sentence.wordStartIndex,
    wordEndIndex: sentence.wordEndIndex
  }));

  return {
    version: '1.0',
    words: formattedWords,
    sentences: formattedSentences,
    totalDurationMs: Math.round(totalDurationMs)
  };
}

/**
 * Create output directory structure for learning object
 */
function createOutputStructure(outputDir, learningObjectId) {
  const loDir = path.join(outputDir, 'learning_objects', learningObjectId);

  if (!fs.existsSync(loDir)) {
    fs.mkdirSync(loDir, { recursive: true });
  }

  return loDir;
}

/**
 * Copy audio file to output directory
 */
function copyAudioFile(audioPath, outputDir) {
  const destPath = path.join(outputDir, 'audio.mp3');
  fs.copyFileSync(audioPath, destPath);
  console.log(`✓ Copied audio file to: ${destPath}`);
  return destPath;
}

/**
 * Main pipeline function
 */
async function runPipeline(options) {
  const {
    elevenLabsJson,
    markdownFile,
    audioFile,
    outputDir,
    learningObjectId,
    sentenceGapThreshold = 350
  } = options;

  console.log('\n===== Starting Preprocessing Pipeline =====\n');

  try {
    // Step 1: Read display text from Markdown
    console.log('Step 1: Reading Markdown file...');
    const displayText = fs.readFileSync(markdownFile, 'utf8');

    // Step 2: Process ElevenLabs character data to words
    console.log('\nStep 2: Converting characters to words...');
    const words = processElevenLabsFile(elevenLabsJson, displayText);
    console.log(`✓ Converted ${words.length} words`);

    // Step 3: Detect sentences
    console.log('\nStep 3: Detecting sentences...');
    const sentenceResult = detectSentences(words, { gapThreshold: sentenceGapThreshold });
    console.log(`✓ Detected ${sentenceResult.sentences.length} sentences`);

    // Step 4: Process content from Markdown with paragraph formatting
    console.log('\nStep 4: Processing content with paragraph formatting...');
    const content = processEnhancedContent(displayText);
    console.log(`✓ Processed content (${content.metadata.wordCount} words)`);
    console.log(`  - ${content.headers.length} section headers identified`);
    console.log(`  - ${content.paragraphs.length} paragraphs with proper spacing`);

    // Step 5: Generate timing.json
    console.log('\nStep 5: Generating timing.json...');
    const totalDurationMs = words[words.length - 1].endMs;
    const timingJson = generateTimingJson(
      sentenceResult.wordsWithSentences,
      sentenceResult.sentences,
      totalDurationMs
    );
    console.log(`✓ Generated timing data (${(totalDurationMs / 1000).toFixed(2)} seconds)`);

    // Step 6: Create output structure and save files
    console.log('\nStep 6: Saving output files...');
    const loOutputDir = createOutputStructure(outputDir, learningObjectId);

    // Save content.json
    const contentPath = path.join(loOutputDir, 'content.json');
    fs.writeFileSync(contentPath, JSON.stringify(content, null, 2));
    console.log(`✓ Saved content.json to: ${contentPath}`);

    // Save timing.json
    const timingPath = path.join(loOutputDir, 'timing.json');
    fs.writeFileSync(timingPath, JSON.stringify(timingJson, null, 2));
    console.log(`✓ Saved timing.json to: ${timingPath}`);

    // Copy audio file if provided
    if (audioFile && fs.existsSync(audioFile)) {
      copyAudioFile(audioFile, loOutputDir);
    }

    // Step 7: Validate output
    console.log('\nStep 7: Validating output...');

    // Check that all required files exist
    const requiredFiles = ['content.json', 'timing.json', 'audio.mp3'];
    const missingFiles = requiredFiles.filter(f =>
      !fs.existsSync(path.join(loOutputDir, f))
    );

    if (missingFiles.length > 0) {
      console.warn(`⚠ Warning: Missing files: ${missingFiles.join(', ')}`);
    } else {
      console.log('✓ All required files generated successfully');
    }

    // Display summary
    console.log('\n===== Pipeline Complete =====\n');
    console.log('Summary:');
    console.log(`  Learning Object ID: ${learningObjectId}`);
    console.log(`  Output Directory: ${loOutputDir}`);
    console.log(`  Total Words: ${words.length}`);
    console.log(`  Total Sentences: ${sentenceResult.sentences.length}`);
    console.log(`  Total Duration: ${(totalDurationMs / 1000).toFixed(2)} seconds`);
    console.log(`  Reading Time: ${content.metadata.estimatedReadingTime}`);

    console.log('\nGenerated files:');
    console.log(`  - content.json (${(fs.statSync(contentPath).size / 1024).toFixed(1)} KB)`);
    console.log(`  - timing.json (${(fs.statSync(timingPath).size / 1024).toFixed(1)} KB)`);
    if (fs.existsSync(path.join(loOutputDir, 'audio.mp3'))) {
      console.log(`  - audio.mp3 (${(fs.statSync(path.join(loOutputDir, 'audio.mp3')).size / 1024 / 1024).toFixed(1)} MB)`);
    }

    return {
      success: true,
      outputDir: loOutputDir,
      files: {
        content: contentPath,
        timing: timingPath,
        audio: path.join(loOutputDir, 'audio.mp3')
      }
    };

  } catch (error) {
    console.error('\n❌ Pipeline Error:', error.message);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * CLI interface
 */
function main() {
  const args = process.argv.slice(2);

  if (args.length < 3) {
    console.log('Usage: node pipeline_runner.js <elevenlabs.json> <markdown.md> <audio.mp3> [options]');
    console.log('\nOptions:');
    console.log('  --output-dir=<path>     Output directory (default: ./output/processed)');
    console.log('  --learning-object-id=<id>  Learning object ID (default: generated)');
    console.log('  --gap-threshold=<ms>    Sentence gap threshold in ms (default: 350)');
    console.log('\nExample:');
    console.log('  node pipeline_runner.js input.json content.md audio.mp3 --learning-object-id=63ad7b78');
    process.exit(1);
  }

  // Parse arguments
  const elevenLabsJson = args[0];
  const markdownFile = args[1];
  const audioFile = args[2];

  // Parse options
  let outputDir = 'preprocessing_pipeline/output/processed';
  let learningObjectId = '63ad7b78-0970-4265-a4fe-51f3fee39d5f'; // Default test ID
  let sentenceGapThreshold = 350;

  args.slice(3).forEach(arg => {
    if (arg.startsWith('--output-dir=')) {
      outputDir = arg.split('=')[1];
    } else if (arg.startsWith('--learning-object-id=')) {
      learningObjectId = arg.split('=')[1];
    } else if (arg.startsWith('--gap-threshold=')) {
      sentenceGapThreshold = parseInt(arg.split('=')[1]);
    }
  });

  // Verify input files exist
  if (!fs.existsSync(elevenLabsJson)) {
    console.error(`Error: ElevenLabs JSON file not found: ${elevenLabsJson}`);
    process.exit(1);
  }
  if (!fs.existsSync(markdownFile)) {
    console.error(`Error: Markdown file not found: ${markdownFile}`);
    process.exit(1);
  }
  if (!fs.existsSync(audioFile)) {
    console.error(`Error: Audio file not found: ${audioFile}`);
    process.exit(1);
  }

  // Run pipeline
  runPipeline({
    elevenLabsJson,
    markdownFile,
    audioFile,
    outputDir,
    learningObjectId,
    sentenceGapThreshold
  });
}

// Export for use in other scripts
module.exports = {
  runPipeline,
  generateTimingJson
};

// Run if called directly
if (require.main === module) {
  main();
}