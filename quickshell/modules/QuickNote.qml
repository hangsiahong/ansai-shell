import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import "notemd.js" as Md

// Quick Note (Alt+N): jot something down without leaving what you're doing. Opens on the latest note,
// saves as you type to ~/.local/share/ansai-shell/notes.json. Ctrl+N new note, Esc stops editing, then closes.
// Notes are Markdown: shown formatted (click a line to edit there, click ☐ to tick it), plain while you type.
Sheet {
    id: root
    name: "note"
    exclusiveKeys: true
    panelWidth: Math.min(960, width - 64)
    panelHeight: Math.min(680, height - Theme.barH - 80)
    panelY: Theme.barH + 40
    panelRadius: Theme.m3 ? 28 : 22

    property var notes: []      // [{ id, text, updated }], newest first
    property string cur: ""
    readonly property var note: notes.find(n => n.id === cur) ?? null
    property bool reading: false
    readonly property var md: !reading ? ({ html: "", lines: [] }) : Md.render(editor.text, {
        text: Theme.text.toString(), muted: Theme.muted.toString(), accent: Theme.accent.toString(),
        code: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.14).toString()
    })
    // Formatted view → editing, with the cursor at the end of source line i (-1: end of the note).
    function write(i: int): void {
        reading = false;
        editor.forceActiveFocus();
        if (i < 0) { editor.cursorPosition = editor.text.length; return; }
        const l = editor.text.split("\n");
        editor.cursorPosition = l.slice(0, i + 1).join("\n").length;
    }
    function read(): void { if (editor.text.trim()) { reading = true; keys.forceActiveFocus(); } }

    readonly property string file: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/ansai-shell/notes.json"
    FileView {
        id: store
        path: root.file
        printErrors: false
        atomicWrites: true
        blockLoading: true
        watchChanges: true   // Ask Ansai's quick_note tools write the same file
        onFileChanged: reload()
        onLoaded: root.merge(text())
    }
    property string lastSaved: ""
    // Take in notes changed outside the panel, keeping an unsaved empty note and anything typed but not yet saved.
    function merge(t: string): void {
        if (t === lastSaved) return;
        let l = [];
        try { l = JSON.parse(t || "[]"); } catch (e) { return; }
        const mine = note;
        if (saver.running && mine) l = [mine, ...l.filter(n => n.id !== mine.id)];
        else if (mine && !mine.text.trim() && !l.some(n => n.id === mine.id)) l = [mine, ...l];
        notes = l;
        const now = notes.find(n => n.id === cur);
        if (!now && notes.length) open(notes[0].id);
        else if (now && now.text !== editor.text) { if (!editor.activeFocus) reading = !!now.text.trim(); const c = editor.cursorPosition; editor.text = now.text; editor.cursorPosition = Math.min(c, editor.text.length); }
    }
    Timer { id: saver; interval: 400; onTriggered: root.persist() }
    function persist(): void {
        Quickshell.execDetached(["mkdir", "-p", root.file.slice(0, root.file.lastIndexOf("/"))]);
        lastSaved = JSON.stringify(notes.filter(n => n.text.trim()));
        store.setText(lastSaved);
    }

    onShownChanged: {
        if (shown) {
            // Reuse an empty note at the top, otherwise open the latest one.
            if (!notes.length) newNote();
            else open(notes[0].id);
        } else {
            notes = notes.filter(n => n.text.trim());
            persist();
        }
    }

    // ---- Ask Ansai inside the note
    property string askA: ""
    property bool askBusy: false
    property bool askErr: false
    property var askProc: null
    property var askLast: null   // previous question and answer, so follow-ups work
    function askNote(q: string): void {
        q = q.trim();
        if (!q || askBusy) return;
        if (!AI.hasKey) { askA = "Add your KOOMPI AI key in Settings → AI first."; askErr = true; return; }
        askIn.text = "";
        askA = ""; askErr = false; askBusy = true;
        const id = cur;
        const msgs = [{ role: "system", content: `You help with a note in the user's Quick Note. Today is ${Qt.formatDate(new Date(), "dddd d MMMM yyyy")}.
When asked to write, rewrite, fix, summarize, translate, continue or turn it into a list, reply with only the text to put in the note:
no preamble, no quotes. The note shows Markdown formatted, so write it well: "# Title" for a new note, "## " sections,
"- " bullets, "- [ ] " to-dos, **bold** for key words, short lines; no tables or HTML. For questions about the note, answer briefly. Match the note's language
unless asked to translate. The clipboard tool reads what the user copied (now, or search/list older copies); use it when they mention
the clipboard, "what I copied" or pasting, and put that content into your answer.\n\nThe note:\n<<<\n${editor.text}\n>>>` }];
        if (askLast) msgs.push({ role: "user", content: askLast.q }, { role: "assistant", content: askLast.a });
        msgs.push({ role: "user", content: q });
        askProc = AI.ask(msgs, d => { if (cur === id) askA += d; }, (full, err) => {
            askBusy = false; askProc = null;
            if (cur !== id) return;
            if (err) { askA = err; askErr = true; return; }
            askA = (full ?? askA).trim();
            askLast = { q: q, a: askA };
        }, { only: ["clipboard"] });
    }
    function useAnswer(replace: bool): void {
        const t = askA.trim();
        if (!t) return;
        editor.text = replace ? t : editor.text.replace(/\s*$/, "") + (editor.text.trim() ? "\n\n" : "") + t;
        askA = ""; askLast = null;
        read();
    }
    onCurChanged: { if (askProc) askProc.stop(); askA = ""; askBusy = false; askLast = null; }

    function open(id: string): void {
        cur = id;
        editor.text = note?.text ?? "";
        if (editor.text.trim()) read(); else write(-1);
    }
    function newNote(): void {
        if (notes.length && !notes[0].text.trim()) { open(notes[0].id); return; }
        const n = { id: Date.now().toString(36), text: "", updated: Date.now() };
        notes = [n, ...notes];
        open(n.id);
    }
    function edit(t: string): void {
        if (!note || note.text === t) return;
        const n = Object.assign({}, note, { text: t, updated: Date.now() });
        notes = [n, ...notes.filter(x => x.id !== n.id)];
        saver.restart();
    }
    function remove(id: string): void {
        notes = notes.filter(n => n.id !== id);
        persist();
        if (notes.length) open(notes[0].id); else newNote();
    }
    function title(n): string { return (Md.title(n.text) || "New note").slice(0, 60); }
    function when(t: real): string {
        const d = new Date(t), now = new Date();
        return d.toDateString() === now.toDateString() ? Qt.formatTime(d, Settings.use24h ? "HH:mm" : "h:mm AP") : Qt.formatDate(d, "d MMM");
    }

    Row {
        anchors.fill: parent
        anchors.margins: 10

        // Notes list
        Item {
            width: 230
            height: parent.height
            Row {
                id: head
                x: 8; y: 6
                spacing: 4
                Txt { text: "Quick Note"; font.pixelSize: 15; font.weight: Theme.strong; anchors.verticalCenter: parent.verticalCenter }
            }
            IconButton {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: head.verticalCenter }
                icon: "edit_square"; iconSize: 18
                onClicked: root.newNote()
            }
            ListView {
                anchors { top: head.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
                clip: true
                spacing: 2
                model: root.notes
                boundsBehavior: Flickable.StopAtBounds
                delegate: Hover {
                    id: row
                    required property var modelData
                    width: ListView.view.width - 6
                    height: 48
                    radius: Theme.m3 ? 24 : 10
                    active: modelData.id === root.cur
                    activeColor: Theme.m3 ? Theme.accentSoft : Theme.fill
                    onClicked: root.open(modelData.id)
                    Column {
                        anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        Txt { width: parent.width; text: root.title(row.modelData); font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight }
                        Txt { text: root.when(row.modelData.updated); font.pixelSize: 11; color: Theme.muted }
                    }
                }
            }
        }

        Rectangle { width: 1; height: parent.height; color: Theme.line }

        // Editor
        Item {
            width: parent.width - 231
            height: parent.height
            Txt {
                id: stamp
                x: 18; y: 10
                text: root.note ? root.when(root.note.updated) : ""
                font.pixelSize: 11
                color: Theme.muted
            }
            IconButton {
                anchors { right: del.left; rightMargin: 2; verticalCenter: stamp.verticalCenter }
                icon: root.reading ? "edit" : "visibility"; iconSize: 18; iconColor: Theme.muted
                visible: !!root.note && root.note.text.trim() !== ""
                onClicked: root.reading ? root.write(-1) : root.read()
            }
            IconButton {
                id: del
                anchors { right: parent.right; rightMargin: 6; verticalCenter: stamp.verticalCenter }
                icon: "delete"; iconSize: 18; iconColor: Theme.muted
                visible: !!root.note && root.note.text.trim() !== ""
                onClicked: root.remove(root.cur)
            }
            Flickable {
                id: flick
                anchors { top: stamp.bottom; topMargin: 10; left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 14; bottom: askBox.top; bottomMargin: 8 }
                contentHeight: root.reading ? view.contentHeight : editor.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                function follow(r) {
                    if (r.y < contentY) contentY = r.y;
                    else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
                }
                // Formatted view. Typing here starts a new line at the end.
                TextEdit {
                    id: view
                    visible: root.reading
                    width: flick.width
                    readOnly: true
                    selectByMouse: false
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.RichText
                    text: root.md.html
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    onLinkActivated: link => {
                        if (link.startsWith("tick:")) editor.text = Md.tick(editor.text, +link.slice(5));
                        else Qt.openUrlExternally(link);
                    }
                    HoverHandler { cursorShape: view.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
                    TapHandler {
                        onTapped: (ev) => {
                            if (view.linkAt(ev.position.x, ev.position.y)) return;
                            const p = view.positionAt(ev.position.x, ev.position.y);
                            const b = view.getText(0, p).split(String.fromCharCode(0x2029)).length - 1;
                            root.write(ev.position.y > view.contentHeight ? -1 : root.md.lines[b] ?? -1);
                        }
                    }
                }
                Item {
                    id: keys
                    Keys.onEscapePressed: Shell.close()
                    Keys.onPressed: e => {
                        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_N) { root.newNote(); e.accepted = true; return; }
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { root.write(-1); editor.insert(editor.cursorPosition, "\n"); e.accepted = true; return; }
                        if (e.text && e.text.charCodeAt(0) >= 32 && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                            root.write(-1);
                            editor.insert(editor.cursorPosition, (editor.text.endsWith("\n") ? "" : "\n") + e.text);
                            e.accepted = true;
                        }
                    }
                }
                TextEdit {
                    id: editor
                    visible: !root.reading
                    width: flick.width
                    height: Math.max(flick.height, contentHeight)
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    selectByMouse: true
                    focus: true
                    onTextChanged: root.edit(text)
                    onCursorRectangleChanged: if (activeFocus) flick.follow(cursorRectangle)
                    Keys.onEscapePressed: if (text.trim()) root.read(); else Shell.close()
                    Keys.onPressed: e => {
                        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_N) { root.newNote(); e.accepted = true; }
                    }
                    Txt {
                        visible: !editor.text
                        text: "Write something…"
                        color: Theme.faint
                        font.pixelSize: 15
                    }
                }
            }

            // Ask Ansai about this note: the answer can go into the note or replace it.
            Column {
                id: askBox
                anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 6; bottom: parent.bottom; bottomMargin: 4 }
                spacing: 6
                Rectangle {
                    visible: root.askA !== "" || root.askBusy
                    width: parent.width
                    height: Math.min(170, ans.contentHeight + 20) + (ansBtns.visible ? ansBtns.height + 8 : 0)
                    radius: 14
                    color: Theme.m3 ? Theme.surface3 : Theme.fill2
                    Flickable {
                        id: ansFlick
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        height: Math.min(170, ans.contentHeight + 20) - 20
                        contentHeight: ans.contentHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        onContentHeightChanged: if (root.askBusy) contentY = Math.max(0, contentHeight - height)
                        TextEdit {
                            id: ans
                            width: ansFlick.width
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.MarkdownText
                            text: root.askA || "…"
                            color: root.askErr ? Theme.danger : Theme.text
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                    }
                    Row {
                        id: ansBtns
                        anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                        spacing: 4
                        visible: !root.askBusy && !root.askErr && root.askA !== ""
                        Repeater {
                            model: [
                                { l: "Add to note", f: () => root.useAnswer(false) },
                                { l: "Replace note", f: () => root.useAnswer(true) },
                                { l: "Dismiss", f: () => { root.askA = ""; } }
                            ]
                            delegate: Hover {
                                required property var modelData
                                width: bl.implicitWidth + 20; height: 26
                                radius: 13
                                base: Theme.m3 ? Theme.tonal : Theme.fill
                                onClicked: modelData.f()
                                Txt { id: bl; anchors.centerIn: parent; text: parent.modelData.l; font.pixelSize: 12 }
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 36
                    radius: 18
                    color: Theme.m3 ? Theme.surface3 : Theme.fill2
                    Icon { id: sp; x: 12; anchors.verticalCenter: parent.verticalCenter; name: "auto_awesome"; size: 17; color: Theme.accent }
                    TextInput {
                        id: askIn
                        anchors { left: sp.right; leftMargin: 8; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        clip: true
                        onAccepted: root.askNote(text)
                        Keys.onEscapePressed: { if (text) text = ""; else editor.forceActiveFocus(); }
                        Txt {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !askIn.text
                            text: root.askBusy ? "Thinking…" : "Ask Ansai about this note (summarize, fix, translate, add a to-do…)"
                            color: Theme.faint
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }
}
