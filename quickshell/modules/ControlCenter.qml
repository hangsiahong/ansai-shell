import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services

Sheet {
    id: root
    name: "control"
    panelWidth: 360
    panelHeight: col.implicitHeight + 24
    panelX: width - panelWidth - 8
    panelY: 44

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    onShownChanged: if (shown) Brightness.refresh()

    Process {
        running: Settings.nightLight
        command: ["wlsunset", "-T", "6500", "-t", "4000", "-S", "00:00", "-s", "00:01", "-d", "1"]
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                on: Net.wifiOn || Net.wired
                icon: Net.netIcon()
                title: Net.wired ? "Ethernet" : "Wi-Fi"
                sub: Net.netLabel()
                onClicked: m => m.button === Qt.RightButton ? Quickshell.execDetached(["nm-connection-editor"]) : Net.toggleWifi()
            }
            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                on: Net.btOn
                icon: Net.btOn ? "bluetooth" : "bluetooth_disabled"
                title: "Bluetooth"
                sub: !Net.bt ? "Unavailable" : !Net.btOn ? "Off" : Net.btConnected.length ? Net.btConnected[0].name : "On"
                onClicked: Net.toggleBt()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            RoundToggle {
                Layout.fillWidth: true
                on: Settings.dnd
                icon: "do_not_disturb_on"
                label: "Focus"
                onColor: Theme.indigo
                onClicked: Settings.dnd = !Settings.dnd
            }
            RoundToggle {
                Layout.fillWidth: true
                on: Theme.dark
                icon: "dark_mode"
                label: "Dark"
                onClicked: Settings.theme = Theme.dark ? "light" : "dark"
            }
            RoundToggle {
                Layout.fillWidth: true
                on: Settings.nightLight
                icon: "nightlight"
                label: "Night"
                onColor: Theme.warn
                onClicked: Settings.nightLight = !Settings.nightLight
            }
            RoundToggle {
                Layout.fillWidth: true
                on: Battery.profile !== "Balanced"
                icon: Battery.profile === "Performance" ? "bolt" : Battery.profile === "PowerSaver" ? "eco" : "balance"
                label: Battery.profile === "PowerSaver" ? "Saver" : Battery.profile === "Performance" ? "Perf" : "Balanced"
                onColor: Battery.profile === "PowerSaver" ? Theme.green : Theme.danger
                onClicked: Battery.cycleProfile()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: sliders.implicitHeight + 24
            radius: Theme.r
            color: Theme.fill2

            ColumnLayout {
                id: sliders
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 12

                ColumnLayout {
                    visible: Brightness.available
                    spacing: 6
                    Txt { text: "Display"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.muted }
                    Slider {
                        Layout.fillWidth: true
                        value: Brightness.value
                        icon: "light_mode"
                        onMoved: v => Brightness.set(v)
                    }
                }
                ColumnLayout {
                    spacing: 6
                    RowLayout {
                        Txt { text: "Sound"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.muted }
                        Item { Layout.fillWidth: true }
                        Txt {
                            Layout.maximumWidth: 200
                            text: Audio.sink?.description ?? ""
                            font.pixelSize: 11
                            color: Theme.faint
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                    Slider {
                        Layout.fillWidth: true
                        value: Audio.muted ? 0 : Audio.volume
                        icon: Audio.icon()
                        onMoved: v => Audio.setVolume(v)
                    }
                }
            }
        }

        Rectangle {
            visible: root.player !== null
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: Theme.r
            color: Theme.fill2

            Rectangle {
                id: art
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 56; height: 56; radius: 10
                color: Theme.surface3
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Icon { anchors.centerIn: parent; name: "music_note"; visible: !root.player?.trackArtUrl; color: Theme.muted }
            }
            Column {
                anchors { left: art.right; leftMargin: 12; right: ctrls.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 2
                Txt { width: parent.width; text: root.player?.trackTitle || root.player?.identity || ""; font.pixelSize: 14; font.weight: Font.DemiBold }
                Txt { width: parent.width; text: root.player?.trackArtist ?? ""; font.pixelSize: 12; color: Theme.muted }
            }
            Row {
                id: ctrls
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                IconButton { icon: "skip_previous"; filled: true; onClicked: root.player?.previous() }
                IconButton { icon: root.player?.isPlaying ? "pause" : "play_arrow"; iconSize: 24; filled: true; onClicked: root.player?.togglePlaying() }
                IconButton { icon: "skip_next"; filled: true; onClicked: root.player?.next() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            IconButton {
                icon: "screenshot_region"
                onClicked: { Shell.close(); Niri.action("screenshot"); }
            }
            IconButton {
                icon: "tune"
                onClicked: { Shell.close(); Quickshell.execDetached(["xdg-open", Settings.dir + "/settings.json"]); }
            }
            Item { Layout.fillWidth: true }
            Txt {
                visible: Battery.present
                text: Math.round(Battery.pct * 100) + "%" + (Battery.charging ? " · charging" : "")
                font.pixelSize: 12
                color: Theme.muted
            }
            IconButton {
                icon: "lock"
                onClicked: { Shell.close(); Lock.lock(); }
            }
            IconButton {
                icon: "power_settings_new"
                onClicked: Shell.open = "power"
            }
        }
    }
}
