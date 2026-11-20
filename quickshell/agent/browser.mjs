// The user's own Brave (or Chrome/Chromium) over the DevTools protocol, for the browser_* tools.
// Brave asks "Allow remote debugging?" for every new connection, so one helper process (`ansai-agent.js browserd`)
// keeps a single connection open on $XDG_RUNTIME_DIR/ansai-browser.sock: Allow once per browser start.
// Needs brave://inspect/#remote-debugging turned on. Page reading and id actions follow browser-use-pi's ax.ts
// (MIT, github.com/browser-use/browser-use-pi): accessibility tree as [backendNodeId] lines, coverage-checked clicks.
import { spawn } from "node:child_process";
import { createConnection, createServer } from "node:net";
import { readFile, stat, unlink } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

const SOCK = join(process.env.XDG_RUNTIME_DIR || "/tmp", "ansai-browser.sock");
const CFGD = process.env.XDG_CONFIG_HOME || join(homedir(), ".config");
const PROFILES = ["BraveSoftware/Brave-Origin", "BraveSoftware/Brave-Browser", "BraveSoftware/Brave-Browser-Beta", "BraveSoftware/Brave-Browser-Nightly",
    "google-chrome", "google-chrome-beta", "google-chrome-unstable", "chromium", "vivaldi", "microsoft-edge"];
const sleep = ms => new Promise(r => setTimeout(r, ms));
const gone = e => ["ENOENT", "ECONNREFUSED"].includes(e?.code);

// ---- client (inside the agent)
function ask(op, args) {
    return new Promise((res, rej) => {
        const c = createConnection(SOCK);
        let buf = "";
        const t = setTimeout(() => { c.destroy(); rej(new Error("The browser didn't answer in time")); }, 150000);
        c.on("connect", () => c.write(JSON.stringify({ op, args }) + "\n"));
        c.on("data", d => {
            buf += d;
            const i = buf.indexOf("\n");
            if (i < 0) return;
            clearTimeout(t);
            c.end();
            const m = JSON.parse(buf.slice(0, i));
            m.e != null ? rej(new Error(m.e)) : res(m.ok);
        });
        c.on("error", e => { clearTimeout(t); rej(e); });
    });
}
export async function browser(op, args = {}) {
    try { return await ask(op, args); } catch (e) { if (!gone(e)) throw e; }
    spawn(process.execPath, [process.argv[1], "browserd"], { detached: true, stdio: "ignore" }).unref();
    for (let i = 0; ; i++) {
        await sleep(100);
        try { return await ask(op, args); } catch (e) { if (!gone(e) || i > 40) throw e; }
    }
}

// ---- helper process
const norm = s => String(s ?? "").replace(/\s+/g, " ").trim();
const clip = (s, n) => (s.length > n ? s.slice(0, n) + "…" : s);
const prop = (n, k) => n.properties?.find(p => p.name === k)?.value.value;
const LOST = /Execution context was destroyed|Cannot find context|Cannot find default execution context|Inspected target navigated|Target closed|No frame|Could not find node/;
const CONTROLS = new Set("button link textbox searchbox combobox listbox option checkbox radio switch slider spinbutton tab menuitem menuitemcheckbox menuitemradio treeitem".split(" "));
const BLOCKS = new Set(["paragraph", "listitem", "row", "LabelText"]);
const NATIVE = new Set(["Date", "DateTime", "InputTime"]);

async function findBrowser() {
    let best = null;
    for (const p of PROFILES) {
        const f = join(CFGD, p, "DevToolsActivePort");
        try {
            const [port, path] = (await readFile(f, "utf8")).split("\n");
            const t = (await stat(f)).mtimeMs;
            const up = await new Promise(r => { const c = createConnection(Number(port), "127.0.0.1"); c.on("connect", () => { c.destroy(); r(true); }); c.on("error", () => r(false)); });
            if (up && (!best || t > best.t)) best = { port: Number(port), path: path.trim(), name: p.split("/").pop().replace(/-/g, " "), t };
        } catch { /* not this browser */ }
    }
    return best;
}

