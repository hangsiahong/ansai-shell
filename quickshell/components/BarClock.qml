import QtQuick
import qs
import qs.services

// Clock; material puts it on the left like Android's status bar.
Hover {
    implicitHeight: Theme.m3 ? 32 : 28
    implicitWidth: clockRow.implicitWidth + (Theme.m3 ? 24 : 20)
    radius: height / 2
    active: Shell.open === "calendar"
    activeColor: Theme.m3 ? Theme.accentSoft : Theme.fill
    onClicked: Shell.toggle("calendar")
    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8
        Txt {
            text: Time.time
            font.pixelSize: Theme.m3 ? 15 : 13
            font.weight: Theme.m3 ? Font.Medium : Theme.strong
            font.features: { "tnum": 1 }
            anchors.verticalCenter: parent.verticalCenter
            visible: Theme.m3
        }
        Txt { text: Time.date; color: Theme.m3 ? Theme.muted : Theme.text2; font.pixelSize: 13; font.weight: Theme.m3 ? Font.Normal : Font.Medium; anchors.verticalCenter: parent.verticalCenter }
        Txt { visible: !Theme.m3; text: Time.time; font.pixelSize: 13; font.weight: Theme.strong; font.features: { "tnum": 1 } }
        Rectangle {
            visible: Notifs.list.length > 0
            width: 6; height: 6; radius: 3
            color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
