import QtQuick
import qs
import qs.services

// Workspace dots; material puts them in the centre like a page indicator.
Rectangle {
    required property var wss
    implicitHeight: Theme.m3 ? 28 : 26
    implicitWidth: wsRow.implicitWidth + (Theme.m3 ? 16 : 12)
    radius: height / 2
    color: Theme.m3 ? Theme.tonal : Theme.fill2
    visible: wss.length > 0

    Row {
        id: wsRow
        anchors.centerIn: parent
        spacing: Theme.m3 ? 6 : 4
        Repeater {
            model: wss
            Hover {
                required property var modelData
                readonly property bool on: modelData.is_active
                readonly property bool busy: modelData.active_window_id !== null && modelData.active_window_id !== undefined
                width: on ? (Theme.m3 ? 30 : 26) : 18
                height: 18
                radius: 9
                base: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                onClicked: Niri.focusWorkspace(modelData)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.on ? parent.width - (Theme.m3 ? 0 : 8) : Theme.m3 ? 8 : 7
                    height: Theme.m3 ? 8 : 7
                    radius: height / 2
                    color: parent.on ? Theme.accent : parent.busy ? (Theme.m3 ? Theme.tonalInk : Theme.muted) : Theme.faint
                    Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                    Behavior on color { ColorAnimation { duration: Theme.med } }
                }
            }
        }
    }
}
