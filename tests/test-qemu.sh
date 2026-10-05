#!/bin/bash
# ==============================================================================
# VaultOS Headless QEMU Testing & Multi-Screen Capture
# 1. Boots ISO directly into the HTML/SVG Installer
# 2. Captures screenshot of Installer (screenshot-installer.png)
# 3. Triggers "Try OS" / close installer via QMP send-key
# 4. Captures screenshot of Sway Desktop (screenshot-desktop.png)
# ==============================================================================

set -euo pipefail

ISO_PATH="${1:-$(pwd)/VaultOS-x86_64.iso}"
OUT_DIR="$(pwd)/tests"
QMP_SOCK="/tmp/qmp-sock"
QEMU_PID="/tmp/qemu.pid"

mkdir -p "$OUT_DIR"

if [ ! -f "$ISO_PATH" ]; then
    echo "[ERROR] ISO file tidak ditemukan: $ISO_PATH"
    exit 1
fi

echo "=== [1/5] Menjalankan QEMU Headless untuk Testing Live USB ==="

rm -f "$QMP_SOCK" "$QEMU_PID" /tmp/screen-*.ppm

qemu-system-x86_64 \
    -m 2048 \
    -smp 2 \
    -cdrom "$ISO_PATH" \
    -boot d \
    -vga virtio \
    -display none \
    -vnc :1 \
    -qmp "unix:$QMP_SOCK,server,nowait" \
    -daemonize \
    -pidfile "$QEMU_PID"

echo "--> QEMU berjalan dengan PID: $(cat "$QEMU_PID")"
echo "=== [2/5] Menunggu Sistem & Installer Selesai Dimuat (70 detik)... ==="

for i in $(seq 70 -5 5); do
    echo "    Menunggu boot & GUI... ${i}s tersisa"
    sleep 5
done

echo "=== [3/5] Mengambil Screenshot Tampilan Installer ==="

python3 - << 'PYEOF'
import socket
import json
import time

def qmp_execute(sock, cmd):
    sock.sendall(json.dumps(cmd).encode() + b"\n")
    time.sleep(1)
    return sock.recv(2048)

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect("/tmp/qmp-sock")
s.recv(1024)

# Negotiate
qmp_execute(s, {"execute": "qmp_capabilities"})

# 1. Capture Installer Screen
print("--> Menangkap screenshot installer...")
qmp_execute(s, {"execute": "screendump", "arguments": {"filename": "/tmp/screen-installer.ppm"}})

# 2. Simulate Try OS / Super+Q to close installer and show Sway desktop
print("--> Mengirim pintasan keyboard Super+Q untuk beralih ke Desktop Sway (Try OS)...")
qmp_execute(s, {
    "execute": "send-key",
    "arguments": {
        "keys": [
            {"type": "qcode", "data": "meta_l"},
            {"type": "qcode", "data": "q"}
        ]
    }
})
time.sleep(4)

# 3. Capture Sway Desktop Screen
print("--> Menangkap screenshot desktop Sway (Try OS)...")
qmp_execute(s, {"execute": "screendump", "arguments": {"filename": "/tmp/screen-desktop.ppm"}})

s.close()
print("--> Screendump QMP selesai.")
PYEOF

echo "=== [4/5] Mengonversi Format Screenshot ke PNG ==="

convert_ppm() {
    local src="$1"
    local dst="$2"
    if [ -f "$src" ]; then
        if command -v convert >/dev/null 2>&1; then
            convert "$src" "$dst"
        elif command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -y -i "$src" "$dst"
        else
            cp "$src" "${dst%.png}.ppm"
        fi
        echo "--> Berhasil membuat: $dst ($(ls -lh "$dst" | awk '{print $5}'))"
    fi
}

convert_ppm "/tmp/screen-installer.ppm" "$OUT_DIR/screenshot-installer.png"
convert_ppm "/tmp/screen-desktop.ppm" "$OUT_DIR/screenshot-desktop.png"

# Backward compatibility copy
cp -v "$OUT_DIR/screenshot-installer.png" "$OUT_DIR/screenshot.png" || true

echo "=== [5/5] Membersihkan Proses QEMU ==="
if [ -f "$QEMU_PID" ]; then
    kill -9 "$(cat "$QEMU_PID")" 2>/dev/null || true
    rm -f "$QEMU_PID" "$QMP_SOCK" /tmp/screen-*.ppm
fi

echo "=== Pengujian QEMU Installer & Try OS selesai! ==="
ls -lh "$OUT_DIR"/*.png
