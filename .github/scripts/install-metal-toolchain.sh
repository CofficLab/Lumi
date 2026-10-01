#!/usr/bin/env bash
#
# install-metal-toolchain.sh — make the Metal compiler usable on CI runners.
#
# Xcode 26 made the Metal toolchain an optional component and the hosted
# runner images do not pre-install it. mlx-swift compiles .metal sources, so
# archiving fails with "cannot execute tool 'metal'" while the payload is
# absent.
#
# The component is delivered as a cryptex (an encrypted disk image) mounted
# under /private/var/run/com.apple.security.cryptexd. `xcodebuild
# -downloadComponent` returns as soon as the asset lands in MobileAsset, so a
# probe fired immediately afterwards can still fail with "missing Metal
# Toolchain" until the image is mounted. This script downloads when needed and
# then polls the compiler until the toolchain is actually usable.
#
# `xcrun -f metal` is not a usable probe: it resolves the launcher shim inside
# XcodeDefault.xctoolchain even when no payload is installed, which would
# silently skip the download.
#
# Usage:
#   install-metal-toolchain.sh [options]
#
# Options:
#   --timeout <seconds>  total wait budget for the toolchain to become usable
#                        (default: 120)
#   --interval <seconds> delay between probes (default: 2)
#
# Environment variables (override defaults):
#   METAL_TOOLCHAIN_TIMEOUT   fallback when --timeout is not passed
#   METAL_TOOLCHAIN_INTERVAL  fallback when --interval is not passed
#
# Exit codes:
#   0   the Metal compiler is available
#   1   the toolchain could not be made usable
#   2   usage error

set -euo pipefail

timeout="${METAL_TOOLCHAIN_TIMEOUT:-120}"
interval="${METAL_TOOLCHAIN_INTERVAL:-2}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --timeout requires a value" >&2
        exit 2
      fi
      timeout="$2"
      shift 2
      ;;
    --interval)
      if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
        echo "error: --interval requires a value" >&2
        exit 2
      fi
      interval="$2"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

case "${timeout}" in
  ''|*[!0-9]*) echo "error: --timeout must be a positive integer" >&2; exit 2 ;;
esac
case "${interval}" in
  ''|*[!0-9]*) echo "error: --interval must be a positive integer" >&2; exit 2 ;;
esac
if [ "${interval}" -lt 1 ]; then
  echo "error: --interval must be at least 1 second" >&2
  exit 2
fi

metal_available() {
  xcrun metal --version >/dev/null 2>&1
}

# Poll until the compiler answers, or the wait budget runs out. Returns 0 once
# the toolchain is usable and 1 when the budget is exhausted, so callers can
# distinguish "ready" from "timed out".
wait_for_metal() {
  local elapsed=0
  while :; do
    if metal_available; then
      return 0
    fi
    if [ "${elapsed}" -ge "${timeout}" ]; then
      return 1
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done
}

if metal_available; then
  echo "Metal toolchain already available"
else
  echo "Downloading the Metal toolchain..."
  xcodebuild -downloadComponent MetalToolchain
  # The download reports completion before the cryptex is mounted, so retry
  # instead of failing on the first probe.
  sleep "${interval}"
  if ! wait_for_metal; then
    echo "Metal toolchain is still unusable after the download" >&2
    exit 1
  fi
  echo "Metal toolchain installed"
fi

xcrun metal --version