let conn = null, connecting = null;
async function connect() {
    if (conn) return conn;
    return connecting ||= (async () => {
        const b = await findBrowser();
        if (!b) throw new Error("No browser to control: in Brave open brave://inspect/#remote-debugging and turn on remote debugging (Chrome: chrome://inspect). Until then use desktop_read.");
        const ws = new WebSocket(`ws://127.0.0.1:${b.port}${b.path}`);
        const waits = new Map();
        let seq = 0;
        const c = {
            ws, name: b.name, sessions: new Map(), opened: new Set(), cur: "",
            send(method, params = {}, sessionId, ms = 30000) {
                if (ws.readyState !== 1) return Promise.reject(new Error("The browser connection closed"));
                return new Promise((res, rej) => {
                    const id = ++seq;
                    const t = setTimeout(() => { waits.delete(id); rej(new Error(`${method} timed out`)); }, ms);
                    waits.set(id, { res: v => { clearTimeout(t); res(v); }, rej: e => { clearTimeout(t); rej(e); } });
                    ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
                });
            },
        };
        ws.onmessage = ev => {
            const m = JSON.parse(ev.data);
            if (m.id) { const w = waits.get(m.id); waits.delete(m.id); w && (m.error ? w.rej(new Error(m.error.message)) : w.res(m.result)); return; }
            onEvent(c, m.method, m.params || {}, m.sessionId);
        };
        await new Promise((res, rej) => {
            ws.onopen = res;
            ws.onerror = () => rej(new Error(`Couldn't connect to ${b.name}`));
        });
        ws.onclose = () => { if (conn === c) conn = null; for (const w of waits.values()) w.rej(new Error("The browser connection closed (Allow not clicked, or the browser quit)")); waits.clear(); };
        // Commands wait until the user answers the browser's Allow prompt.
        c.ready = c.send("Target.getTargets", {}, undefined, 600000);
        c.ready.catch(() => {});
        conn = c;
        return c;
    })().finally(() => { connecting = null; });
}
async function ready() {
    const c = await connect();
    const r = await Promise.race([c.ready, sleep(45000).then(() => null)]);
    if (!r) throw new Error(`${c.name} is asking “Allow remote debugging?”. Click Allow there (once per browser start), then try again.`);
    return c;
}

function onEvent(c, method, p, sid) {
    if (method === "Target.detachedFromTarget") { for (const [k, s] of c.sessions) if (s.id === p.sessionId) c.sessions.delete(k); return; }
    const s = [...c.sessions.values()].find(x => x.id === sid);
    if (!s) return;
    if (method === "Page.javascriptDialogOpening") {
        // Accept dialogs our own action opened (they block the page); leave the user's alone and report them.
        if (Date.now() < s.acting) {
            s.dialogs.push(`[dialog ${p.type}] ${JSON.stringify(clip(p.message || "", 300))} (accepted)`);
            c.send("Page.handleJavaScriptDialog", { accept: true, promptText: p.defaultPrompt ?? "" }, sid).catch(() => {});
        } else s.dialogs.push(`[dialog ${p.type}] ${JSON.stringify(clip(p.message || "", 300))} is open in this tab and blocks it`);
    } else if (method === "Page.frameNavigated" && !p.frame?.parentId) s.ctx = 0;
    else if (method === "Network.requestWillBeSent") { if (!["WebSocket", "EventSource", "Media", "Ping", "Manifest"].includes(p.type)) s.net.set(p.requestId, Date.now()); s.lastNet = Date.now(); }
    else if (method === "Network.loadingFinished" || method === "Network.loadingFailed") { s.net.delete(p.requestId); s.lastNet = Date.now(); }
}

async function session(c, targetId) {
    let s = c.sessions.get(targetId);
    if (s) return s;
    const { sessionId } = await c.send("Target.attachToTarget", { targetId, flatten: true });
    s = { id: sessionId, targetId, ctx: 0, net: new Map(), lastNet: 0, acting: 0, dialogs: [], last: new Map() };
    c.sessions.set(targetId, s);
    await Promise.all(["Page.enable", "Network.enable"].map(m => c.send(m, {}, sessionId).catch(() => {})));
    return s;
}
const pages = async c => (await c.send("Target.getTargets")).targetInfos.filter(t => t.type === "page" && !t.url.startsWith("devtools://"));
const short = id => id.slice(0, 6).toLowerCase();

// The tab to work in: the one picked last, else the tab the user is looking at.
async function tab(c, want) {
    const ps = await pages(c);
    if (want) {
        const t = ps.find(p => short(p.targetId) === String(want).toLowerCase().slice(0, 6));
        if (!t) throw new Error(`No tab ${want}; list them with action tabs`);
        c.cur = t.targetId;
    }
    if (!ps.some(p => p.targetId === c.cur)) {
        c.cur = "";
        let vis = "";
        for (const p of ps.slice(0, 20)) {
            const s = await session(c, p.targetId).catch(() => null);
            const r = s && await c.send("Runtime.evaluate", { expression: "[document.visibilityState, document.hasFocus()]", returnByValue: true }, s.id, 3000).catch(() => null);
            const [v, f] = r?.result?.value || [];
            if (f) { c.cur = p.targetId; break; }
            if (v === "visible" && !vis) vis = p.targetId;
        }
        c.cur ||= vis || ps[0]?.targetId || "";
    }
    if (!c.cur) throw new Error("The browser has no tabs open");
    return session(c, c.cur);
}

