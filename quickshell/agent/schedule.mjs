#!/usr/bin/env node
// Ask Ansai scheduled tasks: systemd user timers that run a prompt through ansai-agent.js with nobody watching.
// The shell owns ai-schedules.json ({ system, mcp, tasks: [{ id, name, prompt, kind, time, day, cron, model, account, act, on }] });
// each run writes ai-runs/<id>-<time>.json, which the shell imports as a chat (ipc `ai scheduled`) and then deletes.
//   node schedule.mjs sync          write/enable/remove the ansai-task-* units; prints {id: {next, e}}
//   node schedule.mjs check <json>  {kind, time, day, cron} → {cal, next} or {e}
//   node schedule.mjs run <id>      run one task now (what the timer starts)
import { execFile, spawn } from "node:child_process";
import { mkdir, readFile, readdir, rm, writeFile, rename } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const DATA = join(process.env.XDG_DATA_HOME || join(homedir(), ".local/share"), "ansai-shell");
const FILE = join(DATA, "ai-schedules.json");
const RUNS = join(DATA, "ai-runs");
const UNITS = join(process.env.XDG_CONFIG_HOME || join(homedir(), ".config"), "systemd/user");
const AGENT = join(dirname(fileURLToPath(import.meta.url)), "ansai-agent.js");
const SELF = fileURLToPath(import.meta.url);
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

const sh = (cmd, args) => new Promise(res => execFile(cmd, args, { encoding: "utf8", timeout: 20000 }, (err, stdout, stderr) =>
    res({ code: err ? (typeof err.code === "number" ? err.code : 1) : 0, out: stdout || "", err: stderr || "" })));
const print = o => process.stdout.write(JSON.stringify(o) + "\n");
const load = async () => JSON.parse(await readFile(FILE, "utf8"));
const unit = id => `ansai-task-${String(id).replace(/[^A-Za-z0-9_-]/g, "")}`;

// 5-field cron → systemd OnCalendar; anything else is taken as an OnCalendar expression.
function fromCron(c) {
    const f = c.trim().split(/\s+/);
    if (f.length !== 5 || !f.every(x => /^[\d*,\/-]+$/.test(x))) return c.trim();
    const conv = (x, start) => x.split(",").map(p => p.replace(/^\*\/(\d+)$/, `${start}/$1`).replace(/^(\d+)-(\d+)$/, "$1..$2")).join(",");
    const [m, h, dom, mon, dow] = f;
    const days = dow === "*" ? "" : dow.split(",").map(p => p.replace(/\d+/g, d => DAYS[+d] ?? d).replace("-", "..")).join(",") + " ";
    return `${days}*-${conv(mon, 1)}-${conv(dom, 1)} ${conv(h, 0)}:${conv(m, 0)}:00`;
}
function calendar(t) {
    const at = /^\d{1,2}:\d{2}$/.test(t.time ?? "") ? t.time : "08:00";
    switch (t.kind) {
        case "hourly": return "*-*-* *:00:00";
        case "daily": return `*-*-* ${at}:00`;
        case "weekdays": return `Mon..Fri *-*-* ${at}:00`;
        case "weekly": return `${t.day || "Mon"} *-*-* ${at}:00`;
        default: return fromCron(t.cron || "");
    }
}
async function check(t) {
    const cal = calendar(t);
    if (!cal) return { e: "Write a schedule" };
    const r = await sh("systemd-analyze", ["calendar", "--iterations=1", cal]);
    const next = /Next elapse:\s*(.+)/.exec(r.out)?.[1]?.trim();
    const utc = /\(in UTC\):\s*\w+ (\S+) (\S+) UTC/.exec(r.out);
    return r.code || !next ? { e: (r.err.trim().split("\n").pop() || "Not a valid schedule") } : { cal, next, at: utc ? Date.parse(`${utc[1]}T${utc[2]}Z`) : 0 };
}

async function sync() {
    let s = { tasks: [] };
    try { s = await load(); } catch { /* none yet */ }
    await mkdir(UNITS, { recursive: true });
    const node = process.execPath, want = new Set(), res = {};
    for (const t of s.tasks ?? []) {
        const u = unit(t.id), c = await check(t);
        want.add(u);
        res[t.id] = c;
        await writeFile(join(UNITS, u + ".service"), `# Written by Ask Ansai (Scheduled); edits are replaced.
[Unit]
Description=Ask Ansai: ${String(t.name || "task").replace(/\n/g, " ")}

[Service]
Type=oneshot
ExecStart="${node}" "${SELF}" run ${t.id}
TimeoutStartSec=45min
`);
        if (c.cal) await writeFile(join(UNITS, u + ".timer"), `# Written by Ask Ansai (Scheduled); edits are replaced.
[Unit]
Description=Ask Ansai: ${String(t.name || "task").replace(/\n/g, " ")}

[Timer]
OnCalendar=${c.cal}
Persistent=true

[Install]
WantedBy=timers.target
`);
    }
    const old = (await readdir(UNITS)).filter(f => /^ansai-task-.*\.(service|timer)$/.test(f));
    const gone = [...new Set(old.map(f => f.replace(/\.(service|timer)$/, "")))].filter(u => !want.has(u));
    if (gone.length) await sh("systemctl", ["--user", "disable", "--now", ...gone.map(u => u + ".timer")]);
    for (const f of old) if (gone.includes(f.replace(/\.(service|timer)$/, ""))) await rm(join(UNITS, f), { force: true });
    await sh("systemctl", ["--user", "daemon-reload"]);
    const on = (s.tasks ?? []).filter(t => t.on && res[t.id].cal).map(t => unit(t.id) + ".timer");
    const off = (s.tasks ?? []).filter(t => !(t.on && res[t.id].cal)).map(t => unit(t.id) + ".timer");
    if (on.length) await sh("systemctl", ["--user", "enable", "--now", ...on]);
    if (off.length) await sh("systemctl", ["--user", "disable", "--now", ...off]);
    print(res);
}

