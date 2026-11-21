#!/usr/bin/env bash
# Selkies session (runs as abc, HOME=/config): set up the shell on first start, then niri, which starts the shell.
export XDG_RUNTIME_DIR="/tmp/xdg-$(id -u)" XDG_CURRENT_DESKTOP=niri
mkdir -p -m 700 "$XDG_RUNTIME_DIR"
ls /dev/dri/renderD* >/dev/null 2>&1 || export LIBGL_ALWAYS_SOFTWARE=1
if [ ! -e "$HOME/.config/ansai-shell/settings.json" ]; then
    /opt/ansai-shell/install.sh >/dev/null 2>&1
    rm -f "$HOME/.config/niri/ansai-outputs.kdl"
    mkdir -p "$HOME/.config/ansai-shell"
    printf '%s\n' '{"wallpaper": "/opt/ansai-shell/quickshell/assets/wallpapers/drift-dark.jpg", "style": "material", "accent": "purple", "barStats": false, "widgets": ["clock", "calendar", "weather"], "pinned": ["ansai", "brave-origin", "org.gnome.Nautilus", "org.gnome.TextEditor", "org.gnome.Calculator", "org.gnome.Loupe"]}' > "$HOME/.config/ansai-shell/settings.json"
    mkdir -p "$HOME/.local/share/applications"
    mkdir -p "$HOME/.config/BraveSoftware/Brave-Origin"   # skip Origin's free-tier welcome screen
    printf '%s\n' '{"brave": {"origin": {"free_tier_accepted": true}}}' > "$HOME/.config/BraveSoftware/Brave-Origin/Local State"
    printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=ansai' 'Comment=Control room for coding agents' 'Icon=utilities-terminal' \
        'Exec=brave-origin --app=http://127.0.0.1:7777' 'Categories=Development;' > "$HOME/.local/share/applications/ansai.desktop"
fi
# Docker's seccomp blocks Chromium's namespace sandbox; the per-visitor container is the sandbox here.
# KOOMPI Cloud caps a container at ~256 threads: these fold Brave's GPU, network and storage services into its main
# process and drop V8's helper threads (fast.com + ansai: ~140 → ~80 threads), or new apps and tabs fail to start.
mkdir -p "$HOME/.config"
printf '%s\n' --no-sandbox --test-type --ozone-platform=wayland --no-first-run --no-default-browser-check --disable-breakpad \
    --disable-gpu --in-process-gpu --renderer-process-limit=2 --num-raster-threads=1 --js-flags=--single-threaded \
    --disable-site-isolation-trials --enable-features=NetworkServiceInProcess2,StorageServiceInProcess \
    --disable-features=BackForwardCache,SpareRendererForSitePerProcess > "$HOME/.config/brave-origin-flags.conf"
# ansai (agent control room) on :7777, opened by the ansai app above.
(cd /opt/ansai && ANSAI_PORT=7777 exec bun src/server/index.ts >/tmp/ansai.log 2>&1) &
# Web: every window opens floating (move/close with the mouse, as the Super shortcuts rarely reach a browser tab).
c="$HOME/.config/niri/config.kdl"
if [ -L "$c" ]; then cp --remove-destination "$(readlink -f "$c")" "$c"; printf '\nwindow-rule {\n    open-floating true\n}\n' >> "$c"; fi
# Selkies resizes the X screen to the browser window; make niri's window (and so its output) follow it.
(while sleep 0.5; do
    w=$(xdotool search --name '^niri$' 2>/dev/null | head -1) || continue
    [ -n "$w" ] || continue
    s=$(xdotool getdisplaygeometry | tr ' ' x); g=$(xdotool getwindowgeometry "$w" | sed -n 's/.*Geometry: //p')
    [ "$s" = "$g" ] || xdotool windowsize "$w" ${s%x*} ${s#*x}
    # No X window manager: give niri's window the keyboard focus, or typed keys never reach it.
    [ "$(xdotool getwindowfocus 2>/dev/null)" = "$w" ] || xdotool windowfocus "$w" 2>/dev/null
done) &
exec dbus-launch --exit-with-session sh -c 'gsettings set org.gnome.desktop.interface icon-theme Papirus; exec niri >/tmp/niri.log 2>&1'