// An isolated world per document: our observer and helpers stay invisible to the page's scripts.
async function evalw(c, s, expression) {
    for (let i = 0; ; i++) {
        try {
            if (!s.ctx) {
                const { frameTree } = await c.send("Page.getFrameTree", {}, s.id);
                s.ctx = (await c.send("Page.createIsolatedWorld", { frameId: frameTree.frame.id, worldName: "ansai" }, s.id)).executionContextId;
            }
            const r = await c.send("Runtime.evaluate", { expression, contextId: s.ctx, returnByValue: true, awaitPromise: true }, s.id, 10000);
            if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text);
            return r.result.value;
        } catch (e) {
            s.ctx = 0;
            if (i >= 15 || !LOST.test(e.message)) throw e;
            await sleep(100);
        }
    }
}

// URL, title, document identity, and a count of real DOM changes (not style-only animation) and form edits.
const PROBE = `(() => {
    if (!window.__a) {
        const a = window.__a = { last: performance.now(), n: 0, doc: Math.random() }, styled = new WeakMap();
        new MutationObserver(rs => {
            const now = performance.now();
            let real = false;
            for (const r of rs) {
                if (r.attributeName && r.oldValue === r.target.getAttributeNS(r.attributeNamespace, r.attributeName)) continue;
                if (r.attributeName !== "style" || now - (styled.get(r.target) ?? -1e9) > 200) real = true;
                if (r.attributeName === "style") styled.set(r.target, now);
            }
            if (real) { a.last = now; a.n++; }
        }).observe(document, { subtree: true, childList: true, attributes: true, attributeOldValue: true, characterData: true });
        for (const t of ["input", "change"]) addEventListener(t, () => a.n++, true);
    }
    const a = window.__a;
    return { idle: performance.now() - a.last, ready: document.readyState, url: location.href, title: document.title, n: a.n, doc: a.doc, w: innerWidth, h: innerHeight };
})()`;

// Wait on events, never a fixed sleep: document parsed, no fresh requests (older than 1.5 s count as long polls), DOM quiet.
async function settle(c, s, { cap = 3000, quiet = 120, since = 0 } = {}) {
    const start = Date.now();
    let limit = cap, probe;
    const busy = () => [...s.net.values()].filter(t => Date.now() - t < 1500).length;
    while (Date.now() - start < limit) {
        try {
            probe = await evalw(c, s, PROBE);
            if (probe.ready === "loading") limit = Math.max(cap, 8000);
            probe.idle = Math.min(probe.idle, Date.now() - (since || start));
            if (probe.ready !== "loading" && probe.idle >= quiet && !busy() && Date.now() - s.lastNet >= quiet) return { probe, pending: 0 };
        } catch (e) { if (!LOST.test(e.message)) return { probe, pending: 0 }; probe = undefined; }
        await sleep(probe && probe.ready !== "loading" ? Math.max(20, quiet - probe.idle) : 50);
    }
    return { probe, pending: busy() };
}

// Text actually shown: the tree keeps opacity:0 text (pre-rendered banners), which reads as success when it isn't.
const VISIBLE = `(() => {
    const out = [], shown = new Map(), roots = [document];
    for (let i = 0; i < roots.length; i++) {
        const w = document.createTreeWalker(roots[i], NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
        for (let n = w.nextNode(); n; n = w.nextNode()) {
            if (n.nodeType === 1) { if (n.shadowRoot) roots.push(n.shadowRoot); try { if (n.contentDocument) roots.push(n.contentDocument); } catch {} continue; }
            let e = n.parentElement;
            if (!e || !n.textContent.trim()) continue;
            while (e.parentElement && getComputedStyle(e).display === "contents") e = e.parentElement;
            if (!shown.has(e)) shown.set(e, e.checkVisibility({ checkOpacity: true, checkVisibilityCSS: true }));
            if (shown.get(e)) out.push(n.textContent);
        }
    }
    return out.join(" ").replace(/\\s+/g, " ").toLowerCase();
})()`;

