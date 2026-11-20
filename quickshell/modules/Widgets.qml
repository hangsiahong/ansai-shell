import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services

// Desktop widgets on the wallpaper, under the windows (Background layer): clock, weather, battery,
// calendar, now playing. Settings.widgets picks which; each is dragged anywhere (DeskWidget).
Item {
    id: root
    readonly property int s: 164   // small widget side
    readonly property int g: 14    // gap
    readonly property int m: 2 * s + g   // medium width
    readonly property real x0: width - 28 - m
    readonly property real y0: Theme.barH + 28
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    DeskWidget {
        wid: "clock"
        card: false
        pad: 0
        width: root.m; height: 116
        home: Qt.point(root.x0, root.y0)
        Column {
            anchors.right: parent.right
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, Theme.dark ? 0.5 : 0.18); shadowBlur: 0.6; shadowVerticalOffset: 2 }
            Txt {
                anchors.right: parent.right
                text: Time.longDate
                font.pixelSize: 18
                font.weight: Theme.strong
                color: Theme.text
            }
            Txt {
                anchors.right: parent.right
                text: Time.shortTime
                font.pixelSize: 80
                font.weight: Font.DemiBold
                font.letterSpacing: -2
                color: Theme.text
            }
        }
    }

    DeskWidget {
        wid: "weather"
        visible: Settings.widgets.includes("weather") && Weather.enabled && Weather.current !== null
        width: root.s; height: root.s
        home: Qt.point(root.x0, root.y0 + 116 + root.g)
        readonly property var lk: Weather.current ? Weather.look(Weather.current.code, Weather.current.day) : ["cloud", ""]
        Column {
            anchors.fill: parent
            spacing: 0
            Txt { width: parent.width; text: Weather.place; font.pixelSize: 13; font.weight: Theme.strong }
            Txt { text: (Weather.current?.temp ?? "") + "°"; font.pixelSize: 44; font.weight: Font.Light }
            Item { width: 1; height: 6 }
            Icon { name: parent.parent.parent.lk[0]; size: 20; filled: true; color: Theme.warn }
            Txt { width: parent.width; text: parent.parent.parent.lk[1]; font.pixelSize: 12; font.weight: Theme.strong }
            Txt {
                width: parent.width
                text: Weather.days.length ? "H:" + Weather.days[0].max + "°  L:" + Weather.days[0].min + "°" : ""
                font.pixelSize: 12
                color: Theme.muted
            }
        }
    }

    DeskWidget {
        wid: "calendar"
        width: root.s; height: root.s
        pad: 12
        home: Qt.point(root.x0 + root.s + root.g, root.y0 + 116 + root.g)
        readonly property date d: Time.now
        Column {
            anchors.fill: parent
            spacing: 3
            Txt { text: Qt.formatDate(parent.parent.parent.d, "MMMM").toUpperCase(); font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 0.4; color: Theme.danger }
            Grid {
                id: cal
                columns: 7
                readonly property real cw: parent.width / 7
                readonly property date d: parent.parent.parent.d
                readonly property int first: (new Date(d.getFullYear(), d.getMonth(), 1).getDay() + 6) % 7
                readonly property int days: new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Txt { required property string modelData; width: cal.cw; height: 15; horizontalAlignment: Text.AlignHCenter; text: modelData; font.pixelSize: 9; font.weight: Font.Bold; color: Theme.muted }
                }
                Repeater {
                    model: 42
                    Item {
                        required property int index
                        readonly property int day: index - cal.first + 1
                        readonly property bool today: day === cal.d.getDate()
                        visible: index < Math.ceil((cal.first + cal.days) / 7) * 7
                        width: cal.cw; height: 17
                        Rectangle { anchors.centerIn: parent; width: 17; height: 17; radius: 8.5; color: Theme.danger; visible: parent.today }
                        Txt {
                            anchors.centerIn: parent
                            text: parent.day >= 1 && parent.day <= cal.days ? parent.day : ""
                            font.pixelSize: 10
                            font.weight: parent.today ? Font.Bold : Font.Medium
                            color: parent.today ? "#ffffff" : Theme.text
                        }
                    }
                }
            }
        }
    }

    DeskWidget {
        wid: "battery"
        visible: Settings.widgets.includes("battery") && Battery.present
        width: root.s; height: root.s
        home: Qt.point(root.x0, root.y0 + 116 + 2 * root.g + root.s)
        Txt { text: "Battery"; font.pixelSize: 13; font.weight: Theme.strong }
        Canvas {
            id: ring
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
            width: 100; height: 100
            readonly property real v: Battery.pct
            readonly property color c: Battery.charging ? Theme.green : Battery.low ? Theme.danger : Theme.accent
            onVChanged: requestPaint()
            onCChanged: requestPaint()
            Connections { target: Theme; function onDarkChanged() { ring.requestPaint(); } }
            onPaint: {
                const x = getContext("2d");
                x.reset();
                x.lineWidth = 9;
                x.lineCap = "round";
                x.strokeStyle = Theme.dark ? "rgba(255,255,255,0.14)" : "rgba(0,0,0,0.08)";
                x.beginPath(); x.arc(50, 50, 44, 0, 2 * Math.PI); x.stroke();
                x.strokeStyle = c;
                x.beginPath(); x.arc(50, 50, 44, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.01, v)); x.stroke();
            }
            Column {
                anchors.centerIn: parent
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Battery.charging ? "bolt" : "laptop"; size: 18; filled: true; color: ring.c }
                Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(Battery.pct * 100) + "%"; font.pixelSize: 20; font.weight: Theme.strong }
            }
        }
    }

    DeskWidget {
        wid: "media"
        visible: Settings.widgets.includes("media") && root.player !== null
        width: root.s; height: root.s
        pad: 12
        home: Qt.point(root.x0 + root.s + root.g, root.y0 + 116 + 2 * root.g + root.s)
        Rectangle {
            id: art
            width: 64; height: 64; radius: 12
            color: Theme.surface3
            clip: true
            Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(128, 128); asynchronous: true }
            Icon { anchors.centerIn: parent; name: "music_note"; visible: !root.player?.trackArtUrl; color: Theme.muted }
        }
        Column {
            anchors { left: parent.left; right: parent.right; top: art.bottom; topMargin: 8 }
            Txt { width: parent.width; text: root.player?.trackTitle || root.player?.identity || ""; font.pixelSize: 13; font.weight: Theme.strong }
            Txt { width: parent.width; text: root.player?.trackArtist ?? ""; font.pixelSize: 11; color: Theme.muted }
        }
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: -6 }
            IconButton { icon: "skip_previous"; filled: true; iconSize: 18; onClicked: root.player?.previous() }
            IconButton { icon: root.player?.isPlaying ? "pause" : "play_arrow"; filled: true; iconSize: 22; onClicked: root.player?.togglePlaying() }
            IconButton { icon: "skip_next"; filled: true; iconSize: 18; onClicked: root.player?.next() }
        }
    }
}
