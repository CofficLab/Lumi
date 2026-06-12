#!/bin/bash
# Installs Sparkle release tools (generate_appcast) for CI appcast generation.
# Sparkle is no longer an Xcode SPM dependency, but release still signs appcasts.
set -euo pipefail

SPARKLE_VERSION="${SPARKLE_VERSION:-2.9.1}"
INSTALL_ROOT="${1:-${RUNNER_TEMP:-/tmp}/sparkle-tools}"
INSTALL_DIR="${INSTALL_ROOT}/${SPARKLE_VERSION}"
SPARKLE_BIN="${INSTALL_DIR}/bin"

if [ -x "${SPARKLE_BIN}/generate_appcast" ]; then
    echo "${SPARKLE_BIN}"
    exit 0
fi

mkdir -p "${INSTALL_DIR}"
ARCHIVE="${INSTALL_DIR}/Sparkle-${SPARKLE_VERSION}.tar.xz"
URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"

echo "⬇️  Downloading Sparkle ${SPARKLE_VERSION} tools..."
curl -fsSL "${URL}" -o "${ARCHIVE}"
tar -xf "${ARCHIVE}" -C "${INSTALL_DIR}"

if [ ! -x "${SPARKLE_BIN}/generate_appcast" ]; then
    echo "❌ generate_appcast not found after extracting ${ARCHIVE}" >&2
    ls -la "${INSTALL_DIR}" >&2 || true
    exit 1
fi

echo "${SPARKLE_BIN}"
