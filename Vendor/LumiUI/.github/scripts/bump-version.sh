#!/usr/bin/env bash
#
# Calculate the semantic-version increment from Conventional Commits.
# Output: major | minor | patch
#

set -euo pipefail

VERSION_TAGS=$(git tag --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)
LAST_TAG=$(printf '%s\n' "$VERSION_TAGS" | sed '/^$/d' | sort -V | tail -n 1)

if [ -n "$LAST_TAG" ]; then
  COMMITS=$(git log "$LAST_TAG..HEAD" --pretty=format:%B 2>/dev/null || true)
else
  COMMITS=$(git log HEAD --pretty=format:%B 2>/dev/null || true)
fi

if [ -z "$COMMITS" ]; then
  echo "patch"
  exit 0
fi

if printf '%s\n' "$COMMITS" | grep -E '(^BREAKING CHANGE|^(feat|fix|refactor)(\([^)]*\))?!:)' >/dev/null; then
  echo "major"
elif printf '%s\n' "$COMMITS" | grep -E '^feat(\([^)]*\))?:' >/dev/null; then
  echo "minor"
else
  echo "patch"
fi
