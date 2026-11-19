pragma Singleton

import QtQuick
import qs
import Quickshell

// Which overlay is open. Only one sheet at a time, like the web app.
Singleton {
    property string open: ""   // "", "launcher", "control", "power", "calendar", "appmenu"
    property real appMenuX: 0
    // Dock context menu: the item it was opened on (null for the dock's own settings), where, and which screen.
    property var dockItem: null
    property real dockMenuX: 0
    property real dockTop: 0
    // Nested test runs must not take over the host session's D-Bus services.
    readonly property bool nested: Quickshell.env("ANSAI_SHELL_NESTED") === "1"

    function toggle(name: string): void {
        open = open === name ? "" : name;
    }
    function close(): void {
        open = "";
    }
}
