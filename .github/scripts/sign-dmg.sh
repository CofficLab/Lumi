#!/usr/bin/env bash
# Sign one disk image with a Developer ID Application identity and verify it.

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <dmg> <signing-identity>" >&2
  exit 2
fi

dmg="$1"
identity="$2"

[ -f "${dmg}" ] || { echo "error: DMG missing: ${dmg}" >&2; exit 2; }
[ -n "${identity}" ] || { echo "error: signing identity is empty" >&2; exit 2; }

codesign --force --timestamp --sign "${identity}" "${dmg}"
codesign --verify --strict --verbose=2 "${dmg}"

echo "Signed and verified DMG: $(basename "${dmg}")"
