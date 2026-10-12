#!/usr/bin/env bash
# Compute the immutable metadata shared by both architecture builds and publish.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: prepare-release-metadata.sh --channel stable|preview --source-sha SHA --run-id ID --output FILE [options]

Options:
  --download-root URL       Public Lumi download root (default: https://s.kuaiyizhi.cn/lumi)
  --marketing-version VER   Override calculate-version.sh (tests/recovery only)
  --previous-tag VER        Override the previous v* tag without the v prefix
  --timestamp-build NUMBER  Override the UTC YYYYMMDDHHmmss candidate
  --xcode-version VALUE     Override the detected Xcode version
  --stable-feed SOURCE      Required stable feed URL or local fixture; repeatable
  --preview-feed SOURCE     Optional preview feed URL or local fixture; repeatable
  --skip-default-feeds      Do not add the three production stable/preview feeds
EOF
  exit 2
}

channel=""
source_sha=""
run_id=""
output=""
download_root="https://s.kuaiyizhi.cn/lumi"
marketing_version=""
previous_tag=""
timestamp_build=""
xcode_version=""
skip_default_feeds=false
stable_feeds=()
preview_feeds=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --channel) channel="${2:-}"; shift 2 ;;
    --source-sha) source_sha="${2:-}"; shift 2 ;;
    --run-id) run_id="${2:-}"; shift 2 ;;
    --output) output="${2:-}"; shift 2 ;;
    --download-root) download_root="${2:-}"; shift 2 ;;
    --marketing-version) marketing_version="${2:-}"; shift 2 ;;
    --previous-tag) previous_tag="${2:-}"; shift 2 ;;
    --timestamp-build) timestamp_build="${2:-}"; shift 2 ;;
    --xcode-version) xcode_version="${2:-}"; shift 2 ;;
    --stable-feed) stable_feeds+=("${2:-}"); shift 2 ;;
    --preview-feed) preview_feeds+=("${2:-}"); shift 2 ;;
    --skip-default-feeds) skip_default_feeds=true; shift ;;
    *) echo "error: unknown option: $1" >&2; usage ;;
  esac
done

case "${channel}" in stable|preview) ;; *) usage ;; esac
[ -n "${source_sha}" ] && [ -n "${run_id}" ] && [ -n "${output}" ] || usage
[[ "${source_sha}" =~ ^[0-9a-fA-F]{40}$ ]] || { echo "error: source SHA must be 40 hexadecimal characters" >&2; exit 2; }
source_sha="$(printf '%s' "${source_sha}" | tr 'A-F' 'a-f')"
download_root="${download_root%/}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "${repo_root}"
actual_sha="$(git rev-parse HEAD 2>/dev/null || true)"
if [ -n "${actual_sha}" ] && [ "${actual_sha}" != "${source_sha}" ]; then
  echo "error: checkout SHA ${actual_sha} does not match requested source SHA ${source_sha}" >&2
  exit 1
fi

main_lock="Lumi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
acp_lock="Packages/FactoryLumiACP/Package.resolved"
for lock in "${main_lock}" "${acp_lock}"; do
  [ -f "${lock}" ] || { echo "error: required lock missing: ${lock}" >&2; exit 1; }
done

if [ -z "${marketing_version}" ]; then
  marketing_version="$(.github/scripts/calculate-version.sh)"
