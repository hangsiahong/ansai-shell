import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// macOS-style menu for the focused app, opened from its name in the bar.
// Wayland has no global-menu protocol, so items come from the .desktop entry plus niri window actions.
Sheet {
    id: root
    name: "appmenu"
    exclusiveKeys: true
    panelX: Math.min(Shell.appMenuX, width - panelWidth - 8)
    panelY: 40
    panelWidth: 248
    panelHeight: col.implicitHeight + 12
    panelRadius: 12
    enterFrom: -4

    // Captured on open so the target can't change while the menu holds focus.
    property var win: null
    readonly property var entry: win ? DesktopEntries.heuristicLookup(win.app_id) : null
    readonly property var sameApp: win ? Object.values(Niri.windows).filter(w => w.app_id === win.app_id) : []
    readonly property var wss: win ? Niri.workspaces.filter(w => w.output === Niri.workspaces.find(x => x.id === win.workspace_id)?.output).sort((a, b) => a.idx - b.idx) : []

    onShownChanged: if (shown) { win = Niri.barWindow; panel.forceActiveFocus(); }

    function run(f): void {
        Shell.close();
        f();
    }
    function act(...args): void {
        run(() => Niri.action(...args));
    }

    component Item_: Hover {
        id: it
        property string icon
        property string label
        property string hint
        property bool destructive: false
        Layout.fillWidth: true
        Layout.preferredHeight: 28
        radius: 6
        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
            spacing: 10
            Icon { name: it.icon; size: 17; color: it.destructive ? Theme.danger : Theme.text2 }
            Txt {
                Layout.fillWidth: true
                text: it.label
                elide: Text.ElideRight
                font.pixelSize: 13
                color: it.destructive ? Theme.danger : Theme.text
            }
            Txt { text: it.hint; visible: !!it.hint; font.pixelSize: 12; color: Theme.faint }
        }
    }
    component Sep: Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        implicitHeight: 1
        color: Theme.line
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
        spacing: 0

        Txt {
            Layout.leftMargin: 8
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            text: root.entry?.name ?? root.win?.app_id ?? ""
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.muted
        }

        Item_ {
            visible: !!root.entry
            icon: "add"
            label: "New Window"
            onClicked: root.run(() => root.entry.execute())
        }
        Repeater {
            model: (root.entry?.actions ?? []).filter(a => a.name.toLowerCase() !== "new window")
            Item_ {
                required property var modelData
                icon: "chevron_right"
                label: modelData.name
                onClicked: root.run(() => modelData.execute())
            }
        }
        Sep { visible: !!root.entry }

        Item_ {
            icon: "fullscreen"
            label: "Fullscreen"
            onClicked: root.act("fullscreen-window", "--id", String(root.win.id))
        }
        Item_ {
            icon: "width_full"
            label: "Maximize Column"
            onClicked: root.run(() => { Niri.focusWindow(root.win.id); Niri.action("maximize-column"); })
        }
        Item_ {
            icon: root.win?.is_floating ? "view_column" : "picture_in_picture"
            label: root.win?.is_floating ? "Tile Window" : "Float Window"
            onClicked: root.act("toggle-window-floating", "--id", String(root.win.id))
        }

        Txt {
            Layout.leftMargin: 8
            Layout.topMargin: 6
            Layout.bottomMargin: 4
            text: "Move to Workspace"
            font.pixelSize: 12
            color: Theme.muted
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            Layout.bottomMargin: 2
            spacing: 4
            Repeater {
                model: root.wss
                Hover {
                    required property var modelData
                    readonly property bool here: modelData.id === root.win?.workspace_id
                    width: 26; height: 26; radius: 6
                    base: Theme.fill2
                    active: here
                    activeColor: Theme.accentSoft
                    onClicked: if (!here) root.act("move-window-to-workspace", "--window-id", String(root.win.id), "--focus", "false", String(modelData.idx))
                    Txt {
                        anchors.centerIn: parent
                        text: modelData.idx
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: parent.here ? Theme.accent : Theme.text2
                    }
                }
            }
        }
        Sep {}

        Item_ {
            icon: "close"
            label: "Close Window"
            onClicked: root.act("close-window", "--id", String(root.win.id))
        }
        Item_ {
            icon: "power_settings_new"
            label: root.sameApp.length > 1 ? `Quit ${root.entry?.name ?? "App"} (${root.sameApp.length} windows)` : `Quit ${root.entry?.name ?? "App"}`
            destructive: true
            onClicked: {
                const ids = root.sameApp.map(w => w.id);
                root.run(() => ids.forEach(id => Niri.action("close-window", "--id", String(id))));
            }
        }
    }
}
