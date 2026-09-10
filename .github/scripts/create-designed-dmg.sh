#!/bin/bash
set -euo pipefail

# Create a Finder-style DMG with a branded background and layout.
# Usage: create-designed-dmg.sh APP_PATH OUTPUT_PATH [VOLUME_NAME] [BACKGROUND_PATH] [APP_NAME]

if [[ $# -lt 2 || $# -gt 5 ]]; then
  echo "Usage: $0 APP_PATH OUTPUT_PATH [VOLUME_NAME] [BACKGROUND_PATH] [APP_NAME]" >&2
  exit 2
fi

APP_PATH="$1"
OUTPUT_PATH="$2"
VOLUME_NAME="${3:-Lumi}"
BACKGROUND_PATH="${4:-.github/dmg/Lumi-dmg-background.png}"
APP_NAME="${5:-$(basename "$APP_PATH" .app)}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ "$BACKGROUND_PATH" != /* ]]; then
  BACKGROUND_PATH="$ROOT_DIR/$BACKGROUND_PATH"
fi

[[ -d "$APP_PATH" ]] || { echo "App not found: $APP_PATH" >&2; exit 1; }
[[ -f "$BACKGROUND_PATH" ]] || { echo "Background not found: $BACKGROUND_PATH" >&2; exit 1; }

OUTPUT_DIR="$(dirname "$OUTPUT_PATH")"
mkdir -p "$OUTPUT_DIR"

TEMP_ROOT="${RUNNER_TEMP:-/tmp}"
WORK_DIR="$(mktemp -d "$TEMP_ROOT/lumi-dmg.XXXXXX")"
STAGING_DIR="$WORK_DIR/staging"
READ_WRITE_DMG="$WORK_DIR/$VOLUME_NAME-rw.dmg"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$STAGING_DIR/.background"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$BACKGROUND_PATH" "$STAGING_DIR/.background/background.png"
chflags hidden "$STAGING_DIR/.background"

mdutil -i off "$STAGING_DIR" >/dev/null 2>&1 || true
sync

hdiutil detach "/Volumes/$VOLUME_NAME" -force >/dev/null 2>&1 || true

create_read_write_image() {
  rm -f "$READ_WRITE_DMG"
  hdiutil create \
    -size 200m \
    -fs HFS+ \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    "$READ_WRITE_DMG" >/dev/null
}

attempt=0
until create_read_write_image; do
  attempt=$((attempt + 1))
  if [[ "$attempt" -ge 6 ]]; then
    echo "Unable to create DMG after 6 attempts: $VOLUME_NAME" >&2
    exit 1
  fi
  echo "Retrying DMG creation ($attempt/5): $VOLUME_NAME" >&2
  sleep $((attempt * 2))
done

ATTACH_OUTPUT="$(hdiutil attach "$READ_WRITE_DMG" -readwrite -noverify -noautoopen)"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Unable to locate mounted DMG for $VOLUME_NAME" >&2
  exit 1
fi

osascript - "$VOLUME_NAME" "$APP_NAME" <<'APPLESCRIPT'
on run argv
  set volumeName to item 1 of argv
  set appName to item 2 of argv
  tell application "Finder"
    tell disk volumeName
      open
      delay 1
      set containerWindow to container window
      set current view of containerWindow to icon view
      set toolbar visible of containerWindow to false
      set statusbar visible of containerWindow to false
      set sidebar width of containerWindow to 0
      set bounds of containerWindow to {120, 120, 840, 660}
      set iconViewOptions to icon view options of containerWindow
      set icon size of iconViewOptions to 112
      set text size of iconViewOptions to 12
      set arrangement of iconViewOptions to not arranged
      set background picture of iconViewOptions to file ".background:background.png"
      set position of item (appName & ".app") to {220, 300}
      set position of item "Applications" to {500, 300}
      close containerWindow
      open
      delay 1
      set bounds of container window to {120, 120, 840, 660}
    end tell
  end tell
end run
APPLESCRIPT

sync
hdiutil detach "$MOUNT_POINT" >/dev/null
MOUNT_POINT=""

rm -f "$OUTPUT_PATH"
hdiutil convert "$READ_WRITE_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_PATH" >/dev/null

echo "Created $OUTPUT_PATH"
