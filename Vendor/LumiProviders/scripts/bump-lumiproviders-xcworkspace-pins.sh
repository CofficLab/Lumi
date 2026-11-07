#!/bin/bash
# Bump the LumiProviders pin in xcodeproj workspace lock files.
#
# `swift package update` cannot touch xcodeproj workspaces, so this rewrites the
# single pin in place. Only the version and revision bytes change; the rest of
# the file keeps Xcode's exact formatting so the diff stays reviewable.
#
# Usage: scripts/bump-lumiproviders-xcworkspace-pins.sh <commit-sha> [--dry-run]
#
# Defaults to LP_VERSION (1.11.0) when no commit sha is given.

set -uo pipefail

COFFIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="https://github.com/CofficLab/LumiProviders.git"
REVISION=""
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) REVISION="$arg" ;;
  esac
done

if [[ -z "$REVISION" ]]; then
  # Tags are annotated, so `refs/tags/X` resolves to the tag object while
  # `refs/tags/X^{}` peels it to the commit. Package.resolved pins the commit,
  # so only the peeled ref is usable here.
  REVISION="$(git ls-remote "$REPO" "refs/tags/${LP_VERSION:-1.11.0}^{}" | awk '{print $1}')"
fi
[[ -z "$REVISION" ]] && { echo "Cannot resolve revision" >&2; exit 1; }

VERSION="${LP_VERSION:-1.11.0}"
log() { printf '%s\n' "$*"; }

LOCKS="$(find "$COFFIC_DIR" -name Package.resolved -path "*xcshareddata/swiftpm*" \
  -not -path "*/.build/*" -not -path "*SourcePackages*" 2>/dev/null | sort)"

changed=0
pending=0
for lock in $LOCKS; do
  grep -q "lumiproviders" "$lock" 2>/dev/null || continue

  python3 - "$lock" "$REVISION" "$VERSION" "$DRY_RUN" <<'PY'
import re, sys
path, rev, ver, dry = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
raw = open(path).read()
if '"lumiproviders"' not in raw:
    sys.exit(3)
i = raw.index('"lumiproviders"')
j = raw.index('}', raw.index('"state"', i))
block = raw[i:j]
old_rev = re.search(r'"revision"\s*:\s*"([0-9a-f]+)"', block)
old_ver = re.search(r'"version"\s*:\s*"([0-9.]+)"', block)
if not old_rev or not old_ver or (old_ver.group(1) == ver and old_rev.group(1) == rev):
    sys.exit(3)
print(f"  {old_ver.group(1)} {old_rev.group(1)[:12]} -> {ver} {rev[:12]}  {path}")
if dry:
    sys.exit(1)
block2 = block.replace(old_rev.group(1), rev).replace(f'"{old_ver.group(1)}"', f'"{ver}"')
open(path, 'w').write(raw[:i] + block2 + raw[j:])
sys.exit(0)
PY
  case $? in
    0) changed=$((changed+1)) ;;
    1) pending=$((pending+1)) ;;
    *) : ;;
  esac
done

log ""
log "workspaces updated: $changed (revision $REVISION, version $VERSION)"
if [[ $pending -gt 0 ]]; then
  log "dry run: $pending pending change(s) not written"
fi
exit 0
