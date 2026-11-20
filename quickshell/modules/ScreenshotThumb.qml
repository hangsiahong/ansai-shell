import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// macOS-style floating thumbnail after a screenshot: bottom right for a few seconds (longer while hovered).
// Click opens Markup to draw on it; "Copy text" copies the text in it (services/Ocr.qml); the x dismisses it.
PanelWindow {
    id: root
    property string file: ""
    property bool up: false
    readonly property int tw: 220
    readonly property real th: img.implicitWidth ? Math.min(160, tw * img.implicitHeight / img.implicitWidth) : 124

    visible: file !== "" && (up || card.x < width)
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    color: "transparent"
    anchors { bottom: true; right: true }
    implicitWidth: tw + 48
    implicitHeight: th + 48
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ansai-screenshot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Connections {
        target: Niri
        function onScreenshotTaken(path: string): void {
            root.file = path;
            img.source = "";
            img.source = "file://" + path;
            root.up = true;
            hide.restart();
        }
    }
    Connections {
        target: Shell
        function onOpenChanged(): void { if (Shell.open === "markup") root.up = false; }
    }

    Timer {
        id: hide
        interval: 6000
        onTriggered: if (ma.containsMouse || ocr.containsMouse) restart(); else root.up = false
    }

    Item {
        id: card
        width: root.tw
        height: root.th
        y: 24
        x: root.up ? 24 : root.width + 8
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        Rectangle {
            id: frame
            anchors.fill: parent
            radius: 12
            color: Theme.surface3
            border.width: 3
            border.color: "#ffffff"
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0, 0, 0, 0.35); shadowBlur: 0.8; shadowVerticalOffset: 4 }
            Image {
                id: img
                anchors { fill: parent; margins: 3 }
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: root.tw * 2
                asynchronous: true
                cache: false
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mask
                }
            }
            Rectangle { id: mask; anchors.fill: img; radius: 9; visible: false; layer.enabled: true }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Shell.markup(root.file)
        }
        Rectangle {
            visible: ma.containsMouse || x0.containsMouse || ocr.containsMouse
            anchors { left: parent.left; top: parent.top; margins: -8 }
            width: 24; height: 24; radius: 12
            color: Qt.rgba(0, 0, 0, 0.7)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.5)
            Icon { anchors.centerIn: parent; name: "close"; size: 13; color: "#ffffff" }
            MouseArea { id: x0; anchors.fill: parent; hoverEnabled: true; onClicked: root.up = false }
        }
        Rectangle {
            visible: ma.containsMouse || ocr.containsMouse
            anchors { right: parent.right; top: parent.top; margins: 8 }
            width: ocrRow.implicitWidth + 16; height: 24; radius: 12
            color: ocr.containsMouse ? Theme.accent : Qt.rgba(0, 0, 0, 0.7)
            Row {
                id: ocrRow
                anchors.centerIn: parent
                spacing: 4
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "document_scanner"; size: 13; color: "#ffffff" }
                Txt { anchors.verticalCenter: parent.verticalCenter; text: "Copy text"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#ffffff" }
            }
            MouseArea { id: ocr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Ocr.copyFrom(root.file); root.up = false; } }
        }
        Rectangle {
            visible: ma.containsMouse
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
            width: hint.implicitWidth + 20; height: 24; radius: 12
            color: Qt.rgba(0, 0, 0, 0.65)
            Txt { id: hint; anchors.centerIn: parent; text: "Click to mark up"; font.pixelSize: 11; font.weight: Font.DemiBold; color: "#ffffff" }
        }
    }
}