async function capture(c, s) {
    for (let i = 0; ; i++) {
        try {
            const [{ nodes }, { frameTree }] = await Promise.all([c.send("Accessibility.getFullAXTree", {}, s.id), c.send("Page.getFrameTree", {}, s.id)]);
            const kids = [];
            const walk = t => t.childFrames?.forEach(k => { kids.push(k.frame); walk(k); });
            walk(frameTree);
            const frames = await Promise.all(kids.map(f => c.send("Accessibility.getFullAXTree", { frameId: f.id }, s.id).then(r => ({ url: f.url, nodes: r.nodes }), () => ({ url: f.url, nodes: [] }))));
            return [{ url: "", nodes }, ...frames];
        } catch (e) {
            if (i >= 20 || !LOST.test(e.message)) throw e;
            await sleep(50);
        }
    }
}

// The page in order: [id] role "name" = value states, ## headings, visible text; * marks ids new since the last look.
async function state(c, s, { max = 8000, find = "", since = 0 } = {}) {
    const st = await settle(c, s, { since });
    const [frames, info, visible] = await Promise.all([capture(c, s), st.probe ?? evalw(c, s, PROBE), evalw(c, s, VISIBLE).catch(() => undefined)]);
    const prev = s.last;
    s.last = new Map();
    const lines = [], text = [];
    const flush = () => text.length && lines.push(text.splice(0).join(" "));
    for (const f of frames) {
        const byId = new Map(f.nodes.map(n => [n.nodeId, n]));
        const at = lines.length;
        const walk = (n, inside) => {
            if (!n) return;
            const role = String(n.role?.value ?? ""), name = norm(n.name?.value);
            const kids = () => n.childIds?.forEach(k => walk(byId.get(k), inside));
            if (n.ignored) return kids();
            if (role === "StaticText") {
                const t = name.toLowerCase();
                if (t && !inside.includes(t) && (visible === undefined || visible.includes(t))) text.push(name);
                return;
            }
            if (role === "heading" && name) { flush(); lines.push(`## ${name}`); inside = name.toLowerCase(); return kids(); }
            const id = n.backendDOMNodeId;
            const focusable = prop(n, "focusable") && role !== "RootWebArea" && (name || n.value?.value || prop(n, "editable"));
            if (!id || !(CONTROLS.has(role) || focusable)) {
                if (!BLOCKS.has(role)) return kids();
                flush(); kids(); return flush();
            }
            flush();
            if (lines.at(-1)?.toLowerCase() === name.toLowerCase()) lines.pop();
            const value = norm(n.value?.value);
            const ck = prop(n, "checked"), ex = prop(n, "expanded");
            const states = [ck === undefined ? "" : ck === "false" ? "unchecked" : "checked", ex === undefined ? "" : ex ? "expanded" : "collapsed",
                ...["selected", "disabled", "focused"].map(k => (prop(n, k) ? k : ""))].filter(Boolean);
            const popup = n.childIds?.map(k => byId.get(k)).find(k => k?.role?.value === "MenuListPopup");
            const opts = [];
            const collect = k => k?.role?.value === "option" ? opts.push(norm(k.name?.value)) : k?.childIds?.forEach(x => collect(byId.get(x)));
            collect(popup);
            const shown = popup ? "select" : role === "button" && value ? "file" : role === "generic" && prop(n, "editable") ? "textbox" : role;
            s.last.set(id, { role: shown, name });
            lines.push(`${prev.size && !prev.has(id) ? "*" : ""}[${id}] ${shown}${name ? ` "${clip(name, 150)}"` : ""}${value ? ` = ${JSON.stringify(clip(value, 100))}` : ""}` +
                `${states.length ? " " + states.join(" ") : ""}${opts.length ? `  options: ${opts.slice(0, 5).join(" | ")}${opts.length > 5 ? ` | … ${opts.length - 5} more` : ""}` : ""}`);
            if (popup || NATIVE.has(role)) return;
            inside = `${inside} ${clip(name, 150)} ${value}`.toLowerCase();
            kids();
            flush();
        };
        walk(f.nodes[0], "");
        flush();
        if (f.url && lines.length > at) lines.splice(at, 0, `--- frame ${f.url} ---`);
    }
    let body = lines;
    if (find) {
        const q = find.toLowerCase();
        body = lines.filter(l => l.toLowerCase().includes(q));
        if (!body.length) body = [`(nothing on the page contains “${find}”)`];
    }
    const fit = (from, budget) => { let n = 0; const i = from.findIndex(l => (n += l.length + 1) > budget); return i < 0 ? from.length : i; };
    // Over max keep the top and the last fifth: a dialog's Done/Submit is usually last.
    if (fit(body, max) < body.length) {
        const head = fit(body, max * 0.8), tail = fit(body.toReversed(), max * 0.2);
        body = [...body.slice(0, head), `… ${body.length - head - tail} lines cut here (pass find, or a bigger max)`, ...body.slice(body.length - tail)];
    }
    const dialogs = s.dialogs.splice(0);
    return `[tab ${short(s.targetId)}] ${info.title} | ${info.url}${st.pending ? ` | still loading (${st.pending})` : ""}${dialogs.length ? "\n" + dialogs.join("\n") : ""}\n${body.join("\n")}`;
}

