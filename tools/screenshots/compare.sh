#!/bin/bash
# compare.sh <reference-dir> <candidate-dir>
# Exits non-zero if any screenshot differs by even one pixel, or exists on only one side.
set -euo pipefail
REFERENCE="$1"
CANDIDATE="$2"
different=0
for reference in "$REFERENCE"/*.png; do
  name="$(basename "$reference")"
  if [ ! -f "$CANDIDATE/$name" ]; then
    echo "❌ missing: $name"; different=$((different + 1)); continue
  fi
  pixels="$(magick compare -metric AE "$reference" "$CANDIDATE/$name" null: 2>&1 || true)"
  pixels="${pixels%% *}"
  if [ "$pixels" != "0" ]; then
    echo "❌ $name differs by $pixels pixels"; different=$((different + 1))
  fi
done
for candidate in "$CANDIDATE"/*.png; do
  if [ ! -f "$REFERENCE/$(basename "$candidate")" ]; then
    echo "❌ unexpected: $(basename "$candidate")"; different=$((different + 1))
  fi
done
if [ "$different" -gt 0 ]; then
  echo "❌ $different screenshots differ"; exit 1
fi
echo "✅ all screenshots identical"
