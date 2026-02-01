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
LAST_TAG=$(git describe --tags --match "v*" --abbrev=0 2>/dev/null || echo "v0.0.0")

# Strip 'v' prefix if present
LAST_TAG="${LAST_TAG#v}"

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
