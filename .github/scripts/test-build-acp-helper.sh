#!/usr/bin/env bash
#
# Tests for build-acp-helper.sh.
#
# Uses fake xcrun/lipo/ditto to verify parameter forwarding, architecture
# validation, and copy behavior without requiring a real Xcode toolchain.
#
# Usage: bash .github/scripts/test-build-acp-helper.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/build-acp-helper.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# ---------------------------------------------------------------------------
# Fake tools
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/bin"

# Fake xcrun: records invocations and produces expected outputs.
cat > "${WORK}/bin/xcrun" <<'FAKE_XCRUN'
#!/usr/bin/env bash
set -uo pipefail

echo "$@" >> "${FAKE_LOG}/xcrun-calls.txt"

case "$1" in
  --find)
    # swift lookup
    echo "${FAKE_LOG}/fake-swift"
    ;;
  --sdk)
    # macosx --show-sdk-path
    echo "${FAKE_LOG}/fake-sdk"
    ;;
  swift)
    shift
    echo "$@" >> "${FAKE_LOG}/swift-calls.txt"
    # If --show-bin-path, print the scratch/bin/Release path
    for arg in "$@"; do
      if [ "${arg}" = "--show-bin-path" ]; then
        # Find --scratch-path
        scratch=""
        prev=""
        for a in "$@"; do
          if [ "${prev}" = "--scratch-path" ]; then
            scratch="${a}"
          fi
          prev="${a}"
        done
        if [ -n "${scratch}" ]; then
          echo "${scratch}/arm64-apple-macosx/release"
        fi
        exit 0
      fi
    done
    # Regular build: create the fake binary in the scratch path
    scratch=""
    config="release"
    prev=""
    for a in "$@"; do
      case "${prev}" in
        --scratch-path) scratch="${a}" ;;
        -c) config="${a}" ;;
      esac
      prev="${a}"
    done
    if [ -n "${scratch}" ]; then
      bin_subdir="${scratch}/arm64-apple-macosx/${config}"
      mkdir -p "${bin_subdir}"
      echo "fake binary" > "${bin_subdir}/LumiACPExecutable"
      chmod +x "${bin_subdir}/LumiACPExecutable"
      # Create a fake resource bundle
      mkdir -p "${bin_subdir}/FactoryLumiACP_FactoryLumiACP.bundle"
      echo "fake resource" > "${bin_subdir}/FactoryLumiACP_FactoryLumiACP.bundle/data.txt"
    fi
    ;;
esac
exit 0
FAKE_XCRUN
chmod +x "${WORK}/bin/xcrun"

# Fake lipo: verify_arch succeeds if the arch matches the expected value.
cat > "${WORK}/bin/lipo" <<'FAKE_LIPO'
#!/usr/bin/env bash
set -uo pipefail
echo "$@" >> "${FAKE_LOG}/lipo-calls.txt"

case "${2:-}" in
  -verify_arch)
    binary="$1"
    arch="$3"
    if [ "${arch}" = "${FAKE_LIPO_ARCH:-arm64}" ]; then
      exit 0
    else
      exit 1
    fi
    ;;
esac

case "$1" in
  -archs)
    echo "${FAKE_LIPO_ARCH:-arm64}"
    ;;
esac
exit 0
FAKE_LIPO
chmod +x "${WORK}/bin/lipo"

# Fake ditto: just records the call.
cat > "${WORK}/bin/ditto" <<'FAKE_DITTO'
#!/usr/bin/env bash
echo "$@" >> "${FAKE_LOG}/ditto-calls.txt"
exit 0
FAKE_DITTO
chmod +x "${WORK}/bin/ditto"

# ---------------------------------------------------------------------------
# Fake FactoryLumiACP package
# ---------------------------------------------------------------------------
setup_fake_package() {
  local pkg_dir="${WORK}/fake-package"
  mkdir -p "${pkg_dir}/Sources/LumiACPExecutable"
  echo 'print("hello")' > "${pkg_dir}/Sources/LumiACPExecutable/main.swift"
  cat > "${pkg_dir}/Package.swift" <<'PKG'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "FactoryLumiACP", products: [.executable(name: "LumiACPExecutable", targets: ["LumiACPExecutable"])], targets: [.executableTarget(name: "LumiACPExecutable", path: "Sources/LumiACPExecutable")])
