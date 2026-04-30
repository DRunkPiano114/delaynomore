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
echo "Checking Sparkle framework..."
SPARKLE="$APP_DIR/Contents/Frameworks/Sparkle.framework"
check "$SPARKLE"
check "$SPARKLE/Versions/Current/XPCServices/Downloader.xpc"
check "$SPARKLE/Versions/Current/XPCServices/Installer.xpc"
check "$SPARKLE/Versions/Current/Autoupdate"
check "$SPARKLE/Versions/Current/Updater.app"

echo ""
echo "Checking code signature (deep)..."
if codesign --verify --strict --deep --verbose=2 "$APP_DIR" >/dev/null 2>&1; then
  echo "OK:   codesign deep verify"
else
  if [ -n "${SIGNING_IDENTITY:-}" ]; then
    echo "FAIL: codesign --verify --strict --deep failed"
    codesign --verify --strict --deep --verbose=2 "$APP_DIR" 2>&1 | tail -10
    failed=1
  else
    echo "SKIP: app is not signed (SIGNING_IDENTITY not set)"
  fi
fi

echo ""
echo "Smoke test: launching app from a clean location..."
# Copy the .app outside the project tree and clear the SwiftPM build cache so
# the binary cannot fall back to .build/release/<bundle>. This forces the app
# to load resources from .app/Contents/Resources, mirroring what end users hit.
SMOKE_DIR=$(mktemp -d)
cp -R "$APP_DIR" "$SMOKE_DIR/DelayNoMore.app"
rm -rf "$ROOT_DIR/.build/release" "$ROOT_DIR/.build/arm64-apple-macosx"

LOG_FILE="$SMOKE_DIR/launch.log"
"$SMOKE_DIR/DelayNoMore.app/Contents/MacOS/DelayNoMore" >"$LOG_FILE" 2>&1 &
APP_PID=$!

for _ in 1 2 3 4 5; do
  sleep 1
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    break
  fi
done

if kill -0 "$APP_PID" 2>/dev/null; then
  echo "OK:   app stayed alive 5 s — menu bar reachable"
  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
else
  echo "FAIL: app exited before 5 s"
  echo "--- launch.log ---"
  cat "$LOG_FILE"
  echo "------------------"
  failed=1
fi

rm -rf "$SMOKE_DIR"

echo ""
if [ "$failed" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some checks failed."
  exit 1
fi
