#!/usr/bin/env node

/**
 * Enhanced Content Processor
 * Converts Markdown text to structured content with proper paragraph spacing
 * Adds visual breaks between paragraphs for better readability
 */

const fs = require('fs');

/**
 * Identify headers and section titles in the text
 * These will be marked for bold display
 */
function identifyHeaders(lines) {
  const headers = [];
  const headerPatterns = [
    // Common section headers in our content
    /^(The Effect of .+)$/,
    /^(Perception versus Reality)$/,
    /^(Fueling Negative Perceptions)$/,
    /^(What Do You Know\?)$/,
    /^(Making Citizens and Society More Resilient)$/,
    /^(The Risk Consulting Role)$/,
    /^(Assessing a Customer's Risks)$/,
    /^(The Rise of .+)$/,
    /^(Summary)$/,
    /^(Glossary)$/,
    // Generic patterns
    /^([A-Z][A-Za-z\s]+)$/, // Line starting with capital, likely a header
  ];

  lines.forEach((line, index) => {
    const trimmedLine = line.trim();

    // Check if this line matches any header pattern
    for (const pattern of headerPatterns) {
      if (pattern.test(trimmedLine)) {
        // Check context - headers usually have blank lines around them or are at the start
        const prevLine = index > 0 ? lines[index - 1].trim() : '';
        const nextLine = index < lines.length - 1 ? lines[index + 1].trim() : '';

        // Headers typically have blank lines before or after, or are short standalone lines
        if ((!prevLine || !nextLine) || trimmedLine.length < 50) {
          headers.push({
            text: trimmedLine,
            lineIndex: index,
            charStart: null, // Will be calculated later
            charEnd: null
          });
          break;
        }
      }
    }
  });

  return headers;
}

/**
 * Format text with proper paragraph breaks
 * Adds double newlines between paragraphs for visual spacing
 */
function formatTextWithParagraphs(text) {
  const lines = text.split('\n');
  const formattedLines = [];
  const headers = identifyHeaders(lines);
  const headerTexts = new Set(headers.map(h => h.text));

  let inList = false;
  let previousWasHeader = false;
  let previousWasEmpty = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    const isHeader = headerTexts.has(line);
    const isBulletPoint = /^[•\-*]\s/.test(line) || /^(Telematics|Wearables|IoT|Smartphones|Cloud|Predictive|Artificial)/.test(line);

    // Skip truly empty lines in our logic
    if (!line) {
      previousWasEmpty = true;
      continue;
    }

    // Add spacing before headers (if not at the start)
    if (isHeader && formattedLines.length > 0 && !previousWasEmpty) {
      formattedLines.push(''); // Add blank line before header
    }

    // Add the header without markers (just like regular text)
    if (isHeader) {
      formattedLines.push(line); // No bold markers, just the text
      previousWasHeader = true;
      previousWasEmpty = false;
      continue;
    }

    // Handle list items
    if (isBulletPoint) {
      if (!inList && formattedLines.length > 0) {
        formattedLines.push(''); // Add blank line before list
      }
      formattedLines.push(line);
      inList = true;
      previousWasHeader = false;
      previousWasEmpty = false;
      continue;
    }

    // Regular paragraph
    if (inList) {
      formattedLines.push(''); // Add blank line after list
      inList = false;
    }

    // Check if this starts a new paragraph
    const nextLine = i < lines.length - 1 ? lines[i + 1].trim() : '';
    const isEndOfParagraph = (
      !nextLine || // Next line is empty
      headerTexts.has(nextLine) || // Next line is a header
      /^[•\-*]\s/.test(nextLine) || // Next line starts a list
      (line.endsWith('.') && nextLine && /^[A-Z]/.test(nextLine)) // Sentence ending followed by capital letter
    );

    formattedLines.push(line);

    // Add paragraph break if needed
    if (isEndOfParagraph && nextLine) {
      formattedLines.push(''); // Add blank line for paragraph break
    }

    previousWasHeader = false;
    previousWasEmpty = false;
  }

  // Join lines and clean up multiple blank lines
  let formattedText = formattedLines.join('\n');
  formattedText = formattedText.replace(/\n{3,}/g, '\n\n'); // Max 2 newlines

  return {
    text: formattedText,
    headers: headers.map(h => h.text),
    paragraphs: formattedText.split(/\n\n+/).filter(p => p.trim())
  };
}

