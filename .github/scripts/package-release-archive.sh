#!/usr/bin/env bash
# Package one verified xcarchive into a provenance-carrying transfer artifact.

set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $(basename "$0") <archive> <arm64|x86_64> <release-metadata.json> <output-dir>" >&2
  exit 2
fi

archive="$1"
arch="$2"
metadata="$3"
output_dir="$4"

case "${arch}" in arm64|x86_64) ;; *) echo "error: unsupported architecture: ${arch}" >&2; exit 2 ;; esac
[ -d "${archive}" ] || { echo "error: archive not found: ${archive}" >&2; exit 2; }
[ -f "${metadata}" ] || { echo "error: metadata not found: ${metadata}" >&2; exit 2; }

expected_root="Lumi-${arch}.xcarchive"
if [ "$(basename "${archive}")" != "${expected_root}" ]; then
  echo "error: archive root must be named ${expected_root}" >&2
  exit 2
fi

read -r version build source_sha run_id <<EOF
$(python3 - "${metadata}" <<'PY'
import json, re, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
values = (d.get("marketing_version", ""), str(d.get("build_number", "")), d.get("source_sha", ""), str(d.get("run_id", "")))
if not re.fullmatch(r"\d+\.\d+\.\d+", values[0]) or not re.fullmatch(r"\d+", values[1]) or not re.fullmatch(r"[0-9a-f]{40}", values[2]) or not values[3]:
    raise SystemExit("invalid release metadata")
print(*values)
PY
)
EOF

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${script_dir}/verify-release-archive.sh" "${archive}" "${arch}" --expected-version "${version}" --expected-build "${build}"

mkdir -p "${output_dir}"
archive_file="Lumi-${arch}.xcarchive.tar.gz"
archive_tar="${output_dir}/${archive_file}"
rm -f "${archive_tar}"
tar -C "$(dirname "${archive}")" -czf "${archive_tar}" "${expected_root}"
archive_sha256="$(shasum -a 256 "${archive_tar}" | awk '{print $1}')"

app="${archive}/Products/Applications/Lumi.app"
main_binary="${app}/Contents/MacOS/Lumi"
helper="${app}/Contents/MacOS/lumi-acp"
main_uuid="$(dwarfdump -u "${main_binary}" 2>/dev/null | awk -v a="${arch}" '$0 ~ "\\(" a "\\)" {print $2; exit}')"
if [ -z "${main_uuid}" ]; then main_uuid="$(dwarfdump -u "${main_binary}" 2>/dev/null | awk 'NR==1 {print $2}')"; fi
helper_archs="$(lipo -archs "${helper}" | xargs)"
actual_xcode_build="$(xcodebuild -version | tail -1 | awk '{print $NF}')"
sdk_version="$(xcrun --sdk macosx --show-sdk-version)"
runner_image="${ImageOS:-${RUNNER_IMAGE:-local}}"

cp "${metadata}" "${output_dir}/release-metadata.json"

ARCHIVE_FILE="${archive_file}" ARCHIVE_SHA256="${archive_sha256}" TARGET_ARCH="${arch}" \
MAIN_UUID="${main_uuid}" HELPER_ARCHS="${helper_archs}" ACTUAL_XCODE_BUILD="${actual_xcode_build}" \
SDK_VERSION="${sdk_version}" RUNNER_IMAGE="${runner_image}" METADATA="${metadata}" \
MANIFEST="${output_dir}/manifest.json" python3 - <<'PY'
import json, os
release = json.load(open(os.environ["METADATA"], encoding="utf-8"))
manifest = {
    "schema_version": 1,
    "release": release,
    "target_arch": os.environ["TARGET_ARCH"],
    "archive_root": f"Lumi-{os.environ['TARGET_ARCH']}.xcarchive",
    "archive_file": os.environ["ARCHIVE_FILE"],
    "archive_sha256": os.environ["ARCHIVE_SHA256"],
    "actual_xcode_build": os.environ["ACTUAL_XCODE_BUILD"],
    "sdk_version": os.environ["SDK_VERSION"],
    "runner_image": os.environ["RUNNER_IMAGE"],
    "main_uuid": os.environ["MAIN_UUID"],
    "helper_archs": os.environ["HELPER_ARCHS"].split(),
}
with open(os.environ["MANIFEST"], "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=2, sort_keys=True)
    handle.write("\n")
PY

echo "Packaged ${expected_root}: ${archive_sha256}"
