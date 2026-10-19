#!/usr/bin/env bash
# Submit one signed DMG to the notary service and persist its durable submission id.
#
# Submission is deliberately separated from waiting. `notarytool submit --wait` only
# writes its JSON result when the wait succeeds, so a slow queue destroys the one
# handle that makes the work resumable. Submitting first keeps the id on disk.

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <dmg> <arch> <record.json>" >&2
  exit 2
fi

dmg="$1"
arch="$2"
record="$3"

case "${arch}" in arm64|x86_64) ;; *) echo "error: unknown arch: ${arch}" >&2; exit 2 ;; esac
: "${API_KEY_PATH:?missing API_KEY_PATH}"
: "${APP_STORE_CONNECT_KEY_ID:?missing APP_STORE_CONNECT_KEY_ID}"
: "${APP_STORE_CONNECT_KEY_ISSUER_ID:?missing APP_STORE_CONNECT_KEY_ISSUER_ID}"
[ -f "${dmg}" ] || { echo "error: DMG missing: ${dmg}" >&2; exit 2; }

# A disk image is a signed distribution container, not an installer package.
# Reject unsigned or damaged images before spending a notarization slot on them.
codesign --verify --strict --verbose=2 "${dmg}"

sha="$(shasum -a 256 "${dmg}" | cut -d' ' -f1)"
mkdir -p "$(dirname "${record}")"

read_record() {
  python3 - "$1" "$2" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))
except Exception:
    print("")
PY
}

# Re-submitting identical bytes would consume a second notarization slot for the
# same result, so an existing record for the same DMG content is authoritative.
existing_id="$(read_record "${record}" submission_id)"
existing_sha="$(read_record "${record}" sha256)"
if [ -n "${existing_id}" ] && [ "${existing_sha}" = "${sha}" ]; then
  echo "Reusing notarization submission for $(basename "${dmg}"): ${existing_id}"
  exit 0
fi

# No --wait here: this call must return promptly and hand back a submission id.
xcrun notarytool submit "${dmg}" \
  --key "${API_KEY_PATH}" --key-id "${APP_STORE_CONNECT_KEY_ID}" \
  --issuer "${APP_STORE_CONNECT_KEY_ISSUER_ID}" \
  --output-format json > "${record}.submit"

submission_id="$(python3 - "${record}.submit" <<'PY'
import json, sys
print(json.load(open(sys.argv[1])).get("id", ""))
PY
)"
[ -n "${submission_id}" ] || { echo "error: notarytool submit returned no submission id" >&2; exit 1; }

SHA256="${sha}" SUBMISSION_ID="${submission_id}" ARCH="${arch}" \
  DMG="$(basename "${dmg}")" RECORD="${record}" python3 - <<'PY'
import json, os
json.dump({
    "arch": os.environ["ARCH"],
    "dmg": os.environ["DMG"],
    "sha256": os.environ["SHA256"],
    "submission_id": os.environ["SUBMISSION_ID"],
    "status": "Submitted",
}, open(os.environ["RECORD"], "w"), indent=2, sort_keys=True)
PY

echo "Submitted $(basename "${dmg}") for notarization: ${submission_id}"
