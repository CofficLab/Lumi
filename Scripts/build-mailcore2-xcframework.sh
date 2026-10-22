#!/usr/bin/env bash
#
# build-mailcore2-xcframework.sh — rebuild the vendored MailCore2.xcframework.
#
# KitMail vendors MailCore2 as a local SPM binary target. The upstream
# distribution is unusable for Lumi:
#
#   * The official SPM binary (MailCore2-2020-09-24.xcframework.zip) is built
#     from 2020 sources: no libetpan MIME-parser fix, no Xcode 27 SDK
#     compatibility, incomplete header set. Merging its macos-x86_64 slice
#     would produce a macOS slice that is neither the same source nor the same
#     patch set as the arm64 slice.
#   * mailcore2 master does not build at all: its JMAP sources require
#     libetpan's mailjmap.h, but the pinned submodule (6dc099a) does not ship
#     that file.
#
# So the macOS slice is built from source. This script reproduces that build
# end to end so it never has to be done by hand again.
#
# Source baseline: mailcore2 @ 1b48bab — the commit immediately before
# "Add initial JMAP API layers" (8b0527e). That baseline matches the vendored
# arm64 slice exactly (540 public headers, no JMAP headers), so the arm64 and
# x86_64 slices stay the same source with the same patches.
#
# Patches applied on top of the baseline:
#   1. libetpan mailimf.c — quoted-string parser infinite loop. When both the
#      FWS and the qcontent parse fail, the cursor stops advancing and the
#      loop never exits (MCOMessageParser spins at 100% CPU). The fix matches
#      upstream libetpan master.
#   2. MCICUTypes.h — `typedef char16_t UChar` collides with the macOS
#      umachine.h branch; use `unsigned short` like that branch does.
#   3. MCString.cpp — the structuredError callback must take a non-const
#      xmlError* under the current SDK.
#   4. Public header set — the project's "Copy Headers" phase copies only 247
#      of the 542 headers; the rest are copied in after the build.
#
# Usage:
#   Scripts/build-mailcore2-xcframework.sh [--work-dir DIR] [--keep-work-dir]
#
#   --work-dir DIR      Scratch directory for sources and build output.
#                       Default: a temporary directory that is removed on exit.
#   --keep-work-dir     Do not delete the scratch directory when finished.
#
# Output:
#   Packages/KitMail/Vendor/MailCore2.xcframework is replaced in place, with
#   the macOS slice carrying both arm64 and x86_64.
#
# Requirements: macOS with Xcode, git, autoconf/automake/libtool, curl, unzip.

set -euo pipefail

readonly MAILCORE2_REPO="https://github.com/MailCore/mailcore2.git"
readonly MAILCORE2_BASELINE="1b48bab"

readonly LIBETPAN_REV="6dc099a813344ee9c48009d70a78016ae838afcc"
readonly CTEMPLATE_REV="d004783679560176f501998fd620f50acfc233f0"
readonly TIDY_HTML5_REV="10c3674befa76f0f8c56e2944959a0ba9e1ef638"

readonly DEPLOYMENT_TARGET="14.0"
readonly ARCHS="arm64 x86_64"

workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly workspace_root
readonly vendor_dir="${workspace_root}/Packages/KitMail/Vendor"
readonly xcframework_path="${vendor_dir}/MailCore2.xcframework"

work_dir=""
keep_work_dir=0

log() {
  printf '==> %s\n' "$*"
}

