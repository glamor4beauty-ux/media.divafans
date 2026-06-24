#!/usr/bin/env bash
set -uo pipefail
# shellcheck disable=SC1091
source /etc/owncast-recorder.conf
PID=""; CURRENT=""
is_online(){ local b; b="$(curl -fsS --max-time 5 "$STATUS_URL" 2>/dev/null | tr -d '[:space:]')" || return 1
  [[ "$b" == *'"online":true'* ]]; }
free_gb(){ df -BG --output=avail "$REC_DIR" 2>/dev/null | tail -1 | tr -dc '0-9'; }
start_rec(){ local a; a="$(free_gb)"; a="${a:-0}"
  if [ "$a" -lt "${MIN_FREE_GB:-4}" ]; then
    logger -t owncast-recorder "LOW DISK (${a}GB) — not recording"; PID=""; CURRENT=""; return; fi
  sleep "${WARMUP_SECONDS:-6}"; is_online || { PID=""; CURRENT=""; return; }
  CURRENT="${REC_DIR}/owncast_$(date +%Y-%m-%d_%H-%M-%S).mp4"
  logger -t owncast-recorder "LIVE — recording ${CURRENT}"
  "$FFMPEG" -nostdin -y -loglevel warning -i "$HLS_URL" -c copy -movflags +faststart "$CURRENT" &
  PID=$!; }
stop_rec(){ if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    logger -t owncast-recorder "OFFLINE — finalizing ${CURRENT}"; kill -INT "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; fi
  PID=""; CURRENT=""; }
trap 'stop_rec; exit 0' INT TERM
while true; do
  if is_online; then
    if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then [ -n "$PID" ] && stop_rec; start_rec; fi
  else [ -n "$PID" ] && stop_rec; fi
  sleep "${POLL_SECONDS:-8}"
done
