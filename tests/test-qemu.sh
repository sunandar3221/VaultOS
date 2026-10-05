#!/bin/bash
# ==============================================================================
# VaultOS Headless QEMU Testing & Screenshot Capture
# Boots the ISO in QEMU, waits for Sway GUI, and captures a live screenshot
# Executed strictly inside GitHub Actions CI runner
# ==============================================================================

set -euo pipefail

ISO_PATH="${1:-$(pwd)/VaultOS-x86_64.iso}"
SCREENSHOT_OUTPUT="${2:-$(pwd)/tests/screenshot.png}"
QMP_SOCK="/tmp/qmp-sock"
QEMU_PID="/tmp/qemu.pid"
PPM_TEMP="/tmp/screenshot.ppm"

mkdir -p "$(dirname "$SCREENSHOT_OUTPUT")"

if [ ! -f "$ISO_PATH" ]; then
    echo "[ERROR] ISO file tidak ditemukan: $ISO_PATH"
    exit 1
fi

echo "=== [1/4] Menjalankan QEMU Headless untuk Testing Boot ==="

# Clean any existing sockets
rm -f "$QMP_SOCK" "$QEMU_PID" "$PPM_TEMP"

# Launch QEMU
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
echo "=== [2/4] Menunggu Sistem Selesai Booting (55 detik)... ==="

for i in $(seq 55 -5 5); do
    echo "    Menunggu... ${i}s tersisa"
    sleep 5
done

echo "=== [3/4] Mengambil Screenshot Tampilan Layar via QEMU QMP ==="

python3 - << 'PYEOF'
import socket
import json
import time

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect("/tmp/qmp-sock")

# Read greeting
s.recv(1024)

# Negotiate capabilities
s.sendall(json.dumps({"execute": "qmp_capabilities"}).encode() + b"\n")
s.recv(1024)

# Execute screendump
screendump_cmd = {"execute": "screendump", "arguments": {"filename": "/tmp/screenshot.ppm"}}
s.sendall(json.dumps(screendump_cmd).encode() + b"\n")
time.sleep(2)
s.recv(1024)
s.close()
print("--> Screendump QMP berhasil dikirim.")
PYEOF

echo "=== [4/4] Mengonversi Format Screenshot ke PNG ==="

if [ -f "$PPM_TEMP" ]; then
    if command -v convert >/dev/null 2>&1; then
        convert "$PPM_TEMP" "$SCREENSHOT_OUTPUT"
    elif command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -y -i "$PPM_TEMP" "$SCREENSHOT_OUTPUT"
    else
        echo "[WARN] convert/ffmpeg tidak ditemukan, menyimpan raw ppm"
        cp "$PPM_TEMP" "${SCREENSHOT_OUTPUT%.png}.ppm"
    fi
    echo "--> Screenshot berhasil disimpan ke: $SCREENSHOT_OUTPUT"
    ls -lh "$SCREENSHOT_OUTPUT"
else
    echo "[ERROR] File screendump tidak ditemukan!"
fi

# Clean up QEMU process
if [ -f "$QEMU_PID" ]; then
    echo "--> Mematikan instance QEMU..."
    kill -9 "$(cat "$QEMU_PID")" 2>/dev/null || true
    rm -f "$QEMU_PID" "$QMP_SOCK" "$PPM_TEMP"
fi

echo "=== Pengujian QEMU dan pengambilan screenshot selesai! ==="
