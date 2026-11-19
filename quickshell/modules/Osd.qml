import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// Volume / brightness pill, bottom center, like iOS.
PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    anchors.bottom: true
    margins.bottom: 72
    implicitWidth: 260
    implicitHeight: Theme.m3 ? 60 : 52
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || pill.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ansai-osd"
    mask: Region {}

    property bool shown: false
    property string kind: "volume"
    property bool ready: false

    BackgroundEffect.blurRegion: Region { item: root.shown && pill.opacity > 0.95 ? pill : null; radius: pill.radius }

    function pop(k: string): void {
        if (!ready) return;
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer { id: hide; interval: 1400; onTriggered: root.shown = false }
    Timer { interval: 1500; running: true; onTriggered: root.ready = true }
    Connections { target: Audio; function onChanged() { root.pop("volume"); } }
    Connections { target: Brightness; function onChanged() { root.pop("brightness"); } }

    Glass {
        id: pill
        anchors.fill: parent
        radius: height / 2
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: Theme.med } }
        Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }

        Icon {
            id: ic
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            name: root.kind === "volume" ? Audio.icon() : "light_mode"
            filled: true
            size: 22
            color: Theme.m3 ? Theme.accent : Theme.text
        }
        Rectangle {
            anchors { left: ic.right; leftMargin: 12; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            height: Theme.m3 ? 16 : 6; radius: height / 2
            color: Theme.m3 ? Theme.tonal : Theme.fill
            Rectangle {
                width: Math.max(Theme.m3 ? parent.height : 0, parent.width * (root.kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.value))
                height: parent.height; radius: height / 2
                color: Theme.m3 ? Theme.accent : Theme.text
                Behavior on width { NumberAnimation { duration: Theme.fast } }
            }
        }
    }
}
