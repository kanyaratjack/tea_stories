#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT_DIR/.run"
BACKEND_DIR="$ROOT_DIR/backend/go-api"
WEB_DIR="$ROOT_DIR/web-admin"
MOBILE_DIR="$ROOT_DIR/mobile-app"

BACKEND_PORT="${BACKEND_PORT:-8080}"
WEB_PORT="${WEB_PORT:-5173}"
DATABASE_URL="${DATABASE_URL:-postgres://postgres:postgres@localhost:5432/tea_store?sslmode=disable}"

BACKEND_LOG="$RUN_DIR/backend.log"
WEB_LOG="$RUN_DIR/web-admin.log"
BACKEND_PID_FILE="$RUN_DIR/backend.pid"
WEB_PID_FILE="$RUN_DIR/web-admin.pid"

mkdir -p "$RUN_DIR"

is_running() {
  local pid="$1"
  if [[ -z "$pid" ]]; then return 1; fi
  kill -0 "$pid" 2>/dev/null
}

start_backend() {
  if [[ -f "$BACKEND_PID_FILE" ]]; then
    local pid
    pid="$(cat "$BACKEND_PID_FILE" || true)"
    if is_running "$pid"; then
      echo "[backend] already running (pid=$pid)"
      return 0
    fi
  fi

  echo "[backend] starting on :$BACKEND_PORT"
  (
    cd "$BACKEND_DIR"
    nohup env DATABASE_URL="$DATABASE_URL" PORT="$BACKEND_PORT" go run ./cmd/server >"$BACKEND_LOG" 2>&1 &
    echo $! >"$BACKEND_PID_FILE"
  )

  sleep 1
  if ! curl -fsS "http://127.0.0.1:${BACKEND_PORT}/healthz" >/dev/null 2>&1; then
    echo "[backend] health check failed, see $BACKEND_LOG"
    exit 1
  fi
  echo "[backend] healthy"
}

start_web() {
  if [[ -f "$WEB_PID_FILE" ]]; then
    local pid
    pid="$(cat "$WEB_PID_FILE" || true)"
    if is_running "$pid"; then
      echo "[web-admin] already running (pid=$pid)"
      return 0
    fi
  fi

  echo "[web-admin] starting on :$WEB_PORT"
  (
    cd "$WEB_DIR"
    nohup python3 -m http.server "$WEB_PORT" >"$WEB_LOG" 2>&1 &
    echo $! >"$WEB_PID_FILE"
  )

  sleep 1
  if ! curl -fsS "http://127.0.0.1:${WEB_PORT}" >/dev/null 2>&1; then
    echo "[web-admin] startup check failed, see $WEB_LOG"
    exit 1
  fi
  echo "[web-admin] ready: http://127.0.0.1:${WEB_PORT}"
}

start_backend
start_web

echo ""
echo "========== Dev Services =========="
echo "Backend:   http://127.0.0.1:${BACKEND_PORT}"
echo "Web Admin: http://127.0.0.1:${WEB_PORT}"
echo "Logs:"
echo "  $BACKEND_LOG"
echo "  $WEB_LOG"
echo "=================================="
echo ""
echo "[mobile] starting Flutter... (Ctrl+C only stops flutter; services stay running)"

cd "$MOBILE_DIR"
exec flutter run "$@"
