// Ask AI's agent, built on pi-mono (pi-agent-core's loop over pi-ai's OpenAI-compatible API) with the
// KOOMPI AI Gateway as provider. Desktop tools (files, commands, apps, windows, clipboard, screen) plus
// the tools of connected MCP servers (bridged through scripts/mcp.py serve, which owns OAuth tokens).
// Protocol with services/AI.qml, one JSON line each way:
//   stdin  first line {"model", "messages": [{role, content, image?}], "mcp": [urls]}; later lines answer
//          approvals: "y" runs the waiting tool, anything else declines it
//   stdout {"d": text} | {"tool": {id, name, title, server, args, ask}} | {"tool_done": {id, ok, preview}} | {"e": msg}
// Tools that change something wait for approval; looking things up runs right away.
// The key comes from ~/.config/ansai-shell/ai-key (or $ANSAI_AI_KEY) and is never printed.
import { Agent } from "@earendil-works/pi-agent-core";
import { createModels, createProvider } from "@earendil-works/pi-ai";
import { stream, streamSimple } from "@earendil-works/pi-ai/api/openai-completions";
import { execFile, spawn } from "node:child_process";
import { mkdtemp, readFile, readdir, rm, stat, writeFile, mkdir } from "node:fs/promises";
import { createInterface } from "node:readline";
import { homedir, tmpdir } from "node:os";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const MCP_PY = join(HERE, "..", "scripts", "mcp.py");
const CFG = join(process.env.XDG_CONFIG_HOME || join(homedir(), ".config"), "ansai-shell");
const BASE = process.env.ANSAI_AI_BASE || "https://ai.koompi.cloud/v1";
const MAX_TURNS = 20;
const OUT_CAP = 24000;

const out = o => process.stdout.write(JSON.stringify(o) + "\n");

// ---- stdin: the request, then approval answers
const lines = [], waiters = [];
const rl = createInterface({ input: process.stdin });
rl.on("line", l => (waiters.length ? waiters.shift()(l) : lines.push(l)));
rl.on("close", () => { while (waiters.length) waiters.shift()(null); });
const nextLine = () => (lines.length ? Promise.resolve(lines.shift()) : new Promise(r => waiters.push(r)));

