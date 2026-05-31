#!/bin/bash
# transcribe.sh — local Whisper transcription via whisper-cpp
# Optimised for Apple Silicon (Metal acceleration)
#
# SETUP: Set MODELS_DIR below to the folder where your Whisper models live.
# Download models from: https://github.com/ggerganov/whisper.cpp

set -euo pipefail

MODELS_DIR="/path/to/your/whisper-models"   # <-- set this
METAL_PATH="$(brew --prefix whisper-cpp)/share/whisper-cpp"
DEFAULT_MODEL="ggml-medium.en.bin"
OUTPUT_FORMAT="txt"
LANGUAGE="en"
MAX_LEN=42

usage() {
  echo "Usage: transcribe.sh [options] <audio-file> [audio-file ...]"
  echo ""
  echo "Options:"
  echo "  -m <model>    Model filename in $MODELS_DIR (default: $DEFAULT_MODEL)"
  echo "  -f <format>   Output format: txt, srt, vtt, json (default: txt)"
  echo "  -o <dir>      Output directory (default: same dir as input file)"
  echo "  -h            Show this help"
  echo ""
  echo "Available models in $MODELS_DIR:"
  ls "$MODELS_DIR"/*.bin 2>/dev/null | xargs -I{} basename {} || echo "  (none found)"
  exit 0
}

# Parse options
MODEL="$DEFAULT_MODEL"
OUTPUT_DIR=""

while getopts "m:f:o:h" opt; do
  case $opt in
    m) MODEL="$OPTARG" ;;
    f) OUTPUT_FORMAT="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    l) MAX_LEN="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [ $# -eq 0 ]; then
  echo "Error: no audio file(s) specified."
  usage
fi

MODEL_PATH="$MODELS_DIR/$MODEL"

# Sanity checks
if [ ! -f "$MODEL_PATH" ]; then
  echo "Error: model not found at $MODEL_PATH"
  echo "Available models:"
  ls "$MODELS_DIR"/*.bin 2>/dev/null | xargs -I{} basename {} || echo "  (none)"
  exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
  echo "Error: ffmpeg not found. brew install ffmpeg"
  exit 1
fi

if ! command -v whisper-cli &>/dev/null; then
  echo "Error: whisper-cli not found. brew install whisper-cpp"
  exit 1
fi

# Process each file
for INPUT_FILE in "$@"; do
  if [ ! -f "$INPUT_FILE" ]; then
    echo "Warning: file not found, skipping: $INPUT_FILE"
    continue
  fi

  BASENAME=$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')
  DEST_DIR="${OUTPUT_DIR:-$(dirname "$INPUT_FILE")}"
  OUTPUT_FILE="$DEST_DIR/$BASENAME"

  echo ""
  echo "▶ Transcribing: $INPUT_FILE"
  echo "  Model:  $MODEL"
  echo "  Format: $OUTPUT_FORMAT"
  echo "  Output: $OUTPUT_FILE.$OUTPUT_FORMAT"

  ffmpeg -i "$INPUT_FILE" -ar 16000 -ac 1 -f wav - 2>/dev/null | \
    GGML_METAL_PATH_RESOURCES="$METAL_PATH" \
    whisper-cli \
      --model "$MODEL_PATH" \
      --language "$LANGUAGE" \
      --output-"$OUTPUT_FORMAT" \
      --output-file "$OUTPUT_FILE" \
      --max-len "$MAX_LEN" \
      --threads 16 \
      -

  echo "  ✓ Done → $OUTPUT_FILE.$OUTPUT_FORMAT"
done

echo ""
echo "All done."