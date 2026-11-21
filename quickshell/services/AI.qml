pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// KOOMPI AI Gateway or signed-in provider accounts (ChatGPT, Claude, Copilot…) via agent/ansai-agent.js
// (pi-mono agent loop: desktop tools + MCP connectors), which holds the keys and tokens.
// ask() runs one request; the Ask Ansai sidebar's conversation lives here so it survives closing it.
Singleton {
    id: root

    readonly property string keyFile: Settings.dir + "/ai-key"
    readonly property string script: Quickshell.shellDir + "/agent/ansai-agent.js"
    readonly property var models: ["koompi-luna", "koompi-smart", "koompi-fast", "koompi-lite", "koompi-balance"]
    property bool hasKey: false
    // ---- Signed-in accounts (agent/accounts.mjs; tokens stay in ai-accounts.json, only metadata comes here)
    property var providers: []      // [{ id, name, oauth: { name, sub } | null, key }]
    property var catalogModels: ({})  // provider id → [{ id, name, image }] for providers with an account
    property var accounts: []       // [{ id, provider, label, type, limitedUntil, error, lastUsed }]
    property var via: null          // account the last answer came from
    readonly property string provider: Settings.aiModel.includes("/") ? Settings.aiModel.split("/")[0] : ""
    readonly property bool ready: provider ? accounts.some(a => a.provider === provider) : hasKey
    readonly property string modelLabel: provider ? Settings.aiModel.slice(provider.length + 1) : Settings.aiModel
    function providerName(id) { return id === "" ? "KOOMPI" : (providers.find(p => p.id === id)?.name ?? id); }
    function refreshAccounts(): void { if (!catalogProc.running) catalogProc.running = true; }
    // Sign-in in progress: { provider, kind, step: "busy"|"url"|"code"|"prompt"|"done"|"error", url, code, prompt, msg }
    property var signin: null
    property var signinProc: null
    function signIn(provider: string, kind: string): void {
        cancelSignIn();
        signin = { provider: provider, kind: kind, step: "busy", msg: "Starting…" };
        signinProc = loginComp.createObject(root, { command: ["node", script, "login", provider, kind] });
        signinProc.running = true;
    }
    function answerSignIn(text: string): void {
        if (!signinProc) return;
        signinProc.write(text.replace(/\n/g, " ") + "\n");
        signin = Object.assign({}, signin, { step: "busy", msg: "Signing in…" });
    }
    function cancelSignIn(): void {
        if (signinProc) { signinProc.stopped = true; signinProc.running = false; }
        signinProc = null;
        signin = null;
    }
    function signOut(id: string): void { acctCmd.createObject(root, { command: ["node", script, "logout", id] }).running = true; }
    function renameAccount(id: string, label: string): void { acctCmd.createObject(root, { command: ["node", script, "rename", id, label] }).running = true; }
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
    // opts.tools: let it use the desktop tools; opts.only: just these tool names (e.g. ["clipboard"]); opts.mcp: server urls whose tools it may use;
    // opts.onEvent(ev) gets tool / tool_done events.
    function ask(messages, onDelta, onDone, opts) {
        const p = req.createObject(root, {
            body: JSON.stringify({ model: Settings.aiModel, account: Settings.aiAccount, messages: messages, mcp: opts?.mcp ?? [], tools: !!opts?.tools, only: opts?.only ?? null, learn: !!opts?.tools && Settings.aiLearn }),
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
        refreshAccounts();
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
    property bool thinking: false  // the model is reasoning before it answers (or between steps)
    property int gen: 0   // bumped by reset(): a stopped request must not write into the new chat
    property var current: null
    signal barAsked(string text)
    property bool bar: false
    // The agent is using the mouse and keyboard: shell panels stay out of the way until the answer is done.
    property bool driving: false
    property string reopen: ""
    onBusyChanged: { thinking = false; if (!busy && driving) { driving = false; if (reopen) Shell.open = reopen; reopen = ""; } }   // quick Ask bar at the bottom edge, opened from a key (modules/AskBar.qml)
    property string draft: ""      // text waiting in the sidebar's input
    property string attachment: "" // image path to send with the next message

    // ---- history: every conversation, newest first, in ~/.local/share/ansai-shell/ai-chats.json
    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/ansai-shell"
    property var chats: []         // [{ id, title, updated, messages }]
    property string chatId: ""
    property string chatTitle: ""  // the AI's name for the open chat; "" until named (the first prompt stands in)
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
        const title = chatTitle || (first?.content || "Image").replace(/\s+/g, " ").trim().slice(0, 90);
        chats = [{ id: chatId, title: title, named: !!chatTitle, updated: Date.now(), messages: chat }, ...chats.filter(c => c.id !== chatId)].slice(0, 200);
        histFile.setText(JSON.stringify(chats));
    }
    // After the first answer, a short title from the AI replaces the prompt in the chat list.
    function nameChat(): void {
        if (chatTitle) return;
        const id = chatId, u = chat.find(m => m.role === "user"), a = chat.find(m => m.role === "assistant" && m.content && !m.error);
        if (!u) return;
        task(`Name this chat for a chat list: 2 to 5 words, in the language the user wrote in, like "Facebook post search" or "Sabay Tek owner".
No quotes, no period, no emoji. Reply with only the name.`,
            `User: ${(u.content || "(an image)").slice(0, 600)}\n\nAssistant: ${(a?.content ?? "").slice(0, 400)}`, (full, err) => {
                const t = (full ?? "").trim().split("\n")[0].replace(/^["'“”*#\s]+|["'“”*.\s]+$/g, "").slice(0, 60);
                if (err || !t) return;
                const c = chats.find(x => x.id === id);
                if (!c) return;
                chats = chats.map(x => x.id === id ? Object.assign({}, x, { title: t, named: true }) : x);
                histFile.setText(JSON.stringify(chats));
                if (chatId === id) chatTitle = t;
            });
    }
    function openChat(id: string): void {
        const c = chats.find(x => x.id === id);
        if (!c || busy) return;
        chat = c.messages;
        chatId = id;
        chatTitle = c.named ? c.title : "";
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

    // ---- lessons: one line each in ai-lessons.md, written by the agent's remember_lesson tool and by audit() below,
    // read into every desktop conversation's instructions. Settings → AI lists and deletes them.
    property var lessons: []
    FileView {
        id: lessonsFile
        path: root.dataDir + "/ai-lessons.md"
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.lessons = text().split("\n").filter(l => l.startsWith("- ")).map(l => l.slice(2).trim()).filter(Boolean)
        onLoadFailed: root.lessons = []
    }
    function setLessons(l): void {
        lessons = l;
        lessonsFile.setText(l.length ? "# Ask Ansai lessons (one per line; edit or delete freely)\n" + l.map(x => "- " + x).join("\n") + "\n" : "");
    }
    // After a long or bumpy desktop task, a quick review writes down what would have made it shorter.
    function audit(request: string, msg): void {
        const tools = msg.tools ?? [];
        if (!Settings.aiLearn || !(tools.length >= 6 || tools.some(t => t.status === "fail"))) return;
        const trace = tools.map((t, k) => `${k + 1}. ${t.name} ${JSON.stringify(t.args ?? {}).slice(0, 200)} → ${t.status}: ${(t.preview ?? "").replace(/Screen content below[^.]*\.[^.]*\.[^.]*\.[^.]*\./, "").replace(/\s+/g, " ").slice(0, 160)}`).join("\n");
        task(`You review how a desktop AI assistant did a task, so it does better next time. It controls apps with tools
(open URLs, launch apps, browser_read/browser_act in the web browser, desktop_read/desktop_act on the accessibility tree, desktop_see screenshots, desktop_input mouse and keyboard).
Find the biggest avoidable waste or mistake and write ONE lesson that would prevent it: one line, under 30 words,
general enough to reuse, concrete (name the site, app, URL pattern or tool), no private data (names, messages, numbers).
Example: "YouTube: open https://www.youtube.com/results?search_query=<words> instead of typing into the search box."
Existing lessons (don't repeat or contradict them):
${lessons.map(l => "- " + l).join("\n") || "(none)"}
If the task went fine or nothing reusable can be learned, reply exactly NONE. Otherwise reply with only the lesson line.`,
            `Request: ${request}\n\nSteps:\n${trace}\n\nFinal answer: ${(msg.content ?? "").slice(0, 400)}`, (full, err) => {
                const l = (full ?? "").trim().replace(/^[-*•]\s*/, "").replace(/^"|"$/g, "").split("\n")[0].trim();
                if (err || !l || /^NONE\b/i.test(l) || l.length > 300 || lessons.includes(l)) return;
                setLessons([...lessons, l].slice(-60));
            });
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
start apps, list/focus/arrange windows (niri), read/copy the clipboard and search what the user copied before (clipboard tool), read web pages, and see and use other apps on the screen
(desktop_* tools: read an app's accessibility tree and act on it, or look at the screen and click/type/press keys), and use web pages in the user's browser (browser_* tools).
- Use them instead of telling the user how to do something they asked you to do. Look first (read, list, search), then act.
- Prefer the dedicated tools; use run_command for the rest (system info, packages, git, network). Keep commands safe and specific.
- Anything that changes something waits for the user's approval in the app; if declined, don't retry it.
- To do something in an app (send a message, fill in a form): open or focus it, read or look, act, then check the result.
  Before sending, posting, paying or deleting, make sure the right person, chat or amount is on screen; if you can't, stop and say why.
- Use the fewest steps. For websites, open a URL that already does the job instead of clicking and typing in the page
  (search results: https://www.youtube.com/results?search_query=…, https://www.google.com/search?q=…, https://www.google.com/maps/search/…).
- For web pages use the browser_* tools (the user's own Brave, signed in): browser_read, then browser_act on ids; each action
  returns the page again. If they say remote debugging is off or not allowed, tell the user, then fall back to the desktop tools.
- In other apps prefer desktop_read with find, then desktop_act on the element: exact and cheap. Use desktop_see and
  desktop_input only when the tree doesn't show what you need. Pages need a moment after opening: pass wait to desktop_read/desktop_see.
- After typing something that matters, read it back before pressing Enter or Send.
- When a step failed and you found what works, or the user corrects you, save it with remember_lesson (one short general line).
- After acting, say in one line what you did and the result.` + (Settings.aiLearn && lessons.length ? `

Lessons from earlier tasks (follow them):
${lessons.map(l => "- " + l).join("\n")}` : "") + (names ? `

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
            if (!err) { audit(user.content, chat[i]); nameChat(); }
        }, {
            mcp: mcpLive,
            tools: true,
            onEvent: ev => edit(m => {
                if (ev.t !== undefined) {   // reasoning: kept with the answer (not sent back to the model)
                    m.thinkStart = m.thinkStart || Date.now();
                    m.reasoning = (m.reasoning ?? "") + ev.t;
                    m.thinkMs = Date.now() - m.thinkStart;
                    return;
                }
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
    function reset(): void { stop(); gen++; busy = false; current = null; chat = []; chatId = ""; chatTitle = ""; attachment = ""; }
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
                    else if (ev.t !== undefined) { root.thinking = true; if (p.onEvent) p.onEvent(ev); }
                    else if (ev.d) { root.thinking = false; p.full += ev.d; if (p.onDelta) p.onDelta(ev.d); }
                    else if ((ev.tool || ev.tool_done) && p.onEvent) { root.thinking = false; p.onEvent(ev); }
                    else if (ev.via) { root.via = ev.via; if (ev.via.after) root.refreshAccounts(); }
                }
            }
            stderr: StdioCollector { id: errOut }
            onExited: code => {
                if (!err && code !== 0 && !stopped) err = errOut.text.trim().split("\n").pop() || "AI request failed";
                if (!err && !full.trim() && !stopped) err = "No answer came back";
                if (onDone) onDone(full, err);
                if (root.provider && err) root.refreshAccounts();
                destroy();
            }
        }
    }

    Process {
        id: catalogProc
        command: ["node", root.script, "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text);
                    root.providers = c.providers;
                    root.catalogModels = c.models;
                    root.accounts = c.accounts;
                } catch (e) {}
            }
        }
    }
    Component {
        id: acctCmd
        Process {
            onExited: { root.refreshAccounts(); destroy(); }
        }
    }
    Component {
        id: loginComp
        Process {
            id: lp
            property bool stopped: false
            property string err: ""
            stdinEnabled: true
            stdout: SplitParser {
                onRead: line => {
                    let m;
                    try { m = JSON.parse(line); } catch (e) { return; }
                    if (root.signinProc !== lp) return;
                    const s = Object.assign({}, root.signin);
                    if (m.e) { lp.err = m.e; return; }
                    if (m.ok) { s.step = "done"; s.msg = "Signed in as " + m.ok.label; root.signin = s; return; }
                    if (m.prompt) {
                        // Codex asks browser vs device code: the browser flow, with a pasted-URL fallback, suits a desktop.
                        const br = m.prompt.type === "select" && m.prompt.options.find(o => /browser/i.test(o.id + o.label));
                        if (br) { lp.write(br.id + "\n"); return; }
                        s.step = "prompt"; s.prompt = m.prompt;
                        if (s.url) s.step = "url";
                        root.signin = s;
                        return;
                    }
                    const ev = m.ev ?? {};
                    if (ev.type === "auth_url") {
                        s.step = "url"; s.url = ev.url; s.msg = ev.instructions || "Finish signing in in your browser";
                        Qt.openUrlExternally(ev.url);
                    } else if (ev.type === "device_code") {
                        s.step = "code"; s.code = ev.userCode; s.url = ev.verificationUri; s.msg = "Enter this code on the sign-in page";
                        Qt.openUrlExternally(ev.verificationUri);
                    } else if (ev.message) {
                        s.msg = ev.message;
                        if (ev.links?.length) s.url = ev.links[0].url;
                    }
                    root.signin = s;
                }
            }
            stderr: StdioCollector { id: lerr }
            onExited: code => {
                if (root.signinProc === lp && !stopped && root.signin?.step !== "done")
                    root.signin = Object.assign({}, root.signin, { step: "error", msg: lp.err || lerr.text.trim().split("\n").pop() || "Sign-in failed" });
                if (root.signinProc === lp) root.signinProc = null;
                root.refreshAccounts();
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
        function bar(): void { Shell.close(); root.bar = !root.bar; }
        function auditChat(id: string): void {
            root.readChats();
            const c = root.chats.find(x => x.id === id);
            const m = c?.messages ?? [];
            for (let k = 1; k < m.length; k++) if (m[k].role === "assistant" && m[k - 1].role === "user") root.audit(m[k - 1].content, m[k]);
        }
        function aside(): void {
            if (!root.busy) return;
            if (Shell.open === "ai") root.reopen = "ai";
            Shell.close();
            root.bar = false;
            root.driving = true;
        }
        function barAsk(text: string): void { Shell.close(); root.bar = true; root.barAsked(text); }
        function chatId(): string { return root.chatId; }
        function open(id: string): void { root.openChat(id); }
        function forget(id: string): void { root.deleteChat(id); }
        function screenshot(): void { root.screenshot(); }
        function image(path: string): void { root.askAbout(path, ""); }
        function ask(text: string): void { root.askAbout("", text); }
        function send(text: string): void { Shell.open = "ai"; root.send(text); }
        function reset(): void { root.reset(); }
        function connect(url: string): void { root.connect(url || "https://mcp.koompi.cloud"); }
    }
}
