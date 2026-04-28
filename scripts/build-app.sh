#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_VERSION="${APP_VERSION:-$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")}"
APP_DIR="$ROOT_DIR/.build/app/DelayNoMore.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
rm -rf "$ROOT_DIR/.build/release/"*.bundle
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$ROOT_DIR/.build/release/DelayNoMore" "$MACOS_DIR/DelayNoMore"

for bundle in "$ROOT_DIR/.build/release/"*.bundle; do
  [ -e "$bundle" ] || continue
  cp -R "$bundle" "$APP_DIR/"
done

RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$RESOURCES_DIR"
cp "$ROOT_DIR/Sources/DelayNoMoreApp/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

sed "s|__APP_VERSION__|${APP_VERSION}|g" \
  "$ROOT_DIR/App/Info.plist" \
  > "$CONTENTS_DIR/Info.plist"

echo "Built $APP_DIR"
