import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.modules.settings

// Quick Ask Ansai at the bottom edge: point at the middle of the bottom edge and a field slides up.
// Enter asks (same conversation as the Ask Ansai sidebar) and the answer streams above the field.
// On an empty workspace it stays up; otherwise it hides once the pointer leaves, unless you're typing or it's answering.
PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 460
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ansai-askbar"
    WlrLayershell.keyboardFocus: AI.bar ? WlrKeyboardFocus.Exclusive : open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property bool hot: false
    property bool peek: false   // show the answer after the agent used the screen, until the pointer has been and gone
    property int from: -1   // index in AI.chat of the answer asked from here; -1: none to show
    readonly property var answer: from >= 0 ? AI.chat[from] ?? null : null
    readonly property bool waiting: (answer?.tools ?? []).some(t => t.status === "wait")
    // Always there on an empty workspace; with windows open it waits at the edge for the pointer.
    readonly property var ws: Niri.workspaces.find(w => w.is_active && w.output === root.screen?.name) ?? null
    readonly property bool empty: !!ws && Niri.windowsOn(ws.id).length === 0
    readonly property bool open: Shell.open === "" && !AI.driving && (hot || peek || empty || AI.bar || input.text !== "" || (from >= 0 && AI.busy && input.activeFocus))

    onOpenChanged: if (!open) { input.focus = false; AI.bar = false; }
    Connections {
        target: AI
        function onBarChanged() { if (AI.bar) input.forceActiveFocus(); }
        function onDrivingChanged() { if (!AI.driving && root.from >= 0) root.peek = true; }
        function onBarAsked(text) { input.text = text; root.ask(); }
    }
    Connections {
        target: AI
        function onChatChanged() { if (root.from >= AI.chat.length) root.from = -1; }   // chat reset or switched
    }

    function ask(): void {
        const t = input.text.trim();
        if (!t || AI.busy) return;
        if (from < 0) AI.reset();   // a quick question starts its own chat; follow-ups continue it
        AI.send(t);
        from = AI.chat.length - 1;
        input.text = "";
    }
    function openSidebar(): void {
        hot = false;
        peek = false;
        AI.bar = false;
        Shell.open = "ai";
    }

    mask: Region { item: root.open ? card : edge }
    // The hot strip: the middle third of the bottom edge.
    Item { id: edge; anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter } width: parent.width / 3; height: 3 }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) { leave.stop(); root.hot = true; }
            else leave.restart();
        }
    }
    Timer { id: leave; interval: 500; onTriggered: { root.hot = false; root.peek = false; } }

    Item {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(620, parent.width - 32)
        height: col.height + 12
        y: root.open ? parent.height - height - 14 : parent.height + 8
        opacity: root.open ? 1 : 0
        Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }

        Column {
            id: col
            width: parent.width
            spacing: 8

            // The answer to what was asked here.
            Glass {
                id: reply
                visible: !!root.answer
                screenX: card.x + x
                screenY: root.screen.height - root.height + card.y + y
                width: parent.width
                height: Math.min(300, txt.contentHeight + 24) + (actions.visible ? actions.height + 6 : 0)
                radius: Theme.m3 ? 24 : 20

                Flickable {
                    id: flick
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    height: Math.min(300, txt.contentHeight + 24) - 24
                    contentHeight: txt.contentHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: if (AI.busy) contentY = Math.max(0, contentHeight - height)
                    TextEdit {
                        id: txt
                        width: flick.width
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.MarkdownText
                        text: root.answer?.content || (root.waiting ? "" : AI.busy ? "…" : "")
                        color: root.answer?.error ? Theme.danger : Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentInk
                        font.family: Theme.font
                        font.pixelSize: 14
                    }
                }
                Row {
                    id: actions
                    anchors { right: parent.right; bottom: parent.bottom; margins: 8 }
                    spacing: 6
                    visible: root.waiting || !AI.busy
                    Btn {
                        visible: root.waiting
                        text: "Needs your OK · Review"
                        kind: "filled"
                        onClicked: root.openSidebar()
                    }
                    Btn { text: "Open in Ask Ansai"; kind: "tonal"; onClicked: root.openSidebar() }
                    Btn { text: "Clear"; kind: "tonal"; onClicked: { root.from = -1; root.peek = false; } }
                }
            }

            // The field.
            Glass {
                id: bar
                screenX: card.x + x
                screenY: root.screen.height - root.height + card.y + y
                width: parent.width
                height: Theme.m3 ? 56 : 50
                radius: height / 2

                Icon {
                    id: spark
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    name: "auto_awesome"
                    size: 20
                    color: Theme.accent
                }
                TextInput {
                    id: input
                    anchors { left: spark.right; leftMargin: 10; right: go.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 15
                    selectionColor: Theme.accentSoft
                    clip: true
                    onAccepted: root.ask()
                    Keys.onEscapePressed: { if (text) text = ""; else { root.hot = false; root.peek = false; AI.bar = false; focus = false; } }
                    Txt {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !input.text
                        text: AI.busy ? "Answering…" : root.answer ? "Ask a follow-up" : "Ask Ansai anything"
                        color: Theme.faint
                        font.pixelSize: 15
                    }
                }
                IconButton {
                    id: go
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    width: 36; height: 36
                    icon: AI.busy ? "stop" : "arrow_upward"
                    iconSize: 20
                    iconColor: AI.busy || input.text.trim() ? Theme.accentInk : Theme.muted
                    base: AI.busy || input.text.trim() ? Theme.accent : "transparent"
                    onClicked: AI.busy ? AI.stop() : root.ask()
                }
                // Clicking anywhere on the bar puts the cursor in the field.
                TapHandler { onTapped: input.forceActiveFocus() }
            }
        }
    }
}
