# VaultOS - Immutable Sandboxed Linux Distribution

[![Build and Test VaultOS](https://github.com/sunandar3221/VaultOS/actions/workflows/build-iso.yml/badge.svg)](https://github.com/sunandar3221/VaultOS/actions/workflows/build-iso.yml)

**VaultOS** adalah distribusi Linux yang dirancang dengan arsitektur **Immutable (Read-Only)** dan sistem keamanan terkunci (*kiosk-grade isolation*), di mana pengguna biasa hanya bisa menggunakan sistem tanpa bisa mengubah, merusak, atau mengakses file sistem utama sama sekali.

Distro ini mengusung Window Manager **Sway** (Wayland) yang ringan, modern, dan dilengkapi aplikasi bawaan:
- 🌐 **Web Browser**: Mozilla Firefox
- 📁 **File Manager**: PCManFM
- 💻 **Debian Sandbox Terminal**: Terminal terisolasi berbasis Debian yang diunduh secara *on-demand* saat pertama kali dijalankan, berjalan di dalam container *bubblewrap (bwrap)* sehingga pengguna bebas bereksperimen (`apt install`, dsb.) tanpa menyentuh sistem induk.

---

## 🔒 Konsep & Fitur Unik VaultOS

1. **Sistem Terkunci Total (Zero System Access)**:
   - Root filesystem (`/`) berada di atas image SquashFS *read-only*.
   - Tidak ada akses `sudo`, tidak ada akses `root`, password root terkunci.
   - Pintasan TTY switching (*Ctrl+Alt+F1..F6*) dimatikan.
   - Tidak ada shell langsung ke host sistem bagi pengguna biasa.

2. **Sway Wayland Compositor**:
   - UI minimalis dan elegan dengan Waybar di sisi atas.
   - Launcher pintasan cepat: Firefox, File Manager, Sandbox Terminal, dan Power Menu.
   - Shortcut terkontrol:
     - `Super + F`: Firefox
     - `Super + E`: File Manager
     - `Super + T`: Debian Sandbox Terminal
     - `Super + X`: Power Menu (Shutdown / Reboot)

3. **Debian Sandbox Terminal (On-Demand Download)**:
   - Terminal tidak langsung tersedia di dalam image ISO untuk menghemat ukuran.
   - Saat pertama kali user membuka terminal, skrip otomatis mengunduh rootfs Debian minimal (~30 MB terkompresi).
   - Dijalankan via **Bubblewrap (bwrap)** unprivileged sandbox.
   - Di dalam sandbox, pengguna memiliki hak akses root virtual, dapat menjalankan `apt update`, `apt install`, kompilasi kode, dll., dengan sistem host terlindungi 100%.

4. **100% CI/CD Native via GitHub Actions**:
   - Seluruh proses build ISO, testing headless via QEMU, dan pengambilan screenshot otomatis dilakukan di GitHub Actions runner.
   - Tidak ada build atau kompilasi lokal di mesin laptop.

---

## 🚀 Struktur Direktori

```text
VaultOS/
├── .github/
│   └── workflows/
│       └── build-iso.yml          # GitHub Actions workflow: build, QEMU boot, screenshot, release
├── build/
│   ├── build-rootfs.sh            # Skrip pembuatan rootfs dasar & konfigurasi VaultOS
│   └── build-iso.sh               # Skrip pembuatan bootable Live ISO (SquashFS + GRUB EFI/BIOS)
├── overlay/                       # File konfigurasi yang di-inject ke dalam rootfs
│   ├── etc/
│   │   ├── sway/config            # Konfigurasi terkunci Sway WM
│   │   ├── waybar/
│   │   │   ├── config             # Waybar top bar layout & quick launch buttons
│   │   │   └── style.css          # Styling Waybar modern dark
│   │   ├── systemd/system/
│   │   │   └── getty@tty1.service.d/autologin.conf # Autologin ke vaultuser
│   │   └── profile.d/sway-auto.sh # Auto start Sway pada TTY1
│   └── usr/local/bin/
│       ├── vault-sandbox-terminal.sh # Skrip on-demand downloader & bwrap runner Debian
│       └── vault-power.sh         # GUI menu poweroff & reboot
└── tests/
    └── test-qemu.sh               # Skrip testing headless QEMU & screendump screenshot
```

---

## 📦 Mengunduh dan Menjalankan ISO

Setiap rilis build ISO dan screenshot dapat dilihat dan diunduh di tab **[Releases](https://github.com/sunandar3221/VaultOS/releases)** dan **Artifacts** di GitHub Actions.

Untuk mencoba file ISO di QEMU lokal (opsional):
```bash
qemu-system-x86_64 -m 2048 -enable-kvm -cdrom VaultOS-x86_64.iso
```
