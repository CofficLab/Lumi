#!/bin/bash
#
# calculate-version.sh - Calculate the next semantic version
#
# This script calculates the next version number based on the
# increment type determined by bump-version.sh
#
# Usage: ./calculate-version.sh
# Output: <version> (e.g., 1.2.3)
#

set -euo pipefail

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get the increment type (major, minor, or patch)
INCREMENT_TYPE=$("${SCRIPT_DIR}/bump-version.sh")

# Get the last tag starting with 'v'
# Use sort -V to find the highest version number regardless of git history reachability
LAST_TAG=$(git tag -l "v*" | sort -V | tail -n 1 2>/dev/null || echo "v0.0.0")

# Strip 'v' prefix if present
LAST_TAG="${LAST_TAG#v}"

# Get the current version from Xcode project
# xcodebuild provides more reliable output than agvtool
XCODE_VERSION=$(xcodebuild -project Lumi.xcodeproj -showBuildSettings 2>/dev/null | grep -E "MARKETING_VERSION" | grep -v "CURRENT" | head -1 | awk -F'= ' '{print $2}' || echo "0.0.0")

# Compare versions and use the higher one
# sort -V does version-aware sorting (e.g., 1.10 > 1.9)
BASE_VERSION=$(echo -e "${LAST_TAG}\n${XCODE_VERSION}" | sort -V | tail -n 1)

echo "Git tag version: ${LAST_TAG}" >&2
echo "Xcode version: ${XCODE_VERSION}" >&2
echo "Using base version: ${BASE_VERSION}" >&2

# Use the base version for calculation
LAST_TAG="${BASE_VERSION}"

# Parse the version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$LAST_TAG"

# Handle case where version parsing failed or returned empty
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

# Calculate new version based on increment type
case $INCREMENT_TYPE in
  major)
    NEW_MAJOR=$((MAJOR + 1))
    NEW_VERSION="${NEW_MAJOR}.0.0"
    ;;
  minor)
    NEW_MINOR=$((MINOR + 1))
    NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
    ;;
  patch)
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
    ;;
  *)
    echo "Error: Unknown increment type '$INCREMENT_TYPE'" >&2
    exit 1
    ;;
esac

echo "$NEW_VERSION"
