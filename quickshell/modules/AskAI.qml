import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import "notemd.js" as Md

// "Ask Ansai" sidebar on the right (Mod+I). The conversation lives in services/AI.qml, so closing
// and reopening keeps it. Attach a screenshot (pick an area) or paste the clipboard into the question.
Sheet {
    id: root
    name: "ai"
    exclusiveKeys: true
    enterFrom: 0
    // "side": a panel on the right; "center": big in the middle, with the chat list beside it.
    readonly property bool big: Settings.aiLayout === "center"
    property bool showHistory: false
    property string pane: "chats"   // sidebar list: "chats" | "sched"
    property var editing: null      // scheduled task open in the editor (a copy), or null
    dim: big
    panelWidth: big ? Math.min(1200, width - 96) : Math.min(440, width - 24)
    panelX: big ? (width - panelWidth) / 2 : width - panelWidth - 10
    panelY: big ? Theme.barH + 32 : Theme.barH + 8
    panelHeight: height - panelY - (big ? 32 : 10)
    panelRadius: Theme.m3 ? 28 : 22

    onShownChanged: if (!shown) picker.visible = false; else {
        if (AI.draft) { input.text = AI.draft; AI.draft = ""; input.cursorPosition = input.text.length; }
        input.forceActiveFocus();
        AI.checkKey();
        AI.refreshMcp();
    }

    // Replies render through Quick Note's Markdown (notemd.js): spaced paragraphs, hanging bullets, readable links, tables.
    readonly property var mdColors: ({
        text: Theme.text.toString(), muted: Theme.muted.toString(),
        accent: (Theme.m3 ? Theme.accent : Theme.dark ? "#4da3ff" : "#0a6cdc").toString(),
        code: Qt.rgba(Theme.muted.r, Theme.muted.g, Theme.muted.b, 0.16).toString(),
        line: Theme.line.toString(), codePx: 13
    })

    function when(t): string {
        const at = t.time ?? "08:00";
        return t.kind === "hourly" ? "Every hour" : t.kind === "daily" ? "Daily at " + at : t.kind === "weekdays" ? "Weekdays at " + at
             : t.kind === "weekly" ? (t.day ?? "Mon") + "s at " + at : (t.cron ?? "");
    }
    function ago(ms: real): string {   // "in 3 h" / "5 min ago" / a date
        const d = (ms - Date.now()) / 60000, a = Math.abs(d);
        const s = a < 1 ? "now" : a < 60 ? Math.round(a) + " min" : a < 48 * 60 ? Math.round(a / 60) + " h" : "";
        if (!s) return Qt.formatDate(new Date(ms), "d MMM");
        return s === "now" ? s : d > 0 ? "in " + s : s + " ago";
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
            visible: (root.big || root.showHistory) && !(root.editing && !root.big)
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
                Row {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: [{ v: "chats", l: "Chats" }, { v: "sched", l: "Scheduled" }]
                        Hover {
                            id: ptab
                            required property var modelData
                            readonly property bool on: root.pane === modelData.v
                            width: ptabT.implicitWidth + 20
                            height: 28
                            radius: 14
                            active: on
                            activeColor: Theme.m3 ? Theme.accentSoft : Theme.fill
                            onClicked: root.pane = modelData.v
                            Txt {
                                id: ptabT
                                anchors.centerIn: parent
                                text: ptab.modelData.l
                                font.pixelSize: 13
                                font.weight: ptab.on ? Theme.strong : Font.Normal
                                color: ptab.on ? (Theme.m3 ? Theme.accentSoftInk : Theme.text) : Theme.muted
                            }
                        }
                    }
                }
                IconButton {
                    icon: root.pane === "sched" ? "add" : "edit_square"; iconSize: 19; iconColor: Theme.text2
                    onClicked: {
                        if (root.pane === "sched") { root.editing = AI.newSchedule(); return; }
                        AI.reset(); root.showHistory = false; input.forceActiveFocus();
                    }
                }
            }
            ListView {
                id: sched
                visible: root.pane === "sched"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: AI.schedules
                boundsBehavior: Flickable.StopAtBounds
                delegate: Hover {
                    id: srow
                    required property var modelData
                    readonly property var info: AI.schedInfo[modelData.id] ?? ({})
                    readonly property bool running: !!AI.schedRunning[modelData.id]
                    width: sched.width
                    height: scol.implicitHeight + 16
                    radius: Theme.m3 ? 20 : 10
                    active: root.editing?.id === modelData.id
                    activeColor: Theme.m3 ? Theme.accentSoft : Theme.fill
                    onClicked: root.editing = Object.assign({}, modelData)
                    ColumnLayout {
                        id: scol
                        anchors { left: parent.left; right: sw.left; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 6 }
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: srow.modelData.name; font.pixelSize: 13; opacity: srow.modelData.on ? 1 : 0.55 }
                        Txt {
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            color: srow.info.e ? Theme.danger : Theme.faint
                            text: srow.info.e ? srow.info.e : root.when(srow.modelData) + (srow.modelData.on && srow.info.at ? " · next " + root.ago(srow.info.at) : srow.modelData.on ? "" : " · off")
                        }
                        RowLayout {
                            spacing: 6
                            Hover {
                                visible: !!srow.modelData.last || srow.running
                                implicitWidth: lastT.implicitWidth + 10
                                implicitHeight: lastT.implicitHeight + 4
                                Layout.leftMargin: -5
                                radius: 6
                                onClicked: if (srow.modelData.last?.chat) { root.pane = "chats"; AI.openChat(srow.modelData.last.chat); root.showHistory = false; root.editing = null; }
                                Txt {
                                    id: lastT
                                    anchors.centerIn: parent
                                    font.pixelSize: 11
                                    color: srow.running ? Theme.accent : srow.modelData.last?.ok ? Theme.green : Theme.danger
                                    text: srow.running ? "Running…" : (srow.modelData.last?.ok ? "✓ " : "✗ ") + "ran " + root.ago(srow.modelData.last?.at ?? 0)
                                }
                            }
                            IconButton {
                                implicitWidth: 24; implicitHeight: 24
                                visible: !srow.running
                                opacity: srow.hovered || hovered ? 1 : 0
                                icon: "play_arrow"; iconSize: 16; iconColor: Theme.muted
                                onClicked: AI.runSchedule(srow.modelData.id)
                            }
                        }
                    }
                    Switch {
                        id: sw
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        scale: 0.8
                        checked: srow.modelData.on
                        onToggled: AI.setSchedule(srow.modelData.id, { on: !srow.modelData.on })
                    }
                }
                Txt {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    visible: sched.count === 0
                    text: "Nothing scheduled yet.\nPress + to have Ask Ansai do something every hour, day or week."
                    color: Theme.faint
                    font.pixelSize: 13
                }
            }
            ListView {
                id: hist
                visible: root.pane === "chats"
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
            visible: root.big || !root.showHistory || !!root.editing
            Layout.fillWidth: true
            Layout.fillHeight: true

            ScheduleEditor {
                anchors.fill: parent
                visible: !!root.editing
                task: root.editing
                onClosed: root.editing = null
            }
            ColumnLayout {
                visible: !root.editing
                anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                width: Math.min(parent.width, 860)
                spacing: 10

                // ---- header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: parent.width   // fillWidth alone left it at its implicit width
                    z: 10
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
                        Txt { text: "Ask Ansai"; font.pixelSize: 15; font.weight: Theme.strong }
                        Hover {   // the model in use; click to switch model or provider here
                            id: modelBtn
                            implicitWidth: modelRow.implicitWidth + 8
                            implicitHeight: modelRow.implicitHeight + 2
                            Layout.leftMargin: -4
                            radius: 6
                            active: picker.visible
                            onClicked: picker.toggle()
                            Row {
                                id: modelRow
                                anchors.centerIn: parent
                                spacing: 2
                                Txt {
                                    text: AI.modelLabel + (AI.provider ? " · " + AI.providerName(AI.provider) : "") + (AI.via && AI.provider && AI.accounts.filter(a => a.provider === AI.provider).length > 1 ? " (" + AI.via.label + ")" : "") + " · this computer" + (AI.mcpLive.length ? ", " + AI.mcpServers.filter(s => AI.mcpLive.includes(s.url)).map(s => s.name).join(", ") : "")
                                    font.pixelSize: 11; color: Theme.muted
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Icon { name: "expand_more"; size: 13; color: Theme.muted; anchors.verticalCenter: parent.verticalCenter }
                            }
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
                    IconButton {   // chat actions: new chat, continue in a new chat, compact
                        id: chatMenuBtn
                        visible: AI.chat.length > 0
                        icon: AI.compacting ? "progress_activity" : "more_horiz"; iconSize: 20; iconColor: Theme.text2
                        onClicked: chatMenu.toggle()
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
                    model: AI.chat.length   // a count, not the array: delegates survive each streamed update
                    boundsBehavior: Flickable.StopAtBounds
                    onCountChanged: Qt.callLater(positionViewAtEnd)
                    onContentHeightChanged: if (AI.busy) positionViewAtEnd()

                    delegate: Item {
                        id: msg
                        required property int index
                        readonly property var modelData: AI.chat[index] ?? ({ role: "assistant", content: "" })
                        readonly property bool mine: modelData.role === "user"
                        readonly property bool last: index === AI.chat.length - 1
                        readonly property var tools: modelData.tools ?? []
                        readonly property var running: tools.find(t => t.status === "run" || t.status === "wait")
                        property bool toolsOpen: false
                        property bool thinkOpen: false
                        readonly property string reasoning: (modelData.reasoning ?? "").trim()
                        readonly property bool reasoningNow: last && AI.busy && AI.thinking
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

                            RowLayout {   // a summary that stands in for what came before (Compact, or Continue in a new chat)
                                visible: !!msg.modelData.compact
                                Layout.fillWidth: true
                                spacing: 8
                                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }
                                Icon { name: msg.modelData.handoff ? "arrow_forward" : "summarize"; size: 14; color: Theme.muted }
                                Txt {
                                    text: msg.modelData.handoff ? "Continued from an earlier chat. The AI picks up from this summary" : "Earlier messages compacted. The AI continues from this summary"
                                    font.pixelSize: 12; color: Theme.muted
                                }
                                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }
                            }

                            ColumnLayout {   // the model's reasoning: streams in while it thinks, then folds to one line
                                visible: !msg.mine && !!msg.reasoning
                                Layout.fillWidth: true
                                spacing: 6
                                Hover {
                                    Layout.preferredWidth: thinkRow.implicitWidth + 24
                                    Layout.preferredHeight: 30
                                    radius: 15
                                    base: Theme.m3 ? Theme.surface3 : Theme.glassTile
                                    onClicked: msg.thinkOpen = !msg.thinkOpen
                                    Row {
                                        id: thinkRow
                                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                        spacing: 6
                                        Icon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            name: "lightbulb"; size: 16; filled: true
                                            color: msg.reasoningNow ? Theme.accent : Theme.muted
                                            SequentialAnimation on opacity {
                                                running: msg.reasoningNow; loops: Animation.Infinite
                                                onRunningChanged: if (!running) parent.opacity = 1
                                                NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                                            }
                                        }
                                        Txt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            font.pixelSize: 12
                                            color: Theme.text2
                                            text: msg.reasoningNow ? "Thinking…" : "Thought for " + Math.max(1, Math.round((msg.modelData.thinkMs ?? 0) / 1000)) + " s"
                                        }
                                        Icon { anchors.verticalCenter: parent.verticalCenter; name: msg.thinkOpen || msg.reasoningNow ? "expand_less" : "expand_more"; size: 16; color: Theme.muted }
                                    }
                                }
                                Item {   // live: the last lines, following the text; opened: all of it
                                    visible: msg.thinkOpen || msg.reasoningNow
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: msg.thinkOpen ? thinkText.implicitHeight : Math.min(thinkText.implicitHeight, 96)
                                    clip: true
                                    Rectangle { width: 2; height: parent.height; radius: 1; x: 12; color: Theme.line }
                                    TextEdit {
                                        id: thinkText
                                        x: 24
                                        width: parent.width - 30
                                        y: Math.min(0, parent.height - implicitHeight)
                                        readOnly: true
                                        selectByMouse: true
                                        wrapMode: TextEdit.Wrap
                                        textFormat: TextEdit.PlainText
                                        text: msg.reasoning
                                        color: Theme.text2
                                        selectionColor: Theme.accent
                                        selectedTextColor: Theme.accentInk
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.italic: true
                                    }
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
                                        name: msg.running?.status === "wait" ? "front_hand" : msg.running ? "progress_activity" : sumRow.bad ? "error" : "check_circle"
                                        filled: !msg.running
                                        size: 16
                                        color: msg.running?.status === "wait" ? Theme.warn : msg.running ? Theme.accent : sumRow.bad ? Theme.warn : Theme.green
                                        RotationAnimation on rotation { running: msg.running?.status === "run"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                                    }
                                    Txt {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, col.width - 80)
                                        font.pixelSize: 12
                                        color: Theme.text2
                                        text: msg.running?.status === "wait" ? "Needs your OK: " + (msg.running.title || msg.running.name.replace(/_/g, " "))
                                            : msg.running ? (msg.running.title || msg.running.name.replace(/_/g, " ")) + "…"
                                            : msg.tools.length + (msg.tools.length > 1 ? " steps · " : " step · ")
                                              + msg.tools.map(t => t.title || t.name.replace(/_/g, " ")).filter((v, i, a) => a.indexOf(v) === i).join(", ")
                                    }
                                    Icon { anchors.verticalCenter: parent.verticalCenter; name: msg.toolsOpen ? "expand_less" : "expand_more"; size: 16; color: Theme.muted }
                                }
                            }

                            Repeater {   // tool calls (desktop + MCP connectors): shown when opened, or while one waits for approval
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
                                            readonly property var a: tc.modelData.args ?? {}
                                            // What will happen, the way a person reads it: the command, the file, else key: value lines.
                                            text: a.command ? "$ " + a.command + (a.cwd ? "\n  in " + a.cwd : "")
                                                : a.path && "content" in a ? a.path + "\n" + a.content.split("\n").length + " lines:\n" + a.content
                                                : a.path && "old_text" in a ? a.path + "\n− " + a.old_text + "\n+ " + a.new_text
                                                : Object.keys(a).map(k => k + ": " + (typeof a[k] === "string" ? a[k] : JSON.stringify(a[k]))).join("\n") || "(no details)"
                                            wrapMode: Text.WrapAnywhere
                                            elide: Text.ElideNone
                                            maximumLineCount: tc.open ? 30 : 6
                                            font.family: Theme.mono
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

                            Rectangle {   // bubble (user) or plain text (assistant); typing dots while the answer is on its way
                                readonly property bool waiting: !msg.mine && !msg.modelData.content && AI.busy && msg.last && !msg.tools.length && !msg.reasoning
                                visible: !!msg.modelData.content || waiting
                                Layout.alignment: msg.mine ? Qt.AlignRight : Qt.AlignLeft
                                Layout.preferredWidth: msg.mine ? body.width + 28 : list.width
                                Layout.preferredHeight: Math.max(body.implicitHeight, waiting ? 22 : 0) + (msg.mine ? 18 : 0)
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
                                    textFormat: msg.mine ? TextEdit.PlainText : TextEdit.RichText
                                    text: msg.mine ? msg.modelData.content : Md.render(msg.modelData.content ?? "", root.mdColors).html
                                    onLinkActivated: link => Qt.openUrlExternally(link)
                                    HoverHandler { cursorShape: body.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
                                    color: msg.modelData.error ? Theme.danger : msg.mine ? (Theme.m3 ? Theme.accentSoftInk : "#ffffff") : Theme.text
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.accentInk
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    Row {
                                        visible: parent.parent.waiting
                                        spacing: 8
                                        height: 22
                                        TypingDots { anchors.verticalCenter: parent.verticalCenter; color: body.color }
                                        Txt { anchors.verticalCenter: parent.verticalCenter; visible: AI.thinking; text: "Thinking…"; font.pixelSize: 13; color: Theme.text2 }
                                    }
                                    TextMetrics { id: metrics; font: body.font; text: msg.modelData.content.split("\n").reduce((a, b) => a.length > b.length ? a : b, "") }
                                }
                            }

                            Row {   // actions under a finished answer
                                visible: !msg.mine && !(AI.busy && msg.last) && !!msg.modelData.content && !msg.modelData.compact
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
                            text: AI.ready ? "Ask anything" : "Set up AI in Settings → AI"
                            font.pixelSize: 17; font.weight: Theme.strong
                        }
                        Txt {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 10
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: AI.ready ? "English or ខ្មែរ. Attach a screenshot or paste what you copied."
                                            : "Sign in with ChatGPT, Claude, Copilot and more, or add a KOOMPI AI key."
                            font.pixelSize: 13; color: Theme.muted
                        }
                        Repeater {
                            model: AI.ready ? [
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
                                        text: AI.attachment ? "Ask about this screenshot…" : "Ask " + (AI.provider ? AI.providerName(AI.provider) : "KOOMPI AI") + "…"
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

    MouseArea {
        anchors.fill: parent
        z: 99
        visible: chatMenu.visible
        onClicked: chatMenu.visible = false
    }
    Rectangle {
        id: chatMenu
        z: 100
        visible: false
        function toggle(): void {
            if (visible) { visible = false; return; }
            const p = chatMenuBtn.mapToItem(parent, chatMenuBtn.width, chatMenuBtn.height + 6);
            x = Math.max(12, p.x - width);
            y = p.y;
            visible = true;
        }
        width: 260
        height: chatCol.implicitHeight + 12
        radius: Theme.m3 ? 20 : 12
        color: Theme.surface2
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            id: chatCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 2
            MenuItem { icon: "edit_square"; label: "New chat"; onClicked: { chatMenu.visible = false; AI.reset(); input.forceActiveFocus(); } }
            MenuItem {
                icon: "arrow_forward"; label: "Continue in a new chat"; hint: "summary"
                opacity: AI.busy || AI.compacting ? 0.4 : 1
                onClicked: { chatMenu.visible = false; AI.handoff(); input.forceActiveFocus(); }
            }
            MenuItem {
                icon: "summarize"; label: "Compact this chat"
                opacity: AI.busy || AI.compacting || AI.chat.length < 2 ? 0.4 : 1
                onClicked: { chatMenu.visible = false; AI.compact(); input.forceActiveFocus(); }
            }
        }
    }

    // Model picker under the model name: provider tabs (KOOMPI, then each signed-in account's provider),
    // then that provider's models. Above everything in the panel; a click outside closes it.
    MouseArea {
        anchors.fill: parent
        z: 99
        visible: picker.visible
        onClicked: picker.visible = false
    }
    Rectangle {
        id: picker
        z: 100
        visible: false
        property string tab: ""
        readonly property var tabs: (AI.hasKey || !AI.provider ? [""] : []).concat([...new Set(AI.accounts.map(a => a.provider))])
        readonly property var models: tab === "" ? AI.models.map(m => ({ v: m, l: m })) : (AI.catalogModels[tab] ?? []).map(m => ({ v: tab + "/" + m.id, l: m.id }))
        function toggle(): void {
            if (visible) { visible = false; return; }
            const p = modelBtn.mapToItem(parent, 0, modelBtn.height + 6);
            x = Math.min(p.x, parent.width - width - 12);
            y = p.y;
            tab = tabs.includes(AI.provider) ? AI.provider : (tabs[0] ?? "");
            visible = true;
        }
        width: 300
        height: pickCol.implicitHeight + 12
        radius: Theme.m3 ? 20 : 12
        color: Theme.surface2
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
        MouseArea { anchors.fill: parent }   // clicks on the card's padding don't fall through to close it
        ColumnLayout {
            id: pickCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 4
            Flow {
                Layout.fillWidth: true
                Layout.margins: 3
                spacing: 6
                visible: picker.tabs.length > 1
                Repeater {
                    model: picker.tabs
                    Hover {
                        id: tb
                        required property string modelData
                        readonly property bool on: picker.tab === modelData
                        width: tbTxt.implicitWidth + 22
                        height: 26
                        radius: 13
                        base: on ? Theme.accent : Theme.fill2
                        onClicked: picker.tab = modelData
                        Txt { id: tbTxt; anchors.centerIn: parent; text: AI.providerName(tb.modelData); font.pixelSize: 12; font.weight: Theme.strong; color: tb.on ? Theme.accentInk : Theme.text }
                    }
                }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(modelCol.implicitHeight, 300)
                contentHeight: modelCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: modelCol
                    width: parent.width
                    spacing: 0
                    Repeater {
                        model: picker.models
                        MenuItem {
                            required property var modelData
                            label: modelData.l
                            hint: Settings.aiModel === modelData.v ? "✓" : ""
                            onClicked: { Settings.aiModel = modelData.v; picker.visible = false; input.forceActiveFocus(); }
                        }
                    }
                    Txt { visible: !picker.models.length; Layout.margins: 9; text: "No models listed for this account"; font.pixelSize: 12; color: Theme.muted }
                }
            }
            MenuSep {}
            MenuItem { label: "Accounts and more models…"; onClicked: { picker.visible = false; Shell.openSettings("ai"); } }
        }
    }


}
