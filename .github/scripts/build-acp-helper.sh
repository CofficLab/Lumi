#!/usr/bin/env bash
#
# build-acp-helper.sh — build the ACP helper for a single target architecture.
#
# Extracted from the inline "Build ACP Executable" build phase of
# Lumi.xcodeproj/project.pbxproj so that:
#   * CI can pass an explicit --triple instead of silently building for the
#     host architecture,
#   * the build scratch path is isolated per architecture,
#   * the locked dependency file is enforced,
#   * the resulting binary is verified with lipo before any copy.
#
# Usage:
#   build-acp-helper.sh <arch> <destination-dir>
#     [--config debug|release]
#     [--scratch-path <path>]
#     [--source-dir <path>]
#     [--skip-copy]
#
# Arguments:
#   arch              Target architecture: arm64 or x86_64.
#   destination-dir   Directory to copy the built executable and resource
#                     bundles into. The executable is named "lumi-acp".
#
# Options:
#   --config          Build configuration (default: release).
#   --scratch-path    SwiftPM scratch directory. Defaults to
#                     ./build/ci-acp/<arch> when CI is set, or
#                     ./build/acp/<arch> otherwise.
#   --source-dir      Path to the ACPBootstrap package. Defaults to
#                     ./Packages/ACPBootstrap.
#   --skip-copy       Do not copy; print the binary path and exit.
#
# Exit codes:
#   0   success
#   1   build or verification failure
#   2   usage error

set -euo pipefail

readonly SUPPORTED_ARCHS="arm64 x86_64"
readonly DEFAULT_CONFIG="release"
readonly DEPLOYMENT_TARGET="14.0"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [ "$#" -lt 2 ]; then
  echo "usage: $(basename "$0") <arch> <destination-dir> [options]" >&2
  exit 2
fi

arch="$1"
dest_dir="$2"
shift 2

config="${DEFAULT_CONFIG}"
scratch_path=""
source_dir="./Packages/ACPBootstrap"
skip_copy=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --config)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --config requires a value" >&2
        exit 2
      fi
      config="$2"
      shift 2
      ;;
    --scratch-path)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --scratch-path requires a value" >&2
        exit 2
      fi
      scratch_path="$2"
      shift 2
      ;;
    --source-dir)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --source-dir requires a value" >&2
        exit 2
      fi
      source_dir="$2"
      shift 2
      ;;
    --skip-copy)
      skip_copy=true
      shift
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
case " ${SUPPORTED_ARCHS} " in
  *" ${arch} "*) ;;
  *)
    echo "❌ Unsupported architecture: ${arch}" >&2
    echo "   supported: ${SUPPORTED_ARCHS}" >&2
    exit 2
    ;;
esac

case "${config}" in
  debug|release) ;;
  *)
    echo "❌ Invalid config: ${config} (expected debug or release)" >&2
    exit 2
    ;;
esac

if [ ! -d "${source_dir}" ]; then
  echo "❌ ACPBootstrap package not found: ${source_dir}" >&2
  exit 1
fi

if [ ! -f "${source_dir}/Package.resolved" ]; then
  echo "❌ ACPBootstrap Package.resolved not found: ${source_dir}/Package.resolved" >&2
  echo "   Run 'xcrun swift package --package-path ${source_dir} resolve' first." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Defaults for scratch path
# ---------------------------------------------------------------------------
if [ -z "${scratch_path}" ]; then
  if [ -n "${CI:-}" ]; then
    scratch_path="./build/ci-acp/${arch}"
  else
    scratch_path="./build/acp/${arch}"
  fi
fi

# ---------------------------------------------------------------------------
# Resolve toolchain
# ---------------------------------------------------------------------------
swift_bin="$(xcrun --find swift 2>/dev/null || true)"
if [ -z "${swift_bin}" ]; then
  echo "❌ Cannot find swift; is Xcode installed?" >&2
  exit 1
fi

sdk_path="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [ -z "${sdk_path}" ]; then
  echo "❌ Cannot find macOS SDK path" >&2
  exit 1
fi

triple="${arch}-apple-macosx${DEPLOYMENT_TARGET}"

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
mkdir -p "${scratch_path}"

echo "🔧 Building ACP helper for ${arch} (${config})..."
echo "    triple:    ${triple}"
echo "    scratch:   ${scratch_path}"
echo "    source:    ${source_dir}"

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_seconds="${SECONDS}"

set +e
xcrun swift build \
  --package-path "${source_dir}" \
  -c "${config}" \
  --product ACPBootstrap \
  --triple "${triple}" \
  --sdk "${sdk_path}" \
  --scratch-path "${scratch_path}" \
  --force-resolved-versions 2>&1
build_exit=$?
set -e

elapsed_seconds=$((SECONDS - start_seconds))

if [ "${build_exit}" -ne 0 ]; then
  echo "❌ ACP build failed for ${arch} (exit ${build_exit}) after ${elapsed_seconds}s" >&2
  exit "${build_exit}"
fi

# ---------------------------------------------------------------------------
# Locate binary
# ---------------------------------------------------------------------------
set +e
bin_dir="$(xcrun swift build \
  --package-path "${source_dir}" \
  -c "${config}" \
  --product ACPBootstrap \
  --triple "${triple}" \
  --sdk "${sdk_path}" \
  --scratch-path "${scratch_path}" \
  --show-bin-path 2>/dev/null)"
set -e

if [ -z "${bin_dir}" ]; then
  echo "❌ Could not determine bin path for ${arch}" >&2
  exit 1
fi

binary="${bin_dir}/ACPBootstrap"

if [ ! -x "${binary}" ]; then
  echo "❌ ACPBootstrap binary not found or not executable: ${binary}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Verify architecture
# ---------------------------------------------------------------------------
if ! lipo -verify_arch "${arch}" "${binary}" 2>/dev/null; then
  echo "❌ Binary does not contain expected architecture: ${arch}" >&2
  echo "   actual: $(lipo -archs "${binary}" 2>/dev/null || echo 'unknown')" >&2
  exit 1
fi

echo "✅ ACP helper built for ${arch} in ${elapsed_seconds}s (${started_at})"

# ---------------------------------------------------------------------------
# Copy or print path
# ---------------------------------------------------------------------------
if [ "${skip_copy}" = "true" ]; then
  echo "${binary}"
  exit 0
fi

if [ -z "${dest_dir}" ]; then
  echo "❌ destination-dir is required (or use --skip-copy)" >&2
  exit 2
fi

mkdir -p "${dest_dir}"

# Copy the executable as lumi-acp.
cp -f "${binary}" "${dest_dir}/lumi-acp"
chmod 755 "${dest_dir}/lumi-acp"

# Copy resource bundles alongside the executable.
for bundle in "${bin_dir}"/*.bundle; do
  [ -d "${bundle}" ] || continue
  ditto "${bundle}" "${dest_dir}/$(basename "${bundle}")"
done

echo "✅ Copied lumi-acp to ${dest_dir}"