PKG
  echo '{"pins":[]}' > "${pkg_dir}/Package.resolved"
  echo "${pkg_dir}"
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

expect_not_contains() {
  case "$1" in
    *"$2"*) bad "$3 (unexpected '$2')" ;;
    *) ok "$3" ;;
  esac
}

expect_exists() {
  if [ -e "$1" ]; then ok "$2"; else bad "$2 (missing '$1')"; fi
}

set +e

# ---------------------------------------------------------------------------
# 1. Argument validation
# ---------------------------------------------------------------------------
echo "▶ argument validation"

bash "${SCRIPT}" > /dev/null 2>&1
expect_eq "2" "$?" "no args exits 2"

bash "${SCRIPT}" "arm64" > /dev/null 2>&1
expect_eq "2" "$?" "missing destination exits 2"

bash "${SCRIPT}" "i386" "${WORK}/dest" --source-dir "${WORK}/fake" > /dev/null 2>&1
expect_eq "2" "$?" "unsupported arch exits 2"

bash "${SCRIPT}" "arm64" "${WORK}/dest" --config "profile" --source-dir "${WORK}/fake" > /dev/null 2>&1
expect_eq "2" "$?" "invalid config exits 2"

bash "${SCRIPT}" "arm64" "${WORK}/dest" --unknown-flag > /dev/null 2>&1
expect_eq "2" "$?" "unknown option exits 2"

# ---------------------------------------------------------------------------
# 2. Missing Package.resolved
# ---------------------------------------------------------------------------
echo "▶ missing Package.resolved"

pkg_no_lock="${WORK}/no-lock-pkg"
mkdir -p "${pkg_no_lock}"
bash "${SCRIPT}" "arm64" "${WORK}/dest" --source-dir "${pkg_no_lock}" > /dev/null 2>&1
expect_eq "1" "$?" "missing lock exits 1"

# ---------------------------------------------------------------------------
# 3. Successful build with correct parameters
# ---------------------------------------------------------------------------
echo "▶ successful build forwards correct parameters"

FAKE_LOG="${WORK}/log1"
mkdir -p "${FAKE_LOG}"
pkg_dir="$(setup_fake_package)"
dest="${WORK}/dest1"
resources="${WORK}/resources1"
scratch="${WORK}/scratch1"
cache="${WORK}/cache1"

export PATH="${WORK}/bin:${PATH}"
export FAKE_LOG FAKE_LIPO_ARCH="arm64"

bash "${SCRIPT}" "arm64" "${dest}" \
  --source-dir "${pkg_dir}" \
  --scratch-path "${scratch}" \
  --cache-path "${cache}" \
  --resources-dir "${resources}" \
  --output-name "LumiACP" \
  --config release > "${WORK}/stdout1.txt" 2>&1
run_exit=$?

expect_eq "0" "${run_exit}" "exits 0"
expect_exists "${dest}/LumiACP" "executable copied with requested name"
expect_contains "$(cat "${FAKE_LOG}/ditto-calls.txt" 2>/dev/null || echo '')" "${resources}/FactoryLumiACP_FactoryLumiACP.bundle" "resource copied to requested directory"
SWIFT_CALLS="$(cat "${FAKE_LOG}/swift-calls.txt" 2>/dev/null || echo '')"
expect_contains "${SWIFT_CALLS}" "--product LumiACPExecutable" "builds current executable product"
expect_contains "${SWIFT_CALLS}" "--triple arm64-apple-macosx14.0" "passes correct triple"
expect_contains "${SWIFT_CALLS}" "--scratch-path ${scratch}" "passes scratch path"
expect_contains "${SWIFT_CALLS}" "--cache-path ${cache}" "passes dependency cache path"
expect_contains "${SWIFT_CALLS}" "--force-resolved-versions" "enforces locked versions"
expect_contains "${SWIFT_CALLS}" "-c release" "passes release config"
expect_contains "$(cat "${FAKE_LOG}/lipo-calls.txt" 2>/dev/null)" "LumiACPExecutable -verify_arch arm64" "verifies architecture"

# ---------------------------------------------------------------------------
# 4. x86_64 build uses correct triple
# ---------------------------------------------------------------------------
echo "▶ x86_64 build uses correct triple"

