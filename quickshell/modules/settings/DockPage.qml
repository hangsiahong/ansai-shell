import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

ColumnLayout {
    spacing: 22

    SGroup {
        title: "Behaviour"
        SRow {
            first: true
            icon: "visibility"
            title: "Auto-hide"
            sub: Settings.dockMode === "smart" ? "Hides when a window would cover it; push the pointer to the left edge to show it"
               : Settings.dockMode === "auto" ? "Hidden until you push the pointer to the left edge"
               : "Always shown; windows make room for it"
            Seg {
                model: [{ v: "smart", l: "Smart" }, { v: "auto", l: "Always" }, { v: "always", l: "Never" }]
                value: Settings.dockMode
                onPicked: v => Settings.dockMode = v
            }
        }
        SRow {
            icon: "photo_size_select_small"
            title: "Icon size"
            Seg {
                model: [{ v: 36, l: "Small" }, { v: 44, l: "Medium" }, { v: 54, l: "Large" }]
                value: Settings.dockSize
                onPicked: v => Settings.dockSize = v
            }
        }
        SRow {
            icon: "zoom_in"
            title: "Magnify on hover"
            Switch { checked: Settings.dockMagnify; onToggled: Settings.dockMagnify = !Settings.dockMagnify }
        }
    }

    SGroup {
        title: "Pinned apps"
        note: "Drag icons on the dock to reorder, or drag one off to the right to unpin. Right-click a running app to pin it."
        Repeater {
            model: Settings.pinned
            SRow {
                id: pr
                required property string modelData
                required property int index
                readonly property var entry: DesktopEntries.heuristicLookup(modelData)
                first: index === 0
                title: entry?.name ?? modelData
                sub: modelData
                AppIcon {
                    parent: pr
                    x: 16
                    y: (pr.implicitHeight - height) / 2
                    size: 26
                    icon: pr.entry?.icon ?? pr.modelData
                    label: pr.title
                }
                icon: " "   // reserves the icon column; AppIcon draws over it
                IconButton {
                    icon: "arrow_upward"; iconSize: 18
                    opacity: pr.index > 0 ? 1 : 0.3
                    onClicked: move(pr.index, -1)
                }
                IconButton {
                    icon: "arrow_downward"; iconSize: 18
                    opacity: pr.index < Settings.pinned.length - 1 ? 1 : 0.3
                    onClicked: move(pr.index, 1)
                }
                IconButton {
                    icon: "close"; iconSize: 18; iconColor: Theme.danger
                    onClicked: Settings.pinned = Array.from(Settings.pinned).filter((_, i) => i !== pr.index)
                }
            }
        }
        SRow {
            first: Settings.pinned.length === 0
            visible: Settings.pinned.length === 0
            title: "Nothing pinned"
            sub: "Right-click an app on the dock and choose Pin to Dock"
        }
    }

    function move(i, d) {
        const l = Array.from(Settings.pinned), j = i + d;
        if (j < 0 || j >= l.length) return;
        [l[i], l[j]] = [l[j], l[i]];
        Settings.pinned = l;
    }
}
