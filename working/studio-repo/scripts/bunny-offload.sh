#!/usr/bin/env bash
set -uo pipefail
# shellcheck disable=SC1091
source /etc/bunny-offload.conf

# don't run twice at once
exec 9>/run/bunny-offload.lock
flock -n 9 || exit 0

if [ "$BUNNY_ZONE" = "REPLACE_WITH_ZONE_NAME" ] || [ "$BUNNY_KEY" = "REPLACE_WITH_STORAGE_ZONE_PASSWORD" ]; then
  logger -t bunny-offload "Not configured yet — edit /etc/bunny-offload.conf"
  exit 0
fi

now="$(date +%s)"
shopt -s nullglob
for f in "$REC_DIR"/*.mp4; do
  # skip files still being written
  mtime="$(stat -c %Y "$f")"
  [ $(( now - mtime )) -lt "${SETTLE_SECONDS:-120}" ] && continue

  name="$(basename "$f")"
  url="https://${BUNNY_STORAGE_HOST}/${BUNNY_ZONE}/${REMOTE_PATH}/${name}"

  code="$(curl -sS -o /dev/null -w '%{http_code}' \
            -X PUT --data-binary @"$f" \
            -H "AccessKey: ${BUNNY_KEY}" \
            -H "Content-Type: application/octet-stream" \
            "$url")" || code="000"

  if [ "$code" = "201" ]; then
    rm -f "$f"
    logger -t bunny-offload "Uploaded + removed local: ${name}"
  else
    logger -t bunny-offload "Upload FAILED (HTTP ${code}) for ${name} — keeping local copy"
  fi
done
