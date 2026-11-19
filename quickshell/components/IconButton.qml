import QtQuick
import qs

Hover {
    property alias icon: ic.name
    property alias iconSize: ic.size
    property alias iconColor: ic.color
    property alias filled: ic.filled
    implicitWidth: 32
    implicitHeight: 32
    radius: height / 2

    Icon {
        id: ic
        anchors.centerIn: parent
    }
}
