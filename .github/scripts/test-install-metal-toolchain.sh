#!/bin/bash
# Verifies install-metal-toolchain.sh polling behaviour without Xcode.
#
# The script is exercised with stub `xcrun`, `xcodebuild` and `sleep` binaries
# on PATH so the real Metal toolchain is never touched. Scenarios covered:
#   * a toolchain that is already usable is not downloaded
#   * a download whose payload becomes usable only after the first probes is
#     waited for instead of failing (the cryptex mount race)
#   * a download that never becomes usable still fails loudly
#   * a failing component download aborts the step
#   * invalid options are rejected
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${ROOT}/.github/scripts/install-metal-toolchain.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "${TEST_ROOT}"' EXIT

chmod +x "${SCRIPT}"

BIN_DIR="${TEST_ROOT}/bin"
STATE_DIR="${TEST_ROOT}/state"
mkdir -p "${BIN_DIR}" "${STATE_DIR}"

# Stub `xcrun`: reports the Metal compiler as usable once the probe counter
# reaches READY_AFTER, mirroring a toolchain whose cryptex has mounted.
cat > "${BIN_DIR}/xcrun" <<'STUB'
#!/bin/bash
set -euo pipefail
if [ "${1:-}" != "metal" ]; then
  exit 1
fi
probes=$(( $(cat "${STATE_DIR}/probes" 2>/dev/null || echo 0) + 1 ))
echo "${probes}" > "${STATE_DIR}/probes"
if [ "${probes}" -ge "${READY_AFTER:-1}" ]; then
  echo "Apple metal version 1.0 (stub)"
  exit 0
fi
echo "error: cannot execute tool 'metal' due to missing Metal Toolchain" >&2
exit 1
STUB
chmod +x "${BIN_DIR}/xcrun"

# Stub `xcodebuild`: records that a download was requested.
cat > "${BIN_DIR}/xcodebuild" <<'STUB'
#!/bin/bash
set -euo pipefail
touch "${STATE_DIR}/downloaded"
if [ "${DOWNLOAD_FAILS:-0}" = "1" ]; then
  exit 1
fi
echo "Done downloading: Metal Toolchain (stub)."
STUB
chmod +x "${BIN_DIR}/xcodebuild"

# Stub `sleep` so polling does not slow the test down, while still recording
# that the script waited between probes.
cat > "${BIN_DIR}/sleep" <<'STUB'
#!/bin/bash
set -euo pipefail
count=$(( $(cat "${STATE_DIR}/sleeps" 2>/dev/null || echo 0) + 1 ))
echo "${count}" > "${STATE_DIR}/sleeps"
exit 0
STUB
chmod +x "${BIN_DIR}/sleep"

export PATH="${BIN_DIR}:${PATH}"
export STATE_DIR
export READY_AFTER=1

reset_state() {
  rm -rf "${STATE_DIR}"
  mkdir -p "${STATE_DIR}"
  unset DOWNLOAD_FAILS
}

# --- Scenario 1: toolchain already usable, no download -----------------------
reset_state
export READY_AFTER=1
output="$("${SCRIPT}" 2>&1)"
if ! grep -q "already available" <<<"${output}"; then
  echo "❌ expected 'already available' when the compiler answers immediately" >&2
  echo "${output}" >&2
  exit 1
fi
if [ -f "${STATE_DIR}/downloaded" ]; then
  echo "❌ a usable toolchain must not trigger a download" >&2
  exit 1
fi

# --- Scenario 2: cryptex mount race, toolchain usable after a few probes -----
reset_state
export READY_AFTER=4
output="$("${SCRIPT}" 2>&1)"
if ! grep -q "Metal toolchain installed" <<<"${output}"; then
  echo "❌ expected the script to wait for the toolchain to become usable" >&2
  echo "${output}" >&2
  exit 1
fi
if [ ! -f "${STATE_DIR}/downloaded" ]; then
  echo "❌ expected the toolchain to be downloaded when it is not usable" >&2
  exit 1
fi
if [ "$(cat "${STATE_DIR}/probes")" -lt 4 ]; then
  echo "❌ expected repeated probes while waiting for the mount" >&2
  exit 1
fi
if [ ! -f "${STATE_DIR}/sleeps" ]; then
  echo "❌ expected the script to wait between probes" >&2
  exit 1
fi

# --- Scenario 3: toolchain never becomes usable, must fail loudly ------------
reset_state
export READY_AFTER=99999
set +e
output="$("${SCRIPT}" --timeout 6 --interval 2 2>&1)"
status=$?
set -e
if [ "${status}" -ne 1 ]; then
  echo "❌ expected exit 1 when the toolchain stays unusable (got ${status})" >&2
  echo "${output}" >&2
  exit 1
fi
if ! grep -q "still unusable after the download" <<<"${output}"; then
  echo "❌ expected a loud failure message on timeout" >&2
  echo "${output}" >&2
  exit 1
fi

# --- Scenario 4: a failing download aborts before probing -------------------
reset_state
export READY_AFTER=99999
export DOWNLOAD_FAILS=1
set +e
output="$("${SCRIPT}" --timeout 6 --interval 2 2>&1)"
status=$?
set -e
if [ "${status}" -eq 0 ]; then
  echo "❌ expected a non-zero exit when the component download fails" >&2
  echo "${output}" >&2
  exit 1
fi
unset DOWNLOAD_FAILS

# --- Scenario 5: usage errors are rejected ----------------------------------
reset_state
set +e
"${SCRIPT}" --timeout abc >/dev/null 2>&1
status=$?
set -e
if [ "${status}" -ne 2 ]; then
  echo "❌ expected exit 2 for an invalid --timeout (got ${status})" >&2
  exit 1
fi

set +e
"${SCRIPT}" --interval 0 >/dev/null 2>&1
status=$?
set -e
if [ "${status}" -ne 2 ]; then
  echo "❌ expected exit 2 for an interval below one second (got ${status})" >&2
  exit 1
fi

set +e
"${SCRIPT}" --bogus >/dev/null 2>&1
status=$?
set -e
if [ "${status}" -ne 2 ]; then
  echo "❌ expected exit 2 for an unknown argument (got ${status})" >&2
  exit 1
fi

echo "✅ install-metal-toolchain.sh test passed: reuse, mount-race polling, timeout, download failure, usage"
