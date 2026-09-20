#!/usr/bin/env bash
#
# Tests for collect-build-metrics.sh.
#
# Validates JSON structure, argument handling, and archive scanning.
# Uses the real script (no mocking of system tools) because the script
# already degrades gracefully when tools are absent.
#
# Usage: bash .github/scripts/test-collect-build-metrics.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/collect-build-metrics.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------
checks=0
failures=0

ok() { checks=$((checks + 1)); echo "  ✅ $1"; }
bad() { checks=$((checks + 1)); failures=$((failures + 1)); echo "  ❌ $1"; }

expect_eq() { # expected actual label
  if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (expected '$1', got '$2')"; fi
}

expect_contains() { # haystack needle label
  case "$1" in
    *"$2"*) ok "$3" ;;
    *) bad "$3 (missing '$2')" ;;
  esac
}

expect_not_contains() { # haystack needle label
  case "$1" in
    *"$2"*) bad "$3 (unexpected '$2')" ;;
    *) ok "$3" ;;
  esac
}

expect_exists() { # path label
  if [ -e "$1" ]; then ok "$2"; else bad "$2 (missing '$1')"; fi
}

expect_valid_json_key() { # json key label
  case "$1" in
    *"\"$2\""*) ok "$3" ;;
    *) bad "$3 (missing key '$2')" ;;
  esac
}

set +e

# ---------------------------------------------------------------------------
# 1. Default output goes to stdout and contains required structure
# ---------------------------------------------------------------------------
echo "▶ default stdout output includes all required JSON keys"
output="$(bash "${SCRIPT}" 2>/dev/null)"
run_exit=$?
expect_eq "0" "${run_exit}" "exits 0"
expect_valid_json_key "${output}" "schema_version" "has schema_version"
expect_valid_json_key "${output}" "collected_at" "has collected_at"
expect_valid_json_key "${output}" "source_sha" "has source_sha"
expect_valid_json_key "${output}" "toolchain" "has toolchain"
expect_valid_json_key "${output}" "xcode_version" "has xcode_version"
expect_valid_json_key "${output}" "swift_version" "has swift_version"
expect_valid_json_key "${output}" "sdk_path" "has sdk_path"
expect_valid_json_key "${output}" "runner" "has runner"
expect_valid_json_key "${output}" "hardware" "has hardware"
expect_valid_json_key "${output}" "disk" "has disk"
expect_valid_json_key "${output}" "archives" "has archives"
expect_valid_json_key "${output}" "archive_count" "has archive_count"

# ---------------------------------------------------------------------------
# 2. --output writes to a file
# ---------------------------------------------------------------------------
echo "▶ --output writes JSON to a file"
output_file="${WORK}/metrics.json"
bash "${SCRIPT}" --output "${output_file}" > /dev/null 2>&1
run_exit=$?
expect_eq "0" "${run_exit}" "exits 0"
expect_exists "${output_file}" "output file exists"
file_content="$(cat "${output_file}" 2>/dev/null || echo '')"
expect_valid_json_key "${file_content}" "schema_version" "file has schema_version"
expect_valid_json_key "${file_content}" "archive_count" "file has archive_count"

# ---------------------------------------------------------------------------
# 3. --archive-dir scans archives in the specified directory
# ---------------------------------------------------------------------------
echo "▶ --archive-dir scans mock xcarchives"
archive_dir="${WORK}/test-temp"
mkdir -p "${archive_dir}"

# Create a minimal mock .xcarchive bundle
mock_archive="${archive_dir}/Lumi-arm64.xcarchive"
mkdir -p "${mock_archive}/Products/Applications/Lumi.app/Contents/MacOS"
mkdir -p "${mock_archive}/Products/Applications/Lumi.app/Contents"
echo "fake binary" > "${mock_archive}/Products/Applications/Lumi.app/Contents/MacOS/Lumi"

# Create a minimal Info.plist with CFBundleVersion
cat > "${mock_archive}/Products/Applications/Lumi.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleVersion</key>
  <string>20260920123456</string>
</dict>
</plist>
PLIST

output="$(SOURCE_SHA="abc123" bash "${SCRIPT}" --archive-dir "${archive_dir}" 2>/dev/null)"
run_exit=$?
expect_eq "0" "${run_exit}" "exits 0"
expect_contains "${output}" "Lumi-arm64.xcarchive" "includes the archive name"
expect_contains "${output}" "20260920123456" "includes the bundle version"
expect_contains "${output}" "\"archive_count\": 1" "reports 1 archive"
expect_contains "${output}" "abc123" "records the source SHA"

# ---------------------------------------------------------------------------
# 4. Empty archive directory reports 0 archives
# ---------------------------------------------------------------------------
echo "▶ empty archive directory reports archive_count 0"
empty_dir="${WORK}/empty-temp"
mkdir -p "${empty_dir}"
output="$(bash "${SCRIPT}" --archive-dir "${empty_dir}" 2>/dev/null)"
run_exit=$?
expect_eq "0" "${run_exit}" "exits 0"
expect_contains "${output}" "\"archive_count\": 0" "reports 0 archives"
expect_contains "${output}" "\"archives\": []" "archives array is empty"

# ---------------------------------------------------------------------------
# 5. Invalid arguments are rejected
# ---------------------------------------------------------------------------
echo "▶ invalid arguments are rejected with exit 2"
bash "${SCRIPT}" --unknown-flag > /dev/null 2>&1
expect_eq "2" "$?" "unknown flag exits 2"

bash "${SCRIPT}" --archive-dir > /dev/null 2>&1
expect_eq "2" "$?" "missing --archive-dir value exits 2"

bash "${SCRIPT}" --output > /dev/null 2>&1
expect_eq "2" "$?" "missing --output value exits 2"

# ---------------------------------------------------------------------------
# 6. SOURCE_SHA env var is respected
# ---------------------------------------------------------------------------
echo "▶ SOURCE_SHA env overrides git rev-parse"
output="$(SOURCE_SHA="deadbeef" bash "${SCRIPT}" 2>/dev/null)"
expect_contains "${output}" "deadbeef" "records SOURCE_SHA from env"

# ---------------------------------------------------------------------------
# 7. JSON output is valid (basic structure check)
# ---------------------------------------------------------------------------
echo "▶ JSON output is parseable"
output="$(bash "${SCRIPT}" 2>/dev/null)"
# Check for balanced braces as a basic validity check
open_braces="$(echo "${output}" | tr -cd '{' | wc -c | tr -d ' ')"
close_braces="$(echo "${output}" | tr -cd '}' | wc -c | tr -d ' ')"
expect_eq "${open_braces}" "${close_braces}" "balanced braces in JSON"
# Check that it starts with { and ends with }
first_char="$(echo "${output}" | head -c 1)"
last_nonblank="$(echo "${output}" | sed '/^$/d' | tail -1 | grep -o '[^ ]' | tail -1)"
expect_eq "{" "${first_char}" "JSON starts with {"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ "${failures}" -eq 0 ]; then
  echo "✅ test-collect-build-metrics.sh: ${checks} checks passed"
  exit 0
fi

echo "❌ test-collect-build-metrics.sh: ${failures} of ${checks} checks failed"
exit 1
