#!/bin/bash
#
# sync-versions.sh - Synchronize versions across all targets
#
# This script ensures all targets in the Xcode project have the same
# MARKETING_VERSION and CURRENT_PROJECT_VERSION.
#
# Usage: ./.github/scripts/sync-versions.sh [version] [build_number]
# Example: ./.github/scripts/sync-versions.sh 1.0.8 10
#

set -euo pipefail

# Find the Xcode project file
PROJECT_FILE=$(find $(pwd) -type f -name "*.pbxproj" -not -path "*/.build/*" | head -n 1)

if [ -z "$PROJECT_FILE" ]; then
  echo "Error: Cannot find .pbxproj file" >&2
  exit 1
fi

# Get version from parameters or use current highest version
if [ -n "${1:-}" ]; then
  MARKETING_VERSION="$1"
else
  # Find the highest version among all targets
  MARKETING_VERSION=$(grep -o 'MARKETING_VERSION = [0-9]\+\.[0-9]\+\.[0-9]\+' "$PROJECT_FILE" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | sort -V | tail -n 1)
fi

if [ -n "${2:-}" ]; then
  BUILD_NUMBER="$2"
else
  # Find the highest build number among all targets
  BUILD_NUMBER=$(grep -o 'CURRENT_PROJECT_VERSION = [0-9]\+' "$PROJECT_FILE" | grep -o '[0-9]\+' | sort -n | tail -n 1)
fi

echo "🔧 Syncing versions:" >&2
echo "   MARKETING_VERSION: $MARKETING_VERSION" >&2
echo "   CURRENT_PROJECT_VERSION: $BUILD_NUMBER" >&2

# Update all MARKETING_VERSION entries (matches both x.y and x.y.z)
sed -i '' -E "s/MARKETING_VERSION = [0-9]+\.[0-9]+(\.[0-9]+)?/MARKETING_VERSION = $MARKETING_VERSION/g" "$PROJECT_FILE"

# Update all CURRENT_PROJECT_VERSION entries
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+/CURRENT_PROJECT_VERSION = $BUILD_NUMBER/g" "$PROJECT_FILE"

# Count updates
VERSION_COUNT=$(grep -c "MARKETING_VERSION = $MARKETING_VERSION" "$PROJECT_FILE")
BUILD_COUNT=$(grep -c "CURRENT_PROJECT_VERSION = $BUILD_NUMBER" "$PROJECT_FILE")

echo "✅ Updated $VERSION_COUNT MARKETING_VERSION entries" >&2
echo "✅ Updated $BUILD_COUNT CURRENT_PROJECT_VERSION entries" >&2
echo "" >&2
echo "📋 All targets now using:" >&2
echo "   Version: $MARKETING_VERSION" >&2
echo "   Build: $BUILD_NUMBER" >&2
