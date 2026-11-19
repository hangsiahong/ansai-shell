import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.services

PanelWindow {
    id: bar
    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: 36
    color: "transparent"
    WlrLayershell.namespace: "ansai-bar"
    WlrLayershell.layer: WlrLayer.Top

    readonly property var wss: Niri.workspacesOn(modelData.name)

    // Keeps swayidle from locking or blanking while agents may be driving the desktop.
    IdleInhibitor {
        window: bar
        enabled: Settings.keepAwake
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(242/255, 242/255, 247/255, 0.72)
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.glassLine
        }
    }

    // ---- left: mark, workspaces, focused app
    RowLayout {
        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 6

        Hover {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 8
            onClicked: Shell.toggle("launcher")
            Rectangle {
                anchors.centerIn: parent
                width: 20; height: 20; radius: 5.2
                color: Theme.dark ? "#ffffff" : "#000000"
                Txt {
                    anchors.centerIn: parent
                    text: ">_"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Theme.dark ? "#000000" : "#ffffff"
                }
            }
        }

        Rectangle {
            Layout.preferredHeight: 26
            Layout.preferredWidth: wsRow.implicitWidth + 12
            radius: 13
            color: Theme.fill2
            visible: bar.wss.length > 0

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: bar.wss
                    Hover {
                        required property var modelData
                        readonly property bool on: modelData.is_active
                        readonly property bool busy: modelData.active_window_id !== null && modelData.active_window_id !== undefined
                        width: on ? 26 : 18
                        height: 18
                        radius: 9
                        base: "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }
                        onClicked: Niri.focusWorkspace(modelData)
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.on ? 18 : 7
                            height: 7
                            radius: 3.5
                            color: parent.on ? Theme.accent : parent.busy ? Theme.muted : Theme.faint
                            Behavior on width { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }
                            Behavior on color { ColorAnimation { duration: Theme.med } }
                        }
                    }
                }
            }
        }

        Txt {
            Layout.leftMargin: 6
            Layout.maximumWidth: bar.width * 0.28
            text: Niri.focusedWindow?.title ?? ""
            color: Theme.text2
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    // ---- center: clock
    Hover {
        anchors.centerIn: parent
        height: 28
        width: clockRow.implicitWidth + 20
        radius: 14
        active: Shell.open === "calendar"
        onClicked: Shell.toggle("calendar")
        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 8
            Txt { text: Time.date; color: Theme.text2; font.pixelSize: 13; font.weight: Font.Medium }
            Txt { text: Time.time; font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
            Rectangle {
                visible: Notifs.list.length > 0
                width: 6; height: 6; radius: 3
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- right: tray, status cluster
    RowLayout {
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 4

        Repeater {
            model: Shell.nested ? [] : SystemTray.items
            IconButton {
                required property SystemTrayItem modelData
                implicitWidth: 28; implicitHeight: 28
                onClicked: m => {
                    if (m.button === Qt.RightButton || modelData.onlyMenu) {
                        if (modelData.hasMenu)
                            menuAnchor.open();
                    } else if (m.button === Qt.MiddleButton) {
                        modelData.secondaryActivate();
                    } else {
                        modelData.activate();
                    }
                }
                AppIcon {
                    anchors.centerIn: parent
                    size: 16
                    icon: parent.modelData.icon
                    label: parent.modelData.title
                }
                QsMenuAnchor {
                    id: menuAnchor
                    menu: parent.modelData.menu
                    anchor.window: bar
                    anchor.rect.x: parent.mapToItem(bar.contentItem, 0, 0).x
                    anchor.rect.y: bar.height
                    anchor.rect.width: parent.width
                }
            }
        }

        Txt {
            visible: Niri.layoutNames.length > 1
            text: Niri.keyboardLayout.slice(0, 2).toUpperCase()
            color: Theme.muted
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.rightMargin: 4
        }

        Hover {
            Layout.preferredHeight: 28
            Layout.preferredWidth: status.implicitWidth + 20
            radius: 14
            active: Shell.open === "control"
            onClicked: Shell.toggle("control")
            onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))

            Row {
                id: status
                anchors.centerIn: parent
                spacing: 10
                Icon { name: Net.netIcon(); size: 17; filled: true; color: Theme.text }
                Icon { visible: Net.btConnected.length > 0; name: "bluetooth_connected"; size: 16; color: Theme.text }
                Icon { name: Audio.icon(); size: 17; filled: true; color: Theme.text }
                Row {
                    visible: Battery.present
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        text: Math.round(Battery.pct * 100) + "%"
                        font.pixelSize: 12; font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Battery.low ? Theme.danger : Theme.text2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    BatteryGlyph { anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        IconButton {
            icon: "power_settings_new"
            iconSize: 17
            implicitWidth: 28; implicitHeight: 28
            active: Shell.open === "power"
            onClicked: Shell.toggle("power")
        }
    }
}
