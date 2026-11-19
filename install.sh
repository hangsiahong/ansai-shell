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
mkdir -p "$cfg/ansai-shell" "$HOME/Pictures/Screenshots"

missing=()
for b in niri qs xwayland-satellite brightnessctl wpctl playerctl swayidle wl-paste cliphist fuzzel wlsunset ghostty; do
    command -v "$b" >/dev/null || missing+=("$b")
done
if [ ${#missing[@]} -gt 0 ]; then
    echo "missing commands: ${missing[*]}"
    echo "install with: sudo pacman -S --needed niri xwayland-satellite quickshell brightnessctl playerctl swayidle cliphist fuzzel wlsunset"
fi
command -v niri >/dev/null && niri validate -c "$cfg/niri/config.kdl"
echo "done: log out and pick \"Niri\" in the login screen's session menu."
