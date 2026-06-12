#!/bin/bash
# Verifies install-sparkle-tools.sh returns a usable bin path on a fresh install.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

chmod +x "${ROOT}/.github/scripts/install-sparkle-tools.sh"

SPARKLE_BIN="$(
    SPARKLE_VERSION="${SPARKLE_VERSION:-2.9.1}" \
    RUNNER_TEMP="${TEST_ROOT}" \
    "${ROOT}/.github/scripts/install-sparkle-tools.sh"
)"

if [[ "${SPARKLE_BIN}" == *$'\n'* ]]; then
    echo "❌ install script stdout must be a single line (got multiline output)" >&2
    printf '%q\n' "${SPARKLE_BIN}" >&2
    exit 1
fi

if [ ! -x "${SPARKLE_BIN}/generate_appcast" ]; then
    echo "❌ generate_appcast not executable at ${SPARKLE_BIN}/generate_appcast" >&2
    exit 1
fi

"${SPARKLE_BIN}/generate_appcast" --help >/dev/null

echo "✅ Sparkle tools install test passed: ${SPARKLE_BIN}"
