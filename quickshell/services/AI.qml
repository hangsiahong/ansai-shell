pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// KOOMPI AI Gateway via agent/ansai-agent.js (pi-mono agent loop: desktop tools + MCP connectors), which holds the key.
// ask() runs one request; the Ask AI sidebar's conversation lives here so it survives closing it.
Singleton {
    id: root

    readonly property string keyFile: Settings.dir + "/ai-key"
    readonly property string script: Quickshell.shellDir + "/agent/ansai-agent.js"
    readonly property var models: ["koompi-luna", "koompi-smart", "koompi-fast", "koompi-lite", "koompi-balance"]
    property bool hasKey: false
    function checkKey(): void { keyCheck.running = false; keyCheck.running = true; }
    function setKey(key: string): void {
        keyWriter.key = key.trim();
        keyWriter.running = true;
    }

    readonly property string system: `You are the assistant built into ansai, the user's Linux desktop (niri + Quickshell). ` +
        `Today is ${Qt.formatDate(new Date(), "dddd d MMMM yyyy")}.

How to answer:
- First line: the direct answer (the number, yes/no, the fix, the result). No preamble, don't restate the question.
- Then only the details that matter: a few short bullets or a small table. Bold the key numbers and names.
- Aim for under 100 words unless the user asks for more. No closing offers or filler.
- Get facts right before writing: count lists carefully, never write "Correction:"; if unsure, say what you'd check.
- Reply in the language the user writes in (often Khmer or English). Code goes in fenced blocks.`

    // ask([{ role, content, image? }], onDelta(text), onDone(fullText, error), opts) → handle with .stop()
    // opts.tools: let it use the desktop tools; opts.mcp: server urls whose tools it may use;
    // opts.onEvent(ev) gets tool / tool_done events.
    function ask(messages, onDelta, onDone, opts) {
        const p = req.createObject(root, {
            body: JSON.stringify({ model: Settings.aiModel, messages: messages, mcp: opts?.mcp ?? [], tools: !!opts?.tools }),
            onDelta: onDelta ?? null,
            onDone: onDone ?? null,
            onEvent: opts?.onEvent ?? null
        });
        p.running = true;
        return p;
    }
    // One-shot instruction over some text: ask a system-style task, get the whole answer.
    function task(instruction: string, text: string, onDone, onDelta) {
        return ask([{ role: "system", content: instruction }, { role: "user", content: text }], onDelta, onDone);
    }

    // ---- MCP connectors (scripts/mcp.py: OAuth sign-in in the browser, tokens in mcp-tokens.json)
    property var mcp: ({})         // url → { connected, tools, e, busy }
    readonly property var mcpServers: Array.from(Settings.mcpServers ?? [])
    readonly property var mcpLive: mcpServers.filter(s => s.on && mcp[s.url]?.connected).map(s => s.url)
    readonly property string mcpScript: Quickshell.shellDir + "/scripts/mcp.py"
    function setMcp(url, v) { const m = Object.assign({}, mcp); m[url] = Object.assign({}, m[url] ?? {}, v); mcp = m; }
    function refreshMcp(): void {
        if (!mcpServers.length || mcpStatus.running) return;
        mcpStatus.command = ["python3", mcpScript, "status", ...mcpServers.map(s => s.url)];
        mcpStatus.running = true;
    }
    function connect(url: string): void {
        setMcp(url, { busy: true, e: "" });
        mcpCmd.createObject(root, { url: url, command: ["python3", mcpScript, "login", url] }).running = true;
    }
    function disconnect(url: string): void {
        setMcp(url, { busy: true, e: "" });
        mcpCmd.createObject(root, { url: url, command: ["python3", mcpScript, "logout", url] }).running = true;
    }
    Component.onCompleted: {
        // Chats can hold anything the user pasted: keep them private to the user.
        Quickshell.execDetached(["sh", "-c", `mkdir -p "$1/ai-images" && chmod 700 "$1" && chmod -f 600 "$1/ai-chats.json"; true`, "sh", dataDir]);
        readChats();
        refreshMcp();
    }
    Process {
        id: mcpStatus
        stdout: SplitParser {
            onRead: line => {
                try { const r = JSON.parse(line); root.setMcp(r.url, { connected: r.connected, tools: r.tools ?? 0, e: r.e ?? "" }); } catch (x) {}
            }
        }
    }
    Component {
        id: mcpCmd
        Process {
            property string url
            stdout: SplitParser {
                onRead: line => {
                    let r;
                    try { r = JSON.parse(line); } catch (x) { return; }
                    if (r.opened) root.setMcp(url, { waiting: true });
                    else if (r.e) root.setMcp(url, { e: r.e });
                }
            }
            stderr: StdioCollector { id: mcpErr }
            onExited: code => {
                const tail = mcpErr.text.trim().split("\n").pop();
                if (code !== 0) console.warn("mcp.py failed:", mcpErr.text);
                root.setMcp(url, Object.assign({ busy: false, waiting: false }, code !== 0 && tail ? { e: tail } : {}));
                root.refreshMcp();
                destroy();
            }
        }
    }

    // ---- sidebar conversation
    // [{ role: "user"|"assistant", content, image?, error?, tools?: [{ id, name, title, server, args, ask, status, preview }] }]
    property var chat: []
    property bool busy: false
    property int gen: 0   // bumped by reset(): a stopped request must not write into the new chat
    property var current: null
    property string draft: ""      // text waiting in the sidebar's input
    property string attachment: "" // image path to send with the next message

    // ---- history: every conversation, newest first, in ~/.local/share/ansai-shell/ai-chats.json
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/ansai-shell"
    property var chats: []         // [{ id, title, updated, messages }]
    property string chatId: ""
    property bool chatsRead: false
    // Read the saved chats before anything writes them, so a save can't replace history it hasn't seen.
    function readChats(): void {
        if (chatsRead) return;
        const t = histFile.text();
        if (t) {
            try { chats = JSON.parse(t); }
            catch (e) { console.warn("ai-chats.json unreadable; not overwriting it"); return; }
        }
        chatsRead = true;
    }
    function save(): void {
        if (!chat.length) return;
        readChats();
        if (!chatsRead) return;
        if (!chatId) chatId = Date.now().toString(36);
        const first = chat.find(m => m.role === "user");
        const title = (first?.content || "Image").replace(/\s+/g, " ").trim().slice(0, 90);
        chats = [{ id: chatId, title: title, updated: Date.now(), messages: chat }, ...chats.filter(c => c.id !== chatId)].slice(0, 200);
        histFile.setText(JSON.stringify(chats));
    }
    function openChat(id: string): void {
        const c = chats.find(x => x.id === id);
        if (!c || busy) return;
        chat = c.messages;
        chatId = id;
        attachment = "";
    }
    function deleteChat(id: string): void {
        readChats();
        if (!chatsRead) return;
        chats = chats.filter(c => c.id !== id);
        histFile.setText(JSON.stringify(chats));
        if (id === chatId) { stop(); chat = []; chatId = ""; }
    }
    FileView {
        id: histFile
        path: root.dataDir + "/ai-chats.json"
        printErrors: false
        atomicWrites: true
        blockLoading: true   // text() is the file's content as soon as it's asked for
    }

    function send(text: string): void {
        text = text.trim();
        if ((!text && !attachment) || busy) return;
        const user = { role: "user", content: text || "What's in this screenshot?" };
        if (attachment) user.image = attachment;
        attachment = "";
        const names = mcpServers.filter(s => mcpLive.includes(s.url)).map(s => s.name).join(", ");
        const history = [{ role: "system", content: system + `

You can act on this computer with tools: run commands, read/write/edit files, search files, open files and URLs,
start apps, list/focus/arrange windows (niri), read/copy the clipboard, look at the screen, read web pages.
- Use them instead of telling the user how to do something they asked you to do. Look first (read, list, search), then act.
- Prefer the dedicated tools; use run_command for the rest (system info, packages, git, network). Keep commands safe and specific.
- Anything that changes something waits for the user's approval in the app; if declined, don't retry it.
- After acting, say in one line what you did and the result.` + (names ? `

Tools from the user's connected services (${names}):
- Use them for anything about the user's account, services, usage, billing or data there. Don't guess what a tool would tell you.
- Call independent tools together in one step. If the first tool lacks the data, look for a more specific one
  (per-service metrics, traffic, usage, logs) before saying it isn't available.
- If it truly isn't available, say so in one line and give the closest numbers you did find.
- Only say you did something if the tool succeeded. Actions that change things need the user's approval, which the app asks for.` : "") }];
        // Older images are dropped from the context: only the newest one is sent.
        const prior = chat.filter(m => !m.error).map(m => ({ role: m.role, content: m.content }));
        chat = [...chat, user, { role: "assistant", content: "" }];
        save();
        busy = true;
        const i = chat.length - 1, g = gen;
        const edit = f => { if (g !== gen) return; const c = Array.from(chat); c[i] = Object.assign({}, c[i]); f(c[i]); chat = c; };
        current = ask([...history, ...prior, user], d => edit(m => m.content += d), (full, err) => {
            edit(m => {
                (m.tools ?? []).forEach((t, k) => { if (t.status === "wait" || t.status === "run") m.tools[k] = Object.assign({}, t, { status: "fail", preview: "Stopped" }); });
                if (err) { m.content = m.content ? m.content + "\n\n" + err : err; m.error = !full && !(m.tools ?? []).length; }
            });
            if (g !== gen) return;
            busy = false;
            current = null;
            save();
        }, {
            mcp: mcpLive,
            tools: true,
            onEvent: ev => edit(m => {
                const tools = Array.from(m.tools ?? []);
                const auto = ev.tool?.ask && Settings.aiAllowAll;
                if (auto) current.write("y\n");
                if (ev.tool) tools.push(Object.assign({}, ev.tool, { status: ev.tool.ask && !auto ? "wait" : "run", auto: !!auto }));
                else if (ev.tool_done) {
                    const k = tools.findIndex(t => t.id === ev.tool_done.id);
                    if (k >= 0) tools[k] = Object.assign({}, tools[k], { status: ev.tool_done.preview === "Declined" ? "declined" : ev.tool_done.ok ? "ok" : "fail", preview: ev.tool_done.preview });
                }
                m.tools = tools;
            })
        });
    }
    // Answer a tool that waits for approval (the newest assistant message's).
    // "Always allow": from now on every action runs without asking (Settings → AI turns it back off).
    function allowAll(id: string): void {
        Settings.aiAllowAll = true;
        approve(id, true);
    }
    function approve(id: string, yes: bool): void {
        if (!current) return;
        const i = chat.length - 1, c = Array.from(chat);
        c[i] = Object.assign({}, c[i], { tools: (c[i].tools ?? []).map(t => t.id === id ? Object.assign({}, t, { status: yes ? "run" : "declined" }) : t) });
        chat = c;
        current.write(yes ? "y\n" : "n\n");
    }
    function stop(): void { if (current) current.stop(); }
    function reset(): void { stop(); gen++; busy = false; current = null; chat = []; chatId = ""; attachment = ""; }
    // Open the sidebar with something to ask about.
    function askAbout(image: string, text: string): void {
        if (image) attachment = image;
        if (text) draft = text;
        Shell.open = "ai";
    }
    // Pick an area (slurp), grab it, and open the sidebar with it attached.
    function screenshot(): void {
        Shell.close();
        shot.running = true;
    }

    Process {
        id: shot
        command: ["sh", "-c", `d="\${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"; mkdir -p "$d"; f="$d/Screenshot $(date '+%Y-%m-%d %H-%M-%S').png"; ` +
                              `g=$(slurp -d -b '#00000066' -c '#0a84ffff' -s '#0a84ff22' -w 2) && grim -g "$g" "$f" && wl-copy < "$f" && echo "$f"`]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.askAbout(text.trim(), "") }
    }

    Component {
        id: req
        Process {
            id: p
            property string body
            property var onDelta
            property var onDone
            property var onEvent
            property string full: ""
            property string err: ""
            property bool stopped: false
            function stop() { stopped = true; running = false; }
            command: ["node", root.script]
            stdinEnabled: true
            // stdin stays open: tool approvals are answered on it ("y" / "n").
            onStarted: write(body + "\n")
            stdout: SplitParser {
                onRead: line => {
                    let ev;
                    try { ev = JSON.parse(line); } catch (e) { return; }
                    if (ev.e) p.err = ev.e;
                    else if (ev.d) { p.full += ev.d; if (p.onDelta) p.onDelta(ev.d); }
                    else if ((ev.tool || ev.tool_done) && p.onEvent) p.onEvent(ev);
                }
            }
            stderr: StdioCollector { id: errOut }
            onExited: code => {
                if (!err && code !== 0 && !stopped) err = errOut.text.trim().split("\n").pop() || "AI request failed";
                if (!err && !full.trim() && !stopped) err = "No answer came back";
                if (onDone) onDone(full, err);
                destroy();
            }
        }
    }

    Process {
        id: keyCheck
        running: true
        command: ["test", "-s", root.keyFile]
        onExited: code => root.hasKey = code === 0
    }
    Process {
        id: keyWriter
        property string key
        command: ["sh", "-c", `umask 077; mkdir -p "$(dirname "$1")"; cat > "$1"`, "sh", root.keyFile]
        stdinEnabled: true
        onStarted: { write(key); key = ""; stdinEnabled = false; }
        onExited: root.checkKey()
    }

    IpcHandler {
        target: "ai"
        function toggle(): void { Shell.toggle("ai"); }
        function screenshot(): void { root.screenshot(); }
        function image(path: string): void { root.askAbout(path, ""); }
        function ask(text: string): void { root.askAbout("", text); }
        function send(text: string): void { Shell.open = "ai"; root.send(text); }
        function reset(): void { root.reset(); }
        function connect(url: string): void { root.connect(url || "https://mcp.koompi.cloud"); }
    }
}
