#!/bin/bash
# ==============================================================================
# VaultOS Installer Launcher Script
# Starts the local installer backend server and opens Firefox in Kiosk GUI mode
# ==============================================================================

exec > /tmp/installer-launcher.log 2>&1
echo "[INFO] Starting VaultOS Installer Launcher at $(date)"

SERVER_SCRIPT="/usr/share/vault-installer/installer-server.py"
PORT=8765
URL="http://127.0.0.1:${PORT}/index.html"
PROFILE_DIR="/tmp/vault-installer-profile"

# Start Python backend server in background if not already running
if ! pgrep -f "installer-server.py" >/dev/null 2>&1; then
    echo "[INFO] Menjalankan installer server di background..."
    python3 "$SERVER_SCRIPT" >/tmp/installer-server.log 2>&1 &
fi

# Prepare clean minimal profile for instantaneous kiosk startup
mkdir -p "$PROFILE_DIR"
cat << 'PREF' > "$PROFILE_DIR/user.js"
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("gfx.webrender.software", true);
user_pref("layers.acceleration.disabled", true);
user_pref("browser.tabs.remote.autostart", false);
PREF

# Ensure Wayland and rendering environment
export MOZ_ENABLE_WAYLAND=1
export GDK_BACKEND=wayland

# Wait up to 5 seconds for local server
for i in {1..10}; do
    if curl -s "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
        echo "[INFO] Server siap di port $PORT"
        break
    fi
    sleep 0.5
done

# Launch Firefox in clean kiosk mode
echo "[INFO] Membuka Firefox Kiosk: $URL"
exec firefox --profile "$PROFILE_DIR" --kiosk "$URL"
