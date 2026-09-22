#!/usr/bin/env bash
#
# Tests for resolve-ci-packages.sh.
#
# Uses a fake xcodebuild to verify parameter forwarding without requiring
# a real Xcode installation.
#
# Usage: bash .github/scripts/test-resolve-ci-packages.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/resolve-ci-packages.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# ---------------------------------------------------------------------------
# Fake xcodebuild
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/bin"
cat > "${WORK}/bin/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
set -uo pipefail

# Record all arguments for verification.
printf '%s\n' "$@" > "${FAKE_LOG}/xcodebuild-args.txt"

# Check if this is a resolve command.
is_resolve=false
for arg in "$@"; do
  if [ "${arg}" = "-resolvePackageDependencies" ]; then
    is_resolve=true
    break
  fi
done

if [ "${is_resolve}" = "true" ]; then
  # Simulate successful resolution by creating checkouts directory.
  source_dir=""
  prev=""
  for arg in "$@"; do
    if [ "${prev}" = "-clonedSourcePackagesDirPath" ]; then
      source_dir="${arg}"
    fi
    prev="${arg}"
  done

  if [ -n "${source_dir}" ]; then
    mkdir -p "${source_dir}/checkouts"
    # Create some fake package checkouts.
    mkdir -p "${source_dir}/checkouts/PackageA"
    mkdir -p "${source_dir}/checkouts/PackageB"
    mkdir -p "${source_dir}/checkouts/PackageC"
  fi

  if [ "${FAKE_XCODEBUILD_EXIT:-0}" != "0" ]; then
    echo "error: fake resolution failure"
    exit "${FAKE_XCODEBUILD_EXIT}"
  fi
fi

exit 0
FAKE
chmod +x "${WORK}/bin/xcodebuild"

# ---------------------------------------------------------------------------
# Fake project directory
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/fake.xcodeproj"

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
  # Convert newlines to spaces for easier matching.
  local haystack
  haystack="$(echo "$1" | tr '\n' ' ')"
  case "${haystack}" in
    *"$2"*) ok "$3" ;;
    *) bad "$3 (missing '$2')" ;;
  esac
}

