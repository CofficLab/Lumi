#!/usr/bin/env bash
#
# collect-build-metrics.sh — gather build environment and archive metrics.
#
# Outputs a JSON summary of the CI environment and any produced archives so
# that release diagnostics can be compared across runs. All fields are
# best-effort: a missing tool or unreadable value becomes null rather than
# aborting the script.
#
# Usage:
#   collect-build-metrics.sh [--archive-dir <path>] [--output <path>]
#
# Options:
#   --archive-dir <path>   directory containing .xcarchive bundles
#                           (default: ./temp)
#   --output <path>        write JSON to this file instead of stdout
#
# Environment variables (override defaults):
#   ARCHIVE_DIR            fallback when --archive-dir is not passed
#   SOURCE_SHA             git SHA to record (default: git rev-parse HEAD)

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
archive_dir="${ARCHIVE_DIR:-./temp}"
output_path=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --archive-dir)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "usage: $(basename "$0") [--archive-dir <path>] [--output <path>]" >&2
        exit 2
      fi
      archive_dir="$2"
      shift 2
      ;;
    --output)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "usage: $(basename "$0") [--archive-dir <path>] [--output <path>]" >&2
        exit 2
      fi
      output_path="$2"
      shift 2
      ;;
    *)
      echo "usage: $(basename "$0") [--archive-dir <path>] [--output <path>]" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# json_string: emit a JSON-safe quoted string or the literal null.
json_string() {
  local value="${1:-}"
  if [ -z "${value}" ]; then
    echo "null"
    return
  fi
  # Escape backslashes, double quotes, and control characters for JSON.
  printf '"%s"' "$(printf '%s' "${value}" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')"
}

