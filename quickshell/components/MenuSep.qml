import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    Layout.fillWidth: true
    Layout.leftMargin: 9
    Layout.rightMargin: 9
    Layout.topMargin: 4
    Layout.bottomMargin: 4
    implicitHeight: 1
    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.1)
}
