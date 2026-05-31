# cdj-yt-shorts-anim-subs

Animated karaoke-style subtitles for YouTube Shorts in about 30 seconds, using local Whisper transcription and a Claude skill to generate the subtitle file.

Built by [Creator with a Day Job](https://youtube.com/@CreatorWithADayJob).

---

## What this does

Takes a video file and produces a new video with word-by-word animated subtitles burned in — active word highlights in yellow, 4 words per line, sized for 9:16 vertical video.

**The pipeline:**
```
video file → transcribe.sh → .srt → Claude skill → .ass → ffmpeg → subtitled video
```

---

## Requirements

### Local tools

```bash
brew install ffmpeg whisper-cpp
```

> **Note:** The brew ffmpeg build may not include libass. If you get `No such filter: ass`, download a static build from [evermeet.cx/ffmpeg](https://evermeet.cx/ffmpeg).

### Whisper models

Download a model from [ggerganov/whisper.cpp](https://github.com/ggerganov/whisper.cpp) and place it somewhere on your machine. The script defaults to `ggml-medium.en.bin`.

Update `MODELS_DIR` in `transcribe.sh` to point to your model directory.

### Claude

You need a [Claude](https://claude.ai) account with a Project. The Claude skill lives in your project — see setup below.

---

## Setup

### 1. Clone this repo

```bash
git clone git@github.com:6foot3foot/cdj-yt-shorts-anim-subs.git
cd cdj-yt-shorts-anim-subs
```

### 2. Make the transcription script executable

```bash
chmod +x transcribe.sh
```

Optionally symlink it somewhere on your PATH:

```bash
ln -s $(pwd)/transcribe.sh /usr/local/bin/transcribe
```

### 3. Add the Claude skill to your project

1. Open [claude.ai](https://claude.ai) and create a Project (or open an existing one)
2. Go to **Project Settings → Add Content**
3. Copy the contents of `shorts-ass-generator/SKILL.md` and add it as a project file

Claude will now recognise the skill whenever you're working in that project.

---

## Usage

### Step 1 — Transcribe your clip

```bash
./transcribe.sh -f srt my_short.mov
```

This produces `my_short.srt` in the same directory.

**Options:**
```
-m <model>    Model filename (default: ggml-medium.en.bin)
-f <format>   Output format: txt, srt, vtt, json (default: txt)
-o <dir>      Output directory (default: same dir as input)
```

### Step 2 — Generate the .ass subtitle file

1. Open your Claude Project
2. Upload `my_short.srt`
3. Say: **"generate the ass file"**

Claude will produce a `my_short.ass` file for download.

### Step 3 — Burn subtitles into your video

```bash
ffmpeg -i my_short.mov -vf "ass=my_short.ass" -c:v libx264 -crf 18 -preset fast -c:a pcm_s24le my_short_subtitled.mov
```

Done.

---

## Subtitle style defaults

| Property | Value |
|---|---|
| Resolution | 1080×1920 (9:16) |
| Font | Arial Black, 85pt |
| Active word | Yellow, 95pt |
| Inactive words | White, 85pt |
| Border | Black, 5px |
| Position | 320px from bottom |
| Words per line | 4 |

To change style (font size, highlight colour, word count, position), just tell Claude what you want when you generate the file.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `No such filter: ass` | ffmpeg lacks libass — use static build from evermeet.cx/ffmpeg |
| `No option name near '...'` | Wrong time format in .ass — regenerate the file |
| Words feel mistimed | Re-transcribe the trimmed clip rather than using a clip cut from a longer transcription |
| Subtitles too high/low | Ask Claude to adjust the vertical position when generating |

---

## Notes

- `transcribe.sh` is optimised for Apple Silicon (M-series) with Metal acceleration via whisper-cpp
- Filler words (`uh`, `um`, `oh`) are automatically stripped from subtitles
- Works with any video format ffmpeg can read

---

## License

MIT
