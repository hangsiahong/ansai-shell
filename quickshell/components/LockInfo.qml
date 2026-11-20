import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services

// Lock screen extras under the clock, iOS style: weather line, Now Playing card, the latest notifications
// (app and title only; bodies stay hidden until unlock). White on the dimmed, blurred wallpaper.
Column {
    id: root
    width: 380
    spacing: 10
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property var notes: Notifs.list.slice(0, media.visible ? 2 : 3)   // fits above the password field at 900px
    readonly property color card: Qt.rgba(1, 1, 1, 0.16)

    Row {
        visible: Weather.enabled && Weather.current !== null
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        readonly property var lk: Weather.current ? Weather.look(Weather.current.code, Weather.current.day) : ["cloud", ""]
        Icon { anchors.verticalCenter: parent.verticalCenter; name: parent.lk[0]; filled: true; size: 18; color: "#ffffff" }
        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: (Weather.current?.temp ?? "") + "°  " + parent.lk[1] + (Weather.days.length ? "  ·  H:" + Weather.days[0].max + "° L:" + Weather.days[0].min + "°" : "")
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: Qt.rgba(1, 1, 1, 0.9)
        }
    }

    Item { width: 1; height: 8; visible: media.visible || root.notes.length > 0 }

    Rectangle {
        id: media
        visible: root.player !== null && (root.player.trackTitle || root.player.identity)
        width: root.width; height: 76; radius: 22
        color: root.card
        Rectangle {
            id: art
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            width: 56; height: 56; radius: 12
            color: Qt.rgba(1, 1, 1, 0.14)
            clip: true
            Image { anchors.fill: parent; source: root.player?.trackArtUrl ?? ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(112, 112); asynchronous: true }
            Icon { anchors.centerIn: parent; visible: !root.player?.trackArtUrl; name: "music_note"; color: "#ffffff" }
        }
        Column {
            anchors { left: art.right; leftMargin: 12; right: ctl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            Txt { width: parent.width; text: root.player?.trackTitle || root.player?.identity || ""; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#ffffff" }
            Txt { width: parent.width; text: root.player?.trackArtist ?? ""; font.pixelSize: 12; color: Qt.rgba(1, 1, 1, 0.7) }
        }
        Row {
            id: ctl
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            Repeater {
                model: [["skip_previous", 20, () => root.player?.previous()], [root.player?.isPlaying ? "pause" : "play_arrow", 26, () => root.player?.togglePlaying()], ["skip_next", 20, () => root.player?.next()]]
                Item {
                    required property var modelData
                    width: 34; height: 40
                    Icon { anchors.centerIn: parent; name: parent.modelData[0]; size: parent.modelData[1]; filled: true; color: "#ffffff" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData[2]() }
                }
            }
        }
    }

    Repeater {
        model: root.notes
        Rectangle {
            id: nc
            required property var modelData
            required property int index
            width: root.width; height: 60; radius: 20
            color: root.card
            AppIcon {
                id: ic
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                size: 34
                icon: nc.modelData.n?.appIcon || DesktopEntries.heuristicLookup(nc.modelData.n?.appName ?? "")?.icon || ""
                label: nc.modelData.n?.appName ?? ""
            }
            Column {
                anchors { left: ic.right; leftMargin: 12; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                Item {
                    width: parent.width; height: an.height
                    Txt { id: an; width: parent.width - age.width - 8; text: nc.modelData.n?.appName || "Notification"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Qt.rgba(1, 1, 1, 0.7) }
                    Txt {
                        id: age
                        anchors.right: parent.right
                        text: { const s = Math.floor((Time.now - nc.modelData.time) / 60000); return s < 1 ? "now" : s < 60 ? s + "m ago" : Math.floor(s / 60) + "h ago"; }
                        font.pixelSize: 11
                        color: Qt.rgba(1, 1, 1, 0.55)
                    }
                }
                Txt { width: parent.width; text: nc.modelData.n?.summary || ""; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#ffffff" }
            }
        }
    }
    Txt {
        visible: Notifs.list.length > root.notes.length
        anchors.horizontalCenter: parent.horizontalCenter
        text: (Notifs.list.length - root.notes.length) + " more"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: Qt.rgba(1, 1, 1, 0.6)
    }
}
