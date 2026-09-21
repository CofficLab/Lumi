#!/usr/bin/env bash
#
# verify-release-archive.sh — validate a .xcarchive before release.
#
# Checks:
#   * Main App binary contains the expected target architecture.
#   * lumi-acp helper contains the expected architecture.
#   * Finder extension (if present) contains the expected architecture.
#   * dSYM UUID matches the main binary UUID.
#   * CFBundleShortVersionString and CFBundleVersion match expected values.
#
# Usage:
#   verify-release-archive.sh <archive-path> <expected-arch> [options]
#     [--expected-version <version>]
#     [--expected-build <build>]
#
# Exit codes:
#   0   all checks passed
#   1   one or more checks failed
#   2   usage error

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [ "$#" -lt 2 ]; then
  echo "usage: $(basename "$0") <archive-path> <expected-arch> [--expected-version <v>] [--expected-build <b>]" >&2
  exit 2
fi

archive_path="$1"
expected_arch="$2"
shift 2

expected_version=""
expected_build=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --expected-version)
      if [ "$#" -lt 2 ]; then echo "error: --expected-version requires a value" >&2; exit 2; fi
      expected_version="$2"; shift 2 ;;
    --expected-build)
      if [ "$#" -lt 2 ]; then echo "error: --expected-build requires a value" >&2; exit 2; fi
      expected_build="$2"; shift 2 ;;
    *)
      echo "error: unknown option: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [ ! -d "${archive_path}" ]; then
  echo "❌ Archive not found: ${archive_path}" >&2
  exit 2
fi

case "${expected_arch}" in
  arm64|x86_64) ;;
  *) echo "❌ Unsupported architecture: ${expected_arch}" >&2; exit 2 ;;
esac

app_path="${archive_path}/Products/Applications/Lumi.app"
if [ ! -d "${app_path}" ]; then
  echo "❌ Lumi.app not found in archive" >&2
  exit 1
fi

failures=0
checks=0

check_pass() { checks=$((checks + 1)); echo "  ✅ $1"; }
check_fail() { checks=$((checks + 1)); failures=$((failures + 1)); echo "  ❌ $1"; }

# ---------------------------------------------------------------------------
# 1. Main binary architecture
# ---------------------------------------------------------------------------
echo "▶ Checking main binary architecture"
main_binary="${app_path}/Contents/MacOS/Lumi"
if [ ! -x "${main_binary}" ]; then
  check_fail "Lumi binary not found"
else
  if lipo "${main_binary}" -verify_arch "${expected_arch}" 2>/dev/null; then
    check_pass "Lumi contains ${expected_arch}"
  else
    actual="$(lipo -archs "${main_binary}" 2>/dev/null || echo 'unknown')"
    check_fail "Lumi missing ${expected_arch} (has: ${actual})"
  fi
fi

# ---------------------------------------------------------------------------
# 2. ACP helper architecture
# ---------------------------------------------------------------------------
echo "▶ Checking ACP helper architecture"
acp_binary="${app_path}/Contents/MacOS/lumi-acp"
if [ ! -x "${acp_binary}" ]; then
  check_fail "lumi-acp not found"
else
  if lipo "${acp_binary}" -verify_arch "${expected_arch}" 2>/dev/null; then
    check_pass "lumi-acp contains ${expected_arch}"
  else
    actual="$(lipo -archs "${acp_binary}" 2>/dev/null || echo 'unknown')"
    check_fail "lumi-acp missing ${expected_arch} (has: ${actual})"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Finder extension architecture
# ---------------------------------------------------------------------------
echo "▶ Checking Finder extension architecture"
finder_appex="$(find "${app_path}/Contents/PlugIns" -name "*.appex" -maxdepth 1 -type d 2>/dev/null | head -1)"
if [ -n "${finder_appex}" ] && [ -d "${finder_appex}" ]; then
  finder_binary="${finder_appex}/Contents/MacOS/$(PlistBuddy -c 'Print :CFBundleExecutable' "${finder_appex}/Contents/Info.plist" 2>/dev/null || echo '')"
  if [ -n "${finder_binary}" ] && [ -x "${finder_binary}" ]; then
    if lipo "${finder_binary}" -verify_arch "${expected_arch}" 2>/dev/null; then
      check_pass "Finder extension contains ${expected_arch}"
    else
      actual="$(lipo -archs "${finder_binary}" 2>/dev/null || echo 'unknown')"
      check_fail "Finder extension missing ${expected_arch} (has: ${actual})"
    fi
  else
    check_fail "Finder extension binary not found"
  fi
else
  echo "  ℹ️  No Finder extension found (skipped)"
fi

# ---------------------------------------------------------------------------
# 4. dSYM UUID match
# ---------------------------------------------------------------------------
echo "▶ Checking dSYM UUID"
dsym_path="${archive_path}/dSYMs/Lumi.app.dSYM/Contents/Resources/DWARF/Lumi"
if [ -f "${dsym_path}" ]; then
  main_uuid="$(dwarfdump -u "${main_binary}" 2>/dev/null | head -1 | sed 's/.*UUID: \([A-F0-9-]*\).*/\1/')"
  dsym_uuid="$(dwarfdump -u "${dsym_path}" 2>/dev/null | head -1 | sed 's/.*UUID: \([A-F0-9-]*\).*/\1/')"
  if [ -n "${main_uuid}" ] && [ -n "${dsym_uuid}" ] && [ "${main_uuid}" = "${dsym_uuid}" ]; then
    check_pass "dSYM UUID matches binary (${main_uuid})"
  else
    check_fail "dSYM UUID mismatch (binary: ${main_uuid:-unknown}, dSYM: ${dsym_uuid:-unknown})"
  fi
else
  check_fail "dSYM not found"
fi

# ---------------------------------------------------------------------------
# 5. Version numbers
# ---------------------------------------------------------------------------
echo "▶ Checking version numbers"
info_plist="${app_path}/Contents/Info.plist"
if [ -f "${info_plist}" ]; then
  actual_version="$(PlistBuddy -c 'Print :CFBundleShortVersionString' "${info_plist}" 2>/dev/null || echo '')"
  actual_build="$(PlistBuddy -c 'Print :CFBundleVersion' "${info_plist}" 2>/dev/null || echo '')"

  if [ -n "${expected_version}" ]; then
    if [ "${actual_version}" = "${expected_version}" ]; then
      check_pass "CFBundleShortVersionString = ${actual_version}"
    else
      check_fail "CFBundleShortVersionString mismatch (expected: ${expected_version}, actual: ${actual_version})"
    fi
  else
    check_pass "CFBundleShortVersionString = ${actual_version} (no expected set)"
  fi

  if [ -n "${expected_build}" ]; then
    if [ "${actual_build}" = "${expected_build}" ]; then
      check_pass "CFBundleVersion = ${actual_build}"
    else
      check_fail "CFBundleVersion mismatch (expected: ${expected_build}, actual: ${actual_build})"
    fi
  else
    check_pass "CFBundleVersion = ${actual_build} (no expected set)"
  fi
else
  check_fail "Info.plist not found"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ "${failures}" -eq 0 ]; then
  echo "✅ verify-release-archive.sh: ${checks} checks passed"
  exit 0
fi

echo "❌ verify-release-archive.sh: ${failures} of ${checks} checks failed"
exit 1
