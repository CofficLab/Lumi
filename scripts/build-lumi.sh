#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

# CodeEditSourceEditor / CodeEditTextView currently attach a SwiftLint build-tool
# plugin that fails under this Xcode setup because its Output directory is not
# materialized by the build system. Disable that external lint step so the app
# build itself remains reproducible.
export DISABLE_SWIFTLINT=1

xcodebuild \
  -project Lumi.xcodeproj \
  -scheme Lumi \
  -destination "platform=macOS,arch=arm64" \
  build
