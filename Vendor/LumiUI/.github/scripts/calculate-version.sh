#!/usr/bin/env bash
#
# Calculate the next LumiUI release version.
# Output: <version>, for example 1.0.2
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_TAGS=$(git tag --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true)
LAST_TAG=$(printf '%s\n' "$VERSION_TAGS" | sed '/^$/d' | sort -V | tail -n 1)

# Keep the first standalone package release at 1.0.0.
if [ -z "$LAST_TAG" ]; then
  echo "1.0.0"
  exit 0
fi

INCREMENT_TYPE=$("$SCRIPT_DIR/bump-version.sh")
IFS='.' read -r MAJOR MINOR PATCH <<< "$LAST_TAG"

case "$INCREMENT_TYPE" in
  major)
    echo "$((MAJOR + 1)).0.0"
    ;;
  minor)
    echo "$MAJOR.$((MINOR + 1)).0"
    ;;
  patch)
    echo "$MAJOR.$MINOR.$((PATCH + 1))"
    ;;
  *)
    echo "Unknown increment type: $INCREMENT_TYPE" >&2
    exit 1
    ;;
esac
