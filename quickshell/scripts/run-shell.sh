#!/bin/sh
# Starts the shell from niri and starts it again if it dies (e.g. killed when memory runs out). A dead shell
# leaves the screen black, or locked with no password box, so after a crash it comes back on the lock screen.
# Every 15 minutes the shell's memory goes to ~/.local/state/ansai-shell/memory.log, to catch slow growth.
dir=${XDG_STATE_HOME:-$HOME/.local/state}/ansai-shell
log=$dir/memory.log
mkdir -p "$dir"
note() { echo "$(date '+%F %T') $*" >> "$log"; }

crashed=0 quick=0
while :; do
    began=$(date +%s)
    qs -c ansai &
    pid=$!
    if [ $crashed -eq 1 ]; then
        # The session may still be locked by the shell that died: show the password box again.
        for _ in $(seq 60); do qs -c ansai ipc call lock lock >/dev/null 2>&1 && break; sleep 0.25; done
    fi
    (
        while sleep "${ANSAI_MEM_EVERY:-900}"; do
            awk -v t="$(date '+%F %T')" '/^VmRSS/{r=$2} /^VmSwap/{s=$2} END{printf "%s rss=%dMB swap=%dMB\n", t, r/1024, s/1024}' /proc/$pid/status >> "$log" 2>/dev/null || exit
            [ "$(wc -l < "$log")" -gt 4000 ] && tail -n 2000 "$log" > "$log.tmp" && mv "$log.tmp" "$log"
        done
    ) &
    mon=$!
    wait $pid
    rc=$?
    kill $mon 2>/dev/null
    note "shell exited (code $rc)"
    [ $rc -eq 0 ] && exit 0                       # quit on purpose
    niri msg version >/dev/null 2>&1 || exit 0    # the session is over
    if [ $(( $(date +%s) - began )) -lt 20 ]; then quick=$((quick + 1)); else quick=0; fi
    [ $quick -ge 5 ] && { note "shell keeps failing at start; not restarting"; exit 1; }
    crashed=1
    sleep 1
    note "restarting the shell"
done
