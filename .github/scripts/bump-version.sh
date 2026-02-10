#!/bin/bash
#
# bump-version.sh - Calculate next version based on Conventional Commits
#
# This script analyzes commits since the last tag and determines the
# appropriate version increment (major, minor, or patch) following
# Semantic Versioning 2.0.0 and Conventional Commits specifications.
#
# Usage: ./bump-version.sh
# Output: major|minor|patch
#

set -euo pipefail

# Get the most recent tag starting with 'v', or default to v0.0.0 if no tags exist
# Use sort -V to find the highest version number regardless of git history reachability
LAST_TAG=$(git tag -l "v*" | sort -V | tail -n 1 2>/dev/null || echo "v0.0.0")

# Get all commit messages since the last tag
COMMITS=$(git log ${LAST_TAG}..HEAD --pretty=format:%s 2>/dev/null || echo "")

# If no commits found, default to patch
if [ -z "$COMMITS" ]; then
  echo "patch"
  exit 0
fi

# Check for breaking changes
# BREAKING CHANGE: in commit body
# feat!: or fix!: in commit subject (conventional commits with !)
if echo "$COMMITS" | grep -qE "BREAKING CHANGE|^feat!|^fix!|^refactor!"; then
  echo "major"
  exit 0
fi

# Check for new features
if echo "$COMMITS" | grep -qE "^feat:"; then
  echo "minor"
  exit 0
fi

# Default to patch for bug fixes and other changes
echo "patch"
