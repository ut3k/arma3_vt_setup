#!/usr/bin/env bash
set -euo pipefail

AUTO_STOP_AFTER_SECONDS="${AUTO_STOP_AFTER_SECONDS:-3600}"

ssh-keygen -A

/usr/sbin/sshd -D -e -p 8873 &
SSHD_PID="$!"

(
  sleep "$AUTO_STOP_AFTER_SECONDS"
  echo "Limit czasu ${AUTO_STOP_AFTER_SECONDS}s minął. Wyłączam SSH server..."
  kill -TERM "$SSHD_PID" 2>/dev/null || true
) &
TIMER_PID="$!"

wait "$SSHD_PID"
STATUS="$?"

kill "$TIMER_PID" 2>/dev/null || true
wait "$TIMER_PID" 2>/dev/null || true

exit "$STATUS"