async function run(id) {
    const s = await load();
    const t = (s.tasks ?? []).find(x => x.id === id);
    if (!t) throw new Error(`No scheduled task ${id}`);
    await mkdir(RUNS, { recursive: true, mode: 0o700 });
    const started = Date.now(), now = new Date();
    const today = now.toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric" });
    const system = String(s.system || "").replaceAll("{{today}}", today) + `

This is a scheduled task ("${t.name}") the user set up earlier; it runs on its own at ${now.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" })} and nobody is watching.
- Do the task, then write the result for the user to read later: what you found or did, first line the headline.
` + (t.act ? `- The user allowed this task to act without asking: actions run right away. Do only what the task asks.`
           : `- Actions that change things are declined automatically. Don't retry them: say what you would have done, so the user can do it or allow it.`);
    const body = { model: t.model, account: t.account ?? "", messages: [{ role: "system", content: system }, { role: "user", content: t.prompt }], mcp: s.mcp ?? [], tools: true, learn: false };
    const msg = { role: "assistant", content: "", reasoning: "", tools: [] };
    let err = "";
    const p = spawn(process.execPath, [AGENT], { stdio: ["pipe", "pipe", "pipe"] });
    p.stdin.write(JSON.stringify(body) + "\n");
    let buf = "", errText = "";
    p.stderr.on("data", d => { errText += d; });
    p.stdout.on("data", d => {
        buf += d;
        let i;
        while ((i = buf.indexOf("\n")) >= 0) {
            const line = buf.slice(0, i);
            buf = buf.slice(i + 1);
            let ev;
            try { ev = JSON.parse(line); } catch { continue; }
            if (ev.e) err = ev.e;
            else if (ev.d) msg.content += ev.d;
            else if (ev.t !== undefined) msg.reasoning += ev.t;
            else if (ev.tool) {
                if (ev.tool.ask) p.stdin.write(t.act ? "y\n" : "n\n");
                msg.tools.push({ ...ev.tool, status: "run", auto: !!(ev.tool.ask && t.act) });
            } else if (ev.tool_done) {
                const k = msg.tools.findIndex(x => x.id === ev.tool_done.id);
                if (k >= 0) msg.tools[k] = { ...msg.tools[k], status: ev.tool_done.preview === "Declined" ? "declined" : ev.tool_done.ok ? "ok" : "fail", preview: ev.tool_done.preview };
            }
        }
    });
    const code = await new Promise(r => p.on("close", r));
    if (!err && code) err = errText.trim().split("\n").pop() || "AI request failed";
    if (!err && !msg.content.trim()) err = "No answer came back";
    msg.tools = msg.tools.map(x => x.status === "run" ? { ...x, status: "fail", preview: "Stopped" } : x);
    if (err) { msg.content = msg.content ? msg.content + "\n\n" + err : err; msg.error = !msg.content.trim() || msg.content === err; }
    if (!msg.reasoning) delete msg.reasoning;
    const file = join(RUNS, `${t.id}-${started}.json`);
    await writeFile(file + ".tmp", JSON.stringify({ task: t.id, name: t.name, prompt: t.prompt, started, ended: Date.now(), ok: !err, message: msg }), { mode: 0o600 });
    await rename(file + ".tmp", file);
    // The shell imports it and says so; when the shell isn't running, a plain notification (imported at its next start).
    const r = await sh("qs", ["-c", "ansai", "ipc", "call", "ai", "scheduled", file]);
    if (r.code) await sh("notify-send", ["-a", "Ask Ansai", "-i", "alarm", `⏰ ${t.name}`, (err || msg.content).split("\n").find(l => l.trim())?.slice(0, 200) || "Done"]);
    if (err) process.exitCode = 1;
}

const [cmd, arg] = process.argv.slice(2);
(cmd === "sync" ? sync() : cmd === "check" ? check(JSON.parse(arg || "{}")).then(print) : cmd === "run" ? run(arg) : Promise.reject(new Error("usage: sync | check <json> | run <id>")))
    .catch(e => { print({ e: String(e?.message || e) }); process.exitCode = 1; });
