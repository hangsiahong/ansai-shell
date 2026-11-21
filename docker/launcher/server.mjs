#!/usr/bin/env node
// One ansai web desktop per visitor: starts a container from IMAGE for each new browser (cookie), proxies HTTP and
// WebSocket traffic to it, and removes it when idle. Desktops sit on an --internal Docker network: no internet.
//   node docker/launcher/server.mjs      env: HOST=0.0.0.0 PORT=8080 IMAGE=ansai-web-selkies MAX=4 IDLE_MIN=10 MAX_MIN=60
import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import http from "node:http";
import net from "node:net";

const PORT = +(process.env.PORT || 8080), IMAGE = process.env.IMAGE || "ansai-web-selkies";
const MAX = +(process.env.MAX || 4), IDLE = +(process.env.IDLE_MIN || 10) * 60e3, LIFE = +(process.env.MAX_MIN || 60) * 60e3;
const NET = "ansai-web", PREFIX = "ansai-desk-";
const sessions = new Map();   // id → { name, ip, ready, born, last, socks }

const docker = (...args) => new Promise((res, rej) => execFile("docker", args, { encoding: "utf8" }, (e, out, err) => e ? rej(new Error(err.trim() || e.message)) : res(out.trim())));
const cookie = req => /(?:^|;\s*)ansai_s=([a-f0-9]{24})/.exec(req.headers.cookie || "")?.[1];
const page = (res, code, title, body, refresh) => {
    res.writeHead(code, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
    res.end(`<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width">${refresh ? `<meta http-equiv=refresh content=${refresh}>` : ""}<title>ansai shell</title>
<body style="margin:0;height:100vh;display:grid;place-items:center;background:#15121b;color:#e9e0f0;font:16px system-ui,sans-serif;text-align:center">
<div><h2 style="font-weight:600;margin:0 0 8px">${title}</h2><p style="opacity:.7;margin:0">${body}</p></div>`);
};

async function start(id) {
    const name = PREFIX + id.slice(0, 12), s = { name, ip: "", ready: false, born: Date.now(), last: Date.now(), socks: 0 };
    sessions.set(id, s);
    try {
        await docker("run", "-d", "--rm", "--name", name, "--network", NET, "--shm-size", "1g", "--memory", "1200m", "--cpus", "1.5",
            "--pids-limit", "512", "--label", "ansai-desk=1", IMAGE);
        s.ip = await docker("inspect", "-f", `{{(index .NetworkSettings.Networks "${NET}").IPAddress}}`, name);
        for (let i = 0; i < 120 && sessions.get(id) === s; i++) {
            const ok = await new Promise(r => http.get({ host: s.ip, port: 3000, path: "/", timeout: 1000 }, x => { x.resume(); r(x.statusCode === 200); }).on("error", () => r(false)).on("timeout", function () { this.destroy(); r(false); }));
            if (ok) { s.ready = true; s.last = Date.now(); return; }
            await new Promise(r => setTimeout(r, 500));
        }
        throw new Error("desktop didn't start in time");
    } catch (e) {
        console.error(name, e.message);
        stop(id);
    }
}
function stop(id) {
    const s = sessions.get(id);
    if (!s) return;
    sessions.delete(id);
    docker("rm", "-f", s.name).catch(() => {});
}

const server = http.createServer(async (req, res) => {
    let id = cookie(req), s = id && sessions.get(id);
    if (!s) {
        if (req.url !== "/" && !req.url.startsWith("/?")) return page(res, 404, "Session ended", `<a style="color:#d0bcff" href="/">Start a new desktop</a>`);
        if (sessions.size >= MAX) return page(res, 503, "All desktops are in use", "Please wait, this page retries every 15 seconds.", 15);
        id = randomBytes(12).toString("hex");
        res.setHeader("set-cookie", `ansai_s=${id}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${LIFE / 1000}`);
        start(id);
        return page(res, 200, "Starting your desktop…", "This takes about 15 seconds.", 2);
    }
    if (!s.ready) return page(res, 200, "Starting your desktop…", "This takes about 15 seconds.", 2);
    s.last = Date.now();
    const up = http.request({ host: s.ip, port: 3000, method: req.method, path: req.url, headers: req.headers }, r => { res.writeHead(r.statusCode, r.headers); r.pipe(res); });
    up.on("error", () => { if (!res.headersSent) page(res, 502, "Desktop not reachable", `<a style="color:#d0bcff" href="/">Try again</a>`); else res.destroy(); });
    req.pipe(up);
});

server.on("upgrade", (req, sock, head) => {
    const s = sessions.get(cookie(req));
    if (!s?.ready) return sock.destroy();
    const up = net.connect(3000, s.ip, () => {
        up.write(`${req.method} ${req.url} HTTP/1.1\r\n` + Object.entries(req.headers).map(([k, v]) => `${k}: ${v}\r\n`).join("") + "\r\n");
        if (head?.length) up.write(head);
        sock.pipe(up).pipe(sock);
    });
    s.socks++;
    s.last = Date.now();
    const done = () => { if (!sock.counted) { sock.counted = true; s.socks--; s.last = Date.now(); } up.destroy(); sock.destroy(); };
    up.on("error", done); sock.on("error", done); up.on("close", done); sock.on("close", done);
});

setInterval(() => {
    const now = Date.now();
    for (const [id, s] of sessions) if (now - s.born > LIFE || (s.ready && !s.socks && now - s.last > IDLE)) { console.log("stop", s.name); stop(id); }
}, 30e3);

for (const sig of ["SIGINT", "SIGTERM"]) process.on(sig, async () => {
    await Promise.all([...sessions.values()].map(s => docker("rm", "-f", s.name).catch(() => {})));
    process.exit(0);
});

// Leftovers from an earlier run, and the private network.
const old = await docker("ps", "-aq", "--filter", "label=ansai-desk=1").catch(() => "");
if (old) await docker("rm", "-f", ...old.split("\n")).catch(() => {});
await docker("network", "inspect", NET).catch(() => docker("network", "create", "--internal", NET));
server.listen(PORT, process.env.HOST || "0.0.0.0", () => console.log(`ansai desktops on :${PORT} (image ${IMAGE}, max ${MAX})`));
