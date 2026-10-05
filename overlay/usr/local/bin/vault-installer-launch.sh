#!/bin/bash
# ==============================================================================
# VaultOS Installer Launcher Script
# Starts the local installer backend server and opens Firefox in Kiosk GUI mode
# ==============================================================================

set -e

SERVER_SCRIPT="/usr/share/vault-installer/installer-server.py"
PORT=8765
URL="http://127.0.0.1:${PORT}/index.html"

# Start Python backend server in background if not already running
if ! pgrep -f "installer-server.py" >/dev/null 2>&1; then
    echo "[INFO] Menjalankan installer server di background..."
    python3 "$SERVER_SCRIPT" >/dev/null 2>&1 &
    sleep 1
fi

# Wait for local server to respond
for i in {1..10}; do
    if curl -s "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Kill any existing installer browser window before starting fresh
pkill -f "firefox.*vault-installer" >/dev/null 2>&1 || true

# Launch Firefox in clean kiosk mode
echo "[INFO] Membuka frontend installer..."
exec firefox --kiosk --class "vault-installer" "$URL"
