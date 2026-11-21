#!/usr/bin/env bash
#
# Tests for the detach logic in create-designed-dmg.sh.
#
# A fake hdiutil stands in for the real tool so every detach branch can be
# exercised without mounting anything. The regression this guards is the
# 6.5.4 release failure (run 43980176804): the x86_64 volume stayed busy,
# the forced detach then reported "No such file or directory" because the
# volume had already gone away, and the script treated that as fatal.
#
# Usage: bash .github/scripts/test-create-designed-dmg.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/create-designed-dmg.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

mkdir -p "${WORK}/bin" "${WORK}/state"

# ---------------------------------------------------------------------------
# Fake hdiutil
#
# State lives in ${STUB_STATE}: an `attached` file whose content is the info
# line for the mounted image, a `mode` file selecting the detach behavior,
# and a `calls` log recording every detach invocation.
# ---------------------------------------------------------------------------
cat > "${WORK}/bin/hdiutil" <<'FAKE_HDIUTIL'
#!/usr/bin/env bash
set -uo pipefail

cmd="${1:-}"
shift || true

case "${cmd}" in
  info)
    if [ -f "${STUB_STATE}/attached" ]; then
      cat "${STUB_STATE}/attached"
    else
      printf '/dev/disk1s1\tApple_HFS\t/Volumes/Unrelated\n'
    fi
    exit 0 ;;
  detach)
    printf '%s\n' "$*" >> "${STUB_STATE}/calls"
    mode="$(cat "${STUB_STATE}/mode")"
    force=0
    case " $* " in *" -force "*) force=1 ;; esac
    case "${mode}" in
      ci-enoent)
        # Busy on plain detach; the volume disappears on its own and the
        # forced detach fails with ENOENT — the exact CI failure signature.
        if [ "${force}" -eq 1 ]; then
          rm -f "${STUB_STATE}/attached"
          echo "hdiutil: detach failed - No such file or directory" >&2
          exit 1
        fi
        echo "hdiutil: detach: resource busy" >&2
        exit 1 ;;
      busy-then-force-ok)
        if [ "${force}" -eq 1 ]; then
          rm -f "${STUB_STATE}/attached"
          exit 0
        fi
        echo "hdiutil: detach: resource busy" >&2
        exit 1 ;;
      busy-then-plain-ok)
        count=0
        [ -f "${STUB_STATE}/count" ] && count="$(cat "${STUB_STATE}/count")"
        count=$((count + 1))
        printf '%s' "${count}" > "${STUB_STATE}/count"
        if [ "${count}" -ge 3 ]; then
          rm -f "${STUB_STATE}/attached"
          exit 0
        fi
        echo "hdiutil: detach: resource busy" >&2
        exit 1 ;;
      stuck)
        echo "hdiutil: detach: resource busy" >&2
        exit 1 ;;
    esac
    exit 0 ;;
esac
echo "fake hdiutil: unsupported command ${cmd}" >&2
exit 2
FAKE_HDIUTIL
chmod +x "${WORK}/bin/hdiutil"

cat > "${WORK}/bin/sleep" <<'FAKE_SLEEP'
#!/usr/bin/env bash
exit 0
FAKE_SLEEP
chmod +x "${WORK}/bin/sleep"

# ---------------------------------------------------------------------------
# Extract the real functions under test from the production script.
# ---------------------------------------------------------------------------
extract_functions() {
  sed -n '/^volume_is_attached()/,/^}/p' "$1"
  sed -n '/^detach_mount()/,/^}/p' "$1"
}

extract_functions "${SCRIPT}" > "${WORK}/funcs.sh"
if ! grep -q 'detach_mount()' "${WORK}/funcs.sh"; then
  echo "❌ could not extract detach_mount from ${SCRIPT}" >&2
  exit 1
fi

PASS=0
FAIL=0

# run_detach <mode> <attached:1|0> <device_node> <mount_point>
# Returns the exit code of detach_mount under the fake toolchain.
run_detach() {
  local mode="$1" attached="$2" device="$3" mount="$4"
  rm -rf "${WORK}/state"
  mkdir -p "${WORK}/state"
  printf '%s' "${mode}" > "${WORK}/state/mode"
  if [ "${attached}" = "1" ]; then
    printf '/dev/disk9s2\tApple_HFS\t/Volumes/LumiTest\n' > "${WORK}/state/attached"
  fi
  STUB_STATE="${WORK}/state" \
  PATH="${WORK}/bin:${PATH}" \
  DEVICE_NODE="${device}" MOUNT_POINT="${mount}" VOLUME_NAME="LumiTest" \
    bash -c 'set -euo pipefail; source "$1"; detach_mount' _ "${WORK}/funcs.sh" \
    > "${WORK}/out.log" 2>&1
}

