import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

// One app on the vertical dock: icon, hover magnify, tooltip, running dots, urgent badge, drag to reorder.
Item {
    id: root
    required property var dock
    property var item
    property int idx
    property bool firstUnpinned: false

    readonly property int size: dock.size
    readonly property bool running: item.windows.length > 0
    readonly property bool focused: item.windows.some(w => w.id === Niri.focusedWindowId)
    readonly property bool urgent: item.windows.some(w => w.is_urgent)
    readonly property string name: item.entry?.name ?? item.id
    readonly property bool dragging: dock.dragKey === item.key

    width: size
    height: size + (firstUnpinned ? 13 : 0)

    // Divider between pinned and running-only apps.
    Rectangle {
        visible: root.firstUnpinned
        y: 0
        width: root.size * 0.6; height: 1
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.line
    }

    Item {
        id: slot
        y: root.firstUnpinned ? 13 : 0
        width: root.size; height: root.size

        // Launch feedback: bounce until a window shows up (or 4s).
        property bool launching: false
        onLaunchingChanged: if (launching) giveUp.restart()
        Timer { id: giveUp; interval: 4000; onTriggered: slot.launching = false }
        Connections {
            target: root
            function onRunningChanged() { if (root.running) slot.launching = false; }
        }

        Rectangle {
            id: hl
            anchors.fill: parent
            radius: Theme.m3 ? height / 2 : root.size * 0.258
            color: ma.pressed ? Theme.press : ma.containsMouse ? Theme.hover : "transparent"
        }

        AppIcon {
            id: icon
            anchors.centerIn: parent
            size: root.size * 0.82
            icon: root.item.entry?.icon ?? root.item.id
            label: root.name
            opacity: root.dragging ? 0.85 : 1
            transformOrigin: Item.Left
            scale: Settings.dockMagnify && ma.containsMouse && !root.dragging ? 1.18 : 1
            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.spring } }
            transform: Translate { x: drag.dx + bounce.off; y: drag.dy }
        }

        QtObject {
            id: bounce
            property real off: 0
        }
        SequentialAnimation {
            running: slot.launching || root.urgent
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { target: bounce; property: "off"; to: 10; duration: 260; easing.type: Easing.OutQuad }
            NumberAnimation { target: bounce; property: "off"; to: 0; duration: 340; easing.type: Easing.OutBounce }
            PauseAnimation { duration: root.urgent ? 900 : 120 }
        }

        // Running indicator on the screen-edge side: a dot per window (max 3), a pill when focused.
        Column {
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: -root.dock.pad + 2 }
            spacing: 3
            visible: root.running && !root.dragging
            Repeater {
                model: root.focused ? 1 : Math.min(3, root.item.windows.length)
                Rectangle {
                    width: 4
                    height: root.focused ? 14 : 4
                    radius: 2
                    color: root.focused ? Theme.accent : Theme.text2
                    Behavior on height { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                }
            }
        }

        // Urgent badge
        Rectangle {
            visible: root.urgent
            anchors { right: parent.right; top: parent.top; margins: 1 }
            width: 10; height: 10; radius: 5
            color: Theme.danger
            border.width: 2
            border.color: Theme.surface
        }

        // Tooltip
        Rectangle {
            id: tip
            readonly property bool show: ma.containsMouse && !ma.pressed && !root.dragging && Shell.open !== "dockmenu"
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width + (Settings.dockMagnify ? 22 : 16)
            width: tipTxt.implicitWidth + 20
            height: 26
            radius: Theme.m3 ? 13 : 8
            color: Theme.m3 ? Theme.surface3 : Theme.dark ? "#2c2c2e" : "#ffffff"
            border.width: Theme.m3 ? 0 : 1
            border.color: Theme.glassLine
            opacity: show ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fast; easing.type: Theme.easing } }
            Txt {
                id: tipTxt
                anchors.centerIn: parent
                text: root.item.windows.length > 1 ? `${root.name}  ·  ${root.item.windows.length}` : root.name
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        QtObject {
            id: drag
            property real dx: 0
            property real dy: 0
            property real px: 0
            property real py: 0
            property bool moved: false
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: drag.moved ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onPressed: m => { drag.px = m.x; drag.py = m.y; drag.moved = false; }
            onPositionChanged: m => {
                if (!(pressedButtons & Qt.LeftButton)) return;
                const dx = m.x - drag.px, dy = m.y - drag.py;
                if (!drag.moved && Math.hypot(dx, dy) < 8) return;
                drag.moved = true;
                root.dock.dragKey = root.item.key;
                drag.dx = Math.max(0, dx);
                drag.dy = dy;
                root.dock.dragTo(slot.mapToItem(root.dock.contentItem, 0, m.y).y);
            }
            onReleased: m => {
                if (!drag.moved) return;
                root.dock.drop(root.item, drag.dx > root.size * 1.4);
                drag.dx = 0; drag.dy = 0;
            }
            onClicked: m => {
                if (drag.moved) { drag.moved = false; return; }
                if (m.button === Qt.RightButton) {
                    root.dock.openMenu(root.item, slot.mapToItem(root.dock.contentItem, 0, slot.height / 2).y);
                } else if (m.button === Qt.MiddleButton || (m.modifiers & Qt.ShiftModifier)) {
                    slot.launching = true;
                    root.dock.launch(root.item);
                } else {
                    if (!root.running) slot.launching = true;
                    root.dock.activate(root.item, 1);
                }
            }
            onWheel: w => { if (root.running) root.dock.activate(root.item, w.angleDelta.y > 0 ? -1 : 1); }
        }

        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
    }

    // "Unpin" hint when dragged far enough off the dock.
    Rectangle {
        visible: root.dragging && drag.dx > root.size * 1.4 && root.item.pinned
        x: drag.dx + root.size + 8
        y: slot.y + drag.dy + (root.size - height) / 2
        width: rmTxt.implicitWidth + 16; height: 22; radius: 11
        color: Theme.danger
        Txt { id: rmTxt; anchors.centerIn: parent; text: "Unpin"; font.pixelSize: 11; font.weight: Theme.strong; color: "#ffffff" }
    }
}
