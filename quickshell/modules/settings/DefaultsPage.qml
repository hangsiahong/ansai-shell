import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 22

    // The first mime is the one read back as "current"; setting applies to all of them.
    readonly property var cats: [
        { id: "browser", l: "Web browser", icon: "public", mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html", "application/xhtml+xml"] },
        { id: "mail", l: "Email", icon: "mail", mimes: ["x-scheme-handler/mailto"] },
        { id: "files", l: "Files", icon: "folder", mimes: ["inode/directory"] },
        { id: "terminal", l: "Terminal", icon: "terminal", mimes: [] },
        { id: "text", l: "Text editor", icon: "edit_note", mimes: ["text/plain", "text/markdown", "application/json", "application/x-shellscript"] },
        { id: "pdf", l: "PDF", icon: "picture_as_pdf", mimes: ["application/pdf"] },
        { id: "image", l: "Images", icon: "image", mimes: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp", "image/tiff", "image/svg+xml", "image/avif", "image/heic"] },
        { id: "video", l: "Videos", icon: "movie", mimes: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo", "video/mpeg"] },
        { id: "music", l: "Music", icon: "music_note", mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav", "audio/mp4", "audio/aac", "audio/opus"] }
    ]
    property var handlers: ({})   // mime -> [desktop id]
    property var current: ({})    // cat id -> desktop id
    property string open: ""

    function entry(id) { return DesktopEntries.byId(id.replace(/\.desktop$/, "")); }
    function candidates(c) {
        if (c.id === "terminal")
            return DesktopEntries.applications.values.filter(e => !e.noDisplay && (e.categories ?? []).includes("TerminalEmulator"))
                .map(e => e.id).sort();
        const seen = {};
        for (const m of c.mimes.slice(0, 2))
            for (const id of root.handlers[m] ?? []) seen[id] = true;
        if (root.current[c.id]) seen[root.current[c.id]] = true;
        return Object.keys(seen).filter(id => { const e = root.entry(id); return e && !e.noDisplay; })
            .sort((a, b) => root.entry(a).name.localeCompare(root.entry(b).name));
    }
    function termId() {
        const t = Settings.terminal;
        const e = DesktopEntries.applications.values.find(e => (e.categories ?? []).includes("TerminalEmulator")
            && ((e.command?.[0] ?? "").split("/").pop() === t || e.id.toLowerCase().includes(t.toLowerCase())));
        return e?.id ?? "";
    }
    function pick(c, id) {
        root.open = "";
        if (c.id === "terminal") {
            const e = root.entry(id);
            Settings.terminal = (e?.command?.[0] ?? id).split("/").pop();
            return;
        }
        const d = id.endsWith(".desktop") ? id : id + ".desktop";
        const cmd = (c.id === "browser" ? "xdg-settings set default-web-browser \"$1\"; " : "") + "d=$1; shift; xdg-mime default \"$d\" \"$@\"";
        Quickshell.execDetached(["sh", "-c", cmd, "sh", d].concat(c.mimes));
        const cur = Object.assign({}, root.current);
        cur[c.id] = d;
        root.current = cur;
        later.restart();
    }

    Component.onCompleted: { scan.running = true; stateProc.running = true; }
    Timer { id: later; interval: 800; onTriggered: stateProc.running = true }

    // Every installed .desktop's MimeType line, user dirs first (their copies win).
    Process {
        id: scan
        command: ["sh", "-c", 'IFS=:; for d in "${XDG_DATA_HOME:-$HOME/.local/share}" ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do grep -H -m1 "^MimeType=" "$d"/applications/*.desktop 2>/dev/null; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const h = {}, done = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf(":MimeType=");
                    if (i < 0) continue;
                    const id = l.slice(0, i).split("/").pop();
                    if (done[id]) continue;
                    done[id] = true;
                    for (const m of l.slice(i + 10).split(";")) {
                        if (!m) continue;
                        (h[m] = h[m] ?? []).push(id);
                    }
                }
                root.handlers = h;
            }
        }
    }
    Process {
        id: stateProc
        command: ["sh", "-c", "echo \"browser\t$(xdg-settings get default-web-browser 2>/dev/null)\"; shift; for p in \"$@\"; do echo \"${p%%=*}\t$(xdg-mime query default \"${p#*=}\" 2>/dev/null)\"; done", "sh", "x"]
            .concat(root.cats.filter(c => c.mimes.length && c.id !== "browser").map(c => c.id + "=" + c.mimes[0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const cur = {};
                for (const l of text.trim().split("\n")) {
                    const [k, v] = l.split("\t");
                    if (v) cur[k] = v.trim();
                }
                root.current = cur;
            }
        }
    }

    SGroup {
        title: "Default apps"
        note: "Used when you open a link, file or folder."
        Repeater {
            model: root.cats
            SRow {
                id: cr
                required property var modelData
                required property int index
                readonly property string cur: modelData.id === "terminal" ? root.termId() : (root.current[modelData.id] ?? "")
                readonly property var ent: cur ? root.entry(cur) : null
                readonly property bool isOpen: root.open === modelData.id
                first: index === 0
                icon: modelData.icon
                title: modelData.l
                sub: cr.ent?.name ?? (modelData.id === "terminal" ? Settings.terminal : cr.cur ? cr.cur.replace(/\.desktop$/, "") : "Not set")
                clickable: true
                onClicked: root.open = cr.isOpen ? "" : modelData.id
                AppIcon {
                    visible: !!cr.ent
                    anchors.verticalCenter: parent.verticalCenter
                    size: 24
                    icon: cr.ent?.icon ?? ""
                    label: cr.ent?.name ?? ""
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "expand_more"
                    size: 16
                    color: Theme.muted
                    rotation: cr.isOpen ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: Theme.med } }
                }
                below: Column {
                    visible: cr.isOpen
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: cr.isOpen ? root.candidates(cr.modelData) : []
                        Hover {
                            id: opt
                            required property string modelData
                            readonly property var e: root.entry(modelData)
                            readonly property bool on: (opt.modelData.replace(/\.desktop$/, "")) === cr.cur.replace(/\.desktop$/, "")
                            width: parent.width
                            implicitHeight: 36
                            radius: 8
                            active: on
                            onClicked: root.pick(cr.modelData, opt.modelData)
                            AppIcon {
                                id: oi
                                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                                size: 22
                                icon: opt.e?.icon ?? ""
                                label: opt.e?.name ?? opt.modelData
                            }
                            Txt {
                                anchors { left: oi.right; leftMargin: 10; right: ck.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                text: opt.e?.name ?? opt.modelData
                                font.pixelSize: 13
                            }
                            Icon {
                                id: ck
                                visible: opt.on
                                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                name: "check"
                                size: 16
                                color: Theme.accent
                            }
                        }
                    }
                    Txt {
                        visible: cr.isOpen && !root.candidates(cr.modelData).length
                        text: "No other apps can open these"
                        font.pixelSize: 12
                        color: Theme.muted
                    }
                }
            }
        }
    }
}
