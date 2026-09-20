#!/usr/bin/env bash
#
# resolve-ci-packages.sh — resolve SwiftPM dependencies with strict locking.
#
# This script is designed for CI use with cached source packages. It:
#   * Uses -clonedSourcePackagesDirPath to specify where packages are stored,
#     allowing the same directory to be cached across builds.
#   * Uses -onlyUsePackageVersionsFromResolvedFile to prevent implicit upgrades.
#   * Does NOT delete the source packages directory; the caller is responsible
#     for cache restoration and invalidation.
#
# Usage:
#   resolve-ci-packages.sh <project> <scheme> <source-packages-dir> [options]
#     [--derived-data-path <path>]
#
# Arguments:
#   project              Path to the .xcodeproj file.
#   scheme               Xcode scheme to resolve.
#   source-packages-dir  Directory where SwiftPM packages are/will be stored.
#
# Options:
#   --derived-data-path  Derived data path (default: ./DerivedData).
#
# Exit codes:
#   0   success
#   1   resolution failed
#   2   usage error

set -euo pipefail

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [ "$#" -lt 3 ]; then
  echo "usage: $(basename "$0") <project> <scheme> <source-packages-dir> [--derived-data-path <path>]" >&2
  exit 2
fi

project="$1"
scheme="$2"
source_packages_dir="$3"
shift 3

derived_data_path="./DerivedData"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --derived-data-path)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --derived-data-path requires a value" >&2
        exit 2
      fi
      derived_data_path="$2"
      shift 2
      ;;
    *)
      echo "error: unknown option: $1" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
if [ ! -d "${project}" ]; then
  echo "❌ Project not found: ${project}" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Resolve
# ---------------------------------------------------------------------------
echo "📦 Resolving SwiftPM dependencies..."
echo "    project:    ${project}"
echo "    scheme:     ${scheme}"
echo "    packages:   ${source_packages_dir}"
echo "    derived:    ${derived_data_path}"

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_seconds="${SECONDS}"

# Create the source packages directory if it doesn't exist.
# This is safe even with cached packages; xcodebuild will reuse existing checkouts.
mkdir -p "${source_packages_dir}"
mkdir -p "${derived_data_path}"

set +e
xcodebuild -project "${project}" \
  -scheme "${scheme}" \
  -derivedDataPath "${derived_data_path}" \
  -clonedSourcePackagesDirPath "${source_packages_dir}" \
  -resolvePackageDependencies \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackagePluginValidation \
  -skipPackageSignatureValidation 2>&1
resolve_exit=$?
set -e

elapsed_seconds=$((SECONDS - start_seconds))
finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ "${resolve_exit}" -ne 0 ]; then
  echo "❌ Dependency resolution failed (exit ${resolve_exit}) after ${elapsed_seconds}s" >&2
  echo "   started: ${started_at}  finished: ${finished_at}" >&2
  exit "${resolve_exit}"
fi

# Verify that checkouts were actually created.
if [ ! -d "${source_packages_dir}/checkouts" ]; then
  echo "❌ Resolution succeeded but checkouts directory not found: ${source_packages_dir}/checkouts" >&2
  exit 1
fi

checkout_count="$(ls "${source_packages_dir}/checkouts" | wc -l | tr -d ' ')"
echo "✅ Resolved ${checkout_count} packages in ${elapsed_seconds}s (${started_at} → ${finished_at})"
