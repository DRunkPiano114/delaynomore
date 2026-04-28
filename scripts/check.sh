#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

swift test
bash "$ROOT_DIR/scripts/test-app-bundle.sh"
