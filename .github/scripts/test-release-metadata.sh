#!/usr/bin/env bash
# Tests immutable release metadata generation and xcconfig injection.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
metadata_script="${script_dir}/prepare-release-metadata.sh"
inject_script="${script_dir}/inject-lumi-version.sh"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

repo="${work}/repo"
mkdir -p "${repo}/.github/scripts" "${repo}/LumiApp/Config" \
  "${repo}/Lumi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm" \
  "${repo}/Packages/FactoryLumiACP"
cp "${metadata_script}" "${inject_script}" "${repo}/.github/scripts/"
printf '{"pins":[]}\n' > "${repo}/Lumi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
printf '{"pins":[]}\n' > "${repo}/Packages/FactoryLumiACP/Package.resolved"
for name in Debug Release; do
  printf 'MARKETING_VERSION = 1.0.0;\nCURRENT_PROJECT_VERSION = 20260101000000;\n' \
    > "${repo}/LumiApp/Config/Lumi-${name}.xcconfig"
done
git -C "${repo}" init -q
git -C "${repo}" config user.name Test
git -C "${repo}" config user.email test@example.com
git -C "${repo}" add .
git -C "${repo}" commit -qm initial
sha="$(git -C "${repo}" rev-parse HEAD)"

printf '<sparkle:version>20270101000000</sparkle:version>\n' > "${work}/stable.xml"
printf '<sparkle:version>20270101000005</sparkle:version>\n' > "${work}/preview.xml"

run_prepare() {
  (cd "${repo}" && .github/scripts/prepare-release-metadata.sh \
    --channel "$1" --source-sha "${sha}" --run-id 42 --output "$2" \
    --marketing-version 6.1.0 --previous-tag 6.0.0 --timestamp-build 20270101000000 \
    --xcode-version 'Xcode 26.3 Build version 17C999' --skip-default-feeds \
    --stable-feed "${work}/stable.xml" --preview-feed "${work}/preview.xml")
}

stable="${work}/stable.json"
run_prepare stable "${stable}"
python3 - "${stable}" "${sha}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["source_sha"] == sys.argv[2]
assert d["build_floor"] == "20270101000005"
assert d["build_number"] == "20270101000006"
assert d["tag"] == "v6.1.0" and not d["is_prerelease"]
assert d["dmg_filenames"]["arm64"] == "Lumi_6.1.0_20270101000006_arm64.dmg"
assert d["state_filename"] == "release-state-20270101000006.json"
assert "secret" not in json.dumps(d).lower()
PY

preview="${work}/preview.json"
run_prepare preview "${preview}"
python3 - "${preview}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d["tag"] == "p6.1.0(20270101000006)"
assert d["channel"] == "preview" and d["is_prerelease"]
assert d["download_root"].endswith("/pre") and d["r2_prefix"] == "lumi/pre"
PY

(cd "${repo}" && .github/scripts/inject-lumi-version.sh "${stable}")
for file in "${repo}"/LumiApp/Config/Lumi-*.xcconfig; do
  grep -qx 'MARKETING_VERSION = 6.1.0;' "${file}"
  grep -qx 'CURRENT_PROJECT_VERSION = 20270101000006;' "${file}"
done

bad="${work}/bad.json"
python3 - "${stable}" "${bad}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); d["source_sha"] = "0" * 40
json.dump(d, open(sys.argv[2], "w"))
PY
if (cd "${repo}" && .github/scripts/inject-lumi-version.sh "${bad}" >/dev/null 2>&1); then
  echo "error: injector accepted metadata for a different source SHA" >&2
  exit 1
fi

if (cd "${repo}" && .github/scripts/prepare-release-metadata.sh \
  --channel stable --source-sha "${sha}" --run-id 43 --output "${work}/missing.json" \
  --marketing-version 6.1.0 --timestamp-build 20270101000000 --skip-default-feeds \
  --stable-feed "${work}/does-not-exist.xml" >/dev/null 2>&1); then
  echo "error: stable feed failure was not fatal" >&2
  exit 1
fi

echo "✅ test-release-metadata.sh: metadata, monotonic counter, channels, injection, and failures passed"
