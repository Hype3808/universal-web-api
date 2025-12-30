#!/bin/sh
set -e

APP_HOST="${APP_HOST:-0.0.0.0}"
APP_PORT="${APP_PORT:-8199}"
BROWSER_PORT="${BROWSER_PORT:-9222}"
CHROME_BIN="${CHROME_BIN:-chromium}"

# Avoid noisy DBus lookups in headless containers
export DBUS_SESSION_BUS_ADDRESS=/dev/null
export DBUS_SYSTEM_BUS_ADDRESS=/dev/null

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

# Wait for Chrome DevTools endpoint to become available before starting the API
python - <<'PY'
import sys
import time
import urllib.request

port = int("${BROWSER_PORT}")
url = f"http://127.0.0.1:{port}/json/version"

for attempt in range(30):
    try:
        with urllib.request.urlopen(url, timeout=1) as resp:
            if resp.status == 200:
                break
    except Exception:
        time.sleep(1)
else:
    print(f"Chrome DevTools not ready after 30s at {url}", file=sys.stderr)
    sys.exit(1)
PY

python -m uvicorn main:app \
  --host "${APP_HOST}" \
  --port "${APP_PORT}" \
  --log-level "${UVICORN_LOG_LEVEL:-info}" \
  --proxy-headers
