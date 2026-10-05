#!/bin/sh
# Autostart Sway on TTY1 if not already inside a Wayland compositor
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_CURRENT_DESKTOP=sway
    export XDG_SESSION_TYPE=wayland
    export MOZ_ENABLE_WAYLAND=1
    exec sway
fi
