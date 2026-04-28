#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

pkill -x DelayNoMore || true
bash "$ROOT_DIR/scripts/build-app.sh"
open "$ROOT_DIR/.build/app/DelayNoMore.app"
