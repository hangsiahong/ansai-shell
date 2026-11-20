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
    panelWidth: Theme.m3 ? 360 : 330
    panelHeight: (Theme.m3 ? col : mac).implicitHeight + 24
    panelX: width - panelWidth - 8
    panelY: Theme.barH + 8

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    property string detail: ""   // "", "wifi", "bt": the list open under the tiles
    onShownChanged: if (shown) Brightness.refresh(); else detail = ""

    Process {
        running: Settings.nightLight
        command: ["wlsunset", "-T", "6500", "-t", "4000", "-S", "00:00", "-s", "00:01", "-d", "1"]
    }

    ColumnLayout {
        id: col
        visible: Theme.m3
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
                more: !Net.wired
                expanded: root.detail === "wifi"
                onExpand: root.detail = root.detail === "wifi" ? "" : "wifi"
                onClicked: m => m.button === Qt.RightButton ? Quickshell.execDetached(["nm-connection-editor"]) : Net.toggleWifi()
            }
            Tile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                on: Net.btOn
                icon: Net.btOn ? "bluetooth" : "bluetooth_disabled"
                title: "Bluetooth"
                sub: !Net.bt ? "Unavailable" : !Net.btOn ? "Off" : Net.btConnected.length ? Net.btConnected[0].name : "On"
                more: !!Net.bt
                expanded: root.detail === "bt"
                onExpand: root.detail = root.detail === "bt" ? "" : "bt"
                onClicked: Net.toggleBt()
            }
        }

        Rectangle {
            visible: root.detail !== ""
            Layout.fillWidth: true
            implicitHeight: detailLoader.implicitHeight + 12
            radius: Theme.m3 ? 24 : Theme.r
            color: Theme.fill2
            Loader {
                id: detailLoader
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                active: root.detail !== ""
                sourceComponent: root.detail === "wifi" ? wifiC : btC
            }
            Component { id: wifiC; WifiList {} }
            Component { id: btC; BtList {} }
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
                on: Settings.keepAwake
                icon: "coffee"
                label: "Awake"
                onColor: Theme.green
                onClicked: Settings.keepAwake = !Settings.keepAwake
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
                    Txt { text: "Display"; font.pixelSize: 12; font.weight: Theme.strong; color: Theme.muted }
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
                        Txt { text: "Sound"; font.pixelSize: 12; font.weight: Theme.strong; color: Theme.muted }
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

        // Look: style and font. Both persist in settings.json.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: Theme.r
            color: Theme.fill2

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                spacing: 4
                Repeater {
                    model: [{ id: "ansai", label: "ansai", icon: "terminal" }, { id: "material", label: "Android", icon: "android" }]
                    Hover {
                        required property var modelData
                        readonly property bool sel: Settings.style === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Theme.m3 ? (sel ? 12 : 20) : 10
                        base: "transparent"
                        active: sel
                        activeColor: Theme.m3 ? Theme.accent : Theme.seg
                        Behavior on radius { NumberAnimation { duration: Theme.med; easing.type: Theme.spring } }
                        onClicked: { Settings.style = modelData.id; Settings.font = ""; }
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: modelData.icon; size: 17; filled: parent.parent.sel; color: parent.parent.sel && Theme.m3 ? Theme.accentInk : Theme.text; anchors.verticalCenter: parent.verticalCenter }
                            Txt { text: modelData.label; font.pixelSize: 13; font.weight: Theme.strong; color: parent.parent.sel && Theme.m3 ? Theme.accentInk : Theme.text }
                        }
                    }
                }
                Hover {
                    Layout.preferredWidth: fontLbl.implicitWidth + 40
                    Layout.preferredHeight: 40
                    radius: Theme.m3 ? 20 : 10
                    base: Theme.fill
                    onClicked: m => {
                        const f = Theme.fonts, i = f.indexOf(Theme.fontName);
                        Settings.font = f[(i + (m.button === Qt.RightButton ? f.length - 1 : 1)) % f.length];
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { name: "text_fields"; size: 17; color: Theme.text2; anchors.verticalCenter: parent.verticalCenter }
                        Txt { id: fontLbl; text: Theme.fontName; font.pixelSize: 13; color: Theme.text }
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
                    sourceSize: Qt.size(112, 112)
                    asynchronous: true
                }
                Icon { anchors.centerIn: parent; name: "music_note"; visible: !root.player?.trackArtUrl; color: Theme.muted }
            }
            Column {
                anchors { left: art.right; leftMargin: 12; right: ctrls.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 2
                Txt { width: parent.width; text: root.player?.trackTitle || root.player?.identity || ""; font.pixelSize: 14; font.weight: Theme.strong }
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
                onClicked: Shell.openSettings("")
            }
            IconButton {
                icon: "auto_awesome"
                onClicked: Shell.open = "ai"
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

    // ---- ansai: macOS 27 Control Center, modules of lighter glass on the glass panel.
    ColumnLayout {
        id: mac
        visible: !Theme.m3
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MacModule {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: conn.implicitHeight + 16
                Column {
                    id: conn
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10 }
                    spacing: 2
                    MacConnRow {
                        width: parent.width
                        on: Net.wifiOn || !!Net.wired
                        icon: Net.netIcon()
                        title: Net.wired ? "Ethernet" : "Wi-Fi"
                        sub: Net.netLabel()
                        expanded: root.detail === "wifi"
                        onToggle: Net.toggleWifi()
                        onExpand: root.detail = root.detail === "wifi" ? "" : "wifi"
                    }
                    MacConnRow {
                        width: parent.width
                        on: Net.btOn
                        icon: "bluetooth"
                        title: "Bluetooth"
                        sub: !Net.bt ? "Unavailable" : !Net.btOn ? "Off" : Net.btConnected.length ? Net.btConnected[0].name : "On"
                        expanded: root.detail === "bt"
                        onToggle: Net.toggleBt()
                        onExpand: root.detail = root.detail === "bt" ? "" : "bt"
                    }
                    MacConnRow {
                        width: parent.width
                        on: Settings.keepAwake
                        icon: "coffee"
                        title: "Keep Awake"
                        sub: Settings.keepAwake ? "On" : "Off"
                        onToggle: Settings.keepAwake = !Settings.keepAwake
                        onExpand: Settings.keepAwake = !Settings.keepAwake
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 10
                MacToggle {
                    Layout.fillWidth: true
                    on: Settings.dnd
                    icon: "do_not_disturb_on"
                    label: "Focus"
                    sub: Settings.dnd ? "Do Not Disturb" : ""
                    onColor: Theme.indigo
                    onClicked: Settings.dnd = !Settings.dnd
                }
                MacToggle {
                    Layout.fillWidth: true
                    on: Theme.dark
                    icon: "dark_mode"
                    label: "Dark Mode"
                    onClicked: Settings.theme = Theme.dark ? "light" : "dark"
                }
            }
        }

        MacModule {
            visible: root.detail !== ""
            Layout.fillWidth: true
            implicitHeight: macDetail.implicitHeight + 12
            Loader {
                id: macDetail
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                active: root.detail !== "" && !Theme.m3
                sourceComponent: root.detail === "wifi" ? wifiC : btC
            }
        }

        MacModule {
            visible: Brightness.available
            Layout.fillWidth: true
            implicitHeight: 70
            Txt { x: 14; y: 10; text: "Display"; font.pixelSize: 13; font.weight: Font.DemiBold }
            MacSlider {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                value: Brightness.value
                icon: "light_mode"
                onMoved: v => Brightness.set(v)
            }
        }
        MacModule {
            Layout.fillWidth: true
            implicitHeight: 70
            Txt { x: 14; y: 10; text: "Sound"; font.pixelSize: 13; font.weight: Font.DemiBold }
            Txt {
                anchors { right: parent.right; rightMargin: 14; top: parent.top; topMargin: 11 }
                width: Math.min(implicitWidth, 170)
                text: Audio.sink?.description ?? ""
                font.pixelSize: 11
                color: Theme.muted
            }
            MacSlider {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                value: Audio.muted ? 0 : Audio.volume
                icon: Audio.icon()
                onMoved: v => Audio.setVolume(v)
            }
        }

        MacModule {
            visible: root.player !== null
            Layout.fillWidth: true
            implicitHeight: 64
            Rectangle {
                id: macArt
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 44; radius: 9
                color: Theme.surface3
                clip: true
                Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(88, 88); asynchronous: true }
                Icon { anchors.centerIn: parent; name: "music_note"; visible: !root.player?.trackArtUrl; color: Theme.muted }
            }
            Column {
                anchors { left: macArt.right; leftMargin: 10; right: macCtrls.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                Txt { width: parent.width; text: root.player?.trackTitle || root.player?.identity || ""; font.pixelSize: 13; font.weight: Font.DemiBold }
                Txt { width: parent.width; text: root.player?.trackArtist ?? ""; font.pixelSize: 11; color: Theme.muted }
            }
            Row {
                id: macCtrls
                anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                IconButton { icon: "skip_previous"; filled: true; iconSize: 20; onClicked: root.player?.previous() }
                IconButton { icon: root.player?.isPlaying ? "pause" : "play_arrow"; iconSize: 24; filled: true; onClicked: root.player?.togglePlaying() }
                IconButton { icon: "skip_next"; filled: true; iconSize: 20; onClicked: root.player?.next() }
            }
        }

        // Mixed sizes like macOS: two wide toggles, then a row of icon-only buttons (room to add more).
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MacToggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                on: Settings.nightLight
                icon: "nightlight"
                label: "Night Shift"
                sub: Settings.nightLight ? "On" : "Off"
                onColor: Theme.warn
                onClicked: Settings.nightLight = !Settings.nightLight
            }
            MacToggle {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                on: Battery.profile !== "Balanced"
                icon: Battery.profile === "Performance" ? "bolt" : Battery.profile === "PowerSaver" ? "eco" : "balance"
                label: "Power Mode"
                sub: Battery.profile === "PowerSaver" ? "Low Power" : Battery.profile === "Performance" ? "Performance" : "Balanced"
                onColor: Battery.profile === "PowerSaver" ? Theme.green : Theme.warn
                onClicked: Battery.cycleProfile()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [
                    { icon: "screenshot_region", run: () => { Shell.close(); Niri.action("screenshot"); } },
                    { icon: "auto_awesome", run: () => { Shell.open = "ai"; } },
                    { icon: "android", run: () => { Settings.style = "material"; Settings.font = ""; } },
                    { icon: "lock", run: () => { Shell.close(); Lock.lock(); } },
                    { icon: "power_settings_new", run: () => { Shell.open = "power"; } }
                ]
                MacToggle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    wide: false
                    icon: modelData.icon
                    onClicked: modelData.run()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 2
            Txt {
                Layout.fillWidth: true
                visible: Battery.present
                text: Math.round(Battery.pct * 100) + "%" + (Battery.charging ? " · Charging" : "")
                font.pixelSize: 12
                color: Theme.muted
            }
            Hover {
                implicitWidth: editLbl.implicitWidth + 20; implicitHeight: 26
                radius: 13
                onClicked: Shell.openSettings("")
                Txt { id: editLbl; anchors.centerIn: parent; text: "Settings…"; font.pixelSize: 12; color: Theme.text2 }
            }
        }
    }
}
