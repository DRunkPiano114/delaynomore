#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="${APP_VERSION:-$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")}"
APP_DIR="$ROOT_DIR/.build/app/DelayNoMore.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

cd "$ROOT_DIR"
rm -rf "$ROOT_DIR/.build/release/"*.bundle
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/.build/release/DelayNoMore" "$MACOS_DIR/DelayNoMore"

RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$RESOURCES_DIR"
cp "$ROOT_DIR/Sources/DelayNoMoreApp/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

for bundle in "$ROOT_DIR/.build/release/"*.bundle; do
  [ -e "$bundle" ] || continue
  cp -R "$bundle" "$RESOURCES_DIR/"
done

mkdir -p "$FRAMEWORKS_DIR"
SPARKLE_FW=$(find "$ROOT_DIR/.build" -name "Sparkle.framework" -type d 2>/dev/null \
  | grep -v 'XPCServices' \
  | grep -v 'checkouts' \
  | head -1)
if [ -z "$SPARKLE_FW" ] || [ ! -d "$SPARKLE_FW" ]; then
  echo "Error: Sparkle.framework not found in .build/" >&2
  exit 1
fi
ditto "$SPARKLE_FW" "$FRAMEWORKS_DIR/Sparkle.framework"

sed "s|__APP_VERSION__|${APP_VERSION}|g" \
  "$ROOT_DIR/App/Info.plist" \
  > "$CONTENTS_DIR/Info.plist"

if [ -n "${SIGNING_IDENTITY:-}" ]; then
  ENTITLEMENTS="$ROOT_DIR/App/entitlements.plist"

  SPARKLE_VERSION_DIR=$(find "$FRAMEWORKS_DIR/Sparkle.framework/Versions" -maxdepth 1 -mindepth 1 -type d ! -name 'Current' | head -1)

  while IFS= read -r -d '' xpc; do
    codesign --force --options runtime --timestamp \
      --sign "$SIGNING_IDENTITY" \
      "$xpc"
  done < <(find "$SPARKLE_VERSION_DIR/XPCServices" -maxdepth 1 -mindepth 1 -name '*.xpc' -print0 2>/dev/null)

  if [ -e "$SPARKLE_VERSION_DIR/Autoupdate" ]; then
    codesign --force --options runtime --timestamp \
      --sign "$SIGNING_IDENTITY" \
      "$SPARKLE_VERSION_DIR/Autoupdate"
  fi

  if [ -d "$SPARKLE_VERSION_DIR/Updater.app" ]; then
    codesign --force --options runtime --timestamp \
      --sign "$SIGNING_IDENTITY" \
      "$SPARKLE_VERSION_DIR/Updater.app"
  fi

  codesign --force --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" \
    "$FRAMEWORKS_DIR/Sparkle.framework"

  while IFS= read -r -d '' bundle; do
    codesign --force --options runtime --timestamp \
      --sign "$SIGNING_IDENTITY" \
      "$bundle"
  done < <(find "$APP_DIR" -name '*.bundle' -print0)

  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGNING_IDENTITY" \
    "$MACOS_DIR/DelayNoMore"

  codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$SIGNING_IDENTITY" \
    "$APP_DIR"

  codesign --verify --strict --verbose=2 "$APP_DIR"
  echo "Signed $APP_DIR"
else
  echo "SIGNING_IDENTITY not set — skipping codesign (dev build)"
fi

echo "Built $APP_DIR"
