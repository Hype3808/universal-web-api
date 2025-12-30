#!/bin/sh
set -e

APP_HOST="${APP_HOST:-0.0.0.0}"
APP_PORT="${APP_PORT:-8199}"
BROWSER_PORT="${BROWSER_PORT:-9222}"
CHROME_BIN="${CHROME_BIN:-chromium}"

mkdir -p /app/chrome_profile

"${CHROME_BIN}" \
  --headless=new \
  --disable-gpu \
  --remote-debugging-address=0.0.0.0 \
  --remote-debugging-port="${BROWSER_PORT}" \
  --user-data-dir=/app/chrome_profile \
  --no-sandbox \
  --disable-dev-shm-usage \
  --hide-scrollbars \
  --mute-audio \
  about:blank &
CHROME_PID=$!

cleanup() {
  kill -TERM "${CHROME_PID}" >/dev/null 2>&1 || true
  wait "${CHROME_PID}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

python -m uvicorn main:app \
  --host "${APP_HOST}" \
  --port "${APP_PORT}" \
  --log-level "${UVICORN_LOG_LEVEL:-info}" \
  --proxy-headers
