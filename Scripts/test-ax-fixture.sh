#!/bin/zsh
# Build the AX fixture app and run the real Accessibility integration test.
#
# The fixture is a background-only window (accessory app, never activated, never
# ordered front). It controls no production app and no user desktop state.
#
# Requirements:
#   - The process running this script must hold macOS Accessibility permission
#     (System Settings > Privacy & Security > Accessibility). AXIsProcessTrusted
#     is asserted by the test itself and fails loudly otherwise.
#
# Usage:
#   ./Scripts/test-ax-fixture.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/Packages/PluginComputerUse"
cd "$PACKAGE"

swift build --product AXFixture
BIN_DIR="$(swift build --product AXFixture --show-bin-path)"
BIN="$BIN_DIR/AXFixture"

APP="/tmp/LumiAXFixture.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/AXFixture"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>com.coffic.lumi.tests.axfixture</string>
	<key>CFBundleName</key><string>AXFixture</string>
	<key>CFBundleExecutable</key><string>AXFixture</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

LUMI_AX_FIXTURE="$APP/Contents/MacOS/AXFixture" swift test --filter accessibilityOperatesBackgroundFixtureWithoutMovingCursorOrActivatingIt
