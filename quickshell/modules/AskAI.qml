import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// "Ask AI" sidebar on the right (Mod+I). The conversation lives in services/AI.qml, so closing
// and reopening keeps it. Attach a screenshot (pick an area) or paste the clipboard into the question.
Sheet {
    id: root
    name: "ai"
    exclusiveKeys: true
    enterFrom: 0
    // "side": a panel on the right; "center": big in the middle, with the chat list beside it.
    readonly property bool big: Settings.aiLayout === "center"
    property bool showHistory: false
    dim: big
    panelWidth: big ? Math.min(1200, width - 96) : Math.min(440, width - 24)
    panelX: big ? (width - panelWidth) / 2 : width - panelWidth - 10
    panelY: big ? Theme.barH + 32 : Theme.barH + 8
    panelHeight: height - panelY - (big ? 32 : 10)
    panelRadius: Theme.m3 ? 28 : 22

    onShownChanged: if (shown) {
        if (AI.draft) { input.text = AI.draft; AI.draft = ""; input.cursorPosition = input.text.length; }
        input.forceActiveFocus();
        AI.checkKey();
        AI.refreshMcp();
    }

    // Qt's Markdown lists indent 40 px per level, which wastes a narrow panel: render bullets and
    // numbered items as tight lines instead (code blocks left alone).
    function tight(md) {
        if (!md) return "";
        let fence = false;
        return md.split("\n").map(l => {
            if (/^\s*```/.test(l)) { fence = !fence; return l; }
            if (fence) return l;
            const b = l.match(/^(\s*)[-*+]\s+(.*)$/);
            // Trailing double space = hard line break, so items don't merge into the line above.
            if (b) return "\u2003".repeat(Math.floor(b[1].length / 2)) + (b[1].length >= 2 ? "◦ " : "• ") + b[2] + "  ";
            const n = l.match(/^(\s*)(\d+)[.)]\s+(.*)$/);
            if (n) return "\u2003".repeat(Math.floor(n[1].length / 2)) + n[2] + "\\. " + n[3] + "  ";
            return l.trim() && !/^\s*\|/.test(l) ? l + "  " : l;
        }).join("\n");
    }

    function send() {
        if (AI.busy) return;
        AI.send(input.text);
        if (!AI.busy) return;
        input.text = "";
    }

    Process {
        id: paste
        // An image on the clipboard (e.g. a screenshot) is saved and attached; otherwise the text is pasted.
        command: ["sh", "-c", `t=$(wl-paste -l 2>/dev/null | grep -m1 '^image/'); if [ -n "$t" ]; then ` +
            `d='${AI.dataDir}/ai-images'; mkdir -p "$d"; f="$d/paste-$(date +%s%N).\${t#image/}"; ` +
            `wl-paste -t "$t" > "$f" && echo "IMG:$f"; else wl-paste -n -t text; fi`]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.startsWith("IMG:")) { AI.attachment = text.slice(4).trim(); input.forceActiveFocus(); return; }
                const t = text.trim();
                if (!t) return;
                input.text = (input.text ? input.text + "\n\n" : "") + t;
                input.cursorPosition = input.text.length;
                input.forceActiveFocus();
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ---- chat history
        ColumnLayout {
            visible: root.big || root.showHistory
            Layout.preferredWidth: root.big ? 250 : -1
            Layout.fillWidth: !root.big
            Layout.fillHeight: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.preferredHeight: 36
                IconButton {
                    visible: !root.big
                    icon: "arrow_back"; iconSize: 19; iconColor: Theme.text2
                    onClicked: root.showHistory = false
                }
                Txt { Layout.fillWidth: true; text: "Chats"; font.pixelSize: 15; font.weight: Theme.strong }
                IconButton {
                    icon: "edit_square"; iconSize: 19; iconColor: Theme.text2
                    onClicked: { AI.reset(); root.showHistory = false; input.forceActiveFocus(); }
                }
            }
            ListView {
                id: hist
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: AI.chats
                boundsBehavior: Flickable.StopAtBounds
                delegate: Hover {
                    id: hrow
                    required property var modelData
                    width: hist.width
                    height: 50
                    radius: Theme.m3 ? 25 : 10
                    active: modelData.id === AI.chatId
                    activeColor: Theme.m3 ? Theme.accentSoft : Theme.fill
                    onClicked: { AI.openChat(modelData.id); root.showHistory = false; input.forceActiveFocus(); }
                    ColumnLayout {
                        anchors { left: parent.left; right: del.left; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 4 }
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: hrow.modelData.title; font.pixelSize: 13; color: hrow.active && Theme.m3 ? Theme.accentSoftInk : Theme.text }
                        Txt {
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            color: Theme.faint
                            text: {
                                const d = new Date(hrow.modelData.updated), now = new Date();
                                const days = Math.floor((now.setHours(0, 0, 0, 0) - new Date(d).setHours(0, 0, 0, 0)) / 864e5);
                                return days === 0 ? Qt.formatTime(d, Settings.use24h ? "HH:mm" : "h:mm AP") : days === 1 ? "Yesterday"
                                     : days < 7 ? Qt.formatDate(d, "dddd") : Qt.formatDate(d, "d MMM yyyy");
                            }
                        }
                    }
                    IconButton {
                        id: del
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        implicitWidth: 28; implicitHeight: 28
                        opacity: hrow.hovered || hovered ? 1 : 0
                        icon: "delete"; iconSize: 17; iconColor: Theme.muted
                        onClicked: AI.deleteChat(hrow.modelData.id)
                    }
                }
                Txt {
                    anchors.centerIn: parent
                    visible: hist.count === 0
                    text: "No chats yet"
                    color: Theme.faint
                    font.pixelSize: 13
                }
            }
        }
        Rectangle {
            visible: root.big
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Theme.line
        }

        Item {
            visible: root.big || !root.showHistory
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                width: Math.min(parent.width, 860)
                spacing: 10

                // ---- header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    spacing: 8
                    Rectangle {
                        width: 28; height: 28; radius: Theme.m3 ? 14 : 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.m3 ? Theme.accent : "#5e5ce6" }
                            GradientStop { position: 1; color: Theme.m3 ? Theme.indigo : "#bf5af2" }
                        }
                        Icon { anchors.centerIn: parent; name: "auto_awesome"; size: 17; filled: true; color: Theme.m3 ? Theme.accentInk : "#ffffff" }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Txt { text: "Ask AI"; font.pixelSize: 15; font.weight: Theme.strong }
                        Txt {
                            text: Settings.aiModel + (AI.mcpLive.length ? " · " + AI.mcpServers.filter(s => AI.mcpLive.includes(s.url)).map(s => s.name).join(", ") : " · KOOMPI AI")
                            font.pixelSize: 11; color: Theme.muted
                        }
                    }
                    IconButton {
                        visible: !root.big
                        icon: "history"; iconSize: 20; iconColor: Theme.text2
                        onClicked: root.showHistory = true
                    }
                    IconButton {
                        icon: "edit_square"; iconSize: 19; iconColor: Theme.text2
                        visible: AI.chat.length > 0 && !root.big
                        onClicked: { AI.reset(); input.forceActiveFocus(); }
                    }
                    IconButton {
                        icon: root.big ? "close_fullscreen" : "open_in_full"; iconSize: 18; iconColor: Theme.text2
                        onClicked: { Settings.aiLayout = root.big ? "side" : "center"; root.showHistory = false; input.forceActiveFocus(); }
                    }
                    IconButton {
                        icon: "settings"; iconSize: 19; iconColor: Theme.text2
                        onClicked: Shell.openSettings("ai")
                    }
                    IconButton {
                        icon: "close"; iconSize: 19; iconColor: Theme.text2
                        onClicked: Shell.close()
                    }
                }

                // ---- conversation
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 14
                    model: AI.chat
                    boundsBehavior: Flickable.StopAtBounds
                    onCountChanged: Qt.callLater(positionViewAtEnd)
                    onContentHeightChanged: if (AI.busy) positionViewAtEnd()

                    delegate: Item {
                        id: msg
                        required property var modelData
                        required property int index
                        readonly property bool mine: modelData.role === "user"
                        readonly property bool last: index === AI.chat.length - 1
                        readonly property var tools: modelData.tools ?? []
                        readonly property var running: tools.find(t => t.status === "run")
                        property bool toolsOpen: false
                        width: list.width
                        height: col.implicitHeight

                        ColumnLayout {
                            id: col
                            width: parent.width
                            spacing: 6

                            Rectangle {   // attached screenshot
                                visible: !!msg.modelData.image
                                Layout.alignment: Qt.AlignRight
                                Layout.preferredWidth: Math.min(240, img.implicitWidth > 0 ? 240 : 0)
                                Layout.preferredHeight: img.status === Image.Ready ? Math.min(180, 240 * img.implicitHeight / img.implicitWidth) : 0
                                radius: 12
                                color: Theme.surface3
                                clip: true
                                Image {
                                    id: img
                                    anchors.fill: parent
                                    source: msg.modelData.image ? "file://" + msg.modelData.image : ""
                                    sourceSize.width: 480
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            Hover {   // one line for the tools used; click for the details
                                visible: msg.tools.length > 0
                                Layout.preferredWidth: Math.min(sumRow.implicitWidth + 24, col.width)
                                Layout.preferredHeight: 30
                                radius: 15
                                base: Theme.m3 ? Theme.surface3 : Theme.glassTile
                                onClicked: msg.toolsOpen = !msg.toolsOpen
                                Row {
                                    id: sumRow
                                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 6
                                    readonly property bool bad: msg.tools.some(t => t.status === "fail")
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: msg.running ? "progress_activity" : sumRow.bad ? "error" : "check_circle"
                                        filled: !msg.running
                                        size: 16
                                        color: msg.running ? Theme.accent : sumRow.bad ? Theme.warn : Theme.green
                                        RotationAnimation on rotation { running: !!msg.running; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                                    }
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, col.width - 80)
                                        font.pixelSize: 12
                                        color: Theme.text2
                                        text: msg.running ? (msg.running.title || msg.running.name.replace(/_/g, " ")) + "…"
                                            : msg.tools.length + (msg.tools.length > 1 ? " steps · " : " step · ")
                                              + msg.tools.map(t => t.title || t.name.replace(/_/g, " ")).filter((v, i, a) => a.indexOf(v) === i).join(", ")
                                    }
                                    Icon { anchors.verticalCenter: parent.verticalCenter; name: msg.toolsOpen ? "expand_less" : "expand_more"; size: 16; color: Theme.muted }
                                }
                            }

                            Repeater {   // tool calls (MCP connectors): shown when opened, or while one waits for approval
                                model: msg.tools
                                Rectangle {
                                    id: tc
                                    required property var modelData
                                    readonly property bool waiting: modelData.status === "wait"
                                    property bool open: false
                                    visible: msg.toolsOpen || waiting
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: tcCol.implicitHeight + 16
                                    radius: 12
                                    color: Theme.m3 ? Theme.surface3 : Theme.glassTile
                                    border.width: waiting ? 1 : 0
                                    border.color: Theme.warn
                                    ColumnLayout {
                                        id: tcCol
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10 }
                                        spacing: 6
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Icon {
                                                name: ({ wait: "front_hand", run: "progress_activity", ok: "check_circle", fail: "error", declined: "block" })[tc.modelData.status] ?? "build"
                                                size: 17
                                                filled: tc.modelData.status !== "run"
                                                color: tc.modelData.status === "ok" ? Theme.green : tc.modelData.status === "fail" ? Theme.danger
                                                     : tc.waiting ? Theme.warn : Theme.muted
                                                RotationAnimation on rotation { running: tc.modelData.status === "run"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                                            }
                                            Txt {
                                                Layout.fillWidth: true
                                                text: (tc.modelData.title || tc.modelData.name.replace(/_/g, " ")) + "  <font color='" + Theme.faint + "'>" + tc.modelData.server + "</font>"
                                                textFormat: Text.StyledText
                                                font.pixelSize: 13
                                            }
                                            IconButton {
                                                implicitWidth: 24; implicitHeight: 24
                                                icon: tc.open ? "expand_less" : "expand_more"; iconSize: 18; iconColor: Theme.muted
                                                onClicked: tc.open = !tc.open
                                            }
                                        }
                                        Txt {
                                            visible: tc.waiting || tc.open
                                            Layout.fillWidth: true
                                            text: (tc.waiting ? "Allow this? " : "") + JSON.stringify(tc.modelData.args)
                                            wrapMode: Text.WrapAnywhere
                                            elide: Text.ElideNone
                                            maximumLineCount: tc.open ? 30 : 4
                                            font.family: tc.waiting ? Theme.font : Theme.mono
                                            font.pixelSize: 12
                                            color: Theme.text2
                                        }
                                        Txt {
                                            visible: tc.open && !!tc.modelData.preview
                                            Layout.fillWidth: true
                                            text: tc.modelData.preview ?? ""
                                            wrapMode: Text.WrapAnywhere
                                            elide: Text.ElideNone
                                            maximumLineCount: 12
                                            font.family: Theme.mono
                                            font.pixelSize: 11
                                            color: Theme.muted
                                        }
                                        RowLayout {
                                            visible: tc.waiting
                                            spacing: 6
                                            Hover {
                                                implicitWidth: 76; implicitHeight: 28; radius: 14
                                                base: Theme.accent
                                                onClicked: AI.approve(tc.modelData.id, true)
                                                Txt { anchors.centerIn: parent; text: "Allow"; font.pixelSize: 12; font.weight: Theme.strong; color: Theme.accentInk }
                                            }
                                            Hover {
                                                implicitWidth: alwaysLbl.implicitWidth + 24; implicitHeight: 28; radius: 14
                                                base: Theme.m3 ? Theme.accentSoft : Theme.fill
                                                onClicked: AI.allowAll(tc.modelData.id)
                                                Txt { id: alwaysLbl; anchors.centerIn: parent; text: "Always allow"; font.pixelSize: 12; color: Theme.m3 ? Theme.accentSoftInk : Theme.accent }
                                            }
                                            Hover {
                                                implicitWidth: 76; implicitHeight: 28; radius: 14
                                                base: Theme.fill
                                                onClicked: AI.approve(tc.modelData.id, false)
                                                Txt { anchors.centerIn: parent; text: "Deny"; font.pixelSize: 12 }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {   // bubble (user) or plain text (assistant)
                                visible: !!body.text
                                Layout.alignment: msg.mine ? Qt.AlignRight : Qt.AlignLeft
                                Layout.preferredWidth: msg.mine ? body.width + 28 : list.width
                                Layout.preferredHeight: body.implicitHeight + (msg.mine ? 18 : 0)
                                radius: Theme.m3 ? 20 : 18
                                color: msg.mine ? (Theme.m3 ? Theme.accentSoft : Theme.accent) : "transparent"
                                TextEdit {
                                    id: body
                                    x: msg.mine ? 14 : 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    // User bubbles shrink to short text.
                                    width: msg.mine ? Math.min(list.width * 0.85 - 28, Math.ceil(metrics.advanceWidth) + 2) : list.width - 12
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    textFormat: msg.mine ? TextEdit.PlainText : TextEdit.MarkdownText
                                    text: msg.mine ? msg.modelData.content : root.tight(msg.modelData.content) || (AI.busy && msg.last && !msg.tools.length ? "…" : "")
                                    color: msg.modelData.error ? Theme.danger : msg.mine ? (Theme.m3 ? Theme.accentSoftInk : "#ffffff") : Theme.text
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.accentInk
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    TextMetrics { id: metrics; font: body.font; text: msg.modelData.content.split("\n").reduce((a, b) => a.length > b.length ? a : b, "") }
                                }
                            }

                            Row {   // actions under a finished answer
                                visible: !msg.mine && !(AI.busy && msg.last) && !msg.modelData.error && !!msg.modelData.content
                                spacing: 2
                                Layout.leftMargin: 2
                                IconButton {
                                    id: copyBtn
                                    property bool done: false
                                    implicitWidth: 28; implicitHeight: 28
                                    icon: done ? "check" : "content_copy"; iconSize: 16; iconColor: Theme.muted
                                    onClicked: { Quickshell.execDetached(["wl-copy", "--", msg.modelData.content]); done = true; doneT.restart(); }
                                    Timer { id: doneT; interval: 1400; onTriggered: copyBtn.done = false }
                                }
                                IconButton {
                                    visible: msg.last
                                    implicitWidth: 28; implicitHeight: 28
                                    icon: "refresh"; iconSize: 17; iconColor: Theme.muted
                                    onClicked: {
                                        const q = AI.chat[msg.index - 1];
                                        AI.chat = AI.chat.slice(0, msg.index - 1);
                                        if (q.image) AI.attachment = q.image;
                                        AI.send(q.content);
                                    }
                                }
                            }
                        }
                    }

                    // ---- empty state
                    ColumnLayout {
                        visible: list.count === 0
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 8
                        Icon { Layout.alignment: Qt.AlignHCenter; name: "auto_awesome"; size: 40; color: Theme.faint }
                        Txt {
                            Layout.alignment: Qt.AlignHCenter
                            text: AI.hasKey ? "Ask anything" : "Add your KOOMPI AI key"
                            font.pixelSize: 17; font.weight: Theme.strong
                        }
                        Txt {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 10
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: AI.hasKey ? "English or ខ្មែរ. Attach a screenshot or paste what you copied."
                                            : "Settings → AI. Get one from the KOOMPI AI Gateway in KConsole."
                            font.pixelSize: 13; color: Theme.muted
                        }
                        Repeater {
                            model: AI.hasKey ? [
                                { i: "screenshot_region", t: "Ask about part of the screen", f: () => AI.screenshot() },
                                { i: "translate", t: "Translate my clipboard", f: () => { input.text = "Translate this (English ↔ " + Settings.aiLang + "):\n\n"; paste.running = true; } },
                                { i: "summarize", t: "Summarize my clipboard", f: () => { input.text = "Summarize this:\n\n"; paste.running = true; } },
                                ...AI.mcpServers.filter(s => !AI.mcp[s.url]?.connected).slice(0, 1).map(s => ({ i: "cloud", t: AI.mcp[s.url]?.waiting ? "Finish signing in in your browser…" : "Connect " + s.name, f: () => AI.connect(s.url) })),
                                ...(AI.mcpLive.length ? [{ i: "cloud", t: "What's running on my KOOMPI Cloud?", f: () => AI.send("What apps and services do I have on KOOMPI Cloud, and are they running?") }] : [])
                            ] : [{ i: "key", t: "Open Settings → AI", f: () => Shell.openSettings("ai") }]
                            Hover {
                                required property var modelData
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: sRow.implicitWidth + 28
                                implicitHeight: 36
                                radius: 18
                                base: Theme.m3 ? Theme.surface3 : Theme.glassTile
                                onClicked: modelData.f()
                                Row {
                                    id: sRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Icon { name: modelData.i; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                    Txt { text: modelData.t; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }
                }

                // ---- composer
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: comp.implicitHeight + 16
                    radius: Theme.m3 ? 26 : 20
                    color: Theme.m3 ? Theme.surface3 : Theme.glassTile
                    border.width: Theme.m3 ? 0 : 1
                    border.color: Theme.glassEdge

                    ColumnLayout {
                        id: comp
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        spacing: 6

                        Item {   // pending attachment
                            visible: !!AI.attachment
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: visible ? 64 : 0
                            Layout.leftMargin: 4
                            Rectangle {
                                anchors.fill: parent
                                radius: 10
                                color: Theme.surface3
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: AI.attachment ? "file://" + AI.attachment : ""
                                    sourceSize.width: 192
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            IconButton {
                                anchors { right: parent.right; top: parent.top; margins: -6 }
                                implicitWidth: 22; implicitHeight: 22
                                base: Theme.m3 ? Theme.surface : "#3a3a3c"
                                icon: "close"; iconSize: 14; iconColor: "#ffffff"
                                onClicked: AI.attachment = ""
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(160, Math.max(24, input.contentHeight))
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            Flickable {
                                id: inFlick
                                anchors.fill: parent
                                contentHeight: input.contentHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                TextEdit {
                                    id: input
                                    width: inFlick.width
                                    wrapMode: TextEdit.Wrap
                                    color: Theme.text
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.accentInk
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    focus: true
                                    onCursorRectangleChanged: {
                                        const r = cursorRectangle;
                                        if (r.y < inFlick.contentY) inFlick.contentY = r.y;
                                        else if (r.y + r.height > inFlick.contentY + inFlick.height) inFlick.contentY = r.y + r.height - inFlick.height;
                                    }
                                    Keys.onEscapePressed: Shell.close()
                                    Keys.onPressed: e => {
                                        if (e.key === Qt.Key_V && (e.modifiers & Qt.ControlModifier)) { paste.running = true; e.accepted = true; }
                                    }
                                    Keys.onReturnPressed: e => { if (e.modifiers & Qt.ShiftModifier) e.accepted = false; else root.send(); }
                                    Keys.onEnterPressed: e => { if (e.modifiers & Qt.ShiftModifier) e.accepted = false; else root.send(); }
                                    Txt {
                                        visible: !input.text
                                        text: AI.attachment ? "Ask about this screenshot…" : "Ask KOOMPI AI…"
                                        color: Theme.faint
                                        font.pixelSize: 14
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            IconButton {
                                icon: "screenshot_region"; iconSize: 19; iconColor: Theme.text2
                                onClicked: AI.screenshot()
                            }
                            IconButton {
                                icon: "content_paste"; iconSize: 18; iconColor: Theme.text2  // text or image
                                onClicked: paste.running = true
                            }
                            Txt {
                                Layout.fillWidth: true
                                Layout.leftMargin: 6
                                text: "↵ send · ⇧↵ new line"
                                font.pixelSize: 11
                                color: Theme.faint
                            }
                            IconButton {
                                readonly property bool ready: AI.busy || !!input.text.trim() || !!AI.attachment
                                base: ready ? Theme.accent : Theme.fill
                                icon: AI.busy ? "stop" : "arrow_upward"
                                filled: AI.busy
                                iconSize: 19
                                iconColor: ready ? Theme.accentInk : Theme.faint
                                onClicked: AI.busy ? AI.stop() : root.send()
                            }
                        }
                    }
                }
            }
        }
    }
}
