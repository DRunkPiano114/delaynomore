#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/app/DelayNoMore.app"

failed=0

check() {
  if [ ! -e "$1" ]; then
    echo "FAIL: missing $1"
    failed=1
  else
    echo "OK:   $1"
  fi
}

echo "Building app..."
"$ROOT_DIR/scripts/build-app.sh"
echo ""
echo "Checking app bundle structure..."

check "$APP_DIR/Contents/MacOS/DelayNoMore"
check "$APP_DIR/Contents/Resources/AppIcon.icns"
check "$APP_DIR/Contents/Info.plist"

for bundle in "$APP_DIR/Contents/Resources/"*.bundle; do
  [ -e "$bundle" ] || { echo "FAIL: no resource bundle in Contents/Resources"; failed=1; continue; }
  echo "OK:   $bundle"

  mp4_count=$(find "$bundle" -name "*.mp4" | wc -l | tr -d ' ')
  if [ "$mp4_count" -eq 0 ]; then
    echo "FAIL: no mp4 files in $bundle"
    failed=1
  else
    echo "OK:   $mp4_count mp4 files in resource bundle"
  fi
done

if [ -d "$APP_DIR/Contents/MacOS/"*.bundle 2>/dev/null ]; then
  echo "FAIL: resource bundle should not be in Contents/MacOS/"
  failed=1
fi

echo ""
if [ "$failed" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some checks failed."
  exit 1
fi
