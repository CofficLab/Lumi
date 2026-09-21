#!/usr/bin/env bash
#
# Tests for verify-release-archive.sh.
#
# Uses fake lipo/PlistBuddy/dwarfdump to verify archive validation logic
# without requiring a real xcarchive.
#
# Usage: bash .github/scripts/test-verify-release-archive.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/verify-release-archive.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# ---------------------------------------------------------------------------
# Fake tools
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/bin"

# Fake lipo
cat > "${WORK}/bin/lipo" <<'FAKE_LIPO'
#!/usr/bin/env bash
case "${2:-}" in
  -verify_arch)
    binary="$1"
    arch="$3"
    # Read actual arch from file next to binary (set by test)
    actual_file="${binary}.actual_arch"
    if [ -f "${actual_file}" ]; then
      actual="$(cat "${actual_file}")"
      if [ "${arch}" = "${actual}" ]; then exit 0; else exit 1; fi
    fi
    exit 0
    ;;
esac

case "$1" in
  -archs)
    binary="$2"
    actual_file="${binary}.actual_arch"
    if [ -f "${actual_file}" ]; then
      cat "${actual_file}"
    else
      echo "arm64"
    fi
    ;;
esac
exit 0
FAKE_LIPO
chmod +x "${WORK}/bin/lipo"

# Fake PlistBuddy
cat > "${WORK}/bin/PlistBuddy" <<'FAKE_PLIST'
#!/usr/bin/env bash
key="$2"
plist="$3"
if [ -f "${plist}" ]; then
  case "${key}" in
    "Print :CFBundleExecutable") echo "LumiFinder" ;;
    "Print :CFBundleShortVersionString") cat "${plist}.version" 2>/dev/null || echo "6.0.0" ;;
    "Print :CFBundleVersion") cat "${plist}.build" 2>/dev/null || echo "20260920120000" ;;
  esac
fi
exit 0
FAKE_PLIST
chmod +x "${WORK}/bin/PlistBuddy"
mkdir -p "${WORK}/bin/usr/libexec"
ln -sf "${WORK}/bin/PlistBuddy" "${WORK}/bin/usr/libexec/PlistBuddy"

# Fake dwarfdump
cat > "${WORK}/bin/dwarfdump" <<'FAKE_DWARF'
#!/usr/bin/env bash
# Handle both `dwarfdump -u <binary>` and `dwarfdump -u <binary> ...`
if [ "$1" = "-u" ]; then
  binary="$2"
else
  binary="$1"
fi
uuid_file="${binary}.uuid"
if [ -f "${uuid_file}" ]; then
  echo "UUID: $(cat "${uuid_file}") (x86_64) $(binary)"
fi
exit 0
FAKE_DWARF
chmod +x "${WORK}/bin/dwarfdump"

# Fake find (for Finder extension)
cat > "${WORK}/bin/find" <<'FAKE_FIND'
#!/usr/bin/env bash
# Pass through to real find
/usr/bin/find "$@"
FAKE_FIND
chmod +x "${WORK}/bin/find"

# ---------------------------------------------------------------------------
# Helper: create a fake xcarchive
# ---------------------------------------------------------------------------
create_fake_archive() {
  local archive="$1"
  local arch="${2:-arm64}"
  local version="${3:-6.0.0}"
  local build="${4:-20260920120000}"
  local uuid="${5:-A1B2C3D4-E5F6-7890-ABCD-EF1234567890}"

  mkdir -p "${archive}/Products/Applications/Lumi.app/Contents/MacOS"
  mkdir -p "${archive}/Products/Applications/Lumi.app/Contents/PlugIns/LumiFinder.appex/Contents/MacOS"
  mkdir -p "${archive}/dSYMs/Lumi.app.dSYM/Contents/Resources/DWARF"

  # Main binary
  echo "fake" > "${archive}/Products/Applications/Lumi.app/Contents/MacOS/Lumi"
  chmod +x "${archive}/Products/Applications/Lumi.app/Contents/MacOS/Lumi"
  echo "${arch}" > "${archive}/Products/Applications/Lumi.app/Contents/MacOS/Lumi.actual_arch"
  echo "${uuid}" > "${archive}/Products/Applications/Lumi.app/Contents/MacOS/Lumi.uuid"

  # ACP helper
  echo "fake" > "${archive}/Products/Applications/Lumi.app/Contents/MacOS/lumi-acp"
  chmod +x "${archive}/Products/Applications/Lumi.app/Contents/MacOS/lumi-acp"
  echo "${arch}" > "${archive}/Products/Applications/Lumi.app/Contents/MacOS/lumi-acp.actual_arch"

  # Finder extension
  echo "fake" > "${archive}/Products/Applications/Lumi.app/Contents/PlugIns/LumiFinder.appex/Contents/MacOS/LumiFinder"
  chmod +x "${archive}/Products/Applications/Lumi.app/Contents/PlugIns/LumiFinder.appex/Contents/MacOS/LumiFinder"
  echo "${arch}" > "${archive}/Products/Applications/Lumi.app/Contents/PlugIns/LumiFinder.appex/Contents/MacOS/LumiFinder.actual_arch"
  echo '{"CFBundleExecutable":"LumiFinder"}' > "${archive}/Products/Applications/Lumi.app/Contents/PlugIns/LumiFinder.appex/Contents/Info.plist"

  # dSYM
  echo "fake" > "${archive}/dSYMs/Lumi.app.dSYM/Contents/Resources/DWARF/Lumi"
  echo "${uuid}" > "${archive}/dSYMs/Lumi.app.dSYM/Contents/Resources/DWARF/Lumi.uuid"

  # Info.plist
  touch "${archive}/Products/Applications/Lumi.app/Contents/Info.plist"
  echo "${version}" > "${archive}/Products/Applications/Lumi.app/Contents/Info.plist.version"
  echo "${build}" > "${archive}/Products/Applications/Lumi.app/Contents/Info.plist.build"
}

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------
checks=0
failures=0

