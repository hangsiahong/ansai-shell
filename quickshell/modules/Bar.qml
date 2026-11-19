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
    implicitHeight: Theme.barH
    color: "transparent"
    WlrLayershell.namespace: "ansai-bar"
    WlrLayershell.layer: WlrLayer.Top

    readonly property var wss: Niri.workspacesOn(modelData.name)

    // Keeps swayidle from locking or blanking while agents may be driving the desktop.
    IdleInhibitor {
        window: bar
        enabled: Settings.keepAwake
    }

    BackgroundEffect.blurRegion: Region { item: barBg }

    Rectangle {
        id: barBg
        anchors.fill: parent
        color: Theme.m3 ? Theme.bg : Theme.dark ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(1, 1, 1, 0.45)
        Behavior on color { ColorAnimation { duration: Theme.med } }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1
            color: Theme.glassLine
        }
    }

    // ---- left: mark, workspaces (clock in material), focused app
    RowLayout {
        anchors { left: parent.left; leftMargin: Theme.m3 ? 6 : 10; verticalCenter: parent.verticalCenter }
        spacing: 6

        Hover {
            Layout.preferredWidth: Theme.m3 ? 32 : 28
            Layout.preferredHeight: Theme.m3 ? 32 : 28
            radius: Theme.m3 ? (Shell.open === "launcher" ? 10 : 16) : 8
            base: Theme.m3 ? Theme.accentSoft : "transparent"
            active: Theme.m3 && Shell.open === "launcher"
            activeColor: Theme.accent
            Behavior on radius { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
            onClicked: Shell.toggle("launcher")
            Icon {
                anchors.centerIn: parent
                visible: Theme.m3
                name: "apps"
                size: 20
                color: Shell.open === "launcher" ? Theme.accentInk : Theme.accentSoftInk
            }
            Rectangle {
                anchors.centerIn: parent
                visible: !Theme.m3
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

        BarClock { visible: Theme.m3 }
        BarWorkspaces { visible: !Theme.m3 && wss.length > 0; wss: bar.wss }

        Hover {
            id: appName
            readonly property string appId: Niri.barWindow?.app_id ?? ""
            visible: appId !== ""
            Layout.preferredHeight: Theme.m3 ? 32 : 26
            Layout.preferredWidth: appLabel.implicitWidth + (Theme.m3 ? 24 : 16)
            radius: Theme.m3 ? height / 2 : 7
            active: Shell.open === "appmenu"
            activeColor: Theme.m3 ? Theme.accentSoft : Theme.fill
            onClicked: {
                Shell.appMenuX = appName.mapToItem(null, 0, 0).x;
                Shell.toggle("appmenu");
            }
            Txt {
                id: appLabel
                anchors.centerIn: parent
                text: appName.appId ? (DesktopEntries.heuristicLookup(appName.appId)?.name ?? appName.appId.split(".").pop()) : ""
                color: Theme.m3 && appName.active ? Theme.accentSoftInk : Theme.text
                font.pixelSize: 13
                font.weight: Theme.strong
            }
        }
        Txt {
            Layout.maximumWidth: bar.width * 0.22
            text: Niri.barWindow?.title ?? ""
            color: Theme.muted
            font.pixelSize: 13
        }
    }

    // ---- center: clock (workspaces in material)
    BarClock { anchors.centerIn: parent; visible: !Theme.m3 }
    BarWorkspaces { anchors.centerIn: parent; visible: Theme.m3 && wss.length > 0; wss: bar.wss }

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
            font.weight: Theme.strong
            Layout.rightMargin: 4
        }

        Hover {
            Layout.preferredHeight: Theme.m3 ? 32 : 28
            Layout.preferredWidth: status.implicitWidth + (Theme.m3 ? 24 : 20)
            radius: height / 2
            base: Theme.m3 ? Theme.tonal : "transparent"
            active: Shell.open === "control"
            activeColor: Theme.m3 ? Theme.accent : Theme.fill
            onClicked: Shell.toggle("control")
            onWheel: w => Audio.setVolume(Audio.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))

            Row {
                id: status
                anchors.centerIn: parent
                spacing: Theme.m3 ? 8 : 10
                readonly property color ink: Theme.m3 ? (Shell.open === "control" ? Theme.accentInk : Theme.tonalInk) : Theme.text
                Icon { name: Net.netIcon(); size: 17; filled: true; color: status.ink }
                Icon { visible: Net.btConnected.length > 0; name: "bluetooth_connected"; size: 16; color: status.ink }
                Icon { name: Audio.icon(); size: 17; filled: true; color: status.ink }
                BatteryGlyph { visible: Theme.m3 && Battery.present; ink: status.ink; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    visible: Battery.present && !Theme.m3
                    spacing: 3
                    anchors.verticalCenter: parent.verticalCenter
                    Txt {
                        text: Math.round(Battery.pct * 100) + "%"
                        font.pixelSize: 12; font.weight: Theme.strong
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
            implicitWidth: Theme.m3 ? 32 : 28; implicitHeight: implicitWidth
            base: Theme.m3 ? Theme.tonal : "transparent"
            iconColor: Theme.m3 ? Theme.tonalInk : Theme.text
            active: Shell.open === "power"
            onClicked: Shell.toggle("power")
        }
    }
}
