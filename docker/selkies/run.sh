#!/bin/bash
# Container start without s6 (KOOMPI Cloud runs apps as a non-root user, and the Selkies base's /init needs root):
# Xvfb → the session (startwm.sh: niri + the shell) → Selkies (:8082) → the gate (:8080, also serves the web client).
[ "$(id -u)" = 0 ] && exec s6-setuidgid abc env HOME=/config "$0"
[ -w "${HOME:-/nonexistent}" ] || export HOME=/tmp/home
mkdir -p "$HOME"
# An arbitrary uid has no passwd entry, which dbus, GTK and Chromium need (/etc/passwd is made writable at build).
id -un >/dev/null 2>&1 || echo "ansai:x:$(id -u):$(id -g)::$HOME:/bin/bash" >> /etc/passwd
export DISPLAY=:1 SELKIES_PORT=8082 XCURSOR_THEME=Adwaita
rm -f /tmp/.X1-lock
Xvfb :1 -screen 0 1280x800x24 -dpi 96 +extension COMPOSITE +extension DAMAGE +extension GLX +extension RANDR +extension RENDER \
    +extension MIT-SHM +extension XFIXES +extension XTEST +iglx +render -nolisten tcp -ac -shmem &
for _ in $(seq 100); do xset q >/dev/null 2>&1 && break; sleep 0.1; done
(cd "$HOME" && exec bash /defaults/startwm.sh) &
selkies --addr=localhost &
exec node /opt/ansai-shell/docker/selkies/gate.mjs