async function onNode(c, s, id, fn, arg) {
    const { object } = await c.send("DOM.resolveNode", { backendNodeId: Number(id) }, s.id)
        .catch(e => { throw /No node/.test(e.message) ? new Error("no such element on the page now; read the page again") : e; });
    if (!object?.objectId) throw new Error("That element is gone; look at the page again");
    try {
        const r = await c.send("Runtime.callFunctionOn", { objectId: object.objectId, functionDeclaration: fn, arguments: [{ value: arg }], returnByValue: true, awaitPromise: true }, s.id);
        if (r.exceptionDetails) throw new Error((r.exceptionDetails.exception?.description ?? "failed").split("\n    at ")[0].replace(/^Error: /, ""));
        return r.result.value;
    } finally { c.send("Runtime.releaseObject", { objectId: object.objectId }, s.id).catch(() => {}); }
}

// Scroll into view and return an unobstructed center point, or say what covers it.
async function point(c, s, id, editableCover = false) {
    await c.send("DOM.scrollIntoViewIfNeeded", { backendNodeId: Number(id) }, s.id).catch(() => {});
    const p = await onNode(c, s, id, `function(editableCover) {
        const e = this.nodeType === 1 ? this : this.parentElement;
        if (!e || !e.isConnected) throw Error("Target detached");
        if (e.matches(":disabled") || e.closest('[inert],[aria-disabled="true"]')) throw Error("Target disabled");
        if (e.matches("input[type=file]")) throw Error("File input: clicking opens the system file chooser");
        if (!e.checkVisibility({checkOpacity: true, checkVisibilityCSS: true})) throw Error("Target hidden");
        const r = e.getBoundingClientRect(), x = r.x + r.width / 2, y = r.y + r.height / 2;
        if (!r.width || !r.height || x < 0 || y < 0 || x >= innerWidth || y >= innerHeight) throw Error("Target outside the visible page");
        const hit = e.getRootNode().elementFromPoint(x, y);
        const tf = n => n && (["INPUT", "TEXTAREA"].includes(n.tagName) || n.isContentEditable);
        const covered = !e.contains(hit) && !(hit && hit.contains(e) && getComputedStyle(hit).pointerEvents !== "none" && hit.tagName === "LABEL") && !(editableCover && tf(e) && tf(hit));
        let px = x, py = y;
        for (let w = e.ownerDocument.defaultView; w && w.frameElement; w = w.parent) {
            const f = w.frameElement, fr = f.getBoundingClientRect(), cs = getComputedStyle(f);
            px += fr.x + f.clientLeft + parseFloat(cs.paddingLeft); py += fr.y + f.clientTop + parseFloat(cs.paddingTop);
        }
        return {x: px, y: py, covered};
    }`, editableCover);
    if (!p.covered) return p;
    const hit = await c.send("DOM.getNodeForLocation", { x: Math.round(p.x), y: Math.round(p.y) }, s.id).catch(() => null);
    const tree = hit && await c.send("Accessibility.getPartialAXTree", { backendNodeId: hit.backendNodeId }, s.id).catch(() => null);
    const byId = new Map(tree?.nodes.map(n => [n.nodeId, n]));
    const top = tree?.nodes.find(a => a.backendDOMNodeId === hit?.backendNodeId);
    let n = top;
    while (n && n.role?.value !== "RootWebArea" && (n.ignored || !(norm(n.name?.value) || /dialog/.test(String(n.role?.value))))) n = n.parentId ? byId.get(n.parentId) : undefined;
    if (!n || n.role?.value === "RootWebArea") n = top;
    const label = x => norm(x?.name?.value) || norm(x?.childIds?.map(k => byId.get(k)).find(k => k?.role?.value === "StaticText")?.name?.value);
    throw new Error(`it's covered by ${n ? `[${n.backendDOMNodeId}] ${n.role?.value} "${clip(label(n), 60)}"` : "another element"}; nothing was clicked`);
}
async function clickAt(c, s, x, y, clickCount = 1) {
    await c.send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y }, s.id);
    await c.send("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount }, s.id);
    await c.send("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount }, s.id);
}

const KEYS = { enter: [13, "Enter", "\r"], escape: [27, "Escape"], esc: [27, "Escape"], tab: [9, "Tab"], backspace: [8, "Backspace"], delete: [46, "Delete"],
    space: [32, " ", " ", "Space"], up: [38, "ArrowUp"], down: [40, "ArrowDown"], left: [37, "ArrowLeft"], right: [39, "ArrowRight"], arrowup: [38, "ArrowUp"],
    arrowdown: [40, "ArrowDown"], arrowleft: [37, "ArrowLeft"], arrowright: [39, "ArrowRight"], pageup: [33, "PageUp"], pagedown: [34, "PageDown"], home: [36, "Home"], end: [35, "End"] };
const MODS = { alt: 1, ctrl: 2, control: 2, meta: 4, super: 4, shift: 8 };
async function press(c, s, combo) {
    const parts = String(combo).toLowerCase().split("+").map(x => x.trim()).filter(Boolean);
    const k = parts.pop();
    let modifiers = 0;
    for (const m of parts) { if (!MODS[m]) throw new Error(`Unknown modifier ${m}`); modifiers |= MODS[m]; }
    let [code, key, txt, codeName] = KEYS[k] || (k?.length === 1 ? [k.toUpperCase().charCodeAt(0), k, k, /[a-z]/.test(k) ? "Key" + k.toUpperCase() : /\d/.test(k) ? "Digit" + k : k] : []);
    if (!key) throw new Error(`Unknown key ${k}: use enter, escape, tab, backspace, delete, space, arrows, pageup/pagedown, home, end, or one character`);
    if (modifiers & 3 || modifiers & 4) txt = undefined;
    const base = { key, code: codeName || key, windowsVirtualKeyCode: code, nativeVirtualKeyCode: code, modifiers };
    const cmds = modifiers === 2 && ["a", "c", "x", "v", "z"].includes(k) ? { commands: [{ a: "selectAll", c: "copy", x: "cut", v: "paste", z: "undo" }[k]] } : {};
    await c.send("Input.dispatchKeyEvent", { type: txt ? "keyDown" : "rawKeyDown", ...base, ...(txt ? { text: txt, unmodifiedText: txt } : {}), ...cmds }, s.id);
    await c.send("Input.dispatchKeyEvent", { type: "keyUp", ...base }, s.id);
}

// One action, then: navigated to <url> / page changed / no change, and the page as it is now.
async function act(c, s, what, body) {
    s.acting = Date.now() + 15000;
    const before = await evalw(c, s, PROBE).catch(() => undefined);
    const desc = what.id ? (n => n ? `[${what.id}] ${n.role}${n.name ? ` "${clip(n.name, 60)}"` : ""}` : `[${what.id}]`)(s.last.get(Number(what.id))) : "";
    let detail;
    try { detail = await body(); } catch (e) { throw new Error(`${what.op} ${desc} failed: ${e.message}`.replace(/\s+failed/, " failed")); }
    const since = Date.now();
    const st = await settle(c, s, { since, quiet: 250 });
    const after = st.probe ?? await evalw(c, s, PROBE).catch(() => undefined);
    const change = !before || !after ? "page changed" : after.doc !== before.doc || after.url !== before.url ? `navigated to ${after.url}` : after.n !== before.n ? "page changed" : "no change";
    return `[ok] ${what.op}${desc ? " " + desc : ""}${detail || ""} → ${change}\n\n${await state(c, s, { max: what.max || 6000, since })}`;
}

const OPS = {
    async tabs() {
        const c = await ready();
        await tab(c).catch(() => {});
        const ps = await pages(c);
        return `${c.name}, ${ps.length} tabs (id · title · url):\n` + ps.map(p => `${short(p.targetId)}${p.targetId === c.cur ? " (working here)" : ""} · ${clip(p.title, 80)} · ${clip(p.url, 120)}`).join("\n");
    },
    async state({ tab: t, find, max }) {
        const c = await ready();
        const s = await tab(c, t);
        return state(c, s, { find, max: Math.min(Math.max(Number(max) || 8000, 1000), 40000) });
    },
    async see({ tab: t }) {
        const c = await ready();
        const s = await tab(c, t);
        const r = await c.send("Page.captureScreenshot", { format: "jpeg", quality: 70 }, s.id, 8000).catch(() => { throw new Error("Couldn't capture that tab; it may be in the background (use action show first)"); });
        return { image: r.data, mime: "image/jpeg" };
    },
    async open({ url, new_tab, background }) {
        if (!/^(https?|file|about|brave|chrome):/i.test(String(url || ""))) throw new Error("url must start with https:// (or http://, file://)");
        const c = await ready();
        if (new_tab) {
            const { targetId } = await c.send("Target.createTarget", { url: "about:blank", background: !!background });
            c.cur = targetId;
            c.opened.add(targetId);
        }
        const s = await tab(c);
        return act(c, s, { op: "open" }, async () => {
            const r = await c.send("Page.navigate", { url }, s.id);
            if (r.errorText) throw new Error(r.errorText);
            return ` ${url}`;
        });
    },
    async click({ id, tab: t }) {
        const c = await ready();
        const s = await tab(c, t);
        return act(c, s, { op: "click", id }, async () => { const p = await point(c, s, id); await clickAt(c, s, p.x, p.y); });
    },
    async type({ id, text, enter, tab: t }) {
        if (typeof text !== "string") throw new Error("type needs text");
        const c = await ready();
        const s = await tab(c, t);
        return act(c, s, { op: "type", id }, async () => {
            const kind = await onNode(c, s, id, "function(){const e=this.nodeType===1?this:this.parentElement;if(!e||!e.isConnected)throw Error('Target detached');return {tag:e.tagName,type:e.type||''};}");
            if (kind.tag === "SELECT") {
                const label = await onNode(c, s, id, `function(want){
                    const n = s => String(s).replace(/\\s+/g," ").trim().toLowerCase(), opts = [...this.options].filter(o => !o.disabled);
                    const pre = opts.filter(o => n(o.label).startsWith(n(want)));
                    const o = opts.find(o => n(o.label) === n(want) || n(o.value) === n(want)) ?? (pre.length === 1 ? pre[0] : undefined);
                    if (!o) throw Error((pre.length > 1 ? "several options start with " : "no option ") + JSON.stringify(want) + ". Options: " + (pre.length > 1 ? pre : opts).slice(0, 40).map(o => o.label).join(" | "));
                    this.value = o.value; this.dispatchEvent(new Event("input",{bubbles:true})); this.dispatchEvent(new Event("change",{bubbles:true}));
                    return o.label;
                }`, text);
                return ` = ${JSON.stringify(label)}`;
            }
            if (kind.tag === "INPUT" && ["date", "time", "datetime-local", "month", "week"].includes(kind.type)) {
                await onNode(c, s, id, "function(v){const s=Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set,old=this.value;s.call(this,v);if(this.value!==v){s.call(this,old);throw Error('Not a valid value; use the ISO format like 2026-11-20 or 14:30');}this.dispatchEvent(new Event('input',{bubbles:true}));this.dispatchEvent(new Event('change',{bubbles:true}));}", text);
                return ` = ${JSON.stringify(text)}`;
            }
            const p = await point(c, s, id, true);
            await clickAt(c, s, p.x, p.y);
            // Comboboxes often move focus to their own overlay input on click: type there.
            const moved = await onNode(c, s, id, "function(){const e=this.nodeType===1?this:this.parentElement;let a=document.activeElement;while(a&&a.shadowRoot&&a.shadowRoot.activeElement)a=a.shadowRoot.activeElement;return !!a&&a!==e&&!e.contains(a)&&(['INPUT','TEXTAREA'].includes(a.tagName)||a.isContentEditable);}").catch(() => false);
            if (!moved) await c.send("DOM.focus", { backendNodeId: Number(id) }, s.id).catch(() => {});
            await press(c, s, "ctrl+a");
            if (text === "") await press(c, s, "backspace");
            else {
                // Autocompletes react to key events, which insertText never sends: type the last character as a key.
                const ch = [...text], last = ch.pop();
                if (ch.length) await c.send("Input.insertText", { text: ch.join("") }, s.id);
                await c.send("Input.dispatchKeyEvent", { type: "keyDown", key: last, text: last }, s.id);
                await c.send("Input.dispatchKeyEvent", { type: "keyUp", key: last }, s.id);
            }
            const now = await (moved
                ? c.send("Runtime.evaluate", { expression: "(()=>{let a=document.activeElement;while(a&&a.shadowRoot&&a.shadowRoot.activeElement)a=a.shadowRoot.activeElement;return a?(a.isContentEditable?a.innerText:(a.value??'')):''})()", returnByValue: true }, s.id).then(r => r.result.value)
                : onNode(c, s, id, "function(){const e=this.nodeType===1?this:this.parentElement;return e.isContentEditable?e.innerText:(e.value??'');}")).catch(() => undefined);
            if (enter) await press(c, s, "enter");
            return ` = ${JSON.stringify(clip(text, 60))}${moved ? " (into the box that opened)" : ""}${now !== undefined && now.trim() !== text.trim() ? ` (field now shows ${JSON.stringify(clip(now, 80))})` : ""}${enter ? " +Enter" : ""}`;
        });
    },
    async key({ keys, tab: t }) {
        const c = await ready();
        const s = await tab(c, t);
        return act(c, s, { op: "key" }, async () => { await press(c, s, keys); return ` ${keys}`; });
    },
    async scroll({ id, down, tab: t }) {
        const c = await ready();
        const s = await tab(c, t);
        return act(c, s, { op: "scroll", id }, async () => {
            if (id) { await c.send("DOM.scrollIntoViewIfNeeded", { backendNodeId: Number(id) }, s.id); return " into view"; }
            const p = await evalw(c, s, PROBE), d = Math.trunc(Number(down) || 1), dy = d * Math.round(p.h * 0.8);
            // A background tab never renders the frame a wheel event waits for: scroll it from script instead.
            if (await evalw(c, s, "document.visibilityState") === "hidden") await evalw(c, s, `(document.scrollingElement || document.body).scrollBy(0, ${dy})`);
            else await c.send("Input.dispatchMouseEvent", { type: "mouseWheel", x: p.w / 2, y: p.h / 2, deltaX: 0, deltaY: dy }, s.id, 5000);
            return ` ${d > 0 ? "down" : "up"} ${Math.abs(d)} screen${Math.abs(d) > 1 ? "s" : ""}`;
        });
    },
    async back({ tab: t }) {
        const c = await ready();
        const s = await tab(c, t);
        return act(c, s, { op: "back" }, async () => {
            const h = await c.send("Page.getNavigationHistory", {}, s.id);
            const e = h.entries[h.currentIndex - 1];
            if (!e) throw new Error("no earlier page in this tab");
            await c.send("Page.navigateToHistoryEntry", { entryId: e.id }, s.id);
        });
    },
    async close({ tab: t }) {
        const c = await ready();
        const s = await tab(c, t);
        if (!c.opened.has(s.targetId)) throw new Error("Only tabs you opened (open with new_tab) can be closed");
        await c.send("Target.closeTarget", { targetId: s.targetId });
        c.opened.delete(s.targetId);
        c.cur = "";
        return `Closed tab ${short(s.targetId)}.`;
    },
    async show({ tab: t }) {
        const c = await ready();
        const s = await tab(c, t);
        await c.send("Target.activateTarget", { targetId: s.targetId });
        return `Showing tab ${short(s.targetId)} in ${c.name}.`;
    },
};

export async function serve() {
    let last = Date.now(), queue = Promise.resolve();
    const srv = createServer(sock => {
        let buf = "";
        sock.on("error", () => {});
        sock.on("data", d => {
            buf += d;
            const i = buf.indexOf("\n");
            if (i < 0) return;
            const req = JSON.parse(buf.slice(0, i));
            buf = "";
            last = Date.now();
            // One at a time: two agents (or two tools) never interleave on a tab.
            queue = queue.then(async () => {
                try {
                    const f = OPS[req.op];
                    if (!f) throw new Error(`Unknown browser action ${req.op}`);
                    sock.end(JSON.stringify({ ok: await f(req.args || {}) }) + "\n");
                } catch (e) { sock.end(JSON.stringify({ e: String(e?.message || e) }) + "\n"); }
                last = Date.now();
            });
        });
    });
    await new Promise((res, rej) => {
        srv.once("error", async e => {
            if (e.code !== "EADDRINUSE") return rej(e);
            const live = await new Promise(r => { const c = createConnection(SOCK); c.on("connect", () => { c.destroy(); r(true); }); c.on("error", () => r(false)); });
            if (live) process.exit(0);   // another helper already serves
            await unlink(SOCK).catch(() => {});
            srv.listen(SOCK, res);
        });
        srv.listen(SOCK, res);
    });
    // Quit 15 minutes after the browser connection is gone and nobody asked for anything.
    setInterval(() => { if (!conn && !connecting && Date.now() - last > 900000) { srv.close(); unlink(SOCK).catch(() => {}); process.exit(0); } }, 60000).unref();
    const bye = () => { unlink(SOCK).catch(() => {}).finally(() => process.exit(0)); };
    process.on("SIGTERM", bye);
    process.on("SIGINT", bye);
}