# json_number: emit a number or null.
json_number() {
  local value="${1:-}"
  if [ -z "${value}" ] || ! [[ "${value}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "null"
    return
  fi
  echo "${value}"
}

# safe_command: run a command, return empty string on failure.
safe_command() {
  "$@" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Toolchain info
# ---------------------------------------------------------------------------
xcode_version="$(safe_command xcodebuild -version | head -1 | sed 's/^Xcode //')"
xcode_build="$(safe_command xcodebuild -version | sed -n '2p' | sed 's/^Build version //')"
swift_version="$(safe_command swift --version | head -1 | sed 's/.*version //' | sed 's/ (.*//')"
sdk_path="$(safe_command xcrun --sdk macosx --show-sdk-path)"
sdk_version="$(safe_command xcrun --sdk macosx --show-sdk-version)"

# ---------------------------------------------------------------------------
# Runner / OS info
# ---------------------------------------------------------------------------
runner_os="$(uname -s)"
runner_arch="$(uname -m)"
runner_image="${RUNNER_IMAGE:-}"
if [ -z "${runner_image}" ]; then
  # GitHub-hosted runners set ImageVersion; fall back to sw_vers.
  if [ -n "${ImageVersion:-}" ]; then
    runner_image="macOS-$(sw_vers -productVersion 2>/dev/null || echo 'unknown')-${ImageVersion}"
  else
    runner_image="macOS-$(sw_vers -productVersion 2>/dev/null || echo 'unknown')"
  fi
fi
kernel_version="$(uname -r)"

# ---------------------------------------------------------------------------
# Hardware info
# ---------------------------------------------------------------------------
cpu_model=""
cpu_cores=""
memory_bytes=""
memory_gb=""

if [ "${runner_os}" = "Darwin" ]; then
  cpu_model="$(safe_command sysctl -n machdep.cpu.brand_string 2>/dev/null)"
  cpu_cores="$(safe_command sysctl -n hw.ncpu)"
  memory_bytes="$(safe_command sysctl -n hw.memsize)"
  if [ -n "${memory_bytes}" ]; then
    memory_gb="$(awk "BEGIN { printf \"%.1f\", ${memory_bytes} / 1073741824 }")"
  fi
fi

# ---------------------------------------------------------------------------
# Disk info (volume containing archive_dir)
# ---------------------------------------------------------------------------
disk_total_gb=""
disk_free_gb=""
if [ -d "${archive_dir}" ] || mkdir -p "${archive_dir}" 2>/dev/null; then
  # df -g may not exist on all platforms; fall back to df -k.
  disk_line="$(safe_command df -Pk "${archive_dir}" | tail -1)"
  if [ -n "${disk_line}" ]; then
    disk_total_kb="$(echo "${disk_line}" | awk '{print $2}')"
    disk_free_kb="$(echo "${disk_line}" | awk '{print $4}')"
    if [ -n "${disk_total_kb}" ] && [[ "${disk_total_kb}" =~ ^[0-9]+$ ]]; then
      disk_total_gb="$(awk "BEGIN { printf \"%.1f\", ${disk_total_kb} / 1048576 }")"
    fi
    if [ -n "${disk_free_kb}" ] && [[ "${disk_free_kb}" =~ ^[0-9]+$ ]]; then
      disk_free_gb="$(awk "BEGIN { printf \"%.1f\", ${disk_free_kb} / 1048576 }")"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Source info
# ---------------------------------------------------------------------------
source_sha="${SOURCE_SHA:-}"
if [ -z "${source_sha}" ]; then
  source_sha="$(safe_command git rev-parse HEAD)"
fi

# ---------------------------------------------------------------------------
# Archive metrics
# ---------------------------------------------------------------------------
archives_json="[]"
archive_count=0

if [ -d "${archive_dir}" ]; then
  archive_entries=""
  for xcarchive in "${archive_dir}"/*.xcarchive; do
    [ -d "${xcarchive}" ] || continue
    archive_count=$((archive_count + 1))

    name="$(basename "${xcarchive}")"
    size_bytes="$(safe_command du -sb "${xcarchive}" 2>/dev/null | awk '{print $1}')"
    if [ -z "${size_bytes}" ] || ! [[ "${size_bytes}" =~ ^[0-9]+$ ]]; then
      # macOS du may not support -b; fall back to du -sk * 1024.
      size_kb="$(safe_command du -sk "${xcarchive}" | awk '{print $1}')"
      if [ -n "${size_kb}" ] && [[ "${size_kb}" =~ ^[0-9]+$ ]]; then
        size_bytes=$((size_kb * 1024))
      fi
    fi

    # Extract the main executable's architectures.
    main_binary="${xcarchive}/Products/Applications/Lumi.app/Contents/MacOS/Lumi"
    archs=""
    if [ -x "${main_binary}" ]; then
      archs="$(safe_command lipo -archs "${main_binary}")"
    fi

    # Extract CFBundleVersion from the archived app.
    info_plist="${xcarchive}/Products/Applications/Lumi.app/Contents/Info.plist"
    bundle_version=""
    if [ -f "${info_plist}" ]; then
      bundle_version="$(safe_command /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${info_plist}")"
    fi

    # Extract dSYM UUID if present.
    dsym_uuid=""
    dsym_path="${xcarchive}/dSYMs/Lumi.app.dSYM/Contents/Resources/DWARF/Lumi"
    if [ -f "${dsym_path}" ]; then
      dsym_uuid="$(safe_command dwarfdump -u "${dsym_path}" | head -1 | sed 's/.*UUID: \([A-F0-9-]*\).*/\1/')"
    fi

    entry="    {"
    entry="${entry}\"name\": $(json_string "${name}")"
    entry="${entry}, \"size_bytes\": $(json_number "${size_bytes}")"
    entry="${entry}, \"archs\": $(json_string "${archs}")"
    entry="${entry}, \"bundle_version\": $(json_string "${bundle_version}")"
    entry="${entry}, \"dsym_uuid\": $(json_string "${dsym_uuid}")"
    entry="${entry}}"

    if [ -n "${archive_entries}" ]; then
      archive_entries="${archive_entries},
${entry}"
    else
      archive_entries="${entry}"
    fi
  done

  if [ -n "${archive_entries}" ]; then
    archives_json="[
${archive_entries}
  ]"
  fi
fi

# ---------------------------------------------------------------------------
# Build JSON output
# ---------------------------------------------------------------------------
collected_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

json_output="{
  \"schema_version\": 1,
  \"collected_at\": $(json_string "${collected_at}"),
  \"source_sha\": $(json_string "${source_sha}"),
  \"toolchain\": {
    \"xcode_version\": $(json_string "${xcode_version}"),
    \"xcode_build\": $(json_string "${xcode_build}"),
    \"swift_version\": $(json_string "${swift_version}"),
    \"sdk_path\": $(json_string "${sdk_path}"),
    \"sdk_version\": $(json_string "${sdk_version}")
  },
  \"runner\": {
    \"os\": $(json_string "${runner_os}"),
    \"arch\": $(json_string "${runner_arch}"),
    \"image\": $(json_string "${runner_image}"),
    \"kernel_version\": $(json_string "${kernel_version}")
  },
  \"hardware\": {
    \"cpu_model\": $(json_string "${cpu_model}"),
    \"cpu_cores\": $(json_number "${cpu_cores}"),
    \"memory_gb\": $(json_number "${memory_gb}")
  },
  \"disk\": {
    \"total_gb\": $(json_number "${disk_total_gb}"),
    \"free_gb\": $(json_number "${disk_free_gb}")
  },
  \"archives\": ${archives_json},
  \"archive_count\": ${archive_count}
}
"

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------
if [ -n "${output_path}" ]; then
  mkdir -p "$(dirname "${output_path}")"
  printf '%s' "${json_output}" > "${output_path}"
  echo "✅ Build metrics written to ${output_path}"
else
  printf '%s' "${json_output}"
fi
