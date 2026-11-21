#!/usr/bin/env python3
# Process list for the shell's process viewer (modules/Processes.qml): one JSON line every 2 s while it runs.
# Per process: CPU % (of one core), RAM and swap (KiB), integrated GPU % and VRAM from DRM fdinfo, and
# whether it holds the NVIDIA GPU open (keeps the dGPU awake). nvidia-smi is never run: it would wake the dGPU.
import json, os, sys, time

HZ = os.sysconf("SC_CLK_TCK")
ME = os.getuid()
EVERY = float(sys.argv[1]) if len(sys.argv) > 1 else 2.0
prev_cpu, prev_gpu, prev_t = {}, {}, None


def read(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8", "replace")
    except OSError:
        return ""


def sample():
    global prev_cpu, prev_gpu, prev_t
    now = time.monotonic()
    dt = (now - prev_t) if prev_t else None
    cpu, gpu, out = {}, {}, []
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        pid = int(d)
        stat = read(f"/proc/{pid}/stat")
        if not stat:
            continue
        r = stat.rfind(")")
        name = stat[stat.find("(") + 1:r]
        f = stat[r + 2:].split()
        ppid, ticks = int(f[1]), int(f[11]) + int(f[12])
        cpu[pid] = ticks
        rss = swap = 0
        uid = -1
        for line in read(f"/proc/{pid}/status").splitlines():
            if line.startswith("VmRSS:"): rss = int(line.split()[1])
            elif line.startswith("VmSwap:"): swap = int(line.split()[1])
            elif line.startswith("Uid:"): uid = int(line.split()[1])
        if rss == 0 and swap == 0:
            continue  # kernel threads
        # GPU: DRM fds (fdinfo engine time, deduplicated per client) and NVIDIA device nodes.
        eng, vram, nv, seen = 0, 0, False, set()
        try:
            fds = os.listdir(f"/proc/{pid}/fd")
        except OSError:
            fds = []
        for fd in fds:
            try:
                link = os.readlink(f"/proc/{pid}/fd/{fd}")
            except OSError:
                continue
            if link.startswith("/dev/nvidia") and link[11:12].isdigit():
                nv = True
            elif link.startswith("/dev/dri/"):
                info = read(f"/proc/{pid}/fdinfo/{fd}")
                kv = dict(l.split(":", 1) for l in info.splitlines() if ":" in l)
                cid = kv.get("drm-client-id", "").strip()
                if not cid or cid in seen:
                    continue
                seen.add(cid)
                for k, v in kv.items():
                    if k.startswith("drm-engine-") and not k.startswith("drm-engine-capacity"):
                        eng += int(v.split()[0])
                vram += int((kv.get("drm-memory-vram") or "0 KiB").split()[0])
        gpu[pid] = eng
        c = g = 0.0
        if dt:
            if pid in prev_cpu: c = (ticks - prev_cpu[pid]) / HZ / dt * 100
            if pid in prev_gpu and eng: g = (eng - prev_gpu[pid]) / 1e9 / dt * 100
        args = read(f"/proc/{pid}/cmdline").replace("\0", " ").strip()
        out.append({"pid": pid, "ppid": ppid, "name": name, "cmd": args[:160], "mine": uid == ME,
                    "cpu": round(max(c, 0), 1), "rss": rss, "swap": swap, "gpu": round(min(max(g, 0), 100), 1),
                    "vram": vram, "nv": nv})
    prev_cpu, prev_gpu, prev_t = cpu, gpu, now
    return out


sample()
time.sleep(min(EVERY, 1.0))
while True:
    print(json.dumps(sample(), separators=(",", ":")), flush=True)
    time.sleep(EVERY)
