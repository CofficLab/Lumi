#!/usr/bin/env bash
#
# Generate GitHub Release notes from commit subjects.
# Usage: generate-changelog.sh <current-version> [previous-version]
#

set -euo pipefail

CURRENT_VERSION="${1:?Current version is required}"
PREVIOUS_VERSION="${2:-}"

if [ -n "$PREVIOUS_VERSION" ]; then
  COMMIT_SUBJECTS=$(git log "$PREVIOUS_VERSION..HEAD" --no-merges --pretty=format:'- %s' 2>/dev/null || true)
  RANGE_LABEL="since $PREVIOUS_VERSION"
else
  COMMIT_SUBJECTS=$(git log HEAD --no-merges --pretty=format:'- %s' 2>/dev/null || true)
  RANGE_LABEL="since the initial release"
fi

# Keep user-facing changes and omit maintenance commits, matching Lumi's release notes.
CHANGES=$(printf '%s\n' "$COMMIT_SUBJECTS" \
  | grep -Ev '^- (ci|chore|build|style|test)(\(|:)' \
  | sort -u \
  | sed -n '1,50p' || true)

if [ -z "$CHANGES" ]; then
  CHANGES="- Maintenance and stability improvements"
fi

cat <<EOF
## Release $CURRENT_VERSION

### Changes $RANGE_LABEL

$CHANGES
EOF
