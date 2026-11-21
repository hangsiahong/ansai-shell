#!/bin/sh
# Container entrypoint: software X screen, niri nested in it running the shell, VNC of that screen, noVNC on $PORT.
set -e
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
Xvfb :1 -screen 0 "${GEOMETRY}x24" -nolisten tcp &
export DISPLAY=:1 LIBGL_ALWAYS_SOFTWARE=1
for _ in $(seq 50); do [ -e /tmp/.X11-unix/X1 ] && break; sleep 0.1; done
dbus-run-session -- sh -c 'gsettings set org.gnome.desktop.interface icon-theme Papirus; exec niri' >/tmp/niri.log 2>&1 &
x11vnc -display :1 -forever -shared -nopw -localhost -rfbport 5900 -quiet -noxdamage &
exec websockify --web /opt/novnc "$PORT" localhost:5900
