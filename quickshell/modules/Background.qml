import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    required property ShellScreen modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ansai-wallpaper"
    color: "black"

    Wallpaper { anchors.fill: parent }
}
