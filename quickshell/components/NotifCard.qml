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

    implicitHeight: col.implicitHeight + 24
    radius: Theme.r
    color: popup ? Theme.glass : Theme.fill2
    border.width: popup ? 1 : 0
    border.color: Theme.glassLine

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
        onContainsMouseChanged: hideTimer.running = !containsMouse && root.popup
    }

    Timer {
        id: hideTimer
        running: root.popup
        interval: root.n?.urgency === NotificationUrgency.Critical ? 0x7fffffff : (root.n?.expireTimeout > 0 ? root.n.expireTimeout : 5000)
        onTriggered: Notifs.hidePopup(root.entry)
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 4

        RowLayout {
            spacing: 8
            AppIcon {
                size: 18
                icon: root.n?.appIcon || DesktopEntries.heuristicLookup(root.n?.appName ?? "")?.icon || ""
                label: root.n?.appName ?? ""
            }
            Txt {
                Layout.fillWidth: true
                text: (root.n?.appName || "Notification").toUpperCase()
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 0.4
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
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    Layout.fillWidth: true
                    text: root.n?.summary ?? ""
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.n?.body ?? ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.popup ? 3 : 6
                    font.pixelSize: 13
                    color: Theme.text2
                    onLinkActivated: l => Qt.openUrlExternally(l)
                }
            }
            Image {
                visible: (root.n?.image ?? "") !== ""
                source: root.n?.image ?? ""
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                fillMode: Image.PreserveAspectCrop
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
                    Layout.preferredHeight: 30
                    base: Theme.fill
                    onClicked: { modelData.invoke(); Notifs.hidePopup(root.entry); }
                    Txt { anchors.centerIn: parent; text: parent.modelData.text; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.accent }
                }
            }
        }
    }
}
