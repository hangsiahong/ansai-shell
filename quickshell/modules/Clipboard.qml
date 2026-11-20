import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Clipboard history (cliphist): type to filter, arrows to move, Enter or click copies and closes,
// Delete removes an entry. Images show a thumbnail, decoded on demand into $XDG_RUNTIME_DIR.
// AI (services/AI.qml): Ctrl+T translate, Ctrl+S summarize, Ctrl+E fix writing, Ctrl+J ask in the
// sidebar; Tab asks AI to find an entry from a description ("the wifi password from yesterday").
// Images: Ctrl+O shows the text in them (scripts/ocr.sh, English and Khmer), Enter copies it.
Sheet {
    id: root
    name: "clipboard"
    exclusiveKeys: true
    panelWidth: Math.min(Theme.m3 ? 600 : 620, width - 32)
    panelHeight: mode === "result" ? 460 : Math.min(560, 64 + Math.max(1, list.count) * 56 + 44)
    panelY: height * 0.16
    panelRadius: Theme.m3 ? 28 : 22

    property var all: []       // [{ id, text, image, ext }]
    property string query: ""
    property int sel: 0
    property bool confirmWipe: false
    readonly property string cache: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ansai-clip"
    readonly property var items: {
        if (aiIds) return aiIds.map(id => all.find(e => e.id === id)).filter(e => !!e);
        const q = query.trim().toLowerCase();
        return q ? all.filter(e => e.text.toLowerCase().includes(q)) : all;
    }

    // ---- AI
    property string mode: ""        // "" list | "result"
    property string resultTitle: ""
    property string resultText: ""
    property string resultErr: ""
    property bool resultBusy: false
    property var handle: null
    property var aiIds: null        // ids picked by "Ask Ansai to find", in its order
    property bool finding: false
    readonly property var actions: [
        { k: "translate", l: "Translate", i: "translate", key: "Ctrl+T", t: "Translation" },
        { k: "summarize", l: "Summarize", i: "summarize", key: "Ctrl+S", t: "Summary" },
        { k: "fix", l: "Fix writing", i: "spellcheck", key: "Ctrl+E", t: "Fixed writing" },
        { k: "ask", l: "Ask Ansai", i: "auto_awesome", key: "Ctrl+J", t: "" },
        { k: "ocr", l: "Copy text", i: "document_scanner", key: "Ctrl+O", t: "Text in the image", image: true }
    ]
    function prompt(k) {
        const lang = Settings.aiLang;
        return k === "translate" ? `Translate the user's text. If it is in ${lang}, translate it to English; otherwise translate it to ${lang}. Reply with only the translation, keeping the formatting.`
             : k === "summarize" ? "Summarize the user's text in a few short bullet points, in the same language as the text. Reply with only the summary."
             : "Fix spelling, grammar and punctuation in the user's text. Keep its meaning, tone, language and formatting. Reply with only the corrected text.";
    }
    function act(k) {
        const e = items[sel];
        if (!e || mode === "result") return;
        if (e.image) {
            if (k === "ask") AI.askAbout(`${cache}/${e.id}.${e.ext}`, "");
            if (k !== "ocr") return;
            ocr.command = ["sh", "-c", `[ -s "$2" ] || printf '%s\\t\\n' "$1" | cliphist decode > "$2"; exec "$0" "$2"`,
                           Quickshell.shellDir + "/scripts/ocr.sh", e.id, `${cache}/${e.id}.${e.ext}`];
            ocr.running = true;
            mode = "result";
            resultTitle = "Text in the image";
            resultText = ""; resultErr = ""; resultBusy = true;
            return;
        }
        if (k === "ocr") return;
        decoder.kind = k;
        decoder.command = ["sh", "-c", `printf '%s\\t\\n' "$1" | cliphist decode`, "sh", e.id];
        decoder.running = true;
        if (k === "ask") return;
        mode = "result";
        resultTitle = actions.find(x => x.k === k).t;
        resultText = ""; resultErr = ""; resultBusy = true;
    }
    function run(k, text) {
        if (k === "ask") { AI.askAbout("", text.trim() + "\n\n"); return; }
        handle = AI.task(prompt(k), text, (full, err) => {
            resultBusy = false; handle = null;
            if (err) resultErr = err;
            else resultText = full.trim();
        }, d => resultText += d);
    }
    function back() {
        if (handle) handle.stop();
        handle = null; mode = ""; resultBusy = false;
        input.forceActiveFocus();
    }
    function copyResult() {
        if (!resultText || resultBusy) return;
        Quickshell.execDetached(["wl-copy", "--", resultText.trim()]);
        Shell.close();
    }
    function find() {
        const q = query.trim();
        if (!q || finding || mode === "result") return;
        const lines = all.slice(0, 250).filter(e => !e.image).map(e => e.id + "\t" + e.text.replace(/\s+/g, " ").slice(0, 160));
        finding = true;
        resultErr = "";
        AI.task("You search a clipboard history. Each history line is `id<TAB>text`. Reply with only a JSON array of the ids " +
                "(as strings) of entries matching the user's description, best match first, at most 8. Reply [] if none match.",
                "Description: " + q + "\n\nHistory:\n" + lines.join("\n"), (full, err) => {
            finding = false;
            if (err) { resultErr = err; return; }
            const m = full.match(/\[[\s\S]*?\]/);
            let ids = [];
            try { ids = m ? JSON.parse(m[0]).map(String) : []; } catch (x) {}
            aiIds = ids;
            sel = 0;
        });
    }

    Process {
        id: ocr
        stdout: StdioCollector { id: ocrOut }
        stderr: StdioCollector { id: ocrErr }
        onExited: {
            root.resultBusy = false;
            root.resultText = ocrOut.text.trim();
            if (!root.resultText) root.resultErr = ocrErr.text.trim() || "No text found in this image";
        }
    }
    Process {
        id: decoder
        property string kind
        stdout: StdioCollector { onStreamFinished: root.run(decoder.kind, text) }
    }

    onShownChanged: if (shown) {
        query = ""; input.text = ""; sel = 0; confirmWipe = false;
        mode = ""; aiIds = null; finding = false; resultErr = "";
        loader.running = true;
        input.forceActiveFocus();
    }

    Process {
        id: loader
        command: ["sh", "-c", `mkdir -p '${root.cache}'; cliphist list`]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const id = line.slice(0, tab), body = line.slice(tab + 1);
                    const m = body.match(/^\[\[ binary data (.+?) (png|jpe?g|webp|gif|bmp) (\d+)x(\d+) \]\]$/i);
                    out.push(m ? { id: id, image: true, ext: m[2].toLowerCase(), text: `Image · ${m[3]} × ${m[4]} · ${m[1]}` }
                               : { id: id, image: false, ext: "", text: body });
                }
                root.all = out;
            }
        }
    }

    function copy(i) {
        const e = items[i];
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", `printf '%s\\t\\n' '${e.id}' | cliphist decode | wl-copy`]);
        Shell.close();
    }
    function remove(i) {
        const e = items[i];
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", `printf '%s\\t\\n' '${e.id}' | cliphist delete`]);
        all = all.filter(x => x.id !== e.id);
        sel = Math.min(sel, items.length - 1);
    }
    function wipe() {
        Quickshell.execDetached(["sh", "-c", `cliphist wipe; rm -rf '${cache}'`]);
        all = [];
        confirmWipe = false;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // ---- search
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.m3 ? 52 : 44
            radius: height / 2
            color: Theme.m3 ? Theme.surface3 : "transparent"
            Icon { id: sIcon; x: 14; anchors.verticalCenter: parent.verticalCenter; name: "content_paste_search"; size: 22; color: Theme.muted }
            TextInput {
                id: input
                anchors { left: sIcon.right; leftMargin: 10; right: count.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 18
                clip: true
                focus: true
                onTextChanged: { root.query = text; root.sel = 0; root.aiIds = null; root.resultErr = ""; }
                Keys.onEscapePressed: root.mode === "result" ? root.back() : root.aiIds ? (root.aiIds = null) : Shell.close()
                Keys.onReturnPressed: root.mode === "result" ? root.copyResult() : root.copy(root.sel)
                Keys.onEnterPressed: root.mode === "result" ? root.copyResult() : root.copy(root.sel)
                Keys.onTabPressed: root.find()
                Keys.onDownPressed: root.sel = Math.min(root.items.length - 1, root.sel + 1)
                Keys.onUpPressed: root.sel = Math.max(0, root.sel - 1)
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Delete) { root.remove(root.sel); e.accepted = true; }
                    else if (e.key === Qt.Key_PageDown) { root.sel = Math.min(root.items.length - 1, root.sel + 8); e.accepted = true; }
                    else if (e.key === Qt.Key_PageUp) { root.sel = Math.max(0, root.sel - 8); e.accepted = true; }
                    else if (e.modifiers & Qt.ControlModifier) {
                        const k = { [Qt.Key_T]: "translate", [Qt.Key_S]: "summarize", [Qt.Key_E]: "fix", [Qt.Key_J]: "ask", [Qt.Key_O]: "ocr" }[e.key];
                        if (k) { root.act(k); e.accepted = true; }
                    }
                }
                Txt { anchors.fill: parent; visible: !input.text; text: "Search clipboard history"; color: Theme.faint; font.pixelSize: 18 }
            }
            Txt {
                id: count
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: root.finding ? "Asking AI…" : root.aiIds ? "✦ " + root.items.length + " found" : root.items.length + (root.query ? " / " + root.all.length : "")
                font.pixelSize: 12
                color: Theme.faint
                font.features: { "tnum": 1 }
            }
        }

        // ---- entries
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.mode !== "result"
            model: root.items
            clip: true
            spacing: 2
            currentIndex: root.sel
            highlightMoveDuration: 0
            boundsBehavior: Flickable.StopAtBounds
            delegate: Hover {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: modelData.image ? 64 : 48
                radius: Theme.m3 ? height / 2 : 10
                active: index === root.sel
                activeColor: Theme.m3 ? Theme.accentSoft : Theme.accent
                readonly property color ink: active ? (Theme.m3 ? Theme.accentSoftInk : "#ffffff") : Theme.text
                onClicked: m => { if (m.button === Qt.MiddleButton) root.remove(index); else root.copy(index); }
                onHoveredChanged: if (hovered) root.sel = index

                // Image entries: decode once into the cache, then show it.
                property string thumb: ""
                Process {
                    running: row.modelData.image
                    command: ["sh", "-c", `f='${root.cache}/${row.modelData.id}.${row.modelData.ext}'; [ -s "$f" ] || printf '%s\\t\\n' '${row.modelData.id}' | cliphist decode > "$f"; echo "$f"`]
                    stdout: StdioCollector { onStreamFinished: row.thumb = text.trim() }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                    spacing: 12
                    Rectangle {
                        visible: row.modelData.image
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 48
                        radius: 8
                        color: Theme.surface3
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: row.thumb ? "file://" + row.thumb : ""
                            sourceSize.width: 144
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Icon { visible: !row.modelData.image; name: /^https?:\/\//.test(row.modelData.text) ? "link" : "notes"; size: 18; color: row.active ? row.ink : Theme.muted }
                    Txt {
                        Layout.fillWidth: true
                        text: row.modelData.text.replace(/\s+/g, " ").trim()
                        font.pixelSize: 14
                        color: row.ink
                        elide: Text.ElideRight
                    }
                    Txt {
                        visible: row.active
                        text: "↵ copy · del"
                        font.pixelSize: 11
                        color: Theme.m3 ? Theme.accentSoftInk : Qt.rgba(1, 1, 1, 0.75)
                    }
                }
            }

            Txt {
                anchors.centerIn: parent
                visible: list.count === 0
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: loader.running ? "Loading…" : root.resultErr ? root.resultErr : root.aiIds ? "AI found nothing like that"
                    : root.query ? "No matches · press Tab to ask AI to find it" : "Nothing copied yet"
                color: Theme.muted
                font.pixelSize: 14
            }
        }

        // ---- AI result
        ColumnLayout {
            visible: root.mode === "result"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 8
            RowLayout {
                spacing: 8
                Icon { name: "auto_awesome"; size: 18; filled: true; color: Theme.accent }
                Txt { text: root.resultTitle; font.pixelSize: 14; font.weight: Theme.strong }
                Txt { visible: root.resultBusy; text: "· " + AI.modelLabel; font.pixelSize: 12; color: Theme.faint }
            }
            Flickable {
                id: resFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: res.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: res
                    width: resFlick.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    text: root.resultErr || root.resultText 
                    color: root.resultErr ? Theme.danger : Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentInk
                    font.family: Theme.font
                    font.pixelSize: 15
                    TypingDots { visible: !res.text; y: (res.contentHeight - height) / 2; color: res.color }
                }
            }
        }

        // ---- footer
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.preferredHeight: 32
            spacing: 4

            // AI actions on the selected entry (images: only Ask Ansai)
            Repeater {
                model: root.mode === "result" ? [] : root.actions.filter(a => root.items[root.sel]?.image ? (a.k === "ask" || a.image) : !a.image)
                Hover {
                    required property var modelData
                    visible: root.items.length > 0
                    implicitWidth: aRow.implicitWidth + 20
                    implicitHeight: 28
                    radius: 14
                    base: Theme.m3 ? Theme.surface3 : Theme.glassTile
                    onClicked: root.act(modelData.k)
                    Row {
                        id: aRow
                        anchors.centerIn: parent
                        spacing: 5
                        Icon { name: modelData.i; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Txt { text: modelData.l; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            Txt {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                text: root.mode === "result" ? (root.resultBusy ? (root.resultTitle === "Text in the image" ? "Reading the image…" : "Writing…") : "Enter copies · Esc goes back")
                    : root.items.length ? "" : "Enter copies · Delete removes · Esc closes"
                font.pixelSize: 12
                color: Theme.faint
            }
            Hover {
                visible: root.mode === "result" && !root.resultBusy && !!root.resultText
                implicitWidth: cpRow.implicitWidth + 24
                implicitHeight: 28
                radius: 14
                base: Theme.accent
                onClicked: root.copyResult()
                Row {
                    id: cpRow
                    anchors.centerIn: parent
                    spacing: 5
                    Icon { name: "content_copy"; size: 15; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
                    Txt { text: "Copy"; font.pixelSize: 12; font.weight: Theme.strong; color: Theme.accentInk; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Hover {
                visible: root.all.length > 0 && root.mode !== "result"
                implicitWidth: wipeLbl.implicitWidth + 20
                implicitHeight: 28
                radius: 14
                base: root.confirmWipe ? Theme.danger : "transparent"
                onClicked: root.confirmWipe ? root.wipe() : (root.confirmWipe = true)
                Txt {
                    id: wipeLbl
                    anchors.centerIn: parent
                    text: root.confirmWipe ? "Click again to clear all" : "Clear history"
                    font.pixelSize: 12
                    color: root.confirmWipe ? "#ffffff" : Theme.danger
                }
            }
        }
    }
}