ok() { checks=$((checks + 1)); echo "  ✅ $1"; }
bad() { checks=$((checks + 1)); failures=$((failures + 1)); echo "  ❌ $1"; }

expect_eq() {
  if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (expected '$1', got '$2')"; fi
}

expect_contains() {
  case "$1" in
    *"$2"*) ok "$3" ;;
    *) bad "$3 (missing '$2')" ;;
  esac
}

set +e

export PATH="${WORK}/bin:${PATH}"

# ---------------------------------------------------------------------------
# 1. Argument validation
# ---------------------------------------------------------------------------
echo "▶ argument validation"

bash "${SCRIPT}" > /dev/null 2>&1
expect_eq "2" "$?" "no args exits 2"

bash "${SCRIPT}" "/nonexistent" "arm64" > /dev/null 2>&1
expect_eq "2" "$?" "missing archive exits 2"

# ---------------------------------------------------------------------------
# 2. All checks pass
# ---------------------------------------------------------------------------
echo "▶ all checks pass"

archive="${WORK}/archive-ok"
create_fake_archive "${archive}" "arm64" "6.0.0" "20260920120000" "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"

bash "${SCRIPT}" "${archive}" "arm64" \
  --expected-version "6.0.0" \
  --expected-build "20260920120000" > "${WORK}/out-ok.txt" 2>&1
expect_eq "0" "$?" "valid archive exits 0"
expect_contains "$(cat "${WORK}/out-ok.txt")" "6 checks passed" "reports 6 checks passed"

# ---------------------------------------------------------------------------
# 3. Architecture mismatch on main binary
# ---------------------------------------------------------------------------
echo "▶ architecture mismatch"

archive="${WORK}/archive-arch"
create_fake_archive "${archive}" "arm64"
echo "arm64" > "${archive}/Products/Applications/Lumi.app/Contents/MacOS/Lumi.actual_arch"

bash "${SCRIPT}" "${archive}" "x86_64" > "${WORK}/out-arch.txt" 2>&1
expect_eq "1" "$?" "arch mismatch exits 1"
expect_contains "$(cat "${WORK}/out-arch.txt")" "Lumi missing x86_64" "reports main binary mismatch"

# ---------------------------------------------------------------------------
# 4. ACP helper architecture mismatch
# ---------------------------------------------------------------------------
echo "▶ ACP helper architecture mismatch"

archive="${WORK}/archive-acp"
create_fake_archive "${archive}" "arm64"
echo "arm64" > "${archive}/Products/Applications/Lumi.app/Contents/MacOS/lumi-acp.actual_arch"

bash "${SCRIPT}" "${archive}" "x86_64" > "${WORK}/out-acp.txt" 2>&1
expect_eq "1" "$?" "acp arch mismatch exits 1"
expect_contains "$(cat "${WORK}/out-acp.txt")" "lumi-acp missing x86_64" "reports ACP mismatch"

# ---------------------------------------------------------------------------
# 5. dSYM UUID mismatch
# ---------------------------------------------------------------------------
echo "▶ dSYM UUID mismatch"

archive="${WORK}/archive-uuid"
create_fake_archive "${archive}" "arm64" "6.0.0" "20260920120000" "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
echo "FFFFFFFF-1111-2222-3333-444444444444" > "${archive}/dSYMs/Lumi.app.dSYM/Contents/Resources/DWARF/Lumi.uuid"

bash "${SCRIPT}" "${archive}" "arm64" > "${WORK}/out-uuid.txt" 2>&1
expect_eq "1" "$?" "uuid mismatch exits 1"
expect_contains "$(cat "${WORK}/out-uuid.txt")" "dSYM UUID mismatch" "reports UUID mismatch"

# ---------------------------------------------------------------------------
# 6. Version mismatch
# ---------------------------------------------------------------------------
echo "▶ version mismatch"

archive="${WORK}/archive-ver"
create_fake_archive "${archive}" "arm64" "6.0.0" "20260920120000"

bash "${SCRIPT}" "${archive}" "arm64" \
  --expected-version "7.0.0" > "${WORK}/out-ver.txt" 2>&1
expect_eq "1" "$?" "version mismatch exits 1"
expect_contains "$(cat "${WORK}/out-ver.txt")" "CFBundleShortVersionString mismatch" "reports version mismatch"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ "${failures}" -eq 0 ]; then
  echo "✅ test-verify-release-archive.sh: ${checks} checks passed"
  exit 0
fi

echo "❌ test-verify-release-archive.sh: ${failures} of ${checks} checks failed"
exit 1