expect() {
  local label="$1" want="$2" got="$3"
  if [ "${want}" = "${got}" ]; then
    echo "✅ ${label}"
    PASS=$((PASS + 1))
  else
    echo "❌ ${label}: expected exit ${want}, got ${got}" >&2
    sed 's/^/    /' "${WORK}/out.log" >&2
    FAIL=$((FAIL + 1))
  fi
}

# 1. The CI regression: force detach reports ENOENT but the volume is gone.
run_detach ci-enoent 1 /dev/disk9s2 /Volumes/LumiTest
expect "force detach ENOENT with volume already gone succeeds" 0 $?
grep -q -- '-force' "${WORK}/state/calls" || { echo "❌ expected a forced detach attempt" >&2; FAIL=$((FAIL + 1)); }

# 2. Busy volume, forced detach eventually succeeds.
run_detach busy-then-force-ok 1 /dev/disk9s2 /Volumes/LumiTest
expect "busy volume succeeds via forced detach" 0 $?

# 3. Genuinely stuck volume must still fail loudly.
run_detach stuck 1 /dev/disk9s2 /Volumes/LumiTest
expect "genuinely stuck volume fails" 1 $?
grep -q 'Unable to detach DMG' "${WORK}/out.log" || { echo "❌ missing explicit failure message" >&2; FAIL=$((FAIL + 1)); }

# 4. Volume already gone before detach: no detach call needed.
run_detach stuck 0 /dev/disk9s2 /Volumes/LumiTest
expect "already-unmounted volume succeeds without detaching" 0 $?
[ ! -f "${WORK}/state/calls" ] || { echo "❌ detach called on an already-gone volume" >&2; FAIL=$((FAIL + 1)); }

# 5. Busy clears on a plain retry: no force needed.
run_detach busy-then-plain-ok 1 /dev/disk9s2 /Volumes/LumiTest
expect "busy volume succeeds on plain retry" 0 $?
if [ -f "${WORK}/state/calls" ] && grep -q -- '-force' "${WORK}/state/calls"; then
  echo "❌ forced detach used although plain retry succeeded" >&2
  FAIL=$((FAIL + 1))
fi

# 6. Detach targets the device node, not the fragile /Volumes path.
run_detach busy-then-force-ok 1 /dev/disk9s2 /Volumes/LumiTest
grep -q '^/dev/disk9s2' "${WORK}/state/calls" || { echo "❌ detach did not target the device node" >&2; FAIL=$((FAIL + 1)); }
echo "✅ detach targets the device node"
PASS=$((PASS + 1))

# 7. Fallback when no device node was parsed: mount point still works.
mkdir -p "${WORK}/mnt"
run_detach busy-then-force-ok 1 "" "${WORK}/mnt"
expect "mount-point fallback succeeds via forced detach" 0 $?
grep -q "^${WORK}/mnt" "${WORK}/state/calls" || { echo "❌ fallback did not target the mount point" >&2; FAIL=$((FAIL + 1)); }

# 8. Mutation check: the pre-fix detach logic must fail scenario 1.
if git -C "${SCRIPT_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "${SCRIPT_DIR}" show HEAD:.github/scripts/create-designed-dmg.sh > "${WORK}/old-script.sh" 2>/dev/null
  if [ -s "${WORK}/old-script.sh" ]; then
    extract_functions "${WORK}/old-script.sh" > "${WORK}/funcs.sh"
    run_detach ci-enoent 1 /dev/disk9s2 /Volumes/LumiTest
    expect "pre-fix logic fails the CI scenario (mutation check)" 1 $?
    extract_functions "${SCRIPT}" > "${WORK}/funcs.sh"
  fi
fi

echo
if [ "${FAIL}" -ne 0 ]; then
  echo "❌ ${FAIL} check(s) failed (${PASS} passed)" >&2
  exit 1
fi
echo "✅ create-designed-dmg detach tests passed (${PASS} checks)"