fail() {
  printf '❌ %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
usage: build-mailcore2-xcframework.sh [--work-dir DIR] [--keep-work-dir]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --work-dir)
      [[ $# -ge 2 ]] || fail "--work-dir requires a directory"
      work_dir="$2"
      shift 2
      ;;
    --keep-work-dir)
      keep_work_dir=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unknown argument: $1"
      ;;
  esac
done

if [[ -z "${work_dir}" ]]; then
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/mailcore2-build.XXXXXX")"
fi
mkdir -p "${work_dir}"
readonly work_dir
readonly src_dir="${work_dir}/src"
readonly out_dir="${work_dir}/out"

cleanup() {
  if [[ "${keep_work_dir}" -eq 1 ]]; then
    log "work dir kept at ${work_dir}"
  else
    rm -rf "${work_dir}"
  fi
}
trap cleanup EXIT

for tool in git xcodebuild clang lipo curl unzip; do
  command -v "${tool}" >/dev/null 2>&1 || fail "required tool not found: ${tool}"
done
if ! command -v glibtoolize >/dev/null 2>&1 && ! command -v libtoolize >/dev/null 2>&1; then
  fail "libtoolize (or glibtoolize) is required to run autogen.sh"
fi

# ---------------------------------------------------------------------------
# 1. Fetch the source baseline and its submodules.
# ---------------------------------------------------------------------------

log "cloning mailcore2 (baseline ${MAILCORE2_BASELINE})"
rm -rf "${src_dir}"
# The upstream repo is large enough that a plain clone occasionally dies
# mid-transfer; retry a couple of times before giving up.
clone_attempt=0
until git clone --quiet "${MAILCORE2_REPO}" "${src_dir}"; do
  clone_attempt=$((clone_attempt + 1))
  rm -rf "${src_dir}"
  if [[ ${clone_attempt} -ge 3 ]]; then
    fail "failed to clone ${MAILCORE2_REPO} after ${clone_attempt} attempts"
  fi
  log "clone attempt ${clone_attempt} failed, retrying"
  sleep 5
done
git -C "${src_dir}" checkout --quiet "${MAILCORE2_BASELINE}"

log "checking out submodules"
git -C "${src_dir}" submodule update --init --quiet --depth 1 \
  deps/ctemplate deps/libetpan deps/tidy-html5

for pair in \
  "deps/ctemplate:${CTEMPLATE_REV}" \
  "deps/libetpan:${LIBETPAN_REV}" \
  "deps/tidy-html5:${TIDY_HTML5_REV}"; do
  path="${pair%%:*}"
  rev="${pair##*:}"
  actual="$(git -C "${src_dir}/${path}" rev-parse HEAD)"
  [[ "${actual}" == "${rev}" ]] || fail "${path} is at ${actual}, expected ${rev}"
done

# ---------------------------------------------------------------------------
# 2. Apply the patches.
# ---------------------------------------------------------------------------

log "patching libetpan MIME parser infinite loop"
mailimf="${src_dir}/deps/libetpan/src/low-level/imf/mailimf.c"
python3 - "${mailimf}" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    source = handle.read()

old = """    else if (r != MAILIMF_ERROR_PARSE) {
      res = r;
      goto free_gstr;
    }
  }

  r = mailimf_dquote_parse(message, length, &cur_token);"""

new = """    else if (r == MAILIMF_ERROR_PARSE) {
      break;
    }
    else {
      res = r;
      goto free_gstr;
    }
  }

  r = mailimf_dquote_parse(message, length, &cur_token);"""

if new in source:
    print("  already applied")
    raise SystemExit(0)

if source.count(old) != 1:
    raise SystemExit(f"unexpected mailimf.c layout: {source.count(old)} matches")

with open(path, "w", encoding="utf-8") as handle:
    handle.write(source.replace(old, new))
print("  applied")
PY

log "patching MCICUTypes.h char16_t conflict"
python3 - "${src_dir}/src/core/basetypes/MCICUTypes.h" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    source = handle.read()

old = """#elif defined(__cplusplus) && __cplusplus >= 201103L
typedef char16_t UChar;"""
new = """#elif defined(__cplusplus) && __cplusplus >= 201103L
typedef unsigned short UChar;"""

if new in source:
    print("  already applied")
    raise SystemExit(0)

if source.count(old) != 1:
    raise SystemExit("unexpected MCICUTypes.h layout")

with open(path, "w", encoding="utf-8") as handle:
    handle.write(source.replace(old, new))
print("  applied")
PY

log "patching MCString.cpp structuredError signature"
python3 - "${src_dir}/src/core/basetypes/MCString.cpp" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    source = handle.read()

old = """static void structuredError(void * userData,
                            const xmlError * error)"""
new = """static void structuredError(void * userData,
                            xmlError * error)"""

if new in source:
    print("  already applied")
    raise SystemExit(0)

if source.count(old) != 1:
    raise SystemExit("unexpected MCString.cpp layout")

with open(path, "w", encoding="utf-8") as handle:
    handle.write(source.replace(old, new))
print("  applied")
PY

# ---------------------------------------------------------------------------
# 3. Build the libetpan and ctemplate static libraries.
# ---------------------------------------------------------------------------

log "configuring libetpan"
(
  cd "${src_dir}/deps/libetpan"
  # autogen.sh regenerates ltmain.sh, which the prebuilt configure archive
  # does not ship but libtoolize needs.
  NOCONFIGURE=1 ./autogen.sh >"${work_dir}/libetpan-autogen.log" 2>&1
  export SDKROOT=
  export IPHONEOS_DEPLOYMENT_TARGET=
  ./configure --with-expat=no --with-curl=no --enable-debug \
    >"${work_dir}/libetpan-configure.log" 2>&1
  make stamp-prepare-target >"${work_dir}/libetpan-make.log" 2>&1
)

log "building libetpan (${ARCHS})"
(
  cd "${src_dir}/deps/libetpan/build-mac"
  xcodebuild -project libetpan.xcodeproj \
    -sdk macosx \
    -scheme "static libetpan" \
    -configuration Release \
    ARCHS="${ARCHS}" \
    ONLY_ACTIVE_ARCH=NO \
    MACOSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
    SYMROOT="${out_dir}/libetpan/bin" \
    OBJROOT="${out_dir}/libetpan/obj" \
    >"${work_dir}/libetpan-build.log" 2>&1
)

log "building ctemplate (${ARCHS})"
(
  cd "${src_dir}/deps/ctemplate/build-mac"
  xcodebuild -project ctemplate.xcodeproj \
    -sdk macosx \
    -scheme ctemplate \
    -configuration Release \
    ARCHS="${ARCHS}" \
    ONLY_ACTIVE_ARCH=NO \
    MACOSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
    SYMROOT="${out_dir}/ctemplate/bin" \
    OBJROOT="${out_dir}/ctemplate/obj" \
    >"${work_dir}/ctemplate-build.log" 2>&1
)

for library in \
  "${out_dir}/libetpan/bin/Release/libetpan.a" \
  "${out_dir}/ctemplate/bin/Release/libctemplate.a"; do
  [[ -f "${library}" ]] || fail "expected library missing: ${library}"
  actual_archs="$(lipo -archs "${library}")"
  for arch in ${ARCHS}; do
    [[ " ${actual_archs} " == *" ${arch} "* ]] \
      || fail "${library} is missing the ${arch} slice (has: ${actual_archs})"
  done
done

# The mailcore2 project resolves its dependencies from Externals/<name>-osx.
mkdir -p "${src_dir}/Externals/libetpan-osx/lib" \
         "${src_dir}/Externals/libetpan-osx/include" \
         "${src_dir}/Externals/ctemplate-osx/lib" \
         "${src_dir}/Externals/ctemplate-osx/include"
cp "${out_dir}/libetpan/bin/Release/libetpan.a" "${src_dir}/Externals/libetpan-osx/lib/"
cp -R "${out_dir}/libetpan/bin/Release/include/libetpan" "${src_dir}/Externals/libetpan-osx/include/"
cp "${out_dir}/ctemplate/bin/Release/libctemplate.a" "${src_dir}/Externals/ctemplate-osx/lib/"
cp -R "${out_dir}/ctemplate/bin/Release/include/ctemplate" "${src_dir}/Externals/ctemplate-osx/include/"

# ---------------------------------------------------------------------------
# 4. Build the MailCore framework.
# ---------------------------------------------------------------------------

log "building MailCore.framework (${ARCHS})"
framework_include="${out_dir}/mailcore/bin/Release/include/MailCore"
mkdir -p "${framework_include}"
# The project's Copy Headers phase only copies part of the public headers.
# Seed the rest so the compile sees the complete set.
(
  cd "${src_dir}"
  find src -name "*.h" -print0 | while IFS= read -r -d '' header; do
    base="$(basename "${header}")"
    [[ -f "${framework_include}/${base}" ]] || cp "${header}" "${framework_include}/${base}"
  done
)

(
  cd "${src_dir}/build-mac"
  xcodebuild -project mailcore2.xcodeproj \
    -sdk macosx \
    -scheme "mailcore osx" \
    -configuration Release \
    ARCHS="${ARCHS}" \
    ONLY_ACTIVE_ARCH=NO \
    MACOSX_DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET}" \
    SYMROOT="${out_dir}/mailcore/bin" \
    OBJROOT="${out_dir}/mailcore/obj" \
    >"${work_dir}/mailcore-build.log" 2>&1
)

