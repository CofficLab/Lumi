#!/usr/bin/env bash
#
# verify-release-archive.sh — validate a .xcarchive before release.
#
# Checks:
#   * First-party binaries contain only the expected target architecture.
#   * Required Sparkle and Project RAG runtime resources are present.
#   * Runtime Mach-O files contain the expected architecture.
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
plist_buddy="${PLIST_BUDDY:-/usr/libexec/PlistBuddy}"
if [ ! -d "${app_path}" ]; then
  echo "❌ Lumi.app not found in archive" >&2
  exit 1
fi

failures=0
checks=0

check_pass() { checks=$((checks + 1)); echo "  ✅ $1"; }
check_fail() { checks=$((checks + 1)); failures=$((failures + 1)); echo "  ❌ $1"; }

check_exact_arch() {
  local label="$1" binary="$2"
  if [ ! -x "${binary}" ]; then
    check_fail "${label} not found or not executable"
    return
  fi
  local actual
  actual="$(lipo -archs "${binary}" 2>/dev/null | xargs || true)"
  if [ "${actual}" = "${expected_arch}" ]; then
    check_pass "${label} architecture = ${expected_arch}"
  else
    check_fail "${label} architecture mismatch (expected only: ${expected_arch}, actual: ${actual:-unknown})"
  fi
}

check_contains_arch() {
  local label="$1" binary="$2"
  if [ ! -f "${binary}" ]; then
    check_fail "${label} missing"
    return
  fi
  if lipo "${binary}" -verify_arch "${expected_arch}" 2>/dev/null; then
    check_pass "${label} contains ${expected_arch}"
  else
    local actual
    actual="$(lipo -archs "${binary}" 2>/dev/null || echo unknown)"
    check_fail "${label} missing ${expected_arch} (has: ${actual})"
  fi
}

# ---------------------------------------------------------------------------
# 1. Main binary architecture
# ---------------------------------------------------------------------------
echo "▶ Checking main binary architecture"
main_binary="${app_path}/Contents/MacOS/Lumi"
check_exact_arch "Lumi" "${main_binary}"

# ---------------------------------------------------------------------------
# 2. ACP helper architecture
# ---------------------------------------------------------------------------
echo "▶ Checking ACP helper architecture"
acp_binary="${app_path}/Contents/MacOS/lumi-acp"
check_exact_arch "lumi-acp" "${acp_binary}"

# ---------------------------------------------------------------------------
# 3. Finder extension architecture
# ---------------------------------------------------------------------------
echo "▶ Checking Finder extension architecture"
finder_appex="$(find "${app_path}/Contents/PlugIns" -name "*.appex" -maxdepth 1 -type d 2>/dev/null | head -1)"
if [ -n "${finder_appex}" ] && [ -d "${finder_appex}" ]; then
  finder_binary="${finder_appex}/Contents/MacOS/$(${plist_buddy} -c 'Print :CFBundleExecutable' "${finder_appex}/Contents/Info.plist" 2>/dev/null || echo '')"
  if [ -n "${finder_binary}" ] && [ -x "${finder_binary}" ]; then
    check_exact_arch "Finder extension" "${finder_binary}"
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
  main_uuid="$(dwarfdump -u "${main_binary}" 2>/dev/null | awk -v a="${expected_arch}" '$0 ~ "\\(" a "\\)" {print $2; exit}')"
  dsym_uuid="$(dwarfdump -u "${dsym_path}" 2>/dev/null | awk -v a="${expected_arch}" '$0 ~ "\\(" a "\\)" {print $2; exit}')"
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
  actual_version="$(${plist_buddy} -c 'Print :CFBundleShortVersionString' "${info_plist}" 2>/dev/null || echo '')"
  actual_build="$(${plist_buddy} -c 'Print :CFBundleVersion' "${info_plist}" 2>/dev/null || echo '')"

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
# 6. Required release resources and runtime libraries
# ---------------------------------------------------------------------------
echo "▶ Checking required release resources"
required_paths=(
  "${app_path}/Contents/Frameworks/Sparkle.framework"
  "${app_path}/Contents/Frameworks/vec0.dylib"
  "${app_path}/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle"
  "${app_path}/Contents/Resources/PluginACP_PluginACP.bundle"
)
for required_path in "${required_paths[@]}"; do
  if [ -e "${required_path}" ] || [ -L "${required_path}" ]; then
    check_pass "required path present: ${required_path#${app_path}/}"
  else
    check_fail "required path missing: ${required_path#${app_path}/}"
  fi
done
check_contains_arch "vec0 runtime" "${app_path}/Contents/Frameworks/vec0.dylib"

# ---------------------------------------------------------------------------
# 7. Bundle symlink integrity
# ---------------------------------------------------------------------------
echo "▶ Checking symlink integrity"
broken_link="$(find -L "${app_path}" -type l -print -quit 2>/dev/null || true)"
if [ -z "${broken_link}" ]; then
  check_pass "bundle contains no broken symlinks"
else
  check_fail "broken symlink: ${broken_link}"
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
