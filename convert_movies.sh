#!/bin/bash

HANDBRAKE="/usr/local/bin/HandBrakeCLI"
MOVIES_DIR="/Volumes/jellyfin/Movies"
SHOWS_DIR="/Volumes/jellyfin/Shows"
PRESET_FILE="$HOME/Desktop/no_burn.json"

NTFY_URL="YOUR_NTFY_URL"
MAX_RETRIES=3
MIN_SIZE=104857600  # 100 MB in bytes

send_ntfy() {
    curl -s -X POST "$NTFY_URL" \
        -H "Title: Handbrake" \
        -d "$1" > /dev/null
}

handbrake_convert() {
    local INPUT="$1"
    local OUTPUT="$2"
    "$HANDBRAKE" \
        -i "$INPUT" \
        -o "$OUTPUT" \
        --preset-import-file "$PRESET_FILE" \
        --preset "NoBurn" \
        --preset "Fast 1080p30" \
        --encoder x264 \
        --all-audio \
        --aencoder copy \
        --audio-copy-mask ac3,eac3,dts,dtshd,aac,mp3,flac \
        --audio-fallback av_aac \
        --subtitle 1,2,3,4,5,6,7,8 \
        -q 20
}

is_large_enough() {
    local FILE="$1"
    local SIZE
    SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null)
    [ "$SIZE" -ge "$MIN_SIZE" ]
}

# ---- MOVIES ----
echo "=== Starting movies ==="

MOVIE_DIRS=()
while IFS= read -r dir; do
    MOVIE_DIRS+=("$dir")
done < <(find "$MOVIES_DIR" -mindepth 1 -maxdepth 1 -type d)

for MOVIE_DIR in "${MOVIE_DIRS[@]}"; do
    DIR_NAME=$(basename "$MOVIE_DIR")
    INPUT=$(find "$MOVIE_DIR" -maxdepth 1 -name "*.mkv" ! -name "._*" ! -name "*.tmp.mkv" | head -1)
    [ -z "$INPUT" ] && continue

    OUTPUT="$MOVIE_DIR/${DIR_NAME}.mkv"

    if [ "$INPUT" = "$OUTPUT" ]; then
        echo "Skipping — input and output are the same file: $DIR_NAME"
        continue
    fi

    if [ -f "$OUTPUT" ]; then
        if is_large_enough "$OUTPUT"; then
            echo "Skipping (already converted): $DIR_NAME"
            continue
        else
            echo "Found half-finished file — deleting and converting again: $DIR_NAME"
            rm "$OUTPUT"
            send_ntfy "⚠️ Half-finished file found, converting again: $DIR_NAME"
        fi
    fi

    echo "Converting movie: $DIR_NAME"
    send_ntfy "🎬 Starting conversion: $DIR_NAME"

    ATTEMPT=0
    SUCCESS=false

    while [ $ATTEMPT -lt $MAX_RETRIES ]; do
        ATTEMPT=$((ATTEMPT + 1))
        [ -f "$OUTPUT" ] && rm "$OUTPUT"
        echo "Attempt $ATTEMPT of $MAX_RETRIES..."

        handbrake_convert "$INPUT" "$OUTPUT"

        if [ $? -eq 0 ] && is_large_enough "$OUTPUT"; then
            SUCCESS=true
            break
        else
            send_ntfy "⚠️ Attempt $ATTEMPT failed: $DIR_NAME"
        fi
    done

    if [ "$SUCCESS" = true ]; then
        rm "$INPUT"
        echo "Success — original deleted: $DIR_NAME"
        send_ntfy "✅ Done: $DIR_NAME — original deleted"
    else
        [ -f "$OUTPUT" ] && rm "$OUTPUT"
        echo "ERROR: $DIR_NAME could not be converted after $MAX_RETRIES attempts"
        send_ntfy "❌ ERROR after $MAX_RETRIES attempts: $DIR_NAME — original kept"
    fi
done

# ---- TV SHOWS ----
echo "=== Starting TV shows ==="

EPISODES=()
while IFS= read -r file; do
    EPISODES+=("$file")
done < <(find "$SHOWS_DIR" -mindepth 3 -maxdepth 3 -name "*.mkv" ! -name "._*" ! -name "*.tmp.mkv")

for INPUT in "${EPISODES[@]}"; do
    EPISODE_NAME=$(basename "$INPUT")
    SEASON_DIR=$(dirname "$INPUT")
    SHOW_NAME=$(basename "$(dirname "$SEASON_DIR")")
    SEASON_NAME=$(basename "$SEASON_DIR")
    NAME="$SHOW_NAME / $SEASON_NAME / $EPISODE_NAME"
    MARKER="${INPUT}.done"

    if [ -f "$MARKER" ]; then
        echo "Skipping (already converted): $NAME"
        continue
    fi

    OUTPUT="${INPUT%.mkv}.tmp.mkv"

    echo "Converting episode: $NAME"
    send_ntfy "🎬 Starting conversion: $NAME"

    ATTEMPT=0
    SUCCESS=false

    while [ $ATTEMPT -lt $MAX_RETRIES ]; do
        ATTEMPT=$((ATTEMPT + 1))
        [ -f "$OUTPUT" ] && rm "$OUTPUT"
        echo "Attempt $ATTEMPT of $MAX_RETRIES..."

        handbrake_convert "$INPUT" "$OUTPUT"

        if [ $? -eq 0 ] && is_large_enough "$OUTPUT"; then
            SUCCESS=true
            break
        else
            send_ntfy "⚠️ Attempt $ATTEMPT failed: $NAME"
        fi
    done

    if [ "$SUCCESS" = true ]; then
        rm "$INPUT"
        mv "$OUTPUT" "$INPUT"
        touch "$MARKER"
        echo "Success — original replaced: $NAME"
        send_ntfy "✅ Done: $NAME — original replaced"
    else
        [ -f "$OUTPUT" ] && rm "$OUTPUT"
        echo "ERROR: $NAME could not be converted after $MAX_RETRIES attempts"
        send_ntfy "❌ ERROR after $MAX_RETRIES attempts: $NAME — original kept"
    fi
done

send_ntfy "🏁 All conversions complete!"
echo "Done!"
