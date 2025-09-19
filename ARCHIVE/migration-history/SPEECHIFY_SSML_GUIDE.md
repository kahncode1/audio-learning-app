# Speechify SSML Reference Guide

## Overview

Speech Synthesis Markup Language (SSML) is an XML-based markup language that provides granular control over speech synthesis in Speechify's Text-to-Speech service. This guide covers all supported SSML tags and their parameters.

## Basic Structure

Every SSML document must begin with the `<speak>` tag:

```xml
<speak>Your content to be synthesized here</speak>
```

## Character Escaping

When converting text to SSML, certain characters must be escaped:

| Character | Escaped Form | Usage |
|-----------|--------------|-------|
| `&` | `&amp;` | Ampersand |
| `<` | `&lt;` | Less than |
| `>` | `&gt;` | Greater than |
| `"` | `&quot;` | Double quote |
| `'` | `&apos;` | Single quote/apostrophe |

### Example
```xml
<!-- Original: Some "text" with 5 < 6 & 4 > 3 -->
<speak>Some &quot;text&quot; with 5 &lt; 6 &amp; 4 &gt; 3</speak>
```

### Helper Function (TypeScript)
```typescript
const escapeSSMLChars = (text: string): string =>
  text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
```

## Supported SSML Tags

### 1. `<prosody>` - Speech Characteristics

Controls pitch, rate, and volume of synthesized speech.

#### Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `pitch` | `x-low`, `low`, `medium` (default), `high`, `x-high` | Predefined pitch levels |
| | `-83%` to `+100%` | Percentage adjustment |
| `rate` | `x-slow`, `slow`, `medium` (default), `fast`, `x-fast` | Predefined speed levels |
| | `-50%` to `+9900%` | Percentage adjustment |
| `volume` | `silent`, `x-soft`, `medium` (default), `loud`, `x-loud` | Predefined volume levels |
| | Number + `dB` (e.g., `-6dB`) | Decibel adjustment |
| | Percentage (e.g., `+20%`, `-30%`) | Percentage adjustment |

#### Examples
```xml
<speak>
    Normal speech.
    <prosody pitch="high" rate="fast" volume="+20%">
        Higher, faster, and louder speech!
    </prosody>
    <prosody pitch="-20%" rate="slow" volume="x-soft">
        Lower, slower, and softer speech.
    </prosody>
</speak>
```

### 2. `<break>` - Pauses

Inserts pauses between words or sentences.

#### Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `strength` | `none` (0ms) | No pause |
| | `x-weak` (250ms) | Very weak pause |
| | `weak` (500ms) | Weak pause |
| | `medium` (750ms) | Medium pause |
| | `strong` (1000ms) | Strong pause |
| | `x-strong` (1250ms) | Very strong pause |
| `time` | `100ms`, `1s`, etc. | Specific duration (0-10 seconds) |

#### Examples
```xml
<speak>
    First sentence.<break strength="medium" />
    Second sentence after medium pause.
    <break time="2s" />
    Third sentence after 2-second pause.
    Quick<break time="100ms" />pause in the middle.
</speak>
```

### 3. `<emphasis>` - Text Emphasis

Adds or removes emphasis from text.

#### Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `level` | `reduced` | Reduced emphasis |
| | `moderate` | Moderate emphasis |
| | `strong` | Strong emphasis |

#### Examples
```xml
<speak>
    I <emphasis level="strong">really</emphasis> mean it!
    This is <emphasis level="moderate">quite important</emphasis>.
    <emphasis level="reduced">Just a minor note.</emphasis>
</speak>
```

### 4. `<sub>` - Pronunciation Substitution

Replaces pronunciation for acronyms, abbreviations, or specific text.

#### Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `alias` | String (required) | Text to be spoken instead |

#### Examples
```xml
<speak>
    Please read the <sub alias="Frequently Asked Questions">FAQ</sub> section.
    The <sub alias="World Wide Web Consortium">W3C</sub> sets web standards.
    Call us at <sub alias="five five five, one two three four">555-1234</sub>.
</speak>
```

### 5. `<speechify:style>` - Emotional Styling

Controls the emotional tone of the voice (Speechify-specific extension).

#### Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `emotion` | `angry`, `cheerful`, `sad` | Basic emotions |
| | `terrified`, `relaxed`, `fearful` | Fear/calm spectrum |
| | `surprised`, `calm`, `assertive` | Reaction styles |
| | `energetic`, `warm`, `direct`, `bright` | Delivery styles |

