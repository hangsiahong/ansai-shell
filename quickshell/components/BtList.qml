import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services

// Bluetooth devices: click to connect / disconnect; new devices pair (and get trusted) first.
ColumnLayout {
    id: root
    spacing: 2

    readonly property var devs: (Bluetooth.devices?.values ?? [])
        .filter(d => d.name && d.name !== d.address.replace(/:/g, "-"))
        .slice()
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
        .slice(0, 14)

    Component.onCompleted: if (Net.bt?.enabled) Net.bt.discovering = true
    Component.onDestruction: if (Net.bt) Net.bt.discovering = false

    function icon(d) {
        const i = d.icon ?? "";
        return /headset|headphone/.test(i) ? "headphones" : /audio|speaker/.test(i) ? "speaker"
             : /phone/.test(i) ? "smartphone" : /mouse/.test(i) ? "mouse" : /keyboard/.test(i) ? "keyboard"
             : /computer/.test(i) ? "computer" : /game/.test(i) ? "sports_esports" : "bluetooth";
    }

    Txt {
        visible: !Net.btOn
        Layout.fillWidth: true
        Layout.margins: 12
        text: Net.bt ? "Bluetooth is off" : "No Bluetooth adapter"
        color: Theme.muted
        font.pixelSize: 13
    }
    Txt {
        visible: Net.btOn && root.devs.length === 0
        Layout.fillWidth: true
        Layout.margins: 12
        text: "Looking for devices…"
        color: Theme.muted
        font.pixelSize: 13
    }

    Repeater {
        model: Net.btOn ? root.devs : []
        ListRow {
            id: r
            required property var modelData
            readonly property var d: modelData
            property bool wantConnect: false
            icon: root.icon(d)
            title: d.name
            current: d.connected
            busy: d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting
            sub: d.connected ? "Connected" + (d.batteryAvailable ? ` · ${Math.round(d.battery * 100)}%` : "") + " · click to disconnect"
               : d.pairing ? "Pairing… confirm on the device if asked"
               : d.paired ? "Paired" : "New device · click to pair"
            onClicked: {
                if (d.connected) d.disconnect();
                else if (d.paired) d.connect();
                else { wantConnect = true; d.trusted = true; d.pair(); }
            }
            Connections {
                target: r.d
                function onPairedChanged() { if (r.d.paired && r.wantConnect) { r.wantConnect = false; r.d.connect(); } }
            }
        }
    }

    ListRow {
        icon: "settings"
        title: "Bluetooth settings…"
        visible: !!DesktopEntries.heuristicLookup("blueman-manager")
        onClicked: { Shell.close(); Quickshell.execDetached(["blueman-manager"]); }
    }
}