// ---- helpers
const home = p => resolve(String(p || ".").replace(/^~(?=$|\/)/, homedir()));
const cap = (s, n = OUT_CAP) => (s.length > n ? s.slice(0, n) + `\n… (${s.length - n} more characters cut)` : s);
const text = t => ({ content: [{ type: "text", text: t || "(no output)" }], details: {} });
const IMG = { ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp", ".gif": "image/gif" };

function run(cmd, args, { input, timeout = 60000, cwd, signal } = {}) {
    return new Promise(res => {
        const p = execFile(cmd, args, { timeout, cwd, signal, maxBuffer: 16 << 20, encoding: "utf8" }, (err, stdout, stderr) =>
            res({ code: err ? (typeof err.code === "number" ? err.code : 1) : 0, stdout: stdout || "", stderr: stderr || (err && !stdout ? err.message : ""), killed: err?.killed }));
        if (input != null) { p.stdin.end(input); }
    });
}
const must = async (cmd, args, o) => {
    const r = await run(cmd, args, o);
    if (r.code) throw new Error((r.stderr || r.stdout).trim() || `${cmd} failed`);
    return r.stdout;
};
const niri = async (...a) => JSON.parse(await must("niri", ["msg", "-j", ...a]));

const obj = (props, required = Object.keys(props)) => ({ type: "object", properties: props, required });
const S = d => ({ type: "string", description: d });
const N = d => ({ type: "integer", description: d });

// ---- desktop tools. ask: needs approval; title: shown in the sidebar.
const desktop = [
    {
        name: "run_command", title: "Run a command", ask: true,
        description: "Run a shell command (bash) on the user's computer and get its output. Use for anything the other tools don't cover: system info, packages, git, network, processes.",
        parameters: obj({ command: S("bash command"), cwd: S("working directory, default home"), timeout: N("seconds, default 60") }, ["command"]),
        async run({ command, cwd, timeout }, signal) {
            const r = await run("bash", ["-lc", command], { cwd: home(cwd || "~"), timeout: (timeout || 60) * 1000, signal });
            const body = [r.stdout.trim(), r.stderr.trim() && "stderr:\n" + r.stderr.trim()].filter(Boolean).join("\n") || "(no output)";
            return { ...text(cap(`exit ${r.code}${r.killed ? " (timed out)" : ""}\n${body}`)), isError: r.code !== 0 };
        }
    },
    {
        name: "read_file", title: "Read a file",
        description: "Read a text file (or look at an image file). ~ is the home folder.",
        parameters: obj({ path: S("file path"), offset: N("first line, 1-based"), limit: N("number of lines") }, ["path"]),
        async run({ path, offset, limit }) {
            const p = home(path);
            if (IMG[extname(p).toLowerCase()]) {
                return { content: [{ type: "image", data: (await readFile(p)).toString("base64"), mimeType: IMG[extname(p).toLowerCase()] }], details: {} };
            }
            let s = await readFile(p, "utf8");
            if (offset || limit) s = s.split("\n").slice((offset || 1) - 1, (offset || 1) - 1 + (limit || 1e9)).join("\n");
            return text(cap(s));
        }
    },
    {
        name: "write_file", title: "Write a file", ask: true,
        description: "Create or overwrite a file with the given content. Folders are created as needed.",
        parameters: obj({ path: S("file path"), content: S("full file content") }),
        async run({ path, content }) {
            const p = home(path);
            await mkdir(dirname(p), { recursive: true });
            await writeFile(p, content);
            return text(`Wrote ${content.length} characters to ${p}`);
        }
    },
    {
        name: "edit_file", title: "Edit a file", ask: true,
        description: "Replace one exact, unique piece of text in a file. Read the file first.",
        parameters: obj({ path: S("file path"), old_text: S("exact text to replace, must appear once"), new_text: S("replacement") }),
        async run({ path, old_text, new_text }) {
            const p = home(path), s = await readFile(p, "utf8");
            const n = s.split(old_text).length - 1;
            if (n !== 1) throw new Error(n ? `old_text appears ${n} times; include more context` : "old_text not found");
            await writeFile(p, s.replace(old_text, () => new_text));
            return text(`Edited ${p}`);
        }
    },
    {
        name: "list_dir", title: "List a folder",
        description: "List a folder's entries (folders end with /).",
        parameters: obj({ path: S("folder path, default home") }, []),
        async run({ path }) {
            const p = home(path || "~");
            const es = await readdir(p, { withFileTypes: true });
            return text(cap(es.map(e => e.name + (e.isDirectory() ? "/" : "")).sort().join("\n") || "(empty)"));
        }
    },
    {
        name: "search_files", title: "Search files",
        description: "Find files by name (glob-free substring or regex), or with contains=true search inside files for text. Skips hidden and ignored files.",
        parameters: obj({ query: S("name pattern or text to find"), path: S("where to look, default home"), contains: { type: "boolean", description: "search file contents instead of names" } }, ["query"]),
        async run({ query, path, contains }, signal) {
            const where = home(path || "~");
            const r = contains
                ? await run("rg", ["-n", "--max-count", "5", "--max-columns", "200", "-S", query, where], { signal, timeout: 30000 })
                : await run("fd", ["--max-results", "200", query, where], { signal, timeout: 30000 });
            return text(cap(r.stdout.trim() || (r.code > 1 ? r.stderr : "No matches")));
        }
    },
    {
        name: "open", title: "Open",
        description: "Open a file, folder or URL with the user's default app.",
        parameters: obj({ target: S("path or URL") }),
        async run({ target }) {
            const t = /^[a-z]+:\/\//i.test(target) ? target : home(target);
            spawn("xdg-open", [t], { detached: true, stdio: "ignore" }).unref();
            return text(`Opened ${t}`);
        }
    },
    {
        name: "installed_apps", title: "Find apps",
        description: "List apps installed on this computer (desktop entries) whose name matches the query; gives ids for launch_app. Not for cloud apps.",
        parameters: obj({ query: S("part of the app name, empty for all") }, []),
        async run({ query }) {
            return text(cap((await apps()).filter(a => !query || (a.name + " " + a.id).toLowerCase().includes(query.toLowerCase()))
                .map(a => `${a.id}: ${a.name}`).join("\n") || "No apps match"));
        }
    },
    {
        name: "launch_app", title: "Open an app",
        description: "Start an app installed on this computer by its id or name (e.g. firefox, org.gnome.Nautilus, Files).",
        parameters: obj({ app: S("app id or name") }),
        async run({ app }) {
            const all = await apps(), q = app.toLowerCase().replace(/\.desktop$/, "");
            const a = all.find(x => x.id.toLowerCase() === q) || all.find(x => x.name.toLowerCase() === q)
                || all.find(x => (x.name + " " + x.id).toLowerCase().includes(q));
            if (!a) throw new Error(`No installed app matches "${app}"`);
            await must("niri", ["msg", "action", "spawn", "--", "gtk-launch", a.id]);
            return text(`Started ${a.name}`);
        }
    },
    {
        name: "list_windows", title: "List windows",
        description: "List open windows (id, app, title, workspace, focused) and workspaces.",
        parameters: obj({}),
        async run() {
            const [ws, wins] = await Promise.all([niri("workspaces"), niri("windows")]);
            const wsName = id => { const w = ws.find(x => x.id === id); return w ? `${w.output}:${w.name || w.idx}` : "?"; };
            return text(wins.map(w => `${w.id}\t${w.app_id}\t${w.title}\tworkspace ${wsName(w.workspace_id)}${w.is_focused ? "\t(focused)" : ""}`).join("\n")
                + "\n\nworkspaces: " + ws.map(w => `${w.output}:${w.name || w.idx}${w.is_focused ? " (focused)" : ""}`).join(", "));
        }
    },
    {
        name: "focus_window", title: "Switch to a window",
        description: "Bring a window to the front by its id from list_windows.",
        parameters: obj({ id: N("window id") }),
        async run({ id }) { await must("niri", ["msg", "action", "focus-window", "--id", String(id)]); return text("Focused"); }
    },
    {
        name: "window_action", title: "Change windows", ask: true,
        description: "Run a niri action, e.g. close-window --id N, move-window-to-workspace 2, fullscreen-window, focus-workspace 3, set-column-width 50%. See `niri msg action --help`.",
        parameters: obj({ action: S("niri action name"), args: { type: "array", items: { type: "string" }, description: "its arguments" } }, ["action"]),
        async run({ action, args }) {
            if (/^(quit|power-off-monitors|spawn)/.test(action)) throw new Error(`${action} isn't allowed here`);
            await must("niri", ["msg", "action", action, ...(args || [])]);
            return text("Done");
        }
    },
    {
        name: "read_clipboard", title: "Read the clipboard",
        description: "Get the text currently on the clipboard.",
        parameters: obj({}),
        async run() { const r = await run("wl-paste", ["-n", "-t", "text"]); return text(cap(r.stdout || "(clipboard is empty or not text)")); }
    },
    {
        name: "copy_to_clipboard", title: "Copy to clipboard", ask: true,
        description: "Put text on the clipboard.",
        parameters: obj({ text: S("text to copy") }),
        async run({ text: t }) { await must("wl-copy", ["--", t]); return text("Copied"); }
    },
    {
        name: "screenshot", title: "Look at the screen",
        description: "Take a screenshot of the whole screen and look at it.",
        parameters: obj({}),
        async run() {
            const d = await mkdtemp(join(tmpdir(), "ansai-shot-")), f = join(d, "s.png");
            try {
                await must("grim", ["-s", "0.6", f]);
                return { content: [{ type: "image", data: (await readFile(f)).toString("base64"), mimeType: "image/png" }], details: {} };
            } finally { rm(d, { recursive: true, force: true }); }
        }
    },
    {
        name: "fetch_url", title: "Read a web page",
        description: "Download a web page or API URL and get its text (HTML is reduced to plain text).",
        parameters: obj({ url: S("http(s) URL") }),
        async run({ url }, signal) {
            const r = await fetch(url, { signal, headers: { "User-Agent": "ansai-shell" }, redirect: "follow" });
            let s = await r.text();
            if ((r.headers.get("content-type") || "").includes("html")) {
                s = s.replace(/<(script|style|noscript|svg)[\s\S]*?<\/\1>/gi, " ").replace(/<br\s*\/?>|<\/(p|div|li|h\d|tr)>/gi, "\n")
                    .replace(/<[^>]+>/g, " ").replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
                    .replace(/[ \t]+/g, " ").replace(/\n\s*\n+/g, "\n\n").trim();
            }
            return { ...text(cap(`${r.status} ${url}\n\n${s}`, 16000)), isError: !r.ok };
        }
    },
];

let appCache;
async function apps() {
    if (appCache) return appCache;
    const dirs = [join(homedir(), ".local/share"), ...(process.env.XDG_DATA_DIRS || "/usr/local/share:/usr/share").split(":"), "/var/lib/flatpak/exports/share"];
    const seen = new Map();
    for (const d of dirs) {
        let es = [];
        try { es = await readdir(join(d, "applications")); } catch { continue; }
        for (const e of es) {
            if (!e.endsWith(".desktop") || seen.has(e)) continue;
            try {
                const s = await readFile(join(d, "applications", e), "utf8");
                const main = s.split(/^\[/m).find(x => x.startsWith("Desktop Entry]")) || "";
                if (/^(NoDisplay|Hidden)=true/m.test(main)) { seen.set(e, null); continue; }
                seen.set(e, { id: e.slice(0, -8), name: (main.match(/^Name=(.*)$/m) || [])[1] || e });
            } catch { /* unreadable entry */ }
        }
    }
    return (appCache = [...seen.values()].filter(Boolean).sort((a, b) => a.name.localeCompare(b.name)));
}

// ---- MCP bridge: one python process, sessions kept across calls
let bridge, bridgeN = 0;
const pending = new Map();
function mcp(op, payload) {
    if (!bridge) {
        bridge = spawn("python3", [MCP_PY, "serve"], { stdio: ["pipe", "pipe", "inherit"] });
        createInterface({ input: bridge.stdout }).on("line", l => {
            let m; try { m = JSON.parse(l); } catch { return; }
            const p = pending.get(m.id);
            if (!p) return;
            pending.delete(m.id);
            m.e != null ? p.reject(Object.assign(new Error(m.e), { auth: m.auth })) : p.resolve(m.ok);
        });
        bridge.on("exit", () => { for (const p of pending.values()) p.reject(new Error("MCP bridge stopped")); pending.clear(); bridge = null; });
    }
    const id = ++bridgeN;
    return new Promise((res, rej) => { pending.set(id, { resolve: res, reject: rej }); bridge.stdin.write(JSON.stringify({ id, op, ...payload }) + "\n"); });
}

// Tool schemas go out on every step: drop what the model doesn't need (89 tools ≈ 120 KB → ~70 KB).
const slim = s => Array.isArray(s) ? s.map(slim) : s && typeof s === "object"
    ? Object.fromEntries(Object.entries(s).filter(([k]) => !["examples", "$schema", "title", "additionalProperties"].includes(k))
        .map(([k, v]) => [k, k === "description" && typeof v === "string" ? v.slice(0, 120) : slim(v)]))
    : s;

async function mcpTools(urls, taken) {
    const tools = [];
    await Promise.all(urls.map(async (url, i) => {
        let list;
        try { list = await mcp("tools", { url }); } catch (err) { if (!err.auth) out({ e: `${new URL(url).host}: ${err.message}` }); return; }
        for (const t of list) {
            const ann = t.annotations || {}, title = ann.title || t.title || "";
            const desc = (t.description || "").slice(0, 300);
            const clean = n => n.replace(/[^a-zA-Z0-9_-]/g, "_").slice(0, 64);
            let name = clean(urls.length > 1 ? `s${i}_${t.name}` : t.name);
            if (taken.has(name)) name = clean(`s${i}_${t.name}`);
            taken.add(name);
            tools.push({
                name,
                mcpName: t.name, title, server: new URL(url).host, ask: !ann.readOnlyHint,
                description: (title && !desc.toLowerCase().includes(title.toLowerCase()) ? title + ": " : "") + desc,
                parameters: slim(t.inputSchema || { type: "object", properties: {} }),
                async run(args) {
                    const r = String(await mcp("call", { url, name: t.name, args }));
                    return { ...text(cap(r)), isError: r.startsWith("Error: ") };
                }
            });
        }
    }));
    return tools;
}

// ---- main
async function main() {
    let key = (process.env.ANSAI_AI_KEY || "").trim();
    if (!key) {
        try { key = (await readFile(join(CFG, "ai-key"), "utf8")).trim(); } catch { /* no key */ }
    }
    if (!key) return out({ e: `No AI key. Paste one in Settings → AI (saved to ${join(CFG, "ai-key")}).` });
    const req = JSON.parse(await nextLine());

    const modelId = req.model || "koompi-luna";
    const model = {
        id: modelId, name: modelId, api: "openai-completions", provider: "koompi", baseUrl: BASE,
        reasoning: false, input: ["text", "image"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 128000, maxTokens: 8192,
        compat: { supportsDeveloperRole: false, supportsStore: false, supportsReasoningEffort: false, maxTokensField: "max_tokens" },
    };
    const models = createModels();
    models.setProvider(createProvider({
        id: "koompi", name: "KOOMPI AI Gateway", baseUrl: BASE, models: [model],
        auth: { apiKey: { name: "KOOMPI AI key", resolve: async () => ({ auth: { apiKey: key }, source: "ai-key" }) } },
        api: { stream, streamSimple },
    }));

    // The conversation: system messages become the prompt; only the newest image is sent.
    const system = req.messages.filter(m => m.role === "system").map(m => m.content).join("\n\n");
    const convo = req.messages.filter(m => m.role !== "system");
    const zero = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
    const toMsg = async m => {
        if (m.role === "assistant") return { role: "assistant", content: [{ type: "text", text: m.content || "" }], api: "openai-completions", provider: "koompi", model: modelId, usage: zero, stopReason: "stop", timestamp: Date.now() };
        if (!m.image) return { role: "user", content: m.content || "", timestamp: Date.now() };
        const data = (await readFile(m.image)).toString("base64");
        return { role: "user", content: [{ type: "text", text: m.content || "Describe this image." }, { type: "image", data, mimeType: IMG[extname(m.image).toLowerCase()] || "image/png" }], timestamp: Date.now() };
    };
    let msgs;
    try { msgs = await Promise.all(convo.map(toMsg)); } catch (err) { return out({ e: `Couldn't read the image: ${err.message}` }); }
    const last = msgs.pop();

    const local = req.tools === false ? [] : desktop.map(t => ({ ...t, server: "this computer" }));
    const defs = [...local, ...await mcpTools(req.mcp || [], new Set(local.map(t => t.name)))];
    const byName = new Map(defs.map(t => [t.name, t]));
    const tools = defs.map(t => ({
        name: t.name, label: t.title || t.name, description: t.description, parameters: t.parameters, executionMode: "sequential",
        execute: async (_id, args, signal) => t.run(args || {}, signal),
    }));

    const agent = new Agent({
        initialState: { systemPrompt: system, model, tools, messages: msgs },
        streamFn: models.streamSimple.bind(models),
        toolExecution: "sequential",
        identity: { attribution: null },
    });
    const declined = new Set();
    agent.beforeToolCall = async ({ toolCall, args }) => {
        const t = byName.get(toolCall.name);
        out({ tool: { id: toolCall.id, name: t?.mcpName || toolCall.name, title: t?.title || "", server: t?.server || "", args, ask: !!t?.ask } });
        if (!t?.ask) return undefined;
        if ((await nextLine())?.trim() === "y") return undefined;
        declined.add(toolCall.id);
        out({ tool_done: { id: toolCall.id, ok: false, preview: "Declined" } });
        return { block: true, reason: "The user declined this action. Don't retry it; ask them what to do instead." };
    };

    let turns = 0, wrote = false, failed = "";
    agent.subscribe(ev => {
        if (ev.type === "message_update" && ev.assistantMessageEvent.type === "text_delta") {
            out({ d: ev.assistantMessageEvent.delta });
            wrote = true;
        } else if (ev.type === "tool_execution_end" && !declined.has(ev.toolCallId)) {
            const r = ev.result?.content?.map(c => c.type === "text" ? c.text : `[${c.type}]`).join("\n") || "";
            out({ tool_done: { id: ev.toolCallId, ok: !ev.isError, preview: r.slice(0, 300) } });
        } else if (ev.type === "message_end" && ev.message.role === "assistant" && ev.message.stopReason === "error") {
            failed = ev.message.errorMessage || "AI request failed";
        } else if (ev.type === "turn_end") {
            if (wrote && ev.toolResults?.length) { out({ d: "\n\n" }); wrote = false; }
            if (++turns >= MAX_TURNS && ev.toolResults?.length) { failed = "Stopped after too many tool steps"; agent.abort(); }
        }
    });

    await agent.prompt(last);
    if (failed) out({ e: /401|unauthori[sz]ed/i.test(failed) ? `${failed} — check the key in Settings → AI` : failed });
}

main().catch(err => out({ e: String(err?.message || err) })).finally(() => { bridge?.stdin.end(); rl.close(); process.stdin.destroy(); });