#### Examples
```xml
<speak>
    <speechify:style emotion="cheerful">
        Great news everyone!
    </speechify:style>
    <speechify:style emotion="sad">
        I'm sorry to hear that.
    </speechify:style>
    <speechify:style emotion="assertive">
        This needs to be done immediately.
    </speechify:style>
</speak>
```

## Complete Examples

### Example 1: News Broadcast
```xml
<speak>
    <speechify:style emotion="direct">
        <prosody rate="medium" pitch="medium">
            Breaking news just in.
            <break strength="strong" />
            The <sub alias="National Aeronautics and Space Administration">NASA</sub>
            has announced a <emphasis level="strong">major discovery</emphasis> on Mars.
        </prosody>
    </speechify:style>
</speak>
```

### Example 2: Storytelling
```xml
<speak>
    <speechify:style emotion="warm">
        Once upon a time, in a land far away...
        <break time="1s" />
        <prosody pitch="high" rate="fast">
            &quot;Help!&quot; cried the princess.
        </prosody>
        <break time="500ms" />
        <prosody pitch="low" rate="slow">
            &quot;I&apos;m coming,&quot; rumbled the dragon.
        </prosody>
    </speechify:style>
</speak>
```

### Example 3: Tutorial/Instructions
```xml
<speak>
    <speechify:style emotion="calm">
        Welcome to the tutorial.
        <break strength="medium" />
        First, <emphasis level="moderate">carefully</emphasis> open the package.
        <break time="750ms" />
        Next, connect the <sub alias="U S B">USB</sub> cable to your device.
        <prosody rate="slow">
            Make sure the connection is <emphasis level="strong">secure</emphasis>.
        </prosody>
    </speechify:style>
</speak>
```

### Example 4: Multi-Emotion Dialogue
```xml
<speak>
    <speechify:style emotion="angry">
        How many times must I tell you?
    </speechify:style>
    <break time="1s" />
    <speechify:style emotion="sad">
        I&apos;m sorry, I forgot.
    </speechify:style>
    <break time="500ms" />
    <speechify:style emotion="relaxed">
        It&apos;s okay, let&apos;s try again.
    </speechify:style>
</speak>
```

## Best Practices

1. **Always wrap content in `<speak>` tags** - This is mandatory for all SSML documents.

2. **Escape special characters** - Always escape `&`, `<`, `>`, `"`, and `'` characters in text content.

3. **Use breaks judiciously** - Natural pauses improve comprehension, but too many can disrupt flow.

4. **Layer prosody effects** - Combine pitch, rate, and volume for more natural speech variations.

5. **Match emotion to content** - Use `speechify:style` to align emotional tone with message intent.

6. **Test pronunciations** - Use `<sub>` for acronyms, technical terms, or any text that doesn't pronounce correctly by default.

7. **Avoid over-emphasis** - Use `<emphasis>` sparingly for maximum impact.

## Common Use Cases

### Acronyms and Abbreviations
```xml
<sub alias="Application Programming Interface">API</sub>
<sub alias="Structured Query Language">SQL</sub>
<sub alias="Chief Executive Officer">CEO</sub>
```

### Phone Numbers
```xml
<sub alias="eight hundred, five five five, one two three four">800-555-1234</sub>
```

### Dates and Times
```xml
<sub alias="January first, twenty twenty-five">01/01/2025</sub>
<sub alias="three thirty P M">3:30 PM</sub>
```

### Technical Terms
```xml
<sub alias="node jay ess">Node.js</sub>
<sub alias="react">React</sub>
<sub alias="python">Python</sub>
```

## Limitations and Notes

- Maximum pause duration: 10 seconds
- Pitch adjustment range: -83% to +100%
- Rate adjustment range: -50% to +9900%
- All SSML must be well-formed XML
- The `speechify:style` tag is Speechify-specific and may not work with other TTS services
- Tags can be nested, but be mindful of conflicting parameters

## Quick Reference Table

| Tag | Purpose | Key Parameters |
|-----|---------|----------------|
| `<speak>` | Root container | None (required) |
| `<prosody>` | Speech characteristics | pitch, rate, volume |
| `<break>` | Pauses | strength, time |
| `<emphasis>` | Text emphasis | level |
| `<sub>` | Pronunciation substitute | alias (required) |
| `<speechify:style>` | Emotional tone | emotion |

---

*This documentation covers Speechify's SSML implementation. For W3C SSML specifications, refer to [W3C Speech Synthesis Markup Language](https://www.w3.org/TR/speech-synthesis11/).*