#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "[error] 'cloudflared' is not installed or not in PATH."
  exit 1
fi

if [ ! -d "dist" ]; then
  echo "[error] Missing 'dist/' directory. Run './build.py wasm' first."
  exit 1
fi

pkill -f "server/ws_server.py" >/dev/null 2>&1 || true

trap 'echo ""; echo "[stop] Shutting down server and tunnel..."; kill 0' EXIT

echo "[1/2] Starting Walrus Wars HTTP + WebSocket server on http://127.0.0.1:8000 ..."
uv run python server/ws_server.py &

# Wait until port 8000 is actually listening before starting cloudflared
for _ in $(seq 1 30); do
  if python3 -c "import socket; s=socket.create_connection(('127.0.0.1', 8000), 0.2); s.close()" 2>/dev/null; then
    break
  fi
  sleep 0.2
done

echo "[2/2] Starting Cloudflare Quick Tunnel (copy the NEW https://*.trycloudflare.com URL below)..."
cloudflared tunnel --url http://127.0.0.1:8000

