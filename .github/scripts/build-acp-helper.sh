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
#     [--cache-path <path>]
#     [--source-dir <path>]
#     [--resources-dir <path>]
#     [--output-name <name>]
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
#   --cache-path      SwiftPM dependency download cache. Defaults to
#                     ./build/acp-cache.
#   --source-dir      Path to the FactoryLumiACP package. Defaults to
#                     ./Packages/FactoryLumiACP.
#   --resources-dir   Directory for SwiftPM resource bundles. Defaults to the
#                     destination directory.
#   --output-name     Copied executable name (default: lumi-acp).
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
readonly PRODUCT_NAME="LumiACPExecutable"

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
cache_path="${ACP_CACHE_PATH:-./build/acp-cache}"
source_dir="./Packages/FactoryLumiACP"
resources_dir=""
output_name="lumi-acp"
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
    --cache-path)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --cache-path requires a value" >&2
        exit 2
      fi
      cache_path="$2"
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
    --resources-dir)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --resources-dir requires a value" >&2
        exit 2
      fi
      resources_dir="$2"
      shift 2
      ;;
    --output-name)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --output-name requires a value" >&2
        exit 2
      fi
      output_name="$2"
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
  echo "❌ FactoryLumiACP package not found: ${source_dir}" >&2
  exit 1
fi

if [ ! -f "${source_dir}/Package.resolved" ]; then
  echo "❌ FactoryLumiACP Package.resolved not found: ${source_dir}/Package.resolved" >&2
  echo "   Run 'xcrun swift package --package-path ${source_dir} resolve' first." >&2
  exit 1
fi

case "${output_name}" in
  ""|*/*|.|..) echo "❌ Invalid output name: ${output_name}" >&2; exit 2 ;;
esac

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
mkdir -p "${scratch_path}" "${cache_path}"

lock_file="${source_dir}/Package.resolved"
lock_hash_before="$(shasum -a 256 "${lock_file}" | awk '{print $1}')"

echo "🔧 Building ACP helper for ${arch} (${config})..."
echo "    triple:    ${triple}"
echo "    scratch:   ${scratch_path}"
echo "    cache:     ${cache_path}"
echo "    source:    ${source_dir}"

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_seconds="${SECONDS}"

set +e
xcrun swift build \
  --package-path "${source_dir}" \
  -c "${config}" \
  --product "${PRODUCT_NAME}" \
  --triple "${triple}" \
  --sdk "${sdk_path}" \
  --scratch-path "${scratch_path}" \
  --cache-path "${cache_path}" \
  --force-resolved-versions 2>&1
build_exit=$?
set -e

elapsed_seconds=$((SECONDS - start_seconds))

if [ "${build_exit}" -ne 0 ]; then
  echo "❌ ACP build failed for ${arch} (exit ${build_exit}) after ${elapsed_seconds}s" >&2
  exit "${build_exit}"
fi

lock_hash_after="$(shasum -a 256 "${lock_file}" | awk '{print $1}')"
if [ "${lock_hash_before}" != "${lock_hash_after}" ]; then
  echo "❌ ACP dependency lock changed during the build" >&2
  echo "   before: ${lock_hash_before}" >&2
  echo "   after:  ${lock_hash_after}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Locate binary
# ---------------------------------------------------------------------------
set +e
bin_dir="$(xcrun swift build \
  --package-path "${source_dir}" \
  -c "${config}" \
  --product "${PRODUCT_NAME}" \
  --triple "${triple}" \
  --sdk "${sdk_path}" \
  --scratch-path "${scratch_path}" \
  --cache-path "${cache_path}" \
  --force-resolved-versions \
  --show-bin-path 2>/dev/null)"
set -e

if [ -z "${bin_dir}" ]; then
  echo "❌ Could not determine bin path for ${arch}" >&2
  exit 1
fi

binary="${bin_dir}/${PRODUCT_NAME}"

if [ ! -x "${binary}" ]; then
  echo "❌ ${PRODUCT_NAME} binary not found or not executable: ${binary}" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Verify architecture
# ---------------------------------------------------------------------------
if ! lipo "${binary}" -verify_arch "${arch}" 2>/dev/null; then
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
if [ -z "${resources_dir}" ]; then
  resources_dir="${dest_dir}"
fi
mkdir -p "${resources_dir}"

# Copy the executable under the caller-selected runtime name.
cp -f "${binary}" "${dest_dir}/${output_name}"
chmod 755 "${dest_dir}/${output_name}"

# Copy resource bundles alongside the executable.
for bundle in "${bin_dir}"/*.bundle; do
  [ -d "${bundle}" ] || continue
  ditto "${bundle}" "${resources_dir}/$(basename "${bundle}")"
done

echo "✅ Copied ${output_name} to ${dest_dir}"
