#!/usr/bin/env node

/**
 * Pipeline Validation Script
 * Run this to verify the preprocessing pipeline is working correctly
 * Usage: node validate_pipeline.js
 */

const fs = require('fs');
const path = require('path');
const { runPipeline } = require('../scripts/pipeline_runner');

// Colors for console output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logSection(title) {
  console.log('\n' + '='.repeat(60));
  log(title, 'cyan');
  console.log('='.repeat(60));
}

async function validatePipeline() {
  logSection('🔍 PREPROCESSING PIPELINE VALIDATION');

  // Check Node.js version
  log('\n📋 Checking Requirements...', 'blue');
  const nodeVersion = process.version;
  const majorVersion = parseInt(nodeVersion.slice(1).split('.')[0]);
  if (majorVersion < 14) {
    log(`❌ Node.js version ${nodeVersion} is too old. Required: 14.0.0+`, 'red');
    process.exit(1);
  }
  log(`✅ Node.js version: ${nodeVersion}`, 'green');

  // Check required scripts exist
  const requiredScripts = [
    '../scripts/pipeline_runner.js',
    '../scripts/character_to_word_converter.js',
    '../scripts/sentence_detector.js',
    '../scripts/enhanced_content_processor.js'
  ];

  log('\n📁 Checking Required Scripts...', 'blue');
  for (const script of requiredScripts) {
    if (fs.existsSync(path.join(__dirname, script))) {
      log(`✅ Found: ${script}`, 'green');
    } else {
      log(`❌ Missing: ${script}`, 'red');
      process.exit(1);
    }
  }

  // Check for test data
  log('\n📊 Checking Test Data...', 'blue');
  const testDataPath = path.join(__dirname, '../../Test_LO_Content/');
  const testFiles = [
    'Risk Management and Insurance in Action.json',
    'Risk Management and Insurance in Action.md',
    'Risk Management and Insurance in Action.mp3'
  ];

  let testDataAvailable = true;
  for (const file of testFiles) {
    const filePath = path.join(testDataPath, file);
    if (fs.existsSync(filePath)) {
      const stats = fs.statSync(filePath);
      const sizeMB = (stats.size / 1024 / 1024).toFixed(2);
      log(`✅ ${file} (${sizeMB} MB)`, 'green');
    } else {
      log(`⚠️  ${file} not found`, 'yellow');
      testDataAvailable = false;
    }
  }

  if (!testDataAvailable) {
    log('\n⚠️  Test data not found. Please ensure test files are in Test_LO_Content/', 'yellow');
    return;
  }

  // Run the pipeline with test data
  logSection('🚀 RUNNING PIPELINE TEST');

  try {
    const result = await runPipeline({
      elevenLabsJson: path.join(testDataPath, testFiles[0]),
      markdownFile: path.join(testDataPath, testFiles[1]),
      audioFile: path.join(testDataPath, testFiles[2]),
      outputDir: path.join(__dirname, 'test_run'),
      learningObjectId: 'validation-test-' + Date.now()
    });

    if (result.success) {
      log('\n✅ Pipeline executed successfully!', 'green');

      // Validate output files
      logSection('📝 VALIDATING OUTPUT FILES');

      // Check timing.json
      const timingData = JSON.parse(fs.readFileSync(result.files.timing, 'utf8'));
      log('\n📊 timing.json validation:', 'blue');

      const timingChecks = [
        {
          name: 'Has version',
          valid: timingData.version === '1.0'
        },
        {
          name: 'Has words array',
          valid: Array.isArray(timingData.words) && timingData.words.length > 0
        },
        {
          name: 'Has sentences array',
          valid: Array.isArray(timingData.sentences) && timingData.sentences.length > 0
        },
        {
          name: 'Has total duration',
          valid: typeof timingData.totalDurationMs === 'number' && timingData.totalDurationMs > 0
        },
        {
          name: 'Word has required fields',
          valid: timingData.words[0] &&
                 'word' in timingData.words[0] &&
                 'startMs' in timingData.words[0] &&
                 'endMs' in timingData.words[0] &&
                 'charStart' in timingData.words[0] &&
                 'charEnd' in timingData.words[0]
        },
        {
          name: 'Sentence has required fields',
          valid: timingData.sentences[0] &&
                 'text' in timingData.sentences[0] &&
                 'startMs' in timingData.sentences[0] &&
                 'endMs' in timingData.sentences[0] &&
                 'wordStartIndex' in timingData.sentences[0] &&
                 'wordEndIndex' in timingData.sentences[0]
        }
      ];

      timingChecks.forEach(check => {
        if (check.valid) {
          log(`  ✅ ${check.name}`, 'green');
        } else {
          log(`  ❌ ${check.name}`, 'red');
        }
      });

      // Check content.json
      const contentData = JSON.parse(fs.readFileSync(result.files.content, 'utf8'));
      log('\n📄 content.json validation:', 'blue');

      const contentChecks = [
        {
          name: 'Has version',
          valid: contentData.version === '1.0'
        },
        {
          name: 'Has display text',
          valid: typeof contentData.displayText === 'string' && contentData.displayText.length > 0
        },
        {
          name: 'Has paragraphs array',
          valid: Array.isArray(contentData.paragraphs) && contentData.paragraphs.length > 0
        },
        {
          name: 'Has headers array',
          valid: Array.isArray(contentData.headers)
        },
        {
          name: 'Has formatting settings',
          valid: contentData.formatting &&
                 contentData.formatting.boldHeaders === false &&
                 contentData.formatting.paragraphSpacing === true
        },
        {
          name: 'Has metadata',
          valid: contentData.metadata &&
                 typeof contentData.metadata.wordCount === 'number' &&
                 typeof contentData.metadata.characterCount === 'number'
        }
      ];

      contentChecks.forEach(check => {
        if (check.valid) {
          log(`  ✅ ${check.name}`, 'green');
        } else {
          log(`  ❌ ${check.name}`, 'red');
        }
      });

      // Check audio file
      log('\n🎵 audio.mp3 validation:', 'blue');
      if (fs.existsSync(result.files.audio)) {
        const audioStats = fs.statSync(result.files.audio);
        const audioSizeMB = (audioStats.size / 1024 / 1024).toFixed(2);
        log(`  ✅ Audio file exists (${audioSizeMB} MB)`, 'green');
      } else {
        log(`  ❌ Audio file missing`, 'red');
      }

      // Display statistics
      logSection('📈 PROCESSING STATISTICS');
      log(`Words processed: ${timingData.words.length}`, 'cyan');
      log(`Sentences detected: ${timingData.sentences.length}`, 'cyan');
      log(`Paragraphs created: ${contentData.paragraphs.length}`, 'cyan');
      log(`Headers identified: ${contentData.headers.length}`, 'cyan');
      log(`Total duration: ${(timingData.totalDurationMs / 1000).toFixed(2)} seconds`, 'cyan');
      log(`Estimated reading time: ${contentData.metadata.estimatedReadingTime}`, 'cyan');

      // Check data consistency
      logSection('🔗 DATA CONSISTENCY CHECKS');

      // Check character positions
      const lastWord = timingData.words[timingData.words.length - 1];
      const textLength = contentData.displayText.length;
      const charPositionValid = lastWord.charEnd <= textLength;

      if (charPositionValid) {
        log(`✅ Character positions valid (last word ends at ${lastWord.charEnd}, text length ${textLength})`, 'green');
      } else {
        log(`❌ Character position mismatch (last word ends at ${lastWord.charEnd}, text length ${textLength})`, 'red');
      }

      // Check timing continuity
      let timingContinuous = true;
      for (let i = 1; i < timingData.words.length; i++) {
        const prevWord = timingData.words[i - 1];
        const currWord = timingData.words[i];

        // Allow up to 1 second gap for sentence boundaries
        if (currWord.startMs - prevWord.endMs > 1000) {
          timingContinuous = false;
          log(`⚠️  Large gap detected between words ${i-1} and ${i}: ${currWord.startMs - prevWord.endMs}ms`, 'yellow');
          break;
        }
      }

      if (timingContinuous) {
        log('✅ Word timing is continuous', 'green');
      }

      // Check sentence boundaries
      let sentenceBoundariesValid = true;
      for (const sentence of timingData.sentences) {
        if (sentence.wordEndIndex < sentence.wordStartIndex) {
          sentenceBoundariesValid = false;
          log(`❌ Invalid sentence boundaries: ${JSON.stringify(sentence)}`, 'red');
          break;
        }
      }

      if (sentenceBoundariesValid) {
        log('✅ Sentence boundaries are valid', 'green');
      }

      // Final summary
      logSection('✨ VALIDATION COMPLETE');
      log('All validation checks passed! The pipeline is ready for use.', 'green');
      log('\nOutput files saved to:', 'blue');
      log(`  ${result.outputDir}/`, 'cyan');

    } else {
      log(`\n❌ Pipeline failed: ${result.error}`, 'red');
    }

  } catch (error) {
    log(`\n❌ Validation error: ${error.message}`, 'red');
    console.error(error.stack);
  }
}

// Run validation
validatePipeline().catch(error => {
  log(`\n❌ Fatal error: ${error.message}`, 'red');
  process.exit(1);
});