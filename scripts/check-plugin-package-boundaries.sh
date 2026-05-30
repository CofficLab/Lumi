#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PLUGINS_DIR="$ROOT_DIR/LumiApp/Plugins"
PLUGIN_PACKAGES_DIR="$ROOT_DIR/Plugins"

mode="${1:-strict}"
if [[ "$mode" != "strict" && "$mode" != "--allow-legacy" ]]; then
  echo "usage: $0 [strict|--allow-legacy]" >&2
  exit 2
fi

failures=0

echo "Checking plugin package boundaries..."

if [[ -e "$APP_PLUGINS_DIR" ]]; then
  echo "  legacy app plugin directory still exists: LumiApp/Plugins"
  failures=$((failures + 1))
fi

if [[ ! -d "$PLUGIN_PACKAGES_DIR" ]]; then
  echo "  plugin package root is missing: Plugins"
  failures=$((failures + 1))
else
  while IFS= read -r -d '' dir; do
    name="$(basename "$dir")"
    if [[ ! "$name" =~ ^Plugin[A-Za-z0-9]+$ ]]; then
      echo "  unexpected plugin package directory name: Plugins/$name"
      failures=$((failures + 1))
      continue
    fi

    if [[ ! -f "$dir/Package.swift" ]]; then
      echo "  plugin package missing Package.swift: Plugins/$name"
      failures=$((failures + 1))
    fi

    if [[ ! -d "$dir/Sources/$name" ]]; then
      echo "  plugin package missing Sources/$name: Plugins/$name"
      failures=$((failures + 1))
    fi
  done < <(find "$PLUGIN_PACKAGES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
fi

if [[ "$failures" -eq 0 ]]; then
  echo "OK: plugin logic lives in package directories under Plugins/."
  exit 0
fi

echo
echo "Found $failures plugin boundary issue(s)."
if [[ "$mode" == "--allow-legacy" ]]; then
  exit 0
fi

exit 1