built_framework="${out_dir}/mailcore/bin/Release/MailCore.framework"
[[ -d "${built_framework}" ]] || fail "MailCore.framework was not produced"

built_binary="${built_framework}/Versions/A/MailCore"
[[ -f "${built_binary}" ]] || fail "MailCore framework binary is missing"
built_archs="$(lipo -archs "${built_binary}")"
for arch in ${ARCHS}; do
  [[ " ${built_archs} " == *" ${arch} "* ]] \
    || fail "built framework is missing the ${arch} slice (has: ${built_archs})"
done
log "built framework architectures: ${built_archs}"

# ---------------------------------------------------------------------------
# 5. Recombine the xcframework.
# ---------------------------------------------------------------------------

log "recombining MailCore2.xcframework"
# Keep the iOS slices from the current vendored xcframework; only the macOS
# slice is rebuilt.
ios_slices=()
while IFS= read -r slice; do
  ios_slices+=(-framework "${slice}")
done < <(find "${xcframework_path}" -maxdepth 2 -name MailCore.framework \
           -path "*ios*" | sort)

if [[ ${#ios_slices[@]} -eq 0 ]]; then
  fail "no iOS slices found in ${xcframework_path}"
fi

staging="${work_dir}/MailCore2.xcframework"
rm -rf "${staging}"
xcodebuild -create-xcframework \
  -framework "${built_framework}" \
  "${ios_slices[@]}" \
  -output "${staging}" \
  >"${work_dir}/create-xcframework.log" 2>&1

python3 - "${staging}/Info.plist" <<'PY'
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    info = plistlib.load(handle)

macos = [
    library for library in info["AvailableLibraries"]
    if library.get("SupportedPlatform") == "macos"
]
if len(macos) != 1:
    raise SystemExit(f"expected exactly one macOS slice, found {len(macos)}")

archs = set(macos[0]["SupportedArchitectures"])
missing = {"arm64", "x86_64"} - archs
if missing:
    raise SystemExit(f"macOS slice is missing architectures: {sorted(missing)}")

for library in info["AvailableLibraries"]:
    print(f"  {library['LibraryIdentifier']}: {library['SupportedArchitectures']}")
PY

mkdir -p "${vendor_dir}"
rm -rf "${xcframework_path}"
cp -R "${staging}" "${xcframework_path}"

# ---------------------------------------------------------------------------
# 6. Verify the result.
# ---------------------------------------------------------------------------

log "verifying the rebuilt xcframework"
macos_slice="${xcframework_path}/macos-arm64_x86_64/MailCore.framework"
[[ -d "${macos_slice}" ]] || fail "expected macOS slice directory is missing"

final_archs="$(lipo -archs "${macos_slice}/Versions/A/MailCore")"
for arch in ${ARCHS}; do
  [[ " ${final_archs} " == *" ${arch} "* ]] \
    || fail "vendored macOS slice is missing the ${arch} slice (has: ${final_archs})"
done
log "vendored macOS slice architectures: ${final_archs}"

header_count="$(ls "${macos_slice}/Headers" | wc -l | tr -d ' ')"
log "vendored macOS slice headers: ${header_count}"

symbol_count="$(nm -arch x86_64 -gU "${macos_slice}/Versions/A/MailCore" 2>/dev/null \
  | grep -c '_OBJC_CLASS_\$_MCO' || true)"
[[ "${symbol_count}" -gt 0 ]] || fail "no MCO classes found in the x86_64 slice"
log "x86_64 MCO classes: ${symbol_count}"

# Link check: the x86_64 slice must resolve the MCO symbols the mail plugin
# uses. This is the exact failure that broke the release archive.
log "link check for x86_64"
cat >"${work_dir}/linkcheck.m" <<'EOF'
#import <Foundation/Foundation.h>
#import <MailCore/MailCore.h>
int main(void) {
    MCORange r = MCORangeMake(1, 10);
    (void)r;
    return 0;
}
EOF
clang -arch x86_64 \
  -mmacosx-version-min="${DEPLOYMENT_TARGET}" \
  -F"${macos_slice}/.." \
  -framework MailCore \
  -framework Foundation \
  -Wno-nullability-completeness \
  "${work_dir}/linkcheck.m" \
  -o "${work_dir}/linkcheck-x86_64" \
  >"${work_dir}/linkcheck.log" 2>&1 \
  || { cat "${work_dir}/linkcheck.log"; fail "x86_64 link check failed"; }
log "x86_64 link check passed"

log "verifying KitMail builds against the rebuilt xcframework"
(
  cd "${workspace_root}/Packages/KitMail"
  rm -rf .build
  swift build --disable-sandbox >"${work_dir}/kitmail-build.log" 2>&1 \
    || { tail -40 "${work_dir}/kitmail-build.log"; fail "KitMail build failed"; }
)

log "done: ${xcframework_path}"
