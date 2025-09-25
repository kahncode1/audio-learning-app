# ElevenLabs Content Formatting Guide

## Purpose
This guide defines how to format text content BEFORE sending it to ElevenLabs TTS to ensure proper sentence detection and synchronized highlighting in the Audio Learning App.

## Key Principle
**ElevenLabs ignores formatting but respects punctuation.** The text must be structured so that punctuation alone creates the desired sentence boundaries.

## Critical Formatting Rules

### 1. Lists - THE MOST IMPORTANT RULE

#### Problem
When you send this to ElevenLabs:
```
Examples of technology include:

Telematics
Wearables
IoT sensors
```

ElevenLabs will:
- Ignore the line breaks
- Speak continuously: "Examples of technology include Telematics Wearables IoT sensors"
- Create one long sentence that causes highlighting issues

#### Solution
Add periods to EVERY list item:
```
Examples of technology include:

Telematics.
Wearables.
IoT sensors.
```

Or use bullet points with periods:
```
Examples of technology include:

• Telematics.
• Wearables.
• IoT sensors.
```

### 2. Numbered and Lettered Lists

#### Always Add Periods
```
❌ WRONG:
The process has three steps:
1. Data collection
2. Analysis and modeling
3. Implementation

✅ CORRECT:
The process has three steps:
1. Data collection.
2. Analysis and modeling.
3. Implementation.
```

### 3. Colon-Introduced Lists

#### Single-Line Lists
If items follow on the same line, use semicolons and a period:
```
The kit includes: a manual; spare parts; and warranty information.
```

#### Multi-Line Lists
Always use periods for each item:
```
The insurance industry faces several challenges:

Rising costs.
Regulatory changes.
Customer expectations.
Digital transformation.
```

### 4. Headers and Sections

#### Add Periods to Standalone Headers
```
❌ WRONG:
Chapter 1: Introduction
This chapter covers...

✅ CORRECT:
Chapter 1: Introduction.
This chapter covers...
```

#### Or Integrate Headers into Sentences
```
✅ ALSO CORRECT:
In Chapter 1, Introduction, we cover...
```

### 5. Glossary and Definitions

#### Format as Complete Sentences
```
❌ WRONG:
Glossary:
Premium: The amount paid for insurance
Deductible: The amount paid before coverage

✅ CORRECT:
Glossary:
Premium: The amount paid for insurance.
Deductible: The amount paid before coverage begins.
```

### 6. Line Breaks and Paragraphs

#### Preserve Paragraph Breaks
- Keep blank lines between paragraphs
- These help with visual formatting in the app
- ElevenLabs ignores them but they're preserved in the display text

```
This is paragraph one. It has multiple sentences.

This is paragraph two. It's separate for clarity.
```

### 7. Abbreviations

#### No Special Formatting Needed
The preprocessing pipeline handles these automatically:
- Dr., Mr., Mrs., Inc., etc.
- U.S.A., U.K., E.U.
- a.m., p.m.
- Keep them as-is with their periods

### 8. Special Punctuation

#### Ellipses
Use three dots without spaces:
```
Well... I'm not sure about this.
```

#### Em Dashes
Use the em dash character or double hyphen:
```
The solution—if there is one—requires thought.
The solution--if there is one--requires thought.
```

### 9. Quotations and Dialog

#### Ensure Proper Closing Punctuation
```
She said, "This is important."
Manager: "What's our status?"
```

### 10. Mathematical Content

#### Add Periods After Standalone Equations
```
❌ WRONG:
The formula is E = mc²
This shows energy-mass equivalence

✅ CORRECT:
The formula is E = mc².
This shows energy-mass equivalence.
```

## Pre-Processing Checklist

Before sending content to ElevenLabs, verify:

- [ ] ✅ All list items end with periods
- [ ] ✅ Numbered/lettered lists have periods
- [ ] ✅ Standalone headers have periods
- [ ] ✅ Glossary definitions end with periods
- [ ] ✅ All sentences have ending punctuation (. ! ?)
- [ ] ✅ Dialog and quotes are properly closed
- [ ] ✅ No incomplete sentences without punctuation

## Testing Your Formatting

1. **Read it aloud**: If you would naturally pause, add punctuation
2. **Count sentences**: Each intended sentence should end with . ! or ?
3. **Check lists**: Every list item should be a complete sentence with a period

## Common Mistakes to Avoid

### Don't Rely on Line Breaks Alone
```
❌ WRONG (appears as one sentence):
Key benefits include
Cost savings
Time efficiency
Better outcomes

✅ CORRECT (three separate sentences):
Key benefits include:
Cost savings.
Time efficiency.
Better outcomes.
```

### Don't Leave Headers Hanging
```
❌ WRONG:
Summary
The project was successful

✅ CORRECT:
Summary.
The project was successful.
```

### Don't Forget List Item Periods
```
❌ WRONG:
Technologies used:
- Python
- JavaScript
- Flutter

✅ CORRECT:
Technologies used:
- Python.
- JavaScript.
- Flutter.
```

## SSML Alternative (Advanced)

If you need more control, use SSML tags:
```xml
Examples of technology include:<break time="500ms"/>
Telematics.<break time="300ms"/>
Wearables.<break time="300ms"/>
```

## Impact on Audio Quality

Adding periods to list items:
- Creates natural pauses in speech
- Improves comprehension
- Enables accurate sentence-by-sentence highlighting
- Prevents "highlighting flash" from overly long sentences

## Example Transformation

### Original Content (Problematic)
```
The insurance industry is evolving due to:

Growing demand for risk consulting
New predictive technology
Customer expectations

These factors include:
Telematics
IoT sensors
AI systems
```

### Properly Formatted for ElevenLabs
```
The insurance industry is evolving due to:

Growing demand for risk consulting.
New predictive technology.
Customer expectations.

These factors include:
Telematics.
IoT sensors.
AI systems.
```

## Validation

After formatting, ensure:
1. Every intended sentence boundary has punctuation
2. No line relies solely on line breaks for separation
3. Lists are consistently formatted with periods
4. The text reads naturally when spoken aloud

## Remember

**Line breaks are for visual organization only. Punctuation creates sentence boundaries in audio.**

When in doubt, add a period. It's better to have slightly choppy audio than to have highlighting that doesn't track with the narration.