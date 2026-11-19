import QtQuick
import qs
import qs.components

// Text button. kind: "filled" | "tonal" | "text" | "danger"
Hover {
    id: root
    property string text
    property string icon
    property string kind: "tonal"
    implicitWidth: row.implicitWidth + 28
    implicitHeight: Theme.m3 ? 40 : 30
    radius: Theme.m3 ? height / 2 : 8
    base: kind === "filled" ? Theme.accent : kind === "danger" ? Theme.danger : kind === "text" ? "transparent" : (Theme.m3 ? Theme.tonal : Theme.fill)
    readonly property color ink: kind === "filled" ? Theme.accentInk : kind === "danger" ? (Theme.m3 && Theme.dark ? "#690005" : "#ffffff")
        : kind === "text" ? Theme.accent : Theme.m3 ? Theme.tonalInk : Theme.text
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon { visible: !!root.icon; name: root.icon; size: 17; color: root.ink; anchors.verticalCenter: parent.verticalCenter }
        Txt { text: root.text; font.pixelSize: 13; font.weight: Theme.strong; color: root.ink; anchors.verticalCenter: parent.verticalCenter }
    }
}
