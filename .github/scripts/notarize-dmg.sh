#!/usr/bin/env bash
# Submit one DMG, query the original submission after timeouts, staple, and validate.

set -euo pipefail
if [ "$#" -ne 3 ]; then echo "usage: $0 <dmg> <arch> <record.json>" >&2; exit 2; fi
dmg="$1"; arch="$2"; record="$3"
case "${arch}" in arm64|x86_64) ;; *) exit 2 ;; esac
: "${API_KEY_PATH:?missing API_KEY_PATH}"
: "${APP_STORE_CONNECT_KEY_ID:?missing APP_STORE_CONNECT_KEY_ID}"
: "${APP_STORE_CONNECT_KEY_ISSUER_ID:?missing APP_STORE_CONNECT_KEY_ISSUER_ID}"
[ -f "${dmg}" ] || { echo "error: DMG missing: ${dmg}" >&2; exit 2; }

mkdir -p "$(dirname "${record}")"
submit_json="${record}.submit"
set +e
xcrun notarytool submit "${dmg}" \
  --key "${API_KEY_PATH}" --key-id "${APP_STORE_CONNECT_KEY_ID}" \
  --issuer "${APP_STORE_CONNECT_KEY_ISSUER_ID}" --wait --timeout 10m \
  --output-format json > "${submit_json}" 2>"${record}.stderr"
submit_exit=$?
set -e

read_value() {
  python3 - "$1" "$2" <<'PY'
import json, sys
try: d=json.load(open(sys.argv[1]))
except Exception: d={}
print(d.get(sys.argv[2], ""))
PY
}
submission_id="$(read_value "${submit_json}" id)"
status="$(read_value "${submit_json}" status)"

if [ "${status}" != Accepted ] && [ -n "${submission_id}" ]; then
  for _ in $(seq 1 20); do
    info_json="${record}.info"
    xcrun notarytool info "${submission_id}" \
      --key "${API_KEY_PATH}" --key-id "${APP_STORE_CONNECT_KEY_ID}" \
      --issuer "${APP_STORE_CONNECT_KEY_ISSUER_ID}" --output-format json > "${info_json}"
    status="$(read_value "${info_json}" status)"
    case "${status}" in Accepted|Invalid|Rejected) break ;; esac
    sleep 30
  done
fi

if [ "${status}" != Accepted ]; then
  if [ -n "${submission_id}" ]; then
    xcrun notarytool log "${submission_id}" \
      --key "${API_KEY_PATH}" --key-id "${APP_STORE_CONNECT_KEY_ID}" \
      --issuer "${APP_STORE_CONNECT_KEY_ISSUER_ID}" || true
  fi
  echo "error: notarization failed or remained incomplete (exit=${submit_exit}, id=${submission_id:-unknown}, status=${status:-unknown})" >&2
  exit 1
fi

SUBMISSION_ID="${submission_id}" STATUS="${status}" ARCH="${arch}" DMG="$(basename "${dmg}")" RECORD="${record}" python3 - <<'PY'
import json, os
json.dump({"arch":os.environ["ARCH"], "dmg":os.environ["DMG"],
           "submission_id":os.environ["SUBMISSION_ID"], "status":os.environ["STATUS"]},
          open(os.environ["RECORD"], "w"), indent=2, sort_keys=True)
PY
xcrun stapler staple "${dmg}"
xcrun stapler validate "${dmg}"
spctl -a -vvv -t install "${dmg}"
echo "Notarization accepted and validated: ${submission_id}"
