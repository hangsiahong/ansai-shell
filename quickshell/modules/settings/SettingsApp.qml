import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// "ansai Settings": a real toplevel (niri tiles/floats it like any app). Opened from the control
// center's gear, the launcher (.desktop), or `qs -c ansai ipc call shell settings <page>`.
FloatingWindow {
    id: win
    title: "ansai Settings"
    implicitWidth: 940
    implicitHeight: 660
    minimumSize: Qt.size(720, 480)
    color: Theme.m3 ? Theme.bg : Theme.dark ? "#000000" : "#f2f2f7"
    onClosed: Shell.settings = false

    readonly property var pages: [
        { id: "wifi", l: "Wi-Fi", icon: "wifi", sub: "Networks, saved networks", c: "#0a84ff" },
        { id: "bluetooth", l: "Bluetooth", icon: "bluetooth", sub: "Devices, pairing", c: "#0a84ff" },
        { id: "appearance", l: "Appearance", icon: "palette", sub: "Style, theme, wallpaper, font", c: "#636366" },
        { id: "wallpaper", l: "Wallpaper", icon: "wallpaper", sub: "Pick a picture", c: "#32ade6" },
        { id: "dock", l: "Dock", icon: "dock_to_left", sub: "Auto-hide, size, pinned apps", c: "#ff9f0a" },
        { id: "displays", l: "Displays", icon: "desktop_windows", sub: "Resolution, refresh, scale", c: "#30d158" },
        { id: "graphics", l: "Graphics", icon: "memory", sub: "Integrated, hybrid, dGPU", c: "#bf5af2" },
        { id: "power", l: "Power & Battery", icon: "battery_charging_full", sub: "Profile, fans, charge limit, keyboard", c: "#34c759" },
        { id: "sound", l: "Sound", icon: "volume_up", sub: "Output and input devices", c: "#ff375f" },
        { id: "notifications", l: "Notifications", icon: "notifications", sub: "Do Not Disturb, schedule, apps", c: "#ff3b30" },
        { id: "defaults", l: "Default Apps", icon: "apps", sub: "Browser, files, terminal, viewers", c: "#5856d6" },
        { id: "ai", l: "AI", icon: "auto_awesome", sub: "KOOMPI AI: model, key, languages", c: "#5e5ce6" },
        { id: "about", l: "About", icon: "info", sub: "This device, advanced", c: "#8e8e93" }
    ]
    readonly property var page: pages.find(p => p.id === Shell.settingsPage) ?? pages[0]

    Shortcut { sequence: "Ctrl+W"; onActivated: Shell.settings = false }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Shell.settings = false }
    Shortcut { sequence: "Ctrl+PgDown"; onActivated: win.step(1) }
    Shortcut { sequence: "Ctrl+PgUp"; onActivated: win.step(-1) }
    function step(d) {
        const i = pages.indexOf(page);
        Shell.settingsPage = pages[(i + d + pages.length) % pages.length].id;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- sidebar
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 248
            color: Theme.m3 ? Theme.surface : Theme.dark ? "#121214" : "#e9e9ee"
            Rectangle {
                visible: !Theme.m3
                anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                width: 1
                color: Theme.line
            }

            ColumnLayout {
                anchors { fill: parent; margins: 12; topMargin: 18 }
                spacing: 2

                Txt {
                    Layout.leftMargin: 10
                    Layout.bottomMargin: 14
                    text: "Settings"
                    font.pixelSize: Theme.m3 ? 26 : 24
                    font.weight: Theme.m3 ? Font.Normal : Font.Bold
                }

                Repeater {
                    model: win.pages
                    Hover {
                        id: nav
                        required property var modelData
                        required property int index
                        readonly property bool on: win.page.id === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.m3 ? 52 : 40
                        radius: Theme.m3 ? height / 2 : 9
                        active: on
                        activeColor: Theme.m3 ? Theme.accentSoft : Theme.accent
                        onClicked: Shell.settingsPage = modelData.id
                        RowLayout {
                            anchors { fill: parent; leftMargin: Theme.m3 ? 18 : 10; rightMargin: 10 }
                            spacing: Theme.m3 ? 14 : 10
                            Rectangle {
                                visible: !Theme.m3
                                width: 26; height: 26; radius: 7
                                color: nav.on ? Qt.rgba(1, 1, 1, 0.22) : nav.modelData.c
                                Icon { anchors.centerIn: parent; name: nav.modelData.icon; size: 18; filled: true; color: "#ffffff" }
                            }
                            Icon {
                                visible: Theme.m3
                                name: nav.modelData.icon
                                size: 22
                                filled: nav.on
                                color: nav.on ? Theme.accentSoftInk : Theme.text2
                            }
                            Txt {
                                Layout.fillWidth: true
                                text: nav.modelData.l
                                font.pixelSize: Theme.m3 ? 15 : 14
                                font.weight: nav.on ? Theme.strong : Font.Normal
                                color: nav.on ? (Theme.m3 ? Theme.accentSoftInk : "#ffffff") : Theme.text
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        // ---- page
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: body.implicitHeight + 64
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: body
                    x: Math.max(28, (flick.width - width) / 2)
                    y: 26
                    width: Math.min(720, flick.width - 56)
                    spacing: 22

                    ColumnLayout {
                        spacing: 2
                        Txt { text: win.page.l; font.pixelSize: Theme.m3 ? 30 : 28; font.weight: Theme.m3 ? Font.Normal : Font.Bold }
                        Txt { text: win.page.sub; font.pixelSize: 13; color: Theme.muted }
                    }

                    Loader {
                        id: pageLoader
                        Layout.fillWidth: true
                        source: (win.page.id === "ai" ? "AI" : win.page.id[0].toUpperCase() + win.page.id.slice(1)) + "Page.qml"
                        onLoaded: flick.contentY = 0
                    }
                }
            }

            Rectangle {   // scroll indicator
                visible: flick.contentHeight > flick.height
                anchors.right: parent.right
                anchors.rightMargin: 3
                y: flick.visibleArea.yPosition * flick.height
                width: 4; radius: 2
                height: flick.visibleArea.heightRatio * flick.height
                color: Theme.faint
                opacity: flick.moving ? 0.9 : 0.35
                Behavior on opacity { NumberAnimation { duration: Theme.med } }
            }
        }
    }
}
