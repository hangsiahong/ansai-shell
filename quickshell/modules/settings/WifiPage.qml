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

    property var saved: []      // [{ name, uuid, auto }]
    property var info: ({})     // connected network: ip, gw, dns
    property string forgetting: ""

    function refresh() { savedProc.running = true; infoProc.running = true; }
    Component.onCompleted: refresh()
    Connections { target: Net; function onSsidChanged() { root.refresh(); } }

    // nmcli -t escapes ':' inside fields as '\:'.
    function fields(l) {
        const out = [""];
        for (let i = 0; i < l.length; i++) {
            if (l[i] === "\\" && i + 1 < l.length) out[out.length - 1] += l[++i];
            else if (l[i] === ":") out.push("");
            else out[out.length - 1] += l[i];
        }
        return out;
    }
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,AUTOCONNECT", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.saved = text.trim().split("\n").map(root.fields)
                .filter(f => f[2] === "802-11-wireless").map(f => ({ name: f[0], uuid: f[1], auto: f[3] === "yes" }))
                .sort((a, b) => (b.name === Net.ssid) - (a.name === Net.ssid) || a.name.localeCompare(b.name))
        }
    }
    Process {
        id: infoProc
        command: ["sh", "-c", "d=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2==\"wifi\"{print $1; exit}'); [ -n \"$d\" ] && nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show \"$d\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = { dns: [] };
                for (const l of text.trim().split("\n")) {
                    const k = l.slice(0, l.indexOf(":")), v = l.slice(l.indexOf(":") + 1);
                    if (k.startsWith("IP4.ADDRESS") && !o.ip) o.ip = v.split("/")[0];
                    else if (k === "IP4.GATEWAY") o.gw = v;
                    else if (k.startsWith("IP4.DNS")) o.dns.push(v);
                }
                root.info = o;
            }
        }
    }
    function nm(args) {
        Quickshell.execDetached(["sh", "-c", 'nmcli "$@"', "nm"].concat(args));
        later.restart();
    }
    Timer { id: later; interval: 700; onTriggered: root.refresh() }

    SGroup {
        SRow {
            first: true
            icon: Net.wifiOn ? "wifi" : "wifi_off"
            title: "Wi-Fi"
            sub: !Net.wifi ? "No Wi-Fi adapter" : Net.ssid ? "Connected to " + Net.ssid : Net.wifiOn ? "Not connected" : "Off"
            Switch { checked: Net.wifiOn; onToggled: Net.toggleWifi() }
        }
        SRow {
            visible: Net.ssid !== "" && !!root.info.ip
            icon: "lan"
            title: "IP address"
            sub: (root.info.gw ? "Router " + root.info.gw : "") + (root.info.dns?.length ? "  ·  DNS " + root.info.dns.join(", ") : "")
            Txt { text: root.info.ip ?? ""; font.pixelSize: 13; color: Theme.muted; font.features: { "tnum": 1 } }
        }
    }

    SGroup {
        title: "Networks"
        visible: Net.wifiOn
        WifiList { Layout.fillWidth: true; Layout.margins: 6 }
    }

    SGroup {
        title: "Saved networks"
        visible: root.saved.length > 0
        note: "Auto-join off: kept, but only joined when you pick it."
        Repeater {
            model: root.saved
            SRow {
                id: sr
                required property var modelData
                required property int index
                first: index === 0
                icon: "wifi"
                title: modelData.name
                sub: modelData.name === Net.ssid ? "Connected" : ""
                Row {
                    spacing: 10
                    Txt { anchors.verticalCenter: parent.verticalCenter; text: "Auto-join"; font.pixelSize: 12; color: Theme.muted }
                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: sr.modelData.auto
                        onToggled: root.nm(["connection", "modify", sr.modelData.uuid, "connection.autoconnect", sr.modelData.auto ? "no" : "yes"])
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.forgetting === sr.modelData.uuid ? "Forget?" : "Forget"
                        kind: root.forgetting === sr.modelData.uuid ? "danger" : "tonal"
                        onClicked: {
                            if (root.forgetting !== sr.modelData.uuid) { root.forgetting = sr.modelData.uuid; return; }
                            root.forgetting = "";
                            root.nm(["connection", "delete", sr.modelData.uuid]);
                        }
                    }
                }
            }
        }
    }
}
