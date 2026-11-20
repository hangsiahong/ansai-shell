import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.services

// One notification, ansai card style: app icon + name + age, summary, body, actions.
Rectangle {
    id: root
    required property var entry
    property bool popup: false
    readonly property var n: entry.n

    implicitHeight: col.implicitHeight + (Theme.m3 ? 32 : 24)
    // ansai: macOS 27 notification, glass bubble with a big app icon, bold title and the age at the right.
    radius: Theme.m3 ? 24 : 22
    property real screenX: NaN
    property real screenY: NaN
    readonly property bool ownBlur: popup && !Theme.m3 && !isNaN(screenX)
    color: ownBlur ? "transparent" : popup ? Theme.glass : Theme.m3 ? Theme.surface2 : Theme.glassTile
    GlassBackdrop { visible: root.ownBlur; anchors.fill: parent; radius: root.radius; screenX: root.screenX; screenY: root.screenY; z: -2 }
    Rectangle { visible: root.ownBlur; anchors.fill: parent; radius: root.radius; color: Theme.glass; z: -1 }
    border.width: 0
    GlassRim { anchors.fill: parent; radius: root.radius; z: 1000; visible: !Theme.m3 && root.popup }
    readonly property string age: {
        const s = Math.floor((Time.now - entry.time) / 60000);
        return s < 1 ? "now" : s < 60 ? s + "m ago" : Math.floor(s / 60) + "h ago";
    }
    readonly property string iconName: n?.appIcon || DesktopEntries.heuristicLookup(n?.appName ?? "")?.icon || ""

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.MiddleButton) { Notifs.dismiss(root.entry); return; }
            const def = root.n?.actions?.find(a => a.identifier === "default");
            if (def) def.invoke();
            if (root.popup) Notifs.hidePopup(root.entry);
        }
        onContainsMouseChanged: {
            if (!root.popup) return;
            if (containsMouse) hideTimer.stop();
            else { hideTimer.interval = Math.min(root.timeout, 2500); hideTimer.restart(); }
        }
    }

    readonly property int timeout: n?.urgency === NotificationUrgency.Critical ? 0x7fffffff : (n?.expireTimeout > 0 ? n.expireTimeout : 5000)
    // The toast stack's Repeater recreates cards whenever a popup comes or goes, so count from arrival, not creation.
    Timer {
        id: hideTimer
        running: root.popup
        interval: Math.max(300, root.timeout - (Date.now() - root.entry.time))
        onTriggered: Notifs.hidePopup(root.entry)
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.m3 ? 16 : 12 }
        spacing: 4

        RowLayout {
            visible: Theme.m3
            spacing: 8
            AppIcon {
                size: 18
                icon: root.n?.appIcon || DesktopEntries.heuristicLookup(root.n?.appName ?? "")?.icon || ""
                label: root.n?.appName ?? ""
            }
            Txt {
                Layout.fillWidth: true
                text: Theme.m3 ? (root.n?.appName || "Notification") : (root.n?.appName || "Notification").toUpperCase()
                font.pixelSize: Theme.m3 ? 12 : 11
                font.weight: Theme.strong
                font.letterSpacing: Theme.m3 ? 0.1 : 0.4
                color: Theme.muted
            }
            Txt {
                text: {
                    const s = Math.floor((Time.now - root.entry.time) / 60000);
                    return s < 1 ? "now" : s < 60 ? s + "m" : Math.floor(s / 60) + "h";
                }
                font.pixelSize: 11
                color: Theme.faint
            }
            IconButton {
                implicitWidth: 20; implicitHeight: 20
                icon: "close"; iconSize: 14; iconColor: Theme.muted
                onClicked: Notifs.dismiss(root.entry)
            }
        }

        RowLayout {
            spacing: 10
            AppIcon {
                visible: !Theme.m3
                Layout.alignment: Qt.AlignTop
                size: 34
                icon: root.iconName
                label: root.n?.appName ?? ""
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Txt {
                        Layout.fillWidth: true
                        text: root.n?.summary || root.n?.appName || ""
                        font.pixelSize: Theme.m3 ? 14 : 13
                        font.weight: Theme.m3 ? Theme.strong : Font.Bold
                    }
                    Txt { visible: !Theme.m3; text: root.age; font.pixelSize: 11; color: Theme.muted }
                    IconButton {
                        visible: !Theme.m3
                        implicitWidth: 18; implicitHeight: 18
                        icon: "close"; iconSize: 13; iconColor: Theme.muted
                        onClicked: Notifs.dismiss(root.entry)
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.n?.body ?? ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.popup ? 3 : 6
                    font.pixelSize: 13
                    color: Theme.m3 ? Theme.text2 : Theme.text
                    onLinkActivated: l => Qt.openUrlExternally(l)
                }
            }
            Image {
                visible: (root.n?.image ?? "") !== ""
                source: root.n?.image ?? ""
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(80, 80)
                asynchronous: true
            }
        }

        RowLayout {
            Layout.topMargin: 4
            visible: actions.count > 0
            spacing: 6
            Repeater {
                id: actions
                model: (root.n?.actions ?? []).filter(a => a.identifier !== "default")
                Hover {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.m3 ? 36 : 30
                    radius: Theme.m3 ? height / 2 : 9
                    base: Theme.m3 ? Theme.tonal : Theme.glassTile
                    onClicked: { modelData.invoke(); Notifs.hidePopup(root.entry); }
                    Txt { anchors.centerIn: parent; text: parent.modelData.text; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.m3 ? Theme.tonalInk : Theme.text }
                }
            }
        }
    }
}
