#!/usr/bin/env zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/Tools/LumiSwiftUIPreviewHost"
SCRATCH_DIR="${DERIVED_FILE_DIR:-$ROOT_DIR/.build}/LumiSwiftUIPreviewHost"
CONFIGURATION_NAME="${CONFIGURATION:-Debug}"

if [[ "$CONFIGURATION_NAME" == "Release" ]]; then
  SWIFT_CONFIGURATION="release"
else
  SWIFT_CONFIGURATION="debug"
fi

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${CONTENTS_FOLDER_PATH:-}" ]]; then
  echo "error: TARGET_BUILD_DIR and CONTENTS_FOLDER_PATH are required"
  exit 1
fi

if [[ ! -d "$PACKAGE_DIR" ]]; then
  echo "Skipping legacy SwiftUI preview host helper; package not found at $PACKAGE_DIR"
  exit 0
fi

swift build \
  --package-path "$PACKAGE_DIR" \
  --scratch-path "$SCRATCH_DIR" \
  --disable-automatic-resolution \
  --configuration "$SWIFT_CONFIGURATION"

HELPER_BINARY="$SCRATCH_DIR/$SWIFT_CONFIGURATION/LumiSwiftUIPreviewHost"
HELPERS_DIR="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers"
DESTINATION="$HELPERS_DIR/LumiSwiftUIPreviewHost"

if [[ ! -x "$HELPER_BINARY" ]]; then
  echo "error: SwiftUI preview host helper was not built at $HELPER_BINARY"
  exit 1
fi

mkdir -p "$HELPERS_DIR"
cp "$HELPER_BINARY" "$DESTINATION"
chmod 755 "$DESTINATION"

if [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" && -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" && "$EXPANDED_CODE_SIGN_IDENTITY" != "-" ]]; then
  /usr/bin/codesign \
    --force \
    --sign "$EXPANDED_CODE_SIGN_IDENTITY" \
    --timestamp=none \
    "$DESTINATION"
fi

echo "Embedded SwiftUI preview host helper at $DESTINATION"
