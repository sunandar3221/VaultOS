#!/bin/bash
# ==============================================================================
# VaultOS ISO Packager Script
# Compresses rootfs into SquashFS and generates a bootable Hybrid EFI/BIOS ISO
# Executed strictly inside GitHub Actions CI runner
# ==============================================================================

set -euo pipefail

ROOTFS_DIR="${1:-$(pwd)/rootfs}"
OUTPUT_ISO="${2:-$(pwd)/VaultOS-x86_64.iso}"
ISO_STAGING="$(pwd)/iso_staging"

echo "=== [1/4] Menyiapkan Staging ISO ==="
rm -rf "$ISO_STAGING"
mkdir -p "$ISO_STAGING/live"
mkdir -p "$ISO_STAGING/boot/grub"

echo "=== [2/4] Menyalin Kernel dan Initrd ==="
# Find kernel and initrd in rootfs
VMLINUZ=$(find "$ROOTFS_DIR/boot" -name "vmlinuz*" | sort -V | tail -n 1)
INITRD=$(find "$ROOTFS_DIR/boot" -name "initrd.img*" | sort -V | tail -n 1)

if [ -z "$VMLINUZ" ] || [ -z "$INITRD" ]; then
    echo "[ERROR] Kernel atau initrd tidak ditemukan di $ROOTFS_DIR/boot!"
    exit 1
fi

echo "--> Kernel : $VMLINUZ"
echo "--> Initrd : $INITRD"

cp -v "$VMLINUZ" "$ISO_STAGING/live/vmlinuz"
cp -v "$INITRD" "$ISO_STAGING/live/initrd.img"

echo "=== [3/4] Mengompresi Rootfs menjadi SquashFS ==="
mksquashfs "$ROOTFS_DIR" "$ISO_STAGING/live/filesystem.squashfs" \
    -comp zstd \
    -wildcards \
    -e "boot/vmlinuz*" \
    -e "boot/initrd.img*" \
    -e "tmp/*" \
    -e "var/tmp/*" \
    -noappend

echo "=== [4/4] Mengonfigurasi GRUB & Membuat Bootable ISO ==="

cat << 'EOF' > "$ISO_STAGING/boot/grub/grub.cfg"
set default="0"
set timeout=3

search --set=root --file /live/vmlinuz

menuentry "VaultOS (Immutable Sandboxed Linux)" --class os {
    linux /live/vmlinuz boot=live components quiet splash
    initrd /live/initrd.img
}

menuentry "VaultOS (Verbose Boot / Debug)" --class os {
    linux /live/vmlinuz boot=live components
    initrd /live/initrd.img
}
EOF

echo "--> Menjalankan grub-mkrescue untuk membuat hybrid ISO..."
grub-mkrescue \
    -o "$OUTPUT_ISO" \
    "$ISO_STAGING" \
    -- -volid "VAULTOS"

echo "=== Berhasil! File ISO VaultOS dibuat: $OUTPUT_ISO ==="
ls -lh "$OUTPUT_ISO"
