import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Quick Note (Alt+N): jot something down without leaving what you're doing. Opens on the latest note,
// saves as you type to ~/.local/share/ansai-shell/notes.json. Ctrl+N new note, Esc closes.
Sheet {
    id: root
    name: "note"
    exclusiveKeys: true
    panelWidth: Math.min(680, width - 32)
    panelHeight: Math.min(440, height - 120)
    panelY: Theme.barH + 40
    panelRadius: Theme.m3 ? 28 : 22

    property var notes: []      // [{ id, text, updated }], newest first
    property string cur: ""
    readonly property var note: notes.find(n => n.id === cur) ?? null

    readonly property string file: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/ansai-shell/notes.json"
    FileView {
        id: store
        path: root.file
        printErrors: false
        atomicWrites: true
        blockLoading: true
        onLoaded: { try { root.notes = JSON.parse(text()); } catch (e) { root.notes = []; } }
    }
    Timer { id: saver; interval: 400; onTriggered: root.persist() }
    function persist(): void {
        Quickshell.execDetached(["mkdir", "-p", root.file.slice(0, root.file.lastIndexOf("/"))]);
        store.setText(JSON.stringify(notes.filter(n => n.text.trim())));
    }

    onShownChanged: {
        if (shown) {
            // Reuse an empty note at the top, otherwise open the latest one.
            if (!notes.length) newNote();
            else open(notes[0].id);
            editor.forceActiveFocus();
            editor.cursorPosition = editor.text.length;
        } else {
            notes = notes.filter(n => n.text.trim());
            persist();
        }
    }

    function open(id: string): void {
        cur = id;
        editor.text = note?.text ?? "";
    }
    function newNote(): void {
        if (notes.length && !notes[0].text.trim()) { open(notes[0].id); return; }
        const n = { id: Date.now().toString(36), text: "", updated: Date.now() };
        notes = [n, ...notes];
        open(n.id);
        editor.forceActiveFocus();
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
    function title(n): string { return (n.text.trim().split("\n")[0] || "New note").slice(0, 60); }
    function when(t: real): string {
        const d = new Date(t), now = new Date();
        return d.toDateString() === now.toDateString() ? Qt.formatTime(d, Settings.use24h ? "HH:mm" : "h:mm AP") : Qt.formatDate(d, "d MMM");
    }

    Row {
        anchors.fill: parent
        anchors.margins: 10

        // Notes list
        Item {
            width: 200
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
                    onClicked: { root.open(modelData.id); editor.forceActiveFocus(); }
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
            width: parent.width - 201
            height: parent.height
            Txt {
                id: stamp
                x: 18; y: 10
                text: root.note ? root.when(root.note.updated) : ""
                font.pixelSize: 11
                color: Theme.muted
            }
            IconButton {
                anchors { right: parent.right; rightMargin: 6; verticalCenter: stamp.verticalCenter }
                icon: "delete"; iconSize: 18; iconColor: Theme.muted
                visible: !!root.note && root.note.text.trim() !== ""
                onClicked: root.remove(root.cur)
            }
            Flickable {
                id: flick
                anchors { top: stamp.bottom; topMargin: 10; left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: 8 }
                contentHeight: editor.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                function follow(r) {
                    if (r.y < contentY) contentY = r.y;
                    else if (r.y + r.height > contentY + height) contentY = r.y + r.height - height;
                }
                TextEdit {
                    id: editor
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
                    onCursorRectangleChanged: flick.follow(cursorRectangle)
                    Keys.onEscapePressed: Shell.close()
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
        }
    }
}
