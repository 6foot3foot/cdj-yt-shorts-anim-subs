---
name: shorts-ass-generator
description: Generates a karaoke-style animated .ass subtitle file from a trimmed Whisper transcript JSON or .srt file, ready to burn into a YouTube Short with ffmpeg. Use this skill whenever the user uploads a trimmed/edited Whisper JSON or SRT for a Short clip and wants animated subtitles with word-level highlighting. Triggers on phrases like "generate the ass file", "make subtitles for this clip", "create the subtitle file", "burn in subtitles", or when a short clip Whisper JSON or .srt is uploaded after editing. Works for any channel — not CDJ-specific. Always use this skill rather than generating ad-hoc subtitle code.
---

# Shorts .ASS Subtitle Generator

Generates a karaoke-style `.ass` subtitle file from a trimmed Whisper segment-level JSON. Active word highlights in yellow, 4 words per line, sized for 9:16 vertical video.

## Input

- **Trimmed Whisper JSON** — segment-level, same format as full episode but covering only the Short clip (starts at 00:00:00,000)
- **SRT file** — standard subtitle format also accepted; parse `HH:MM:SS,mmm --> HH:MM:SS,mmm` timestamps and text blocks
- Optionally: style preferences (font size, colour, words per line, vertical position)

## Dependencies

- ffmpeg with libass (use static build from evermeet.cx if brew version lacks it)
- burn command: `ffmpeg -i clip.mov -vf "ass=output.ass" -c:v libx264 -crf 18 -preset fast -c:a pcm_s24le output_subtitled.mov`

## Default Style

| Property | Value |
|---|---|
| Resolution | 1080×1920 (9:16) |
| Font | Arial Black, 85pt |
| Active word | Yellow, 95pt |
| Inactive words | White, 85pt |
| Border | Black, 5px |
| Position | 320px from bottom, horizontally centered |
| Words per line | 4 |

## Process

### Step 1 — Parse segments

```python
segments = data['transcription']
# Each segment: timestamps.from/to (HH:MM:SS,mmm), offsets.from/to (ms), text
```

### Step 2 — Filter fillers and interpolate word timing

Whisper gives segment-level timing only. Distribute time proportionally across words:

```python
FILLERS = {"uh", "uh,", "um", "um,", "oh,", "the,"}

for seg in segments:
    raw_words = seg['text'].split()
    display_words = [w for w in raw_words 
                     if w.lower().strip(".,!?") not in FILLERS 
                     and w.lower() not in FILLERS]
    if not display_words:
        continue
    dur = seg['offsets']['to'] - seg['offsets']['from']
    per_word = dur / len(display_words)
    for i, w in enumerate(display_words):
        start_ms = int(seg['offsets']['from'] + i * per_word)
        end_ms = int(seg['offsets']['from'] + (i + 1) * per_word)
        clean = re.sub(r"[.,!?]+$", "", w)
        words.append({"text": clean, "start": start_ms, "end": end_ms})
```

### Step 3 — Group into lines

Default: 4 words per line. Adjust if user requests different pacing.

```python
lines = [words[i:i+4] for i in range(0, len(words), 4)]
```

### Step 4 — Build .ass events

For each line, emit one Dialogue event per word (the active word moment). Each event shows the full line with the active word coloured and sized up via inline override tags.

**Time format:** `H:MM:SS.cs` (centiseconds, not milliseconds)

```python
def ms_to_ass(ms):
    cs = (ms % 1000) // 10
    s = (ms // 1000) % 60
    m = (ms // 60000) % 60
    h = ms // 3600000
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"
```

**Per-word event construction:**
```python
for active_idx, active_word in enumerate(line):
    parts = []
    for i, w in enumerate(line):
        if i == active_idx:
            parts.append(f"{{\\c&H00FFFF&\\fs95}}{w['text']}{{\\c&HFFFFFF&\\fs85}}")
        else:
            parts.append(w['text'])
    text = " ".join(parts)
    # emit Dialogue line
```

**Colour format:** ASS uses BGR hex: white = `&HFFFFFF&`, yellow = `&H00FFFF&`

### Step 5 — Write .ass file

```
[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: 1920
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial Black,85,&H00FFFFFF,&H0000FFFF,&H00000000,&HAA000000,-1,0,0,0,100,100,2,0,1,5,2,2,80,80,320,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
Dialogue: 0,{start},{end},Default,,0,0,0,,{text}
...
```

## Output

- `.ass` file named to match the input JSON (e.g. `Shorts_Rails_001.json` → `Shorts_Rails_001.ass`)
- Present the file for download
- Remind user of the ffmpeg burn command:

```bash
ffmpeg -i your_clip.mov -vf "ass=Shorts_Rails_001.ass" -c:v libx264 -crf 18 -preset fast -c:a pcm_s24le your_clip_subtitled.mov
```

## Common Issues

| Problem | Fix |
|---|---|
| `No such filter: ass` | ffmpeg lacks libass — use static build from evermeet.cx/ffmpeg |
| `No option name near '...'` | Wrong time format in .ass — must be `H:MM:SS.cs` not decimal seconds |
| Words overlapping | Reduce words per line to 3, or increase MarginV |
| Timing feels off | Whisper segment boundaries are approximate — user should re-transcribe the trimmed clip rather than offset from full episode |
| Subtitles too high/low | Adjust MarginV in the Style line (320 = 320px from bottom edge) |

## Style Variations

If user requests different styles, adjust these values:

- **Bigger text:** increase fontsize in Style line and `\fs` override values proportionally
- **Different highlight colour:** change `&H00FFFF&` (yellow in BGR) — e.g. cyan = `&HFFFF00&`, green = `&H00FF00&`
- **3 words per line:** change grouping from 4 to 3 — better for fast speech
- **Higher position:** decrease MarginV (e.g. 500 = higher up the frame)