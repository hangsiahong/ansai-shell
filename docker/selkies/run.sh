#!/bin/bash
# Container start without s6 (KOOMPI Cloud runs apps as a non-root user, and the Selkies base's /init needs root):
# Xvfb → the session (startwm.sh: niri + the shell) → Selkies (:8082) → the gate (:8080, also serves the web client).
[ "$(id -u)" = 0 ] && exec s6-setuidgid abc env HOME=/config "$0"
[ -w "${HOME:-/nonexistent}" ] || export HOME=/tmp/home
mkdir -p "$HOME"
# An arbitrary uid has no passwd entry, which dbus, GTK and Chromium need (/etc/passwd is made writable at build).
id -un >/dev/null 2>&1 || echo "ansai:x:$(id -u):$(id -g)::$HOME:/bin/bash" >> /etc/passwd
export DISPLAY=:1 SELKIES_PORT=8082 XCURSOR_THEME=Adwaita
# llvmpipe starts one thread per host core in every GL window; on a big cloud host under a small CPU quota that
# hits the container's thread limit (fork: Resource temporarily unavailable) and apps fail to open. Size it to the quota.
q=$(cut -d' ' -f1 /sys/fs/cgroup/cpu.max 2>/dev/null); per=$(cut -d' ' -f2 /sys/fs/cgroup/cpu.max 2>/dev/null)
if [ -n "$q" ] && [ "$q" != max ]; then n=$(( (q + per - 1) / per )); else n=$(nproc); fi
[ "$n" -gt 4 ] && n=4; [ "$n" -lt 2 ] && n=2
export LP_NUM_THREADS=$n
echo "[ansai-web] uid $(id -u), $(nproc) cores seen, cpu.max $(cat /sys/fs/cgroup/cpu.max 2>/dev/null), pids.max $(cat /sys/fs/cgroup/pids.max 2>/dev/null), llvmpipe threads $n"
rm -f /tmp/.X1-lock
Xvfb :1 -screen 0 1280x800x24 -dpi 96 +extension COMPOSITE +extension DAMAGE +extension GLX +extension RANDR +extension RENDER \
    +extension MIT-SHM +extension XFIXES +extension XTEST +iglx +render -nolisten tcp -ac -shmem &
for _ in $(seq 100); do xset q >/dev/null 2>&1 && break; sleep 0.1; done
(cd "$HOME" && exec bash /defaults/startwm.sh) &
selkies --addr=localhost &
exec node /opt/ansai-shell/docker/selkies/gate.mjs
