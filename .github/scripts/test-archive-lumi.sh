#!/usr/bin/env bash
#
# Tests for archive-lumi.sh.
#
# A fake xcodebuild stands in for the real toolchain so that the script's arch
# validation, argument construction, log handling, stale-archive cleanup and
# exit-code propagation can be asserted without a real toolchain, a real
# archive or a network round trip. Mocking does not replace a real macOS build;
# it only proves the wrapper forwards the right things to it.
#
# Usage: bash .github/scripts/test-archive-lumi.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/archive-lumi.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# ---------------------------------------------------------------------------
# Fake xcodebuild
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/bin"
cat > "${WORK}/bin/xcodebuild" <<'FAKE'
#!/usr/bin/env bash
set -uo pipefail

printf '%s\n' "$@" > "${FAKE_XCODEBUILD_ARGS}"

prev=""
for arg in "$@"; do
  if [ "${prev}" = "-archivePath" ] && [ "${FAKE_XCODEBUILD_SKIP_ARCHIVE:-0}" != "1" ]; then
    # Emulate a successful archive producing the requested bundle.
    mkdir -p "${arg}/Products/Applications"
  fi
  prev="${arg}"
done

echo "fake xcodebuild invoked with $# arguments"
if [ "${FAKE_XCODEBUILD_EXIT:-0}" != "0" ]; then
  echo "error: fake failure for exit ${FAKE_XCODEBUILD_EXIT}"
  echo "BUILD FAILED"
fi
exit "${FAKE_XCODEBUILD_EXIT:-0}"
FAKE
chmod +x "${WORK}/bin/xcodebuild"

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

expect_not_exists() { # path label
  if [ ! -e "$1" ]; then ok "$2"; else bad "$2 (found '$1')"; fi
}

expect_exists() { # path label
  if [ -e "$1" ]; then ok "$2"; else bad "$2 (missing '$1')"; fi
}

# ---------------------------------------------------------------------------
# Case harness
# ---------------------------------------------------------------------------
CASE_DIR=""
case_start() { # slug
  CASE_DIR="${WORK}/case-$1"
  mkdir -p "${CASE_DIR}"
  export FAKE_XCODEBUILD_ARGS="${CASE_DIR}/args.txt"
  export XCODEBUILD_BIN="${WORK}/bin/xcodebuild"
  export SCHEME="Lumi"
  export PROJECT="Lumi.xcodeproj"
  export DESTINATION="generic/platform=macOS"
  export DERIVED_DATA_PATH="${CASE_DIR}/DerivedData"
  export ARCHIVE_DIR="${CASE_DIR}/temp"
  unset FAKE_XCODEBUILD_EXIT FAKE_XCODEBUILD_SKIP_ARCHIVE
  echo "▶ $2"
}

run_archive() { # [arch] [team]
  set +e
  bash "${SCRIPT}" "$@" > "${CASE_DIR}/stdout.txt" 2>&1
  run_exit=$?
  set -e
}
set +e

# ---------------------------------------------------------------------------
# 1. arm64 success: settings and paths forwarded unchanged
# ---------------------------------------------------------------------------
case_start "arm64-ok" "arm64 success forwards the release settings"
run_archive "arm64" "TEAMID1234"
expect_eq "0" "${run_exit}" "exits 0"
ARGS="$(cat "${FAKE_XCODEBUILD_ARGS}" 2>/dev/null || echo '')"
expect_contains "${ARGS}" "archive" "passes the archive action"
expect_contains "${ARGS}" "Lumi.xcodeproj" "passes the project"
expect_contains "${ARGS}" "generic/platform=macOS" "passes the destination"
expect_contains "${ARGS}" "${CASE_DIR}/DerivedData" "passes the derived data path"
expect_contains "${ARGS}" "${CASE_DIR}/temp/Lumi-arm64.xcarchive" "passes the per-arch archive path"
expect_contains "${ARGS}" "Release" "keeps the Release configuration"
expect_contains "${ARGS}" "CODE_SIGN_STYLE=Manual" "keeps manual signing"
expect_contains "${ARGS}" "CODE_SIGN_IDENTITY=-" "keeps ad-hoc identity"
expect_contains "${ARGS}" "DEVELOPMENT_TEAM=TEAMID1234" "forwards the team id"
expect_contains "${ARGS}" "PROVISIONING_PROFILE_SPECIFIER=" "keeps the empty profile specifier"
expect_contains "${ARGS}" "CODE_SIGNING_REQUIRED=NO" "keeps CODE_SIGNING_REQUIRED=NO"
expect_contains "${ARGS}" "AD_HOC_CODE_SIGNING_ALLOWED=YES" "keeps ad-hoc signing allowed"
expect_contains "${ARGS}" "ARCHS=arm64" "targets only arm64"
expect_contains "${ARGS}" "ONLY_ACTIVE_ARCH=NO" "keeps ONLY_ACTIVE_ARCH=NO"
expect_contains "${ARGS}" "-skipPackagePluginValidation" "keeps plugin validation skip"
expect_contains "${ARGS}" "-skipPackageSignatureValidation" "keeps signature validation skip"
expect_contains "${ARGS}" "-showBuildTimingSummary" "includes build timing summary"
expect_contains "${ARGS}" "-resultBundlePath" "includes result bundle path flag"
expect_contains "${ARGS}" "${CASE_DIR}/temp/results-arm64.xcresult" "passes the per-arch result bundle path"
expect_exists "${CASE_DIR}/temp/archive-arm64.log" "writes a per-arch log file"

