import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

Sheet {
    id: root
    name: "power"
    dim: true
    exclusiveKeys: true
    panelWidth: row.implicitWidth + 32
    panelHeight: 150
    panelY: (height - panelHeight) / 2
    panelRadius: Theme.m3 ? 28 : 24

    property int sel: 0
    readonly property var actions: [
        { icon: "lock", label: "Lock", run: () => Lock.lock() },
        { icon: "bedtime", label: "Sleep", run: () => { Lock.lock(); Quickshell.execDetached(["systemctl", "suspend"]); } },
        { icon: "logout", label: "Log out", run: () => Niri.action("quit", "--skip-confirmation") },
        { icon: "restart_alt", label: "Restart", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { icon: "power_settings_new", label: "Shut down", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
    ]
    function go(i: int): void {
        Shell.close();
        actions[i].run();
    }
    onShownChanged: if (shown) { sel = Shell.powerPick; Shell.powerPick = 0; panel.forceActiveFocus(); }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onLeftPressed: root.sel = Math.max(0, root.sel - 1)
        Keys.onRightPressed: root.sel = Math.min(root.actions.length - 1, root.sel + 1)
        Keys.onReturnPressed: root.go(root.sel)
        Keys.onEscapePressed: Shell.close()

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 14
            Repeater {
                model: root.actions
                Column {
                    required property var modelData
                    required property int index
                    spacing: 10
                    Hover {
                        width: 72; height: 72
                        radius: Theme.m3 ? (root.sel === index ? 22 : 36) : 22
                        base: Theme.m3 ? Theme.tonal : Theme.fill2
                        active: root.sel === index
                        activeColor: index >= 3 ? Theme.danger : Theme.accent
                        scale: Theme.m3 && pressed ? 0.92 : 1
                        Behavior on radius { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.spring } }
                        onClicked: root.go(index)
                        onHoveredChanged: if (hovered) root.sel = index
                        Icon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: 30
                            color: root.sel === index ? (index >= 3 ? (Theme.m3 && Theme.dark ? "#690005" : "#ffffff") : Theme.accentInk) : Theme.m3 ? Theme.tonalInk : Theme.text
                        }
                    }
                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Theme.text2
                    }
                }
            }
        }
    }
}
