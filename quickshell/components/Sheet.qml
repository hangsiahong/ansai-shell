import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

// Full-screen transparent layer that hosts one glass panel. Click outside or Esc closes it.
// The panel draws its own blur (Glass.ownBlur), so the rest stays see-through.
PanelWindow {
    id: root
    required property string name
    property bool dim: false
    property bool exclusiveKeys: false
    default property alias content: panel.data
    property alias panel: panel
    // Panel geometry, set by the user of the sheet.
    property real panelX: (width - panelWidth) / 2
    property real panelY: Theme.barH + 8
    property real panelWidth: 360
    property real panelHeight: 400
    property real panelRadius: Theme.rLg
    property real enterFrom: -8

    readonly property bool shown: Shell.open === name
    property bool live: false
    onShownChanged: if (shown) live = true

    visible: live
    screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ansai-" + name
    WlrLayershell.keyboardFocus: shown ? (exclusiveKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None


    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.dim && root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.med } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Shell.close()
    }

    Glass {
        id: panel
        screenX: x
        screenY: y
        x: root.panelX
        y: root.panelY + (root.shown ? 0 : root.enterFrom)
        width: root.panelWidth
        height: root.panelHeight
        // Rounder than the panel: wl_region corners are pixel steps, and a larger radius keeps them
        // inside the panel's antialiased corner instead of poking out as jaggies.
        radius: root.panelRadius + (Theme.m3 ? 0 : 8)
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.98
        focus: true
        Behavior on opacity { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }
        Behavior on y { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }
        Behavior on scale { NumberAnimation { duration: Theme.med; easing.type: Theme.easing } }
        onOpacityChanged: if (opacity === 0 && !root.shown) root.live = false

        Keys.onEscapePressed: Shell.close()

        // Swallow clicks so they don't reach the close catcher.
        MouseArea { anchors.fill: parent; z: -1 }
    }
}
