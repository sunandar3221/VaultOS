#!/bin/sh
# Autostart Sway on TTY1 if not already inside a Wayland compositor
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland
    export MOZ_ENABLE_WAYLAND=1
    export WLR_RENDERER=pixman
    export WLR_NO_HARDWARE_CURSORS=1
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    exec sway --unsupported-gpu
fi