FAKE_LOG="${WORK}/log2"
mkdir -p "${FAKE_LOG}"
dest="${WORK}/dest2"
scratch="${WORK}/scratch2"
export FAKE_LOG FAKE_LIPO_ARCH="x86_64"

# Patch fake xcrun to handle x86_64 bin path
cat > "${WORK}/bin/xcrun" <<'FAKE_XCRUN2'
#!/usr/bin/env bash
set -uo pipefail
echo "$@" >> "${FAKE_LOG}/xcrun-calls.txt"
case "$1" in
  --find) echo "${FAKE_LOG}/fake-swift" ;;
  --sdk) echo "${FAKE_LOG}/fake-sdk" ;;
  swift)
    shift
    echo "$@" >> "${FAKE_LOG}/swift-calls.txt"
    for arg in "$@"; do
      if [ "${arg}" = "--show-bin-path" ]; then
        scratch=""
        config="release"
        triple=""
        prev=""
        for a in "$@"; do
          case "${prev}" in
            --scratch-path) scratch="${a}" ;;
            -c) config="${a}" ;;
            --triple) triple="${a}" ;;
          esac
          prev="${a}"
        done
        echo "${scratch}/${triple}/${config}"
        exit 0
      fi
    done
    scratch=""
    config="release"
    triple=""
    prev=""
    for a in "$@"; do
      case "${prev}" in
        --scratch-path) scratch="${a}" ;;
        -c) config="${a}" ;;
        --triple) triple="${a}" ;;
      esac
      prev="${a}"
    done
    if [ -n "${scratch}" ]; then
      bin_subdir="${scratch}/${triple}/${config}"
      mkdir -p "${bin_subdir}"
      echo "fake binary" > "${bin_subdir}/LumiACPExecutable"
      chmod +x "${bin_subdir}/LumiACPExecutable"
    fi
    ;;
esac
exit 0
FAKE_XCRUN2
chmod +x "${WORK}/bin/xcrun"

bash "${SCRIPT}" "x86_64" "${dest}" \
  --source-dir "${pkg_dir}" \
  --scratch-path "${scratch}" > "${WORK}/stdout2.txt" 2>&1
run_exit=$?

expect_eq "0" "${run_exit}" "x86_64 exits 0"
SWIFT_CALLS="$(cat "${FAKE_LOG}/swift-calls.txt" 2>/dev/null || echo '')"
expect_contains "${SWIFT_CALLS}" "--triple x86_64-apple-macosx14.0" "x86_64 triple correct"

# ---------------------------------------------------------------------------
# 5. Architecture mismatch fails
# ---------------------------------------------------------------------------
echo "▶ architecture mismatch fails"

FAKE_LOG="${WORK}/log3"
mkdir -p "${FAKE_LOG}"
dest="${WORK}/dest3"
scratch="${WORK}/scratch3"
export FAKE_LOG FAKE_LIPO_ARCH="arm64"  # lipo says arm64

bash "${SCRIPT}" "x86_64" "${dest}" \
  --source-dir "${pkg_dir}" \
  --scratch-path "${scratch}" > "${WORK}/stdout3.txt" 2>&1
run_exit=$?

expect_eq "1" "${run_exit}" "arch mismatch exits 1"
expect_contains "$(cat "${WORK}/stdout3.txt")" "does not contain expected architecture" "reports arch mismatch"

# ---------------------------------------------------------------------------
# 6. --skip-copy prints path and exits
# ---------------------------------------------------------------------------
echo "▶ --skip-copy prints binary path"

FAKE_LOG="${WORK}/log4"
mkdir -p "${FAKE_LOG}"
scratch="${WORK}/scratch4"
export FAKE_LOG FAKE_LIPO_ARCH="arm64"

bash "${SCRIPT}" "arm64" "" \
  --source-dir "${pkg_dir}" \
  --scratch-path "${scratch}" \
  --skip-copy > "${WORK}/stdout4.txt" 2>&1
run_exit=$?

expect_eq "0" "${run_exit}" "skip-copy exits 0"
expect_contains "$(cat "${WORK}/stdout4.txt")" "LumiACPExecutable" "prints binary path"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ "${failures}" -eq 0 ]; then
  echo "✅ test-build-acp-helper.sh: ${checks} checks passed"
  exit 0
fi

echo "❌ test-build-acp-helper.sh: ${failures} of ${checks} checks failed"
exit 1
