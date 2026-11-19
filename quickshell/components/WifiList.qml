import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.services

// Networks to join. Known and open ones connect on click; new secured ones ask for the password inline.
ColumnLayout {
    id: root
    spacing: 2
    property string asking: ""   // network asking for a password
    property string failed: ""
    property string pending: ""

    readonly property var nets: Net.wifiNetworks
        .filter(n => n.name)
        .slice()
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
        .slice(0, 8)

    // Scan while the list is open.
    Component.onCompleted: if (Net.wifi) Net.wifi.scannerEnabled = true
    Component.onDestruction: if (Net.wifi) Net.wifi.scannerEnabled = false

    function bars(s) { return s > 0.66 ? "wifi" : s > 0.33 ? "wifi_2_bar" : "wifi_1_bar"; }
    function secured(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe; }

    Txt {
        visible: !Net.wifiOn
        Layout.fillWidth: true
        Layout.margins: 12
        text: "Wi-Fi is off"
        color: Theme.muted
        font.pixelSize: 13
    }
    Txt {
        visible: Net.wifiOn && root.nets.length === 0
        Layout.fillWidth: true
        Layout.margins: 12
        text: "Looking for networks…"
        color: Theme.muted
        font.pixelSize: 13
    }

    Repeater {
        model: Net.wifiOn ? root.nets : []
        ListRow {
            id: r
            required property var modelData
            readonly property var n: modelData
            readonly property bool open: root.asking === n.name
            icon: root.bars(n.signalStrength)
            title: n.name
            current: n.connected
            busy: n.stateChanging || (root.pending === n.name && !n.connected)
            trailingIcon: root.secured(n) ? "lock" : ""
            sub: n.connected ? "Connected"
               : root.failed === n.name ? "Couldn't connect. Check the password."
               : n.known ? "Saved" : ""
            onClicked: {
                root.failed = "";
                if (n.connected) return;
                if (n.known || !root.secured(n)) { root.pending = n.name; n.connect(); return; }
                root.asking = open ? "" : n.name;
            }
            Connections {
                target: r.n
                function onConnectionFailed(reason) {
                    root.failed = r.n.name;
                    root.pending = "";
                    if (reason === ConnectionFailReason.NoSecrets) root.asking = r.n.name;
                }
                function onConnectedChanged() { if (r.n.connected) { root.pending = ""; root.asking = ""; } }
            }

            RowLayout {
                visible: r.open
                width: parent.width
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    height: 34
                    radius: Theme.m3 ? 17 : 8
                    color: Theme.m3 ? Theme.surface3 : Theme.fill
                    TextInput {
                        id: pw
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: show.on ? TextInput.Normal : TextInput.Password
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        selectByMouse: true
                        clip: true
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                        onAccepted: join.clicked(null)
                        Keys.onEscapePressed: root.asking = ""
                        Txt { visible: !pw.text; text: "Password"; color: Theme.faint; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                IconButton {
                    id: show
                    property bool on: false
                    icon: on ? "visibility_off" : "visibility"
                    iconSize: 18
                    onClicked: on = !on
                }
                Hover {
                    id: join
                    width: 64; height: 34
                    radius: 17
                    base: Theme.accent
                    opacity: pw.text.length >= 8 ? 1 : 0.5
                    onClicked: {
                        if (pw.text.length < 8) return;
                        root.pending = r.n.name;
                        root.asking = "";
                        r.n.connectWithPsk(pw.text);
                    }
                    Txt { anchors.centerIn: parent; text: "Join"; font.pixelSize: 13; font.weight: Theme.strong; color: Theme.accentInk }
                }
            }
        }
    }

    ListRow {
        icon: "settings"
        title: "Network settings…"
        onClicked: { Shell.close(); Quickshell.execDetached(["nm-connection-editor"]); }
    }
}
