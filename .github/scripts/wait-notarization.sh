#!/usr/bin/env bash
# Wait for previously submitted DMGs, staple the ticket, and validate the result.
#
# Consumes the durable submission ids written by notarize-dmg.sh. Every step is
# safe to repeat, so an interrupted run resumes instead of re-paying for
# notarization.

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <notary-record-dir>" >&2
  exit 2
fi

record_dir="$1"
[ -d "${record_dir}" ] || { echo "error: notary record dir missing: ${record_dir}" >&2; exit 2; }

: "${API_KEY_PATH:?missing API_KEY_PATH}"
: "${APP_STORE_CONNECT_KEY_ID:?missing APP_STORE_CONNECT_KEY_ID}"
: "${APP_STORE_CONNECT_KEY_ISSUER_ID:?missing APP_STORE_CONNECT_KEY_ISSUER_ID}"

# Apple queues notary submissions unpredictably. One submission may sit far longer
# than the observed median, so this budget is sized against the queue rather than
# the common case. Both architectures already run concurrently inside Apple, so
# polling both in one loop costs no extra queue time.
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-30}"
POLL_ATTEMPTS="${POLL_ATTEMPTS:-80}"

record_id() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$1" "$2"
}

for arch in arm64 x86_64; do
  record="${record_dir}/${arch}.json"
  [ -f "${record}" ] || { echo "error: missing notarization record: ${record}" >&2; exit 1; }
  submission_id="$(record_id "${record}" submission_id)"
  [ -n "${submission_id}" ] || { echo "error: empty submission id in ${record}" >&2; exit 1; }
  echo "Waiting for notarization of ${arch}: ${submission_id}"
done

for arch in arm64 x86_64; do
  record="${record_dir}/${arch}.json"
  submission_id="$(record_id "${record}" submission_id)"

  attempt=1
  while [ "${attempt}" -le "${POLL_ATTEMPTS}" ]; do
    status="$(xcrun notarytool info "${submission_id}" \
      --key "${API_KEY_PATH}" --key-id "${APP_STORE_CONNECT_KEY_ID}" \
      --issuer "${APP_STORE_CONNECT_KEY_ISSUER_ID}" --output-format json 2>/dev/null \
      | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || echo "")"

    case "${status}" in
      Accepted)
        STATUS="${status}" RECORD="${record}" python3 - <<'PY'
import json, os
record = json.load(open(os.environ["RECORD"]))
record["status"] = os.environ["STATUS"]
json.dump(record, open(os.environ["RECORD"], "w"), indent=2, sort_keys=True)
PY
        echo "Notarization accepted: ${arch} (${submission_id})"
        break
        ;;
      Invalid|Rejected)
        xcrun notarytool log "${submission_id}" \
          --key "${API_KEY_PATH}" --key-id "${APP_STORE_CONNECT_KEY_ID}" \
          --issuer "${APP_STORE_CONNECT_KEY_ISSUER_ID}" || true
        echo "error: notarization of ${arch} was ${status} (${submission_id})" >&2
        exit 1
        ;;
      *)
        if [ "${attempt}" -ge "${POLL_ATTEMPTS}" ]; then
          echo "error: notarization of ${arch} stayed ${status:-unknown} for ${POLL_ATTEMPTS} polls" >&2
          exit 1
        fi
        echo "  ${arch}: status=${status:-unknown} (poll ${attempt}/${POLL_ATTEMPTS})"
        attempt=$((attempt + 1))
        sleep "${POLL_INTERVAL_SECONDS}"
        ;;
    esac
  done
done

for arch in arm64 x86_64; do
  record="${record_dir}/${arch}.json"
  dmg_name="$(record_id "${record}" dmg)"
  dmg="${FINAL_ASSETS:-final-assets}/${dmg_name}"
  [ -f "${dmg}" ] || { echo "error: DMG missing for stapling: ${dmg}" >&2; exit 1; }

  xcrun stapler staple "${dmg}"
  xcrun stapler validate "${dmg}"
  codesign --verify --strict --verbose=2 "${dmg}"
  spctl -a -vvv -t open --context context:primary-signature "${dmg}"
  echo "Stapled and validated DMG: ${dmg_name}"
done

echo "All DMGs notarized, stapled, and validated"
