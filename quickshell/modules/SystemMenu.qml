import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// The menu under the >_ mark at the left of the menu bar (macOS keeps power and settings here).
// Restart, shut down and log out only open the power sheet to confirm.
Sheet {
    id: root
    name: "system"
    exclusiveKeys: true
    panelX: 6
    panelY: Theme.barH + 2
    panelWidth: 240
    panelHeight: col.implicitHeight + 10
    panelRadius: Theme.rMenu
    enterFrom: -4

    onShownChanged: if (shown) panel.forceActiveFocus()

    function run(f): void {
        Shell.close();
        f();
    }
    function power(i): void {
        Shell.powerPick = i;
        Shell.open = "power";
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 5 }
        spacing: 0
        MenuItem { label: "About This Computer"; onClicked: root.run(() => Shell.openSettings("about")) }
        MenuSep {}
        MenuItem { label: "System Settings…"; onClicked: root.run(() => Shell.openSettings("")) }
        MenuItem { label: "App Search…"; hint: "Super Space"; onClicked: Shell.open = "launcher" }
        MenuItem { label: "Displays…"; onClicked: root.run(() => Shell.openSettings("displays")) }
        MenuSep {}
        MenuItem { label: "Sleep"; onClicked: root.power(1) }
        MenuItem { label: "Restart…"; onClicked: root.power(3) }
        MenuItem { label: "Shut Down…"; onClicked: root.power(4) }
        MenuSep {}
        MenuItem { label: "Lock Screen"; hint: "Super L"; onClicked: root.run(() => Lock.lock()) }
        MenuItem { label: "Log Out…"; onClicked: root.power(2) }
    }
}
