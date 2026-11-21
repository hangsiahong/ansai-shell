#!/usr/bin/env bash
# Selkies session (runs as abc, HOME=/config): set up the shell on first start, then niri, which starts the shell.
export XDG_RUNTIME_DIR="/tmp/xdg-$(id -u)" XDG_CURRENT_DESKTOP=niri
mkdir -p -m 700 "$XDG_RUNTIME_DIR"
ls /dev/dri/renderD* >/dev/null 2>&1 || export LIBGL_ALWAYS_SOFTWARE=1
if [ ! -e "$HOME/.config/ansai-shell/settings.json" ]; then
    /opt/ansai-shell/install.sh >/dev/null 2>&1
    rm -f "$HOME/.config/niri/ansai-outputs.kdl"
    mkdir -p "$HOME/.config/ansai-shell"
    printf '%s\n' '{"wallpaper": "/opt/ansai-shell/quickshell/assets/wallpapers/drift-dark.jpg", "style": "material", "accent": "purple", "barStats": false, "widgets": ["clock", "calendar", "weather"], "pinned": ["org.gnome.Nautilus", "org.gnome.TextEditor", "org.gnome.Calculator", "org.gnome.Loupe"]}' > "$HOME/.config/ansai-shell/settings.json"
fi
exec dbus-launch --exit-with-session sh -c 'gsettings set org.gnome.desktop.interface icon-theme Papirus; exec niri >/tmp/niri.log 2>&1'
