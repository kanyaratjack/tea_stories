#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$ROOT_DIR/.run"

stop_by_pid_file() {
  local name="$1"
  local pid_file="$2"
  if [[ ! -f "$pid_file" ]]; then
    echo "[$name] not running"
    return 0
  fi
  local pid
  pid="$(cat "$pid_file" || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" || true
    sleep 0.3
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" || true
    fi
    echo "[$name] stopped (pid=$pid)"
  else
    echo "[$name] stale pid file"
  fi
  rm -f "$pid_file"
}

stop_by_pid_file "web-admin" "$RUN_DIR/web-admin.pid"
stop_by_pid_file "backend" "$RUN_DIR/backend.pid"

echo "done"
