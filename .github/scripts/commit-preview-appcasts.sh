#!/usr/bin/env bash
# Commit only preview fallback feeds to the current pre branch without force-pushing.

set -euo pipefail
if [ "$#" -ne 2 ]; then echo "usage: $0 <asset-dir> <metadata.json>" >&2; exit 2; fi
asset_dir="$(cd "$1" && pwd)"; metadata="$2"
channel="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["channel"])' "${metadata}")"
[ "${channel}" = preview ] || { echo "error: fallback commit is preview-only" >&2; exit 2; }
files=(appcast-pre.xml appcast-pre-arm64.xml appcast-pre-x86_64.xml)
for file in "${files[@]}"; do [ -f "${asset_dir}/${file}" ] || exit 2; done

worktree="${RUNNER_TEMP:-/tmp}/lumi-preview-feed"
for attempt in 1 2 3; do
  git worktree remove --force "${worktree}" >/dev/null 2>&1 || true
  git fetch origin pre
  git worktree add --detach "${worktree}" origin/pre
  for file in "${files[@]}"; do cp "${asset_dir}/${file}" "${worktree}/${file}"; done
  git -C "${worktree}" add -- "${files[@]}"
  if git -C "${worktree}" diff --cached --quiet; then
    git worktree remove --force "${worktree}"
    echo "Preview fallback feeds already match"
    exit 0
  fi
  git -C "${worktree}" -c user.name='GitHub Action' -c user.email='action@github.com' \
    commit -m "ci: update preview appcasts"
  if git -C "${worktree}" push origin HEAD:pre; then
    git worktree remove --force "${worktree}"
    exit 0
  fi
  git worktree remove --force "${worktree}"
  echo "pre advanced while publishing; retrying (${attempt}/3)" >&2
done
echo "error: could not update preview fallback feeds without rewriting pre" >&2
exit 1
