import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Clipboard history (cliphist): type to filter, arrows to move, Enter or click copies and closes,
// Delete removes an entry. Images show a thumbnail, decoded on demand into $XDG_RUNTIME_DIR.
Sheet {
    id: root
    name: "clipboard"
    exclusiveKeys: true
    panelWidth: Math.min(Theme.m3 ? 600 : 620, width - 32)
    panelHeight: Math.min(560, 64 + Math.max(1, list.count) * 56 + 44)
    panelY: height * 0.16
    panelRadius: Theme.m3 ? 28 : 22

    property var all: []       // [{ id, text, image, ext }]
    property string query: ""
    property int sel: 0
    property bool confirmWipe: false
    readonly property string cache: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ansai-clip"
    readonly property var items: {
        const q = query.trim().toLowerCase();
        return q ? all.filter(e => e.text.toLowerCase().includes(q)) : all;
    }

    onShownChanged: if (shown) {
        query = ""; input.text = ""; sel = 0; confirmWipe = false;
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
                onTextChanged: { root.query = text; root.sel = 0; }
                Keys.onEscapePressed: Shell.close()
                Keys.onReturnPressed: root.copy(root.sel)
                Keys.onEnterPressed: root.copy(root.sel)
                Keys.onDownPressed: root.sel = Math.min(root.items.length - 1, root.sel + 1)
                Keys.onUpPressed: root.sel = Math.max(0, root.sel - 1)
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Delete) { root.remove(root.sel); e.accepted = true; }
                    else if (e.key === Qt.Key_PageDown) { root.sel = Math.min(root.items.length - 1, root.sel + 8); e.accepted = true; }
                    else if (e.key === Qt.Key_PageUp) { root.sel = Math.max(0, root.sel - 8); e.accepted = true; }
                }
                Txt { anchors.fill: parent; visible: !input.text; text: "Search clipboard history"; color: Theme.faint; font.pixelSize: 18 }
            }
            Txt {
                id: count
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: root.items.length + (root.query ? " / " + root.all.length : "")
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
                text: loader.running ? "Loading…" : root.query ? "No matches" : "Nothing copied yet"
                color: Theme.muted
                font.pixelSize: 14
            }
        }

        // ---- footer
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 4
            Layout.preferredHeight: 32
            Txt { Layout.fillWidth: true; text: "Enter copies · Delete removes · Esc closes"; font.pixelSize: 12; color: Theme.faint }
            Hover {
                visible: root.all.length > 0
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
