#!/bin/bash
# ==============================================================================
# VaultOS Installer Launcher Script
# Starts the local installer backend server and opens Firefox in Kiosk GUI mode
# ==============================================================================

set -e

SERVER_SCRIPT="/usr/share/vault-installer/installer-server.py"
PORT=8765
URL="http://127.0.0.1:${PORT}/index.html"
PROFILE_DIR="/tmp/vault-installer-profile"

# Start Python backend server in background if not already running
if ! pgrep -f "installer-server.py" >/dev/null 2>&1; then
    echo "[INFO] Menjalankan installer server di background..."
    python3 "$SERVER_SCRIPT" >/tmp/installer-server.log 2>&1 &
    sleep 1
fi

# Wait for local server to respond
for i in {1..10}; do
    if curl -s "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Prepare clean minimal profile for instantaneous kiosk startup
mkdir -p "$PROFILE_DIR"
cat << 'PREF' > "$PROFILE_DIR/user.js"
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
PREF

# Ensure Wayland flags
export MOZ_ENABLE_WAYLAND=1

# Launch Firefox in clean kiosk mode
echo "[INFO] Membuka frontend installer..."
exec firefox --profile "$PROFILE_DIR" --kiosk "$URL"
