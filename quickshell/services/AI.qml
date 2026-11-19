pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// KOOMPI AI Gateway (OpenAI-compatible) via scripts/ai.py, which holds the key and streams the reply.
// ask() runs one request; the Ask AI sidebar's conversation lives here so it survives closing it.
Singleton {
    id: root

    readonly property string keyFile: Settings.dir + "/ai-key"
    readonly property string script: Quickshell.shellDir + "/scripts/ai.py"
    readonly property var models: ["koompi-luna", "koompi-smart", "koompi-fast", "koompi-lite", "koompi-balance"]
    property bool hasKey: false
    function checkKey(): void { keyCheck.running = false; keyCheck.running = true; }
    function setKey(key: string): void {
        keyWriter.key = key.trim();
        keyWriter.running = true;
    }

    readonly property string system: `You are the assistant built into ansai, the user's Linux desktop (niri + Quickshell). ` +
        `Be concise and practical. Reply in the language the user writes in (often Khmer or English). ` +
        `Use Markdown sparingly: short paragraphs, lists and code blocks when they help.`

    // ask([{ role, content, image? }], onDelta(text), onDone(fullText, error)) → handle with .stop()
    function ask(messages, onDelta, onDone) {
        const p = req.createObject(root, {
            body: JSON.stringify({ model: Settings.aiModel, messages: messages }),
            onDelta: onDelta ?? null,
            onDone: onDone ?? null
        });
        p.running = true;
        return p;
    }
    // One-shot instruction over some text: ask a system-style task, get the whole answer.
    function task(instruction: string, text: string, onDone, onDelta) {
        return ask([{ role: "system", content: instruction }, { role: "user", content: text }], onDelta, onDone);
    }

    // ---- sidebar conversation
    property var chat: []          // [{ role: "user"|"assistant", content, image?, error? }]
    property bool busy: false
    property var current: null
    property string draft: ""      // text waiting in the sidebar's input
    property string attachment: "" // image path to send with the next message

    function send(text: string): void {
        text = text.trim();
        if ((!text && !attachment) || busy) return;
        const user = { role: "user", content: text || "What's in this screenshot?" };
        if (attachment) user.image = attachment;
        attachment = "";
        const history = [{ role: "system", content: system }];
        // Older images are dropped from the context: only the newest one is sent.
        const prior = chat.filter(m => !m.error).map(m => ({ role: m.role, content: m.content }));
        chat = [...chat, user, { role: "assistant", content: "" }];
        busy = true;
        const i = chat.length - 1;
        current = ask([...history, ...prior, user], d => {
            const c = Array.from(chat);
            c[i] = { role: "assistant", content: c[i].content + d };
            chat = c;
        }, (full, err) => {
            const c = Array.from(chat);
            if (err) c[i] = { role: "assistant", content: c[i].content ? c[i].content + "\n\n" + err : err, error: !c[i].content };
            chat = c;
            busy = false;
            current = null;
        });
    }
    function stop(): void { if (current) current.stop(); }
    function reset(): void { stop(); chat = []; attachment = ""; }
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
                              `g=$(slurp -d) && grim -g "$g" "$f" && wl-copy < "$f" && echo "$f"`]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) root.askAbout(text.trim(), "") }
    }

    Component {
        id: req
        Process {
            id: p
            property string body
            property var onDelta
            property var onDone
            property string full: ""
            property string err: ""
            property bool stopped: false
            function stop() { stopped = true; running = false; }
            command: ["python3", root.script]
            stdinEnabled: true
            onStarted: { write(body); stdinEnabled = false; }
            stdout: SplitParser {
                onRead: line => {
                    let ev;
                    try { ev = JSON.parse(line); } catch (e) { return; }
                    if (ev.e) p.err = ev.e;
                    else if (ev.d) { p.full += ev.d; if (p.onDelta) p.onDelta(ev.d); }
                }
            }
            stderr: StdioCollector { id: errOut }
            onExited: code => {
                if (!err && code !== 0 && !stopped) err = errOut.text.trim().split("\n").pop() || "AI request failed";
                if (!err && !full && !stopped) err = "No answer came back";
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
    }
}
