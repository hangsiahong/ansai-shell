import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Right-click menu for a dock item (windows, app actions, pin, quit) or, on empty dock space, the dock's settings.
Sheet {
    id: root
    name: "dockmenu"
    exclusiveKeys: true
    panelWidth: 260
    panelHeight: col.implicitHeight + 12
    panelX: Math.max(8, Math.min(Shell.dockMenuX - panelWidth / 2, width - panelWidth - 8))
    panelY: Shell.dockTop - panelHeight - 10
    panelRadius: Theme.m3 ? 20 : 12
    enterFrom: 6

    // Captured on open so live window changes don't reshuffle the menu under the pointer.
    property var it: null
    readonly property var wins: it ? Object.values(Niri.windows).filter(w => Niri.appKey(w.app_id) === it.key).sort((a, b) => a.id - b.id) : []
    readonly property string appName: it ? (it.entry?.name ?? it.id) : ""
    readonly property bool pinned: it ? Settings.pinned.some(p => Niri.appKey(p) === it.key) : false

    onShownChanged: if (shown) { it = Shell.dockItem; panel.forceActiveFocus(); }

    function run(f): void {
        Shell.close();
        f();
    }

    component MItem: Hover {
        id: mi
        property string icon
        property string label
        property string hint
        property bool destructive: false
        property bool checked: false
        property bool checkable: false
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.m3 ? 36 : 28
        radius: Theme.m3 ? 18 : 6
        RowLayout {
            anchors { fill: parent; leftMargin: Theme.m3 ? 12 : 8; rightMargin: 10 }
            spacing: 10
            Icon {
                name: mi.checkable ? (mi.checked ? "radio_button_checked" : "radio_button_unchecked") : mi.icon
                size: 17
                filled: mi.checked
                color: mi.destructive ? Theme.danger : mi.checked ? Theme.accent : Theme.text2
            }
            Txt {
                Layout.fillWidth: true
                text: mi.label
                elide: Text.ElideRight
                font.pixelSize: 13
                color: mi.destructive ? Theme.danger : Theme.text
            }
            Txt { text: mi.hint; visible: !!mi.hint; font.pixelSize: 12; color: Theme.faint }
        }
    }
    component MSep: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Theme.line
    }
    component MHead: Txt {
        Layout.leftMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 2
        font.pixelSize: 12
        font.weight: Theme.strong
        color: Theme.muted
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
        spacing: 0

        // ---------- app menu
        ColumnLayout {
            visible: !!root.it
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 6
                spacing: 10
                AppIcon {
                    size: 28
                    icon: root.it?.entry?.icon ?? root.it?.id ?? ""
                    label: root.appName
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt { Layout.fillWidth: true; text: root.appName; font.pixelSize: 14; font.weight: Theme.strong }
                    Txt {
                        Layout.fillWidth: true
                        text: root.wins.length === 0 ? "Not running" : root.wins.length === 1 ? "1 window" : root.wins.length + " windows"
                        font.pixelSize: 12
                        color: Theme.muted
                    }
                }
            }

            MSep { visible: root.wins.length > 0 }
            MHead { visible: root.wins.length > 0; text: "Windows" }
            Repeater {
                model: root.wins
                MItem {
                    id: wrow
                    required property var modelData
                    icon: modelData.id === Niri.focusedWindowId ? "radio_button_checked" : "web_asset"
                    label: modelData.title || root.appName
                    hint: "ws " + (Niri.workspaces.find(w => w.id === modelData.workspace_id)?.idx ?? "")
                    onClicked: m => {
                        if (m.button === Qt.MiddleButton) Niri.closeWindow(modelData.id);
                        else root.run(() => Niri.focusWindow(modelData.id));
                    }
                    IconButton {
                        anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                        visible: wrow.hovered || hovered
                        implicitWidth: 22; implicitHeight: 22
                        icon: "close"; iconSize: 14; iconColor: Theme.muted
                        base: Theme.m3 ? Theme.surface3 : Theme.surface2
                        onClicked: Niri.closeWindow(wrow.modelData.id)
                    }
                }
            }

            MSep {}
            MItem {
                icon: "add"
                label: "New Window"
                hint: "middle-click"
                onClicked: root.run(() => root.it.entry ? root.it.entry.execute() : Quickshell.execDetached([root.it.id]))
            }
            Repeater {
                model: (root.it?.entry?.actions ?? []).filter(a => !/^new (window|empty window)$/i.test(a.name))
                MItem {
                    required property var modelData
                    icon: /private|incognito/i.test(modelData.name) ? "visibility_off" : "chevron_right"
                    label: modelData.name
                    onClicked: root.run(() => modelData.execute())
                }
            }

            MSep {}
            MItem {
                icon: root.pinned ? "keep_off" : "keep"
                label: root.pinned ? "Unpin from Dock" : "Pin to Dock"
                onClicked: {
                    const it = root.it;
                    root.run(() => {
                        if (root.pinned) {
                            const k = it.key;
                            Settings.pinned = Array.from(Settings.pinned).filter(p => Niri.appKey(p) !== k);
                        } else {
                            Settings.pinned = Array.from(Settings.pinned).concat([it.entry?.id ?? it.id]);
                        }
                    });
                }
            }
            MItem {
                visible: root.wins.length > 1
                icon: "move_down"
                label: "Gather Windows Here"
                onClicked: {
                    const ids = root.wins.map(w => w.id);
                    const ws = Niri.workspaces.find(w => w.is_focused);
                    root.run(() => ids.forEach(id => Niri.action("move-window-to-workspace", "--window-id", String(id), "--focus", "false", String(ws.idx))));
                }
            }
            MItem {
                visible: root.wins.length > 0
                icon: "power_settings_new"
                label: root.wins.length > 1 ? `Quit (${root.wins.length} windows)` : "Quit"
                destructive: true
                onClicked: {
                    const ids = root.wins.map(w => w.id);
                    root.run(() => ids.forEach(id => Niri.closeWindow(id)));
                }
            }
        }

        // ---------- dock settings
        ColumnLayout {
            visible: !root.it
            Layout.fillWidth: true
            spacing: 0

            MHead { text: "Auto-hide" }
            Repeater {
                model: [
                    { v: "smart", l: "When a window covers it" },
                    { v: "auto", l: "Always hide" },
                    { v: "always", l: "Never hide" }
                ]
                MItem {
                    required property var modelData
                    checkable: true
                    checked: Settings.dockMode === modelData.v
                    label: modelData.l
                    onClicked: Settings.dockMode = modelData.v
                }
            }
            MSep {}
            MHead { text: "Icon size" }
            Repeater {
                model: [{ v: 36, l: "Small" }, { v: 44, l: "Medium" }, { v: 54, l: "Large" }]
                MItem {
                    required property var modelData
                    checkable: true
                    checked: Settings.dockSize === modelData.v
                    label: modelData.l
                    onClicked: Settings.dockSize = modelData.v
                }
            }
            MSep {}
            MItem {
                icon: Settings.dockMagnify ? "check_box" : "check_box_outline_blank"
                label: "Magnify on hover"
                onClicked: Settings.dockMagnify = !Settings.dockMagnify
            }
            MItem {
                icon: "apps"
                label: "All Apps…"
                onClicked: Shell.open = "launcher"
            }
        }
    }
}
