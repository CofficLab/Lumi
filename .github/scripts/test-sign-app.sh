#!/usr/bin/env bash
#
# Tests for sign_app.sh.
#
# A fake codesign stands in for the real toolchain so that the set of binaries
# the script signs can be asserted without a Developer ID certificate. The
# regression this guards is notarization rejecting a release because a Mach-O
# binary embedded in a resource bundle (the bundled ripgrep `rg`) was never
# signed.
#
# Usage: bash .github/scripts/test-sign-app.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/sign_app.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# ---------------------------------------------------------------------------
# Fake codesign
#
# Records every signed path into a marker directory (the path is hashed so the
# marker file name stays filesystem-safe). `codesign -d` is a read-only
# inspection used by the script to read existing entitlements and must not be
# counted as a sign operation.
# ---------------------------------------------------------------------------
mkdir -p "${WORK}/bin"
cat > "${WORK}/bin/codesign" <<'FAKE_CODESIGN'
#!/usr/bin/env bash
set -uo pipefail

target="${!#}"

# `codesign -d --verbose=4 <path>` prints the signature facts the script
# asserts on (hardened runtime flag and secure timestamp).
case " $* " in
  *" -d "*) case " $* " in
      *" --verbose=4 "*)
        echo "Executable=${target}"
        echo "Identifier=test"
        echo "flags=0x10000(runtime)"
        echo "Timestamp=2026-01-01T00:00:00Z"
        exit 0 ;;
      *" --entitlements "*)
        # No entitlements available.
        exit 1 ;;
    esac ;;
esac

if [ "${FAKE_CODESIGN_FAIL:-}" != "" ] && [ "${target}" = "${FAKE_CODESIGN_FAIL}" ]; then
  echo "fake codesign failure for ${target}" >&2
  exit 1
fi

mkdir -p "${FAKE_CODESIGN_MARKERS}"
printf '%s' "${target}" > "${FAKE_CODESIGN_MARKERS}/$(printf '%s' "${target}" | shasum -a 256 | cut -d' ' -f1)"
exit 0
FAKE_CODESIGN
chmod +x "${WORK}/bin/codesign"

# ---------------------------------------------------------------------------
# Fake xattr / PlistBuddy
# ---------------------------------------------------------------------------
cat > "${WORK}/bin/xattr" <<'FAKE_XATTR'
#!/usr/bin/env bash
exit 0
FAKE_XATTR
chmod +x "${WORK}/bin/xattr"

cat > "${WORK}/bin/PlistBuddy" <<'FAKE_PLISTBUDDY'
#!/usr/bin/env bash
if [ "${2:-}" = "Print :CFBundleExecutable" ]; then echo "Lumi"; fi
exit 0
FAKE_PLISTBUDDY
chmod +x "${WORK}/bin/PlistBuddy"

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

marker_path() { # path
  printf '%s' "${FAKE_CODESIGN_MARKERS}/$(printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1)"
}

expect_signed() { # path label
  if [ -f "$(marker_path "$1")" ]; then ok "$2"; else bad "$2 (not signed: $1)"; fi
}

expect_not_signed() { # path label
  if [ -f "$(marker_path "$1")" ]; then bad "$2 (unexpectedly signed: $1)"; else ok "$2"; fi
}

# ---------------------------------------------------------------------------
# Fixture
#
# Mirrors the shape of the shipped app: a Mach-O executable without a file
# extension inside a resource bundle (the bundled ripgrep), a dylib next to it,
# and the app's own executables.
# ---------------------------------------------------------------------------
make_macho() { # path
  # Mach-O 64-bit magic (little endian) followed by filler bytes.
  printf '\xcf\xfa\xed\xfe\x07\x00\x00\x01' > "$1"
  printf 'fake-binary' >> "$1"
  chmod +x "$1"
}

create_app() { # app-path
  local app="$1"
  mkdir -p "${app}/Contents/MacOS"
  mkdir -p "${app}/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle/Contents/Resources"
  mkdir -p "${app}/Contents/Frameworks/Sparkle.framework"

  make_macho "${app}/Contents/MacOS/Lumi"
  make_macho "${app}/Contents/MacOS/rg"
  make_macho "${app}/Contents/MacOS/lumi-acp"
  make_macho "${app}/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle/Contents/Resources/rg"
  make_macho "${app}/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle/Contents/Resources/vec0.dylib"

  # A non-binary resource must not be signed.
  echo "plain text" > "${app}/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle/Contents/Resources/README"
  echo '<plist></plist>' > "${app}/Contents/Info.plist"
}

run_sign() { # app-path
  set +e
  bash "${SCRIPT}" "$1" "Developer ID Application: Test (TEAMID1234)" "${WORK}/entitlements.plist" \
    > "${WORK}/stdout.txt" 2>&1
  run_exit=$?
  set -e
}

set +e

export PATH="${WORK}/bin:${PATH}"
export FAKE_CODESIGN_MARKERS="${WORK}/markers"
echo '<plist></plist>' > "${WORK}/entitlements.plist"

# ---------------------------------------------------------------------------
# 1. Argument validation
# ---------------------------------------------------------------------------
echo "▶ argument validation"

bash "${SCRIPT}" > /dev/null 2>&1
expect_eq "1" "$?" "missing arguments exits 1"

# ---------------------------------------------------------------------------
# 2. The bundled ripgrep inside the resource bundle is signed
# ---------------------------------------------------------------------------
echo "▶ bundled resource binaries are signed"

app="${WORK}/Lumi.app"
create_app "${app}"

run_sign "${app}"
expect_eq "0" "${run_exit}" "signing succeeds"
expect_signed "${app}/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle/Contents/Resources/rg" \
  "signs the extension-less ripgrep inside the resource bundle"
expect_signed "${app}/Contents/MacOS/rg" \
  "signs the ripgrep copy in Contents/MacOS"

output="$(cat "${WORK}/stdout.txt")"
expect_contains "${output}" "Signing resource binary" "reports resource binary signing"

# ---------------------------------------------------------------------------
# 3. Non-binary resources are left alone
# ---------------------------------------------------------------------------
echo "▶ non-binary resources are skipped"

expect_not_signed "${app}/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle/Contents/Resources/README" \
  "does not sign a plain text resource"

# ---------------------------------------------------------------------------
# 4. A failing resource binary aborts the whole script
# ---------------------------------------------------------------------------
echo "▶ a failing resource binary fails the script"

app="${WORK}/Lumi-fail.app"
create_app "${app}"
export FAKE_CODESIGN_FAIL="${app}/Contents/Resources/PluginProjectRAG_ProjectRAGEngine.bundle/Contents/Resources/rg"

run_sign "${app}"
expect_eq "1" "${run_exit}" "exits non-zero when a resource binary cannot be signed"

unset FAKE_CODESIGN_FAIL

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [ "${failures}" -eq 0 ]; then
  echo "✅ test-sign-app.sh: ${checks} checks passed"
  exit 0
fi

echo "❌ test-sign-app.sh: ${failures} of ${checks} checks failed"
exit 1
