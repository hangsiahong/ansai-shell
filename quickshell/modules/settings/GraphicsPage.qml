import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// GPU mode through supergfxd. Switching only asks supergfxd for the mode; the log out or reboot it
// needs is left to the user (other sessions and agents may be running), so this page never does it.
ColumnLayout {
    id: root
    spacing: 22

    property string mode: ""
    property var modes: []
    property string action: ""
    property string pendingMode: ""
    property string power: ""
    property string vendor: ""
    property string result: ""
    property string pick: ""
    property int overdrive: -1
    readonly property bool ok: modes.length > 0

    function refresh() { info.running = true; }
    Process {
        id: info
        running: true
        command: ["sh", "-c", "echo mode=$(supergfxctl -g 2>/dev/null); echo modes=$(supergfxctl -s 2>/dev/null); echo action=$(supergfxctl -p 2>/dev/null); echo pmode=$(supergfxctl -P 2>/dev/null); echo power=$(supergfxctl -S 2>/dev/null); echo vendor=$(supergfxctl -V 2>/dev/null); echo od=$(asusctl armoury get panel_overdrive 2>/dev/null | sed -n 's/.*(\\([0-9]\\)).*/\\1/p' | head -1)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1).trim(); }
                root.mode = kv.mode ?? "";
                root.modes = (kv.modes ?? "").replace(/[\[\]]/g, "").split(",").map(s => s.trim()).filter(s => s);
                root.action = kv.action ?? "";
                root.pendingMode = /unknown|none/i.test(kv.pmode ?? "") ? "" : (kv.pmode ?? "");
                root.power = kv.power ?? "";
                root.vendor = kv.vendor ?? "";
                root.overdrive = kv.od === "" || kv.od === undefined ? -1 : parseInt(kv.od);
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }

    Process {
        id: setter
        property string target
        command: ["supergfxctl", "-m", target]
        stdout: StdioCollector { onStreamFinished: root.result = text.trim() }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.result = text.trim() }
        onExited: root.refresh()
    }

    readonly property var about: ({
        Integrated: { l: "Integrated", icon: "battery_saver", d: "Radeon only. NVIDIA is powered off for the longest battery life.", needs: "Log out" },
        Hybrid: { l: "Hybrid", icon: "join_inner", d: "Radeon runs the desktop; NVIDIA wakes for apps that ask for it (prime-run, games). Recommended.", needs: "Log out" },
        AsusMuxDgpu: { l: "dGPU (MUX)", icon: "sports_esports", d: "NVIDIA drives the screen directly through the MUX switch. Best gaming performance, most power.", needs: "Reboot" },
        Vfio: { l: "VFIO", icon: "developer_board", d: "NVIDIA is detached for a virtual machine.", needs: "Log out" },
        AsusEgpu: { l: "eGPU", icon: "cable", d: "External ASUS XG Mobile GPU.", needs: "Reboot" }
    })
    function info_(m) { return about[m] ?? { l: m, icon: "memory", d: "", needs: "Log out" }; }

    // ---- pending action
    Rectangle {
        visible: root.ok && !!root.action && !/no action/i.test(root.action)
        Layout.fillWidth: true
        implicitHeight: pendRow.implicitHeight + 28
        radius: Theme.rGroup
        color: Theme.m3 ? Theme.accentSoft : Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.18)
        RowLayout {
            id: pendRow
            anchors { fill: parent; margins: 14; leftMargin: 18 }
            spacing: 12
            Icon { name: "pending_actions"; size: 22; color: Theme.m3 ? Theme.accentSoftInk : Theme.warn }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    Layout.fillWidth: true
                    text: (root.pendingMode ? `Switching to ${root.info_(root.pendingMode).l}: ` : "") + root.action
                    font.pixelSize: 14; font.weight: Theme.strong
                    color: Theme.m3 ? Theme.accentSoftInk : Theme.text
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                }
                Txt {
                    Layout.fillWidth: true
                    text: "It finishes the next time you do that yourself. Save your work and let running sessions finish first."
                    font.pixelSize: 12
                    color: Theme.m3 ? Theme.accentSoftInk : Theme.muted
                    wrapMode: Text.WordWrap; elide: Text.ElideNone
                }
            }
        }
    }

    SGroup {
        title: "GPU mode"
        note: !root.ok ? "supergfxd is not running, so the GPU mode can't be changed here." :
              `Current: ${root.info_(root.mode).l}` + (root.vendor ? ` · ${root.vendor} dGPU is ${root.power || "unknown"}` : "")

        Item {
            Layout.fillWidth: true
            visible: root.ok
            implicitHeight: cards.implicitHeight + 24
            RowLayout {
                id: cards
                x: 12; y: 12
                width: parent.width - 24
                spacing: 10
                Repeater {
                    model: root.modes
                    Hover {
                        id: card
                        required property string modelData
                        readonly property var a: root.info_(modelData)
                        readonly property bool on: root.mode === modelData
                        readonly property bool picked: root.pick === modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: cc.implicitHeight + 28
                        radius: Theme.m3 ? 22 : 12
                        base: Theme.m3 ? Theme.surface3 : Theme.fill2
                        active: on || picked
                        activeColor: on ? (Theme.m3 ? Theme.accentSoft : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)) : Theme.hover
                        border.width: picked ? 2 : on && !Theme.m3 ? 1 : 0
                        border.color: Theme.accent
                        onClicked: root.pick = on ? "" : modelData
                        ColumnLayout {
                            id: cc
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 6
                            RowLayout {
                                Layout.fillWidth: true
                                Icon { name: card.a.icon; size: 26; filled: card.on; color: card.on ? Theme.accent : Theme.text2 }
                                Item { Layout.fillWidth: true }
                                Icon { visible: card.on; name: "check_circle"; size: 20; filled: true; color: Theme.accent }
                            }
                            Txt { text: card.a.l; font.pixelSize: 15; font.weight: Theme.strong; color: card.on && Theme.m3 ? Theme.accentSoftInk : Theme.text }
                            Txt {
                                Layout.fillWidth: true
                                text: card.a.d
                                wrapMode: Text.WordWrap; elide: Text.ElideNone
                                font.pixelSize: 12
                                color: card.on && Theme.m3 ? Theme.accentSoftInk : Theme.muted
                            }
                            Txt {
                                visible: !card.on
                                text: card.a.needs + " to apply"
                                font.pixelSize: 11; font.weight: Theme.strong
                                color: Theme.warn
                            }
                        }
                    }
                }
            }
        }

        // Confirmation for the picked mode.
        SRow {
            visible: root.pick !== ""
            icon: "warning"
            title: `Switch to ${root.info_(root.pick).l}?`
            sub: `This only tells supergfxd. ${root.info_(root.pick).needs === "Reboot" ? "You'll need to reboot" : "You'll need to log out and back in"} for it to take effect, and nothing here will do that for you. Close other sessions first.`
            Btn { text: "Cancel"; kind: "text"; onClicked: root.pick = "" }
            Btn {
                text: "Switch"
                kind: "filled"
                onClicked: {
                    setter.target = root.pick;
                    setter.running = true;
                    root.pick = "";
                }
            }
        }
        SRow {
            visible: !!root.result
            icon: "terminal"
            title: "supergfxd says"
            sub: root.result
        }
    }

    SGroup {
        title: "Display"
        visible: root.overdrive >= 0
        SRow {
            first: true
            icon: "bolt"
            title: "Panel overdrive"
            sub: "Faster pixel response; can add a little ghosting on some content"
            Switch {
                checked: root.overdrive === 1
                onToggled: {
                    const v = root.overdrive === 1 ? 0 : 1;
                    root.overdrive = v;
                    Quickshell.execDetached(["asusctl", "armoury", "set", "panel_overdrive", String(v)]);
                }
            }
        }
    }
}
