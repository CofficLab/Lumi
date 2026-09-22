#!/usr/bin/env bash
# Inject the immutable release metadata into Lumi's two xcconfig files only.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $(basename "$0") <release-metadata.json>" >&2
  exit 2
fi

metadata="$1"
[ -f "${metadata}" ] || { echo "error: metadata not found: ${metadata}" >&2; exit 2; }

read -r marketing_version build_number source_sha <<EOF
$(python3 - "${metadata}" <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
version = data.get("marketing_version", "")
build = str(data.get("build_number", ""))
sha = data.get("source_sha", "")
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit("invalid marketing_version")
if not re.fullmatch(r"\d+", build):
    raise SystemExit("invalid build_number")
if not re.fullmatch(r"[0-9a-f]{40}", sha):
    raise SystemExit("invalid source_sha")
print(version, build, sha)
PY
)
EOF

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  actual_sha="$(git rev-parse HEAD)"
  if [ "${actual_sha}" != "${source_sha}" ]; then
    echo "error: checkout SHA ${actual_sha} does not match metadata ${source_sha}" >&2
    exit 1
  fi
fi

files=(
  "LumiApp/Config/Lumi-Debug.xcconfig"
  "LumiApp/Config/Lumi-Release.xcconfig"
)

for file in "${files[@]}"; do
  [ -f "${file}" ] || { echo "error: Lumi version config missing: ${file}" >&2; exit 1; }
  sed -i '' "s/^MARKETING_VERSION = .*/MARKETING_VERSION = ${marketing_version};/" "${file}"
  sed -i '' "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${build_number};/" "${file}"
  grep -qx "MARKETING_VERSION = ${marketing_version};" "${file}" || { echo "error: failed to inject version into ${file}" >&2; exit 1; }
  grep -qx "CURRENT_PROJECT_VERSION = ${build_number};" "${file}" || { echo "error: failed to inject build into ${file}" >&2; exit 1; }
done

echo "Injected Lumi ${marketing_version} (${build_number}) for ${source_sha}"
