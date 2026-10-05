#!/bin/bash
# ==============================================================================
# VaultOS Power & Session Dialog
# ==============================================================================

ACTION=$(zenity --list \
    --title="VaultOS Power Menu" \
    --text="Pilih tindakan yang ingin dilakukan:" \
    --column="Opsi" --column="Keterangan" \
    "Poweroff" "Matikan komputer" \
    "Reboot" "Nyalakan ulang komputer" \
    "Cancel" "Batal dan kembali ke desktop" \
    --width=350 --height=250 2>/dev/null)

case "$ACTION" in
    "Poweroff")
        systemctl poweroff || poweroff -f
        ;;
    "Reboot")
        systemctl reboot || reboot -f
        ;;
    *)
        exit 0
        ;;
esac
