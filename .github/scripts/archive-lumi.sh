#!/usr/bin/env bash
#
# archive-lumi.sh — archive ONE architecture of Lumi with the release settings.
#
# Extracted from the inline "Build App (Archive)" step of
# .github/workflows/release.yml so that the CI invocation can be:
#   * tested with a fake xcodebuild (see test-archive-lumi.sh),
#   * instrumented with timings, timing summaries and result bundles,
#   * handed extra per-architecture parameters (SDK, caches, lock enforcement).
#
# The published release behaviour is intentionally identical to the inline
# version: same xcodebuild invocation, same environment variables, same
# per-arch log file, same serial order in the caller.
#
# Usage:
#   archive-lumi.sh <arch> [development-team-id]
#
# Supported architectures: arm64, x86_64. Anything else exits 2 WITHOUT
# invoking xcodebuild. A silent host-architecture fallback is exactly the
# failure mode this script exists to make impossible.
#
# Exit codes:
#   0   archive succeeded and the .xcarchive exists
#   1   xcodebuild reported success but produced no archive
#   2   usage / unsupported architecture
#   N   otherwise the real xcodebuild exit code is propagated unchanged
#
# Configuration (environment variables; CI provides them via workflow env):
#   SCHEME             Xcode scheme / product name            (default: Lumi)
#   PROJECT            Xcode project path     (default: ${SCHEME}.xcodeproj)
#   DESTINATION        xcodebuild -destination (default: generic/platform=macOS)
#   DERIVED_DATA_PATH  xcodebuild -derivedDataPath       (default: ./DerivedData)
#   SOURCE_PACKAGES_PATH  xcodebuild -clonedSourcePackagesDirPath (default: ./SourcePackages)
#   ARCHIVE_DIR        where .xcarchive and logs are written  (default: ./temp)
#   DEVELOPMENT_TEAM   fallback team id when arg 2 is omitted
#   XCODEBUILD_BIN     xcodebuild executable to run (default: xcodebuild)
#
# Diagnostics:
#   Each archive also produces:
#     * ${archive_dir}/results-${arch}.xcresult  — Xcode result bundle
#       (timing summary, per-target build durations, diagnostics)
#     * -showBuildTimingSummary output in the log
#   The result bundle path is cleaned before the run so a stale bundle from
#   an earlier archive never mixes with the current one.

set -euo pipefail

readonly SUPPORTED_ARCHS="arm64 x86_64"
readonly DEFAULT_SCHEME="Lumi"

usage() {
  echo "usage: $(basename "$0") <arch> [development-team-id]" >&2
  echo "       supported archs: ${SUPPORTED_ARCHS}" >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

arch="$1"
team_id="${2:-${DEVELOPMENT_TEAM:-}}"

case " ${SUPPORTED_ARCHS} " in
  *" ${arch} "*) ;;
  *)
    echo "❌ Unsupported architecture: ${arch}" >&2
    usage
    exit 2
    ;;
esac

scheme="${SCHEME:-${DEFAULT_SCHEME}}"
project="${PROJECT:-${scheme}.xcodeproj}"
destination="${DESTINATION:-generic/platform=macOS}"
derived_data_path="${DERIVED_DATA_PATH:-./DerivedData}"
source_packages_path="${SOURCE_PACKAGES_PATH:-./SourcePackages}"
archive_dir="${ARCHIVE_DIR:-./temp}"
xcodebuild_bin="${XCODEBUILD_BIN:-xcodebuild}"

archive_path="${archive_dir}/${scheme}-${arch}.xcarchive"
archive_log="${archive_dir}/archive-${arch}.log"
result_bundle_path="${archive_dir}/results-${arch}.xcresult"

mkdir -p "${archive_dir}"

# Always start from an empty target path: a stale bundle from an earlier run
# must never be mistaken for the result of this one.
rm -rf "${archive_path}"
rm -rf "${result_bundle_path}"

echo "🏗️  Archiving ${scheme} for ${arch}..."
echo "    archive: ${archive_path}"
echo "    log:     ${archive_log}"
echo "    results: ${result_bundle_path}"

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_seconds="${SECONDS}"

# xcodebuild is expected to fail sometimes; capture its real exit code instead
# of letting `set -e` collapse it into a generic failure.
set +e
"${xcodebuild_bin}" archive \
  -project "${project}" \
  -scheme "${scheme}" \
  -destination "${destination}" \
  -derivedDataPath "${derived_data_path}" \
  -clonedSourcePackagesDirPath "${source_packages_path}" \
  -archivePath "${archive_path}" \
  -configuration Release \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackageUpdates \
  -skipPackagePluginValidation \
  -skipPackageSignatureValidation \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  DEVELOPMENT_TEAM="${team_id}" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  CODE_SIGNING_REQUIRED=NO \
  AD_HOC_CODE_SIGNING_ALLOWED=YES \
  DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
  GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
  ARCHS="${arch}" \
  ONLY_ACTIVE_ARCH=NO \
  -showBuildTimingSummary \
  -resultBundlePath "${result_bundle_path}" > "${archive_log}" 2>&1
archive_exit=$?
set -e

finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
elapsed_seconds=$((SECONDS - start_seconds))

if [ "${archive_exit}" -ne 0 ]; then
  echo "❌ Archive failed for ${arch} (exit ${archive_exit}) after ${elapsed_seconds}s"
  echo "   started: ${started_at}  finished: ${finished_at}"
  echo "   full log kept at ${archive_log}; tail:"
  tail -200 "${archive_log}" || true
  echo ""
  echo "--- error / failure lines ---"
  grep -E "(error:|FAILED|BUILD FAILED|Cannot find)" "${archive_log}" | head -60 || true
  # Propagate the real exit code so the caller and CI diagnostics agree.
  exit "${archive_exit}"
fi

# A zero exit without the requested archive is still a failure: the following
# steps read ${archive_path}, not whatever xcodebuild felt like producing.
if [ ! -d "${archive_path}" ]; then
  echo "❌ Archive reported success for ${arch} but ${archive_path} is missing"
  echo "   full log kept at ${archive_log}"
  exit 1
fi

echo "✅ Archived ${arch} in ${elapsed_seconds}s (${started_at} → ${finished_at})"