fi
[[ "${marketing_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "error: invalid marketing version: ${marketing_version}" >&2; exit 1; }

if [ -z "${previous_tag}" ]; then
  previous_tag="$(git tag -l 'v*' | sort -V | tail -n 1 2>/dev/null || true)"
  previous_tag="${previous_tag#v}"
  previous_tag="${previous_tag:-0.0.0}"
fi

extract_max() {
  awk -F'[<>]' '/<sparkle:version>/{ value = $3 + 0; if (value > max) max = value } END { print max + 0 }'
}

source_max=0
for file in LumiApp/Config/Lumi-Debug.xcconfig LumiApp/Config/Lumi-Release.xcconfig; do
  value="$(sed -n 's/^CURRENT_PROJECT_VERSION = \([0-9][0-9]*\);/\1/p' "${file}" | head -1)"
  if [[ "${value}" =~ ^[0-9]+$ ]] && (( value > source_max )); then source_max="${value}"; fi
done

history_max="$(git log --all -p -- appcast.xml appcast-arm64.xml appcast-x86_64.xml appcast-pre.xml appcast-pre-arm64.xml appcast-pre-x86_64.xml 2>/dev/null | extract_max)"

if [ "${skip_default_feeds}" = false ]; then
  stable_feeds+=(
    "${download_root}/appcast.xml"
    "${download_root}/appcast-arm64.xml"
    "${download_root}/appcast-x86_64.xml"
  )
  preview_feeds+=(
    "${download_root}/pre/appcast-pre.xml"
    "${download_root}/pre/appcast-pre-arm64.xml"
    "${download_root}/pre/appcast-pre-x86_64.xml"
  )
fi

read_feed() {
  case "$1" in
    http://*|https://*) curl -fsSL --retry 3 --max-time 20 "$1" ;;
    *) cat "$1" ;;
  esac
}

online_max=0
for feed_source in "${stable_feeds[@]}"; do
  feed="$(read_feed "${feed_source}")" || { echo "error: stable feed unavailable: ${feed_source}" >&2; exit 1; }
  value="$(printf '%s' "${feed}" | extract_max)"
  if (( value > online_max )); then online_max="${value}"; fi
done
for feed_source in "${preview_feeds[@]}"; do
  if feed="$(read_feed "${feed_source}" 2>/dev/null)"; then
    value="$(printf '%s' "${feed}" | extract_max)"
    if (( value > online_max )); then online_max="${value}"; fi
  else
    echo "info: optional preview feed unavailable: ${feed_source}" >&2
  fi
done

if [ -z "${timestamp_build}" ]; then timestamp_build="$(date -u +%Y%m%d%H%M%S)"; fi
[[ "${timestamp_build}" =~ ^[0-9]{14}$ ]] || { echo "error: build candidate must be 14 digits" >&2; exit 1; }
build_floor="$(printf '%s\n' "${source_max}" "${history_max}" "${online_max}" | sort -n | tail -1)"
if (( timestamp_build > build_floor )); then build_number="${timestamp_build}"; else build_number="$((build_floor + 1))"; fi

if [ "${channel}" = preview ]; then
  tag="p${marketing_version}(${build_number})"
  r2_prefix="lumi/pre"
  channel_download_root="${download_root}/pre"
  is_prerelease=true
else
  tag="v${marketing_version}"
  r2_prefix="lumi"
  channel_download_root="${download_root}"
  is_prerelease=false
fi

if [ -z "${xcode_version}" ]; then
  xcode_version="$(xcodebuild -version | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
fi

main_lock_hash="$(shasum -a 256 "${main_lock}" | awk '{print $1}')"
acp_lock_hash="$(shasum -a 256 "${acp_lock}" | awk '{print $1}')"
mkdir -p "$(dirname "${output}")"

SOURCE_SHA="${source_sha}" RUN_ID="${run_id}" MARKETING_VERSION="${marketing_version}" \
BUILD_NUMBER="${build_number}" BUILD_FLOOR="${build_floor}" TAG="${tag}" CHANNEL="${channel}" \
DOWNLOAD_ROOT="${channel_download_root}" R2_PREFIX="${r2_prefix}" PREVIOUS_TAG="${previous_tag}" \
XCODE_VERSION="${xcode_version}" MAIN_LOCK_HASH="${main_lock_hash}" ACP_LOCK_HASH="${acp_lock_hash}" \
IS_PRERELEASE="${is_prerelease}" OUTPUT="${output}" python3 - <<'PY'
import json, os
version = os.environ["MARKETING_VERSION"]
build = os.environ["BUILD_NUMBER"]
metadata = {
    "schema_version": 1,
    "source_sha": os.environ["SOURCE_SHA"].lower(),
    "run_id": str(os.environ["RUN_ID"]),
    "marketing_version": version,
    "build_number": str(build),
    "build_floor": str(os.environ["BUILD_FLOOR"]),
    "tag": os.environ["TAG"],
    "channel": os.environ["CHANNEL"],
    "download_root": os.environ["DOWNLOAD_ROOT"],
    "r2_prefix": os.environ["R2_PREFIX"],
    "previous_tag": os.environ["PREVIOUS_TAG"],
    "is_prerelease": os.environ["IS_PRERELEASE"] == "true",
    "xcode_version": os.environ["XCODE_VERSION"],
    "lock_hashes": {
        "main": os.environ["MAIN_LOCK_HASH"],
        "acp": os.environ["ACP_LOCK_HASH"],
    },
    "dmg_filenames": {
        arch: f"Lumi_{version}_{build}_{arch}.dmg" for arch in ("arm64", "x86_64")
    },
    "dsym_filenames": {
        arch: f"Lumi_{version}_{build}_{arch}_dSYMs.zip" for arch in ("arm64", "x86_64")
    },
    "state_filename": f"release-state-{build}.json",
}
with open(os.environ["OUTPUT"], "w", encoding="utf-8") as handle:
    json.dump(metadata, handle, ensure_ascii=False, indent=2, sort_keys=True)
    handle.write("\n")
PY

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  while IFS='=' read -r key value; do printf '%s=%s\n' "${key}" "${value}" >> "${GITHUB_OUTPUT}"; done <<EOF
source_sha=${source_sha}
marketing_version=${marketing_version}
build_number=${build_number}
build_floor=${build_floor}
tag=${tag}
channel=${channel}
is_prerelease=${is_prerelease}
previous_tag=${previous_tag}
EOF
fi

echo "Prepared ${channel} metadata: ${marketing_version} (${build_number}) from ${source_sha}"
