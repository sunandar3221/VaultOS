#!/bin/bash
# ==============================================================================
# VaultOS Rootfs Generator Script
# Creates a minimal, immutable Linux rootfs with Sway, Firefox, PCManFM & Bubblewrap
# Executed strictly inside GitHub Actions CI runner (Ubuntu 24.04/22.04)
# ==============================================================================

set -euo pipefail

ROOTFS_DIR="${1:-$(pwd)/rootfs}"
OVERLAY_DIR="$(pwd)/overlay"

echo "=== [1/5] Memulai pembuatan rootfs VaultOS di $ROOTFS_DIR ==="

rm -rf "$ROOTFS_DIR"
mkdir -p "$ROOTFS_DIR"

# Package list for minimal Wayland kiosk system
PACKAGES=(
    # Core system & Live boot
    "linux-image-amd64"
    "live-boot"
    "systemd"
    "systemd-sysv"
    "udev"
    "dbus"
    "kmod"
    "procps"

    # Networking & Utilities
    "iproute2"
    "isc-dhcp-client"
    "ca-certificates"
    "curl"
    "wget"
    "tar"
    "xz-utils"

    # Graphical Environment (Wayland + Sway)
    "sway"
    "swaybg"
    "waybar"
    "foot"
    "seatd"
    "fonts-dejavu-core"

    # Pre-installed Built-in Apps
    "firefox-esr"
    "pcmanfm"
    "zenity"

    # Isolation & Sandbox runtime
    "bubblewrap"
)

PKG_LIST=$(IFS=, ; echo "${PACKAGES[*]}")

KEYRING_ARG=""
if [ -f "/usr/share/keyrings/debian-archive-keyring.gpg" ]; then
    KEYRING_ARG="--keyring=/usr/share/keyrings/debian-archive-keyring.gpg"
fi

echo "--> Mengunduh dan memasang paket dasar menggunakan mmdebstrap..."
mmdebstrap \
    $KEYRING_ARG \
    --variant=minbase \
    --include="$PKG_LIST" \
    --components="main" \
    bookworm \
    "$ROOTFS_DIR" \
    http://deb.debian.org/debian

echo "=== [2/5] Menerapkan Overlay Konfigurasi VaultOS ==="
if [ -d "$OVERLAY_DIR" ]; then
    cp -av "$OVERLAY_DIR"/* "$ROOTFS_DIR"/
fi

# Ensure executable permissions on custom scripts
chmod +x "$ROOTFS_DIR"/usr/local/bin/* || true
chmod +x "$ROOTFS_DIR"/etc/profile.d/* || true

echo "=== [3/5] Mengonfigurasi Akun Pengguna & Pengamanan Sistem ==="

chroot "$ROOTFS_DIR" /bin/bash << 'EOF'
set -e

# Buat grup dan pengguna non-root vaultuser
groupadd -g 1000 vaultuser || true
useradd -m -u 1000 -g 1000 -s /bin/bash -G video,input,audio,render vaultuser

# Set password default (bisa diubah, tapi tidak memiliki izin sudo/root)
echo "vaultuser:vaultuser" | chpasswd

# Kunci akun root sehingga tidak ada yang bisa login sebagai root
passwd -l root

# Lindungi direktori /root
chmod 700 /root

# Pastikan sudo tidak ada atau tidak memiliki hak akses untuk vaultuser
if command -v sudo >/dev/null 2>&1; then
    rm -f /etc/sudoers.d/*
    echo "# VaultOS: No sudo access allowed" > /etc/sudoers
fi

# Setup seatd & logind permissions for sway
usermod -aG seat vaultuser 2>/dev/null || true
systemctl enable seatd 2>/dev/null || true

# Setup network
cat << 'NET' > /etc/systemd/network/20-wired.network
[Match]
Name=en* eth*

[Network]
DHCP=yes
NET
systemctl enable systemd-networkd 2>/dev/null || true
systemctl enable systemd-resolved 2>/dev/null || true

# Cleanup caches
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/log/*
EOF

echo "=== [4/5] Memastikan Izin Direktori User ==="
chown -R 1000:1000 "$ROOTFS_DIR/home/vaultuser"

echo "=== [5/5] Rootfs VaultOS berhasil dibuat! ==="
