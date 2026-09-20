#!/bin/bash
# run.sh <scenario> [output-dir]
# Builds a throwaway copy of source/ with harness.lua appended to main.lua, runs it in the
# Simulator, and waits for the PNGs. Exits non-zero if the game or the script crashes.
# The build copy gets its own bundleID so real save data is never touched. Sends no OS input.
set -euo pipefail
ROOT="$(command cd "$(dirname "$0")/../.." && pwd)"
SCENARIO="$1"
OUT="${2:-$ROOT/builds/screenshots}"
SRC="$ROOT/builds/harness-source"
PDX="$ROOT/builds/MazeShots.pdx"
HARNESS_BUNDLE_ID="com.motlin.maze.screenshots"
DATA="$HOME/Developer/PlaydateSDK/Disk/Data/$HARNESS_BUNDLE_ID"
LOG="$DATA/harness-log.txt"

mkdir -p "$OUT"
OUT="$(command cd "$OUT" && pwd)"
find "$OUT" -name "$SCENARIO-*.png" -delete
mkdir -p "$DATA" "$SRC"
# Start from fresh saves; only the game's own flat files live here
find "$DATA" -maxdepth 1 -type f -delete
: > "$LOG"
# Mirror rather than delete-and-copy, so nothing here needs a recursive delete
rsync --archive --delete "$ROOT/source/" "$SRC/"
sed -i '' "s/^bundleID=.*/bundleID=$HARNESS_BUNDLE_ID/" "$SRC/pdxinfo"
grep -q "^bundleID=$HARNESS_BUNDLE_ID$" "$SRC/pdxinfo"
# A name nobody can mistake for the real game, in the Simulator or on a device
sed -i '' "s/^name=.*/name=Maze SCREENSHOT HARNESS/" "$SRC/pdxinfo"
{
  echo ""
  echo "HARNESS_OUT = \"$OUT\""
  echo "HARNESS_SCENARIO = \"$SCENARIO\""
  cat "$ROOT/tools/screenshots/harness.lua"
} >> "$SRC/main.lua"
pdc -q "$SRC" "$PDX"
open -g -a "Playdate Simulator" "$PDX"

for _ in $(seq 1 240); do
  if grep -q "CRASH\|SCRIPT ERROR\|scenario $SCENARIO done" "$LOG"; then break; fi
  sleep 1
done
cat "$LOG"
if ! grep -q "scenario $SCENARIO done" "$LOG"; then
  echo "❌ scenario $SCENARIO did not finish cleanly" >&2
  exit 1
fi
# Leave the real game loaded, so "Upload Game to Device" never sends the harness build
if [ -d "$ROOT/builds/Maze.pdx" ]; then
  open -g -a "Playdate Simulator" "$ROOT/builds/Maze.pdx"
fi
echo "✅ $(find "$OUT" -name "$SCENARIO-*.png" | wc -l | tr -d ' ') screenshots in $OUT"