expect_not_contains() {
  # Convert newlines to spaces for easier matching.
  local haystack
  haystack="$(echo "$1" | tr '\n' ' ')"
  case "${haystack}" in
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

export PATH="${WORK}/bin:${PATH}"
export FAKE_LOG="${WORK}/log-empty"
mkdir -p "${FAKE_LOG}"

bash "${SCRIPT}" > /dev/null 2>&1
expect_eq "2" "$?" "no args exits 2"

bash "${SCRIPT}" "fake.xcodeproj" > /dev/null 2>&1
expect_eq "2" "$?" "missing scheme exits 2"

bash "${SCRIPT}" "fake.xcodeproj" "Lumi" > /dev/null 2>&1
expect_eq "2" "$?" "missing source-packages-dir exits 2"

bash "${SCRIPT}" "fake.xcodeproj" "Lumi" "${WORK}/src" --unknown-flag > /dev/null 2>&1
expect_eq "2" "$?" "unknown option exits 2"

bash "${SCRIPT}" "fake.xcodeproj" "Lumi" "${WORK}/src" --derived-data-path > /dev/null 2>&1
expect_eq "2" "$?" "missing --derived-data-path value exits 2"

# ---------------------------------------------------------------------------
# 2. Missing project directory
# ---------------------------------------------------------------------------
echo "▶ missing project"

FAKE_LOG="${WORK}/log-no-project"
mkdir -p "${FAKE_LOG}"

bash "${SCRIPT}" "/nonexistent/project.xcodeproj" "Lumi" "${WORK}/src" > /dev/null 2>&1
expect_eq "2" "$?" "nonexistent project exits 2"

# ---------------------------------------------------------------------------
# 3. Successful resolution forwards correct parameters
# ---------------------------------------------------------------------------
echo "▶ successful resolution"

FAKE_LOG="${WORK}/log-ok"
mkdir -p "${FAKE_LOG}"
src_dir="${WORK}/source-packages"
derived_dir="${WORK}/derived"

bash "${SCRIPT}" "${WORK}/fake.xcodeproj" "Lumi" "${src_dir}" \
  --derived-data-path "${derived_dir}" > "${WORK}/stdout-ok.txt" 2>&1
run_exit=$?

expect_eq "0" "${run_exit}" "exits 0"
ARGS="$(cat "${FAKE_LOG}/xcodebuild-args.txt" 2>/dev/null || echo '')"
expect_contains "${ARGS}" "-resolvePackageDependencies" "passes resolve action"
expect_contains "${ARGS}" "-clonedSourcePackagesDirPath ${src_dir}" "passes source packages dir"
expect_contains "${ARGS}" "-onlyUsePackageVersionsFromResolvedFile" "uses strict resolution"
expect_contains "${ARGS}" "-skipPackagePluginValidation" "skips plugin validation"
expect_contains "${ARGS}" "-derivedDataPath ${derived_dir}" "passes derived data path"
expect_exists "${src_dir}/checkouts" "checkouts directory created"
expect_contains "$(cat "${WORK}/stdout-ok.txt")" "Resolved 3 packages" "reports package count"

# ---------------------------------------------------------------------------
# 4. Failed resolution propagates exit code
# ---------------------------------------------------------------------------
echo "▶ failed resolution"

FAKE_LOG="${WORK}/log-fail"
mkdir -p "${FAKE_LOG}"
export FAKE_XCODEBUILD_EXIT=65

bash "${SCRIPT}" "${WORK}/fake.xcodeproj" "Lumi" "${WORK}/src-fail" \
  > "${WORK}/stdout-fail.txt" 2>&1
run_exit=$?

expect_eq "65" "${run_exit}" "propagates xcodebuild exit code"
expect_contains "$(cat "${WORK}/stdout-fail.txt")" "resolution failed" "reports failure"
unset FAKE_XCODEBUILD_EXIT

# ---------------------------------------------------------------------------
# 5. Default derived data path
# ---------------------------------------------------------------------------
echo "▶ default derived data path"

FAKE_LOG="${WORK}/log-default"
mkdir -p "${FAKE_LOG}"

# Run from a temporary directory so default ./DerivedData doesn't pollute.
(cd "${WORK}" && bash "${SCRIPT}" "${WORK}/fake.xcodeproj" "Lumi" "${WORK}/src-default" \
  > "${WORK}/stdout-default.txt" 2>&1)
run_exit=$?

expect_eq "0" "${run_exit}" "exits 0 with defaults"
ARGS="$(cat "${FAKE_LOG}/xcodebuild-args.txt" 2>/dev/null || echo '')"
expect_contains "${ARGS}" "-derivedDataPath ./DerivedData" "uses default derived data path"

# ---------------------------------------------------------------------------
# 6. Existing checkouts are preserved (not deleted)
# ---------------------------------------------------------------------------
echo "▶ existing checkouts preserved"

FAKE_LOG="${WORK}/log-preserve"
mkdir -p "${FAKE_LOG}"
preserve_dir="${WORK}/src-preserve"
mkdir -p "${preserve_dir}/checkouts/ExistingPackage"
echo "preserved" > "${preserve_dir}/checkouts/ExistingPackage/marker.txt"

bash "${SCRIPT}" "${WORK}/fake.xcodeproj" "Lumi" "${preserve_dir}" \
  > /dev/null 2>&1
run_exit=$?

expect_eq "0" "${run_exit}" "exits 0"
expect_exists "${preserve_dir}/checkouts/ExistingPackage/marker.txt" "existing package preserved"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ "${failures}" -eq 0 ]; then
  echo "✅ test-resolve-ci-packages.sh: ${checks} checks passed"
  exit 0
fi

echo "❌ test-resolve-ci-packages.sh: ${failures} of ${checks} checks failed"
exit 1
