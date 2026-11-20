pragma Singleton

import QtQuick
import qs
import Quickshell

// Which overlay is open. Only one sheet at a time, like the web app.
Singleton {
    property string open: ""   // "", "launcher", "control", "power", "calendar", "appmenu"
    property real appMenuX: 0
    property int powerPick: 0   // which power action the power sheet preselects
    // Dock context menu: the item it was opened on (null for the dock's own settings), where, and which screen.
    property var dockItem: null
    property real dockMenuY: 0
    property real dockEdge: 0   // the dock's right edge, screen x
    // Settings is a real window, not a sheet, so it stays open alongside them.
    property bool settings: false
    property string settingsPage: "appearance"
    function openSettings(page: string): void {
        if (page) settingsPage = page;
        settings = true;
        open = "";
    }
    // Nested test runs must not take over the host session's D-Bus services.
    readonly property bool nested: Quickshell.env("ANSAI_SHELL_NESTED") === "1"

    // Screenshot markup: the image being edited (modules/Markup.qml).
    property string markupFile: ""
    function markup(path: string): void {
        markupFile = path;
        open = "markup";
    }

    function toggle(name: string): void {
        if (name === "settings") { settings ? (settings = false) : openSettings(""); return; }
        open = open === name ? "" : name;
    }
    function close(): void {
        open = "";
    }
}
