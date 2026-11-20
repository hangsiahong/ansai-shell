import QtQuick
import qs

// A desktop widget: a glass card on the wallpaper, dragged anywhere by its empty area.
// Its spot is saved in Settings.widgetPos as screen fractions so it survives resolution changes.
Item {
    id: root
    required property string wid
    property point home   // default top-left, px
    property bool card: true
    property int pad: 14
    default property alias content: body.data
    readonly property var saved: Settings.widgetPos[wid] ?? null
    visible: Settings.widgets.includes(wid)

    function place(): void {
        if (!parent) return;
        x = Math.max(0, Math.min(parent.width - width, saved ? saved[0] * parent.width : home.x));
        y = Math.max(Theme.barH, Math.min(parent.height - height, saved ? saved[1] * parent.height : home.y));
    }
    Component.onCompleted: place()
    onSavedChanged: place()
    onHomeChanged: place()
    Connections { target: root.parent; function onWidthChanged() { root.place(); } function onHeightChanged() { root.place(); } }

    Glass {
        visible: root.card
        anchors.fill: parent
        radius: Theme.m3 ? 28 : 22
        screenX: root.x
        screenY: root.y
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        drag.target: root
        drag.threshold: 6
        drag.minimumX: 0
        drag.maximumX: root.parent ? root.parent.width - root.width : 0
        drag.minimumY: Theme.barH
        drag.maximumY: root.parent ? root.parent.height - root.height : 0
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onReleased: {
            if (root.x === root.saved?.[0] * root.parent.width && root.y === root.saved?.[1] * root.parent.height) return;
            const p = Object.assign({}, Settings.widgetPos);
            p[root.wid] = [root.x / root.parent.width, root.y / root.parent.height];
            Settings.widgetPos = p;
        }
    }
    Item {
        id: body
        anchors { fill: parent; margins: root.pad }
    }
}