/**
 * Process Markdown content to structured JSON with formatting
 */
function processEnhancedContent(markdownText, options = {}) {
  console.log('Processing Markdown content with enhanced formatting...');

  // IMPORTANT: Keep the original text EXACTLY as is to maintain character position alignment
  // No text transformations that would change character positions
  let processedText = markdownText.trim();

  // For metadata only - identify structure without modifying text
  const lines = processedText.split('\n');
  const headers = identifyHeaders(lines);
  const paragraphs = processedText.split(/\n\n+/).filter(p => p.trim());

  // Create formatted object without modifying the actual text
  const formatted = {
    text: processedText, // Original text, unmodified
    headers: headers,
    paragraphs: paragraphs
  };

  // Calculate metadata
  const plainText = formatted.text.replace(/\*\*/g, ''); // Remove bold markers for word count
  const wordCount = plainText.split(/\s+/).filter(w => w.length > 0).length;
  const characterCount = plainText.length;
  const readingTime = calculateReadingTime(wordCount, options.wordsPerMinute || 200);

  console.log(`Processed: ${wordCount} words, ${characterCount} characters`);
  console.log(`Found ${formatted.headers.length} section headers`);
  console.log(`Identified ${formatted.paragraphs.length} paragraphs (no spacing added)`);

  return {
    version: '1.0',
    displayText: formatted.text,
    paragraphs: formatted.paragraphs,
    headers: formatted.headers,
    formatting: {
      boldHeaders: false, // No bold formatting to avoid character position issues
      paragraphSpacing: true
    },
    metadata: {
      wordCount,
      characterCount,
      estimatedReadingTime: readingTime,
      language: options.language || 'en'
    }
  };
}

/**
 * Calculate reading time
 */
function calculateReadingTime(wordCount, wordsPerMinute = 200) {
  const minutes = Math.ceil(wordCount / wordsPerMinute);
  if (minutes === 1) {
    return '1 minute';
  } else if (minutes < 60) {
    return `${minutes} minutes`;
  } else {
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    if (remainingMinutes === 0) {
      return `${hours} hour${hours !== 1 ? 's' : ''}`;
    } else {
      return `${hours} hour${hours !== 1 ? 's' : ''} ${remainingMinutes} minute${remainingMinutes !== 1 ? 's' : ''}`;
    }
  }
}

/**
 * Main function for standalone execution
 */
function main() {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    console.log('Usage: node enhanced_content_processor.js <markdown.md> [output.json]');
    process.exit(1);
  }

  const inputPath = args[0];
  const outputPath = args[1] || 'enhanced_content.json';

  try {
    // Read Markdown file
    console.log(`Reading Markdown file: ${inputPath}`);
    const markdownText = fs.readFileSync(inputPath, 'utf8');

    // Process content
    const content = processEnhancedContent(markdownText);

    // Display sample output
    console.log('\nSample of formatted text (first 500 chars):');
    console.log(content.displayText.substring(0, 500) + '...');

    console.log('\nIdentified section headers:');
    content.headers.slice(0, 5).forEach(h => {
      console.log(`  - ${h}`);
    });
    if (content.headers.length > 5) {
      console.log(`  ... and ${content.headers.length - 5} more`);
    }

    // Save output
    fs.writeFileSync(outputPath, JSON.stringify(content, null, 2));
    console.log(`\nOutput saved to: ${outputPath}`);

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// Export for use in other scripts
module.exports = {
  processEnhancedContent,
  formatTextWithParagraphs,
  identifyHeaders
};

// Run if called directly
if (require.main === module) {
  main();
}