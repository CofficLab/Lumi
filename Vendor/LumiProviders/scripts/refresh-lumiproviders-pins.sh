#!/bin/bash
# Refresh the LumiProviders pin in every Package.resolved that pins it.
#
# All dependents declare `from: "x.y.z"`, so any newer tag is semver-compatible
# with every existing constraint; only the resolved pin needs to move forward.
#
# Each package runs under `timeout` (where available) so one slow dependency
# graph cannot stall the whole sweep.
#
# Usage: scripts/refresh-lumiproviders-pins.sh [--dry-run] [--deadline N]
#
# LP_VERSION selects the target tag and defaults to the newest release tag, so a
# new release is picked up without editing this script.

set -uo pipefail

COFFIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="https://github.com/CofficLab/LumiProviders.git"
DRY_RUN=0
PER_PACKAGE_TIMEOUT="${LP_TIMEOUT:-120}"
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

log() { printf '%s\n' "$*"; }

# Default to the newest release tag rather than pinning a version in the script:
# a hardcoded target silently marks every package as stale after each release.
TARGET_VERSION="${LP_VERSION:-}"
if [[ -z "$TARGET_VERSION" ]]; then
  TARGET_VERSION="$(git ls-remote --tags --refs "$REPO" 2>/dev/null \
    | awk '{print $2}' | sed 's|refs/tags/||' | sort -V | tail -1)"
fi
[[ -z "$TARGET_VERSION" ]] && { echo "Cannot resolve target version" >&2; exit 1; }

# macOS ships bash 3.2 and no coreutils `timeout`; fall back to a plain run.
RUNNER=""
command -v gtimeout >/dev/null 2>&1 && RUNNER="gtimeout"
[[ -z "$RUNNER" ]] && command -v timeout >/dev/null 2>&1 && RUNNER="timeout"
[[ -z "$RUNNER" ]] && RUNNER="__none__"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

find "$COFFIC_DIR" -name Package.resolved \
  -not -path "*/.build/*" \
  -not -path "*/checkouts/*" \
  -not -path "*SourcePackages*" \
  -not -path "*/build/*" \
  -print0 2>/dev/null \
  | xargs -0 grep -l "lumiproviders" 2>/dev/null | sort > "$WORK/locks.txt"

log "Found $(wc -l < "$WORK/locks.txt" | tr -d ' ') lock files pinning LumiProviders"

: > "$WORK/targets.txt"
while IFS= read -r lock; do
  dir="$(dirname "$lock")"
  [[ -f "$dir/Package.swift" ]] || continue
  echo "$dir" >> "$WORK/targets.txt"
done < "$WORK/locks.txt"
sort -u "$WORK/targets.txt" -o "$WORK/targets.txt"

log "Resolved to $(wc -l < "$WORK/targets.txt" | tr -d ' ') unique packages"

if [[ $DRY_RUN -eq 1 ]]; then
  sed "s|$COFFIC_DIR/||" "$WORK/targets.txt"
  exit 0
fi

# Skip packages already on the target version so re-runs are cheap and idempotent.
: > "$WORK/pending.txt"
while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  if python3 - "$dir/Package.resolved" "$TARGET_VERSION" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if any("lumiproviders" in p.get("identity","").lower()
                  and p.get("state",{}).get("version") == sys.argv[2]
                  for p in d.get("pins", [])) else 1)
PY
  then
    continue
  fi
  echo "$dir" >> "$WORK/pending.txt"
done < "$WORK/targets.txt"

PENDING=$(wc -l < "$WORK/pending.txt" | tr -d ' ')
log "$PENDING packages need an update to $TARGET_VERSION"

ok=0; fail=0; skip=0; timedout=0
: > "$WORK/failed.txt"
while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  name="${dir#$COFFIC_DIR/}"
  if [[ "$RUNNER" == "__none__" ]]; then
    (cd "$dir" && swift package update lumiproviders) >"$WORK/update.log" 2>&1
    rc=$?
  else
    (cd "$dir" && "$RUNNER" "$PER_PACKAGE_TIMEOUT" swift package update lumiproviders) \
      >"$WORK/update.log" 2>&1
    rc=$?
  fi
  if [[ $rc -eq 0 ]]; then
    ok=$((ok+1))
  elif [[ $rc -eq 124 || $rc -eq 137 ]]; then
    timedout=$((timedout+1))
    echo "$name" >> "$WORK/failed.txt"
    log "  TIMEOUT  $name"
  elif grep -qi "does not depend on\|not a dependency\|not found in the dependency graph" "$WORK/update.log"; then
    skip=$((skip+1))
  else
    fail=$((fail+1))
    echo "$name" >> "$WORK/failed.txt"
    log "  FAIL  $name"
    tail -2 "$WORK/update.log" | sed 's/^/        /'
  fi
done < "$WORK/pending.txt"

log ""
log "target version: $TARGET_VERSION"
log "updated=$ok  skipped=$skip  failed=$fail  timeout=$timedout"
if [[ -s "$WORK/failed.txt" ]]; then
  log "Needs manual attention:"
  sed 's/^/  /' "$WORK/failed.txt"
fi

# Fail loudly when packages need attention, so CI does not read a broken sweep
# as a clean run. A timeout counts as needing attention, not as success.
[[ $((fail + timedout)) -eq 0 ]]