# ---------------------------------------------------------------------------
# 2. x86_64 success targets the other slice
# ---------------------------------------------------------------------------
case_start "x86-ok" "x86_64 success targets the Intel slice"
run_archive "x86_64" "TEAMID1234"
expect_eq "0" "${run_exit}" "exits 0"
ARGS="$(cat "${FAKE_XCODEBUILD_ARGS}" 2>/dev/null || echo '')"
expect_contains "${ARGS}" "ARCHS=x86_64" "targets only x86_64"
expect_contains "${ARGS}" "${CASE_DIR}/temp/Lumi-x86_64.xcarchive" "uses the x86_64 archive path"
expect_exists "${CASE_DIR}/temp/archive-x86_64.log" "writes the x86_64 log file"

# ---------------------------------------------------------------------------
# 3. Unsupported architecture is rejected before any build
# ---------------------------------------------------------------------------
case_start "bad-arch" "unsupported architecture never reaches xcodebuild"
run_archive "i386" "TEAMID1234"
expect_eq "2" "${run_exit}" "exits 2"
expect_not_exists "${FAKE_XCODEBUILD_ARGS}" "xcodebuild was not invoked"
expect_contains "$(cat "${CASE_DIR}/stdout.txt")" "Unsupported architecture" "explains the rejection"

case_start "host-arch" "the host architecture name is not accepted silently"
run_archive "arm64e" "TEAMID1234"
expect_eq "2" "${run_exit}" "exits 2"
expect_not_exists "${FAKE_XCODEBUILD_ARGS}" "xcodebuild was not invoked"

case_start "no-args" "a missing architecture argument is a usage error"
run_archive
expect_eq "2" "${run_exit}" "exits 2"
expect_contains "$(cat "${CASE_DIR}/stdout.txt")" "usage:" "prints usage"

case_start "extra-args" "extra arguments are rejected"
run_archive "arm64" "TEAM" "surplus"
expect_eq "2" "${run_exit}" "exits 2"

# ---------------------------------------------------------------------------
# 4. xcodebuild failure: real exit code propagated, diagnostics kept
# ---------------------------------------------------------------------------
case_start "fail-65" "xcodebuild failure propagates the real exit code"
export FAKE_XCODEBUILD_EXIT=65
run_archive "arm64" "TEAMID1234"
expect_eq "65" "${run_exit}" "exits with xcodebuild's 65"
STDOUT="$(cat "${CASE_DIR}/stdout.txt")"
expect_contains "${STDOUT}" "Archive failed for arm64 (exit 65)" "reports the failing arch and code"
expect_contains "${STDOUT}" "error: fake failure for exit 65" "tails the raw log"
expect_contains "${STDOUT}" "BUILD FAILED" "greps the failure lines"
expect_exists "${CASE_DIR}/temp/archive-arm64.log" "keeps the raw log for upload"
unset FAKE_XCODEBUILD_EXIT

case_start "fail-log" "the log is not replaced by a successful run"
export FAKE_XCODEBUILD_EXIT=70
run_archive "x86_64" "TEAMID1234"
expect_eq "70" "${run_exit}" "exits with xcodebuild's 70"
expect_contains "$(cat "${CASE_DIR}/temp/archive-x86_64.log")" "BUILD FAILED" "log holds the failure output"
unset FAKE_XCODEBUILD_EXIT

# ---------------------------------------------------------------------------
# 5. Success without an archive is still a failure
# ---------------------------------------------------------------------------
case_start "missing-archive" "zero exit without an archive fails"
export FAKE_XCODEBUILD_SKIP_ARCHIVE=1
run_archive "arm64" "TEAMID1234"
expect_eq "1" "${run_exit}" "exits 1"
expect_contains "$(cat "${CASE_DIR}/stdout.txt")" "is missing" "names the missing archive"
unset FAKE_XCODEBUILD_SKIP_ARCHIVE

# ---------------------------------------------------------------------------
# 6. A stale archive is removed before the run
# ---------------------------------------------------------------------------
case_start "stale-archive" "stale archive contents never survive into a new run"
mkdir -p "${CASE_DIR}/temp/Lumi-arm64.xcarchive"
echo "stale" > "${CASE_DIR}/temp/Lumi-arm64.xcarchive/stale-marker"
run_archive "arm64" "TEAMID1234"
expect_eq "0" "${run_exit}" "exits 0"
expect_not_exists "${CASE_DIR}/temp/Lumi-arm64.xcarchive/stale-marker" "stale archive was removed"

# ---------------------------------------------------------------------------
# 7. Defaults: no team id argument falls back to the environment
# ---------------------------------------------------------------------------
case_start "team-default" "DEVELOPMENT_TEAM env is the fallback team id"
export DEVELOPMENT_TEAM="ENVTEAM99"
run_archive "arm64"
expect_eq "0" "${run_exit}" "exits 0"
expect_contains "$(cat "${FAKE_XCODEBUILD_ARGS}")" "DEVELOPMENT_TEAM=ENVTEAM99" "uses the environment team id"
unset DEVELOPMENT_TEAM

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ "${failures}" -eq 0 ]; then
  echo "✅ test-archive-lumi.sh: ${checks} checks passed"
  exit 0
fi

echo "❌ test-archive-lumi.sh: ${failures} of ${checks} checks failed"
exit 1
