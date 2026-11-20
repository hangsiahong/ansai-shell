#!/usr/bin/env bash
# Links this repo into ~/.config. Safe to re-run; backs up any existing non-link config.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"

link() { # src dst
    mkdir -p "$(dirname "$2")"
    if [ -e "$2" ] && [ ! -L "$2" ]; then
        mv "$2" "$2.bak.$(date +%s)"
        echo "backed up $2"
    fi
    ln -sfn "$1" "$2"
    echo "linked $2 -> $1"
}

link "$here/niri/config.kdl" "$cfg/niri/config.kdl"
link "$here/quickshell" "$cfg/quickshell/ansai"
link "$here/niri/niri-portals.conf" "$cfg/xdg-desktop-portal/niri-portals.conf"
mkdir -p "$cfg/ansai-shell" "$HOME/Pictures/Screenshots" "$HOME/.local/share/applications"
# Display settings are machine-specific: seed once, then Settings > Displays owns the file.
[ -e "$cfg/niri/ansai-outputs.kdl" ] || cp "$here/niri/outputs.default.kdl" "$cfg/niri/ansai-outputs.kdl"
link "$here/ansai-settings.desktop" "$HOME/.local/share/applications/ansai-settings.desktop"
# The shell is the polkit agent under niri; keep xfce-polkit's autostart from grabbing the slot first.
if [ -e /etc/xdg/autostart/xfce-polkit.desktop ] && [ ! -e "$cfg/autostart/xfce-polkit.desktop" ]; then
    mkdir -p "$cfg/autostart"
    sed 's/^NotShowIn=.*/NotShowIn=GNOME;KDE;niri;/' /etc/xdg/autostart/xfce-polkit.desktop > "$cfg/autostart/xfce-polkit.desktop"
fi

# Bundled UI fonts (OFL) and the Khmer fallback rule, for GTK apps too.
link "$here/quickshell/assets/fonts" "$HOME/.local/share/fonts/ansai-shell"
link "$here/quickshell/assets/fonts/ansai-fonts.conf" "$cfg/fontconfig/conf.d/61-ansai-fonts.conf"
command -v fc-cache >/dev/null && fc-cache "$HOME/.local/share/fonts"

missing=()
for b in niri qs xwayland-satellite brightnessctl wpctl playerctl swayidle wl-paste cliphist fuzzel wlsunset ghostty node python3 grim slurp wtype; do
    command -v "$b" >/dev/null || missing+=("$b")
done
if [ ${#missing[@]} -gt 0 ]; then
    echo "missing commands: ${missing[*]}"
    echo "install with: sudo pacman -S --needed niri xwayland-satellite quickshell brightnessctl playerctl swayidle cliphist fuzzel wlsunset grim slurp wtype nodejs python python-gobject at-spi2-core"
fi
command -v niri >/dev/null && niri validate -c "$cfg/niri/config.kdl"
echo "done: log out and pick \"Niri\" in the login screen's session menu."
