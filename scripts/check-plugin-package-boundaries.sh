#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="$ROOT_DIR/LumiApp/Plugins"
PLUGIN_PACKAGES_DIR="$ROOT_DIR/Plugins"

mode="${1:-strict}"
if [[ "$mode" != "strict" && "$mode" != "--allow-legacy" ]]; then
  echo "usage: $0 [strict|--allow-legacy]" >&2
  exit 2
fi

failures=0

echo "Checking LumiApp/Plugins package boundaries..."

while IFS= read -r -d '' dir; do
  name="$(basename "$dir")"
  if [[ -d "$PLUGIN_PACKAGES_DIR/Plugin${name%Plugin}" || -d "$PLUGIN_PACKAGES_DIR/${name}" ]]; then
    echo "  packaged adapter still uses a directory: LumiApp/Plugins/$name"
  else
    echo "  legacy plugin implementation directory: LumiApp/Plugins/$name"
  fi
  failures=$((failures + 1))
done < <(find "$PLUGINS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

while IFS= read -r -d '' file; do
  rel="${file#$ROOT_DIR/}"
  if [[ "$file" != *.swift ]]; then
    echo "  non-registration file in plugin root: $rel"
    failures=$((failures + 1))
    continue
  fi

  if ! rg -q '^import Plugin|^typealias .* = Plugin' "$file"; then
    echo "  root Swift file is not a package registration adapter: $rel"
    failures=$((failures + 1))
  fi
done < <(find "$PLUGINS_DIR" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

if [[ "$failures" -eq 0 ]]; then
  echo "OK: LumiApp/Plugins contains only package registration files."
  exit 0
fi

echo
echo "Found $failures plugin boundary issue(s)."
if [[ "$mode" == "--allow-legacy" ]]; then
  exit 0
fi

exit 1
