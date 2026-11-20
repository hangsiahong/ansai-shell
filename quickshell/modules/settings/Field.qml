import QtQuick
import qs
import qs.components

// Single-line text input for settings rows. secret: dots instead of text.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder
    property bool secret: false
    signal accepted()
    implicitWidth: 330
    implicitHeight: Theme.m3 ? 40 : 30
    radius: Theme.m3 ? 20 : 8
    color: Theme.m3 ? Theme.surface3 : Theme.fill2
    function focusIn() { input.forceActiveFocus(); }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        verticalAlignment: TextInput.AlignVCenter
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 13
        clip: true
        onAccepted: root.accepted()
        Txt { visible: !input.text; anchors.verticalCenter: parent.verticalCenter; width: parent.width; text: root.placeholder; color: Theme.faint; font.pixelSize: 13 }
    }
}
