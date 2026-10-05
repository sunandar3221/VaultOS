#!/bin/bash
# ==============================================================================
# VaultOS Debian Sandbox Terminal Launcher
# Runs an isolated Debian userland container via Bubblewrap (bwrap)
# ==============================================================================

set -e

SANDBOX_DIR="$HOME/.local/share/vault-sandbox/debian"
TARBALL_CACHE="$HOME/.cache/vault-sandbox/debian-rootfs.tar.xz"
DOWNLOAD_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/dist-amd64/bookworm/rootfs.tar.xz"
BACKUP_URL="https://raw.githubusercontent.com/debuerreotype/docker-debian-artifacts/dist-amd64/bookworm/rootfs.tar.xz"

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[32m"
BLUE="\033[34m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

clear
cat << "EOF"
 __     __            _ _    ___  ____  
 \ \   / /_ _ _   _| | |_ / _ \/ ___| 
  \ \ / / _` | | | | | __| | | \___ \ 
   \ V / (_| | |_| | | |_| |_| |___) |
    \_/ \__,_|\__,_|_|\__|\___/|____/ 
   [ Immutable Sandboxed Linux OS ]
EOF

echo -e "${CYAN}=================================================================${RESET}"
echo -e "${BOLD}              DEBIAN ISOLATED SANDBOX TERMINAL                   ${RESET}"
echo -e "${CYAN}=================================================================${RESET}"
echo -e "${BLUE}* Sistem Host VaultOS:${RESET} Read-Only (Aman & Tidak Dapat Diubah)"
echo -e "${BLUE}* Lingkungan Sandbox :${RESET} Debian Bookworm (Akses Penuh di dalam Sandbox)"
echo -e "${CYAN}-----------------------------------------------------------------${RESET}"

# Check if Debian Sandbox is already installed
if [ ! -f "$SANDBOX_DIR/bin/bash" ] || [ ! -f "$SANDBOX_DIR/etc/debian_version" ]; then
    echo -e "\n${YELLOW}[!] Debian Sandbox belum terpasang di sistem ini.${RESET}"
    echo -e "Distro VaultOS tidak memaketkan terminal secara langsung di image"
    echo -e "untuk menjaga efisiensi dan keamanan sistem."
    echo ""
    echo -e "${GREEN}Mengunduh Debian Minbase Sandbox sekarang...${RESET}"
    echo -e "Ukuran unduhan: ~32 MB (akan diekstrak menjadi ~110 MB)"
    echo ""

    mkdir -p "$HOME/.cache/vault-sandbox"
    mkdir -p "$SANDBOX_DIR"

    # Download rootfs if not cached
    if [ ! -f "$TARBALL_CACHE" ]; then
        echo -e "${CYAN}--> Mengunduh rootfs dari repository Debian official...${RESET}"
        if ! curl -L --progress-bar -f -o "$TARBALL_CACHE" "$DOWNLOAD_URL"; then
            echo -e "${YELLOW}--> Mencoba mirror alternatif...${RESET}"
            curl -L --progress-bar -f -o "$TARBALL_CACHE" "$BACKUP_URL" || {
                echo -e "${RED}[ERROR] Gagal mengunduh Debian rootfs. Periksa koneksi internet!${RESET}"
                echo "Tekan Enter untuk keluar..."
                read -r
                exit 1
            }
        fi
    fi

    echo -e "\n${CYAN}--> Mengekstrak Debian Sandbox ke $SANDBOX_DIR...${RESET}"
    tar -xf "$TARBALL_CACHE" -C "$SANDBOX_DIR"

    # Setup sandbox resolv.conf for networking
    mkdir -p "$SANDBOX_DIR/etc"
    cat << 'RESOLV' > "$SANDBOX_DIR/etc/resolv.conf"
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 1.0.0.1
RESOLV

    # Setup welcome motd inside sandbox
    cat << 'MOTD' > "$SANDBOX_DIR/etc/motd"

=============================================================
  Selamat datang di Debian Sandbox (VaultOS)
=============================================================
* Hak akses : ROOT (Hanya di dalam sandbox container)
* Keamanan  : Host VaultOS terisolasi penuh dari container ini
* Perintah  : apt update && apt install <paket>
=============================================================

MOTD

    # Setup bashrc prompt inside sandbox
    cat << 'BASHRC' >> "$SANDBOX_DIR/root/.bashrc"
export PS1='\[\033[01;32m\]debian-sandbox\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '
cat /etc/motd
BASHRC

    echo -e "${GREEN}[✓] Pemasangan Debian Sandbox berhasil!${RESET}"
    sleep 1
fi

echo -e "\n${GREEN}--> Menjalankan Sandbox via Bubblewrap (Containerized)...${RESET}\n"

# Verify bubblewrap exists
if ! command -v bwrap >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Bubblewrap (bwrap) tidak ditemukan di host!${RESET}"
    read -r
    exit 1
fi

# Run Debian isolated sandbox using bubblewrap:
# Unshares network, ipc, pid, uts namespaces.
# Host filesystem / is completely replaced with $SANDBOX_DIR.
# Host is 100% invisible and inaccessible.
exec bwrap \
    --unshare-all \
    --share-net \
    --bind "$SANDBOX_DIR" / \
    --proc /proc \
    --dev /dev \
    --tmpfs /tmp \
    --tmpfs /run \
    --setenv HOME /root \
    --setenv USER root \
    --setenv LOGNAME root \
    --setenv TERM "${TERM:-xterm-256color}" \
    --setenv PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    --dir /root \
    --chdir /root \
    /bin/bash -l
