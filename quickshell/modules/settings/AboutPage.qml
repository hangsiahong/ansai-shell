import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 22

    property var hw: ({})
    Process {
        running: true
        command: ["sh", "-c", `
echo "model=$(cat /sys/class/dmi/id/product_name 2>/dev/null | sed 's/_.*//')"
echo "vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
echo "cpu=$(lscpu 2>/dev/null | sed -n 's/^Model name: *//p' | head -1)"
echo "cores=$(nproc)"
echo "gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | cut -d: -f3- | sed 's/ (rev.*//' | paste -sd '|')"
echo "ram=$(awk '/MemTotal/ {printf "%.0f GB", $2/1048576}' /proc/meminfo)"
echo "disk=$(df -h --output=size,avail / | tail -1 | awk '{print $2 " free of " $1}')"
echo "os=$(. /etc/os-release; echo $PRETTY_NAME)"
echo "kernel=$(uname -r)"
echo "niri=$(niri --version 2>/dev/null)"
echo "qs=$(qs --version 2>/dev/null | head -1)"
echo "host=$(cat /etc/hostname 2>/dev/null || hostname)"
echo "up=$(uptime -p 2>/dev/null | sed 's/^up //')"
`]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1).trim(); }
                root.hw = kv;
            }
        }
    }

    // ---- hero
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 120
        radius: Theme.rGroup
        color: Theme.m3 ? Theme.accentSoft : Theme.dark ? "#1c1c1e" : "#ffffff"
        RowLayout {
            anchors { fill: parent; margins: 22 }
            spacing: 18
            Rectangle {
                width: 64; height: 64; radius: Theme.m3 ? 22 : 15
                color: Theme.m3 ? Theme.accent : Theme.dark ? "#ffffff" : "#000000"
                Txt {
                    anchors.centerIn: parent
                    text: ">_"
                    font.family: Theme.mono; font.pixelSize: 24; font.weight: Font.Bold
                    color: Theme.m3 ? Theme.accentInk : Theme.dark ? "#000000" : "#ffffff"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt { text: root.hw.model || "This computer"; font.pixelSize: 20; font.weight: Theme.strong; color: Theme.m3 ? Theme.accentSoftInk : Theme.text }
                Txt { text: [root.hw.vendor, root.hw.host].filter(s => s).join(" · "); font.pixelSize: 13; color: Theme.m3 ? Theme.accentSoftInk : Theme.muted }
                Txt { text: "ansai shell on " + (root.hw.os || "Linux"); font.pixelSize: 13; color: Theme.m3 ? Theme.accentSoftInk : Theme.muted }
            }
        }
    }

    component Spec: SRow {
        id: sp
        property string value
        Txt {
            text: sp.value
            font.pixelSize: 13
            color: Theme.muted
            horizontalAlignment: Text.AlignRight
            width: Math.min(implicitWidth, 380)
        }
    }

    SGroup {
        title: "Hardware"
        Spec { first: true; icon: "developer_board"; title: "Processor"; value: (root.hw.cpu ?? "") + (root.hw.cores ? ` · ${root.hw.cores} threads` : "") }
        Repeater {
            model: (root.hw.gpu ?? "").split("|").filter(s => s)
            Spec { required property string modelData; icon: "memory"; title: "Graphics"; value: {
                const b = modelData.match(/\[([^\]]+)\]\s*$/);
                const v = /nvidia/i.test(modelData) ? "NVIDIA " : /amd|ati/i.test(modelData) ? "AMD " : "";
                return b ? v + b[1] : modelData.trim();
            } }
        }
        Spec { icon: "memory_alt"; title: "Memory"; value: root.hw.ram ?? "" }
        Spec { icon: "hard_drive"; title: "Storage"; value: root.hw.disk ?? "" }
    }

    SGroup {
        title: "Software"
        Spec { first: true; icon: "terminal"; title: "Kernel"; value: root.hw.kernel ?? "" }
        Spec { icon: "view_column"; title: "Compositor"; value: root.hw.niri ?? "" }
        Spec { icon: "widgets"; title: "Shell"; value: root.hw.qs ?? "" }
        Spec { icon: "schedule"; title: "Uptime"; value: root.hw.up ?? "" }
    }

    SGroup {
        title: "Advanced"
        note: "Everything here is saved to ~/.config/ansai-shell/settings.json; hand edits apply live too."
        SRow {
            first: true
            icon: "data_object"
            title: "Open settings.json"
            clickable: true
            onClicked: Quickshell.execDetached(["xdg-open", Settings.dir + "/settings.json"])
            Icon { name: "open_in_new"; size: 18; color: Theme.muted }
        }
        SRow {
            icon: "folder_open"
            title: "Open niri config folder"
            sub: "config.kdl, ansai-outputs.kdl, ansai-style.kdl"
            clickable: true
            onClicked: Quickshell.execDetached(["xdg-open", (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/niri"])
            Icon { name: "open_in_new"; size: 18; color: Theme.muted }
        }
        SRow {
            icon: "keyboard_command_key"
            title: "Keyboard shortcuts"
            sub: "Super+Shift+/ shows them all"
            clickable: true
            onClicked: Niri.action("show-hotkey-overlay")
            Icon { name: "open_in_new"; size: 18; color: Theme.muted }
        }
    }
}
