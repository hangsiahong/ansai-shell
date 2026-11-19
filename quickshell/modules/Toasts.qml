import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    visible: Notifs.popups.length > 0 && Shell.open !== "calendar"
    anchors { top: true; right: true }
    margins { top: 8; right: 8 }
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ansai-toasts"

    // ansai cards draw their own blur (GlassBackdrop); niri blurs only for material.
    BackgroundEffect.blurRegion: Region {
        Region { item: Theme.m3 && rep.count > 0 ? rep.itemAt(0) : null; radius: Theme.m3 ? Theme.r : 30 }
        Region { item: Theme.m3 && rep.count > 1 ? rep.itemAt(1) : null; radius: Theme.m3 ? Theme.r : 30 }
        Region { item: Theme.m3 && rep.count > 2 ? rep.itemAt(2) : null; radius: Theme.m3 ? Theme.r : 30 }
        Region { item: Theme.m3 && rep.count > 3 ? rep.itemAt(3) : null; radius: Theme.m3 ? Theme.r : 30 }
    }

    Column {
        id: stack
        width: parent.width
        spacing: 8
        Repeater {
            id: rep
            model: Notifs.popups.slice(0, 4)
            NotifCard {
                required property var modelData
                entry: modelData
                popup: true
                width: stack.width
                screenX: root.screen.width - root.width - 8
                screenY: 8 + y
            }
        }
    }
}
