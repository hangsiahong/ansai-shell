import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 22

    readonly property var all: (Bluetooth.devices?.values ?? []).filter(d => d.name && d.name !== d.address.replace(/:/g, "-"))
    readonly property var mine: all.filter(d => d.paired).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    readonly property var others: all.filter(d => !d.paired).sort((a, b) => a.name.localeCompare(b.name)).slice(0, 12)
    property string forgetting: ""
    property string renaming: ""

    Component.onCompleted: if (Net.bt?.enabled) Net.bt.discovering = true
    Component.onDestruction: if (Net.bt) Net.bt.discovering = false

    function icon(d) {
        const i = d.icon ?? "";
        return /headset|headphone/.test(i) ? "headphones" : /audio|speaker/.test(i) ? "speaker"
             : /phone/.test(i) ? "smartphone" : /mouse/.test(i) ? "mouse" : /keyboard/.test(i) ? "keyboard"
             : /computer/.test(i) ? "computer" : /game/.test(i) ? "sports_esports" : "bluetooth";
    }

    SGroup {
        SRow {
            first: true
            icon: Net.btOn ? "bluetooth" : "bluetooth_disabled"
            title: "Bluetooth"
            sub: !Net.bt ? "No Bluetooth adapter" : Net.btOn ? "On" + (Net.bt.discoverable ? `, visible as "${Net.bt.name}"` : "") : "Off"
            Switch { checked: Net.btOn; onToggled: Net.toggleBt() }
        }
        SRow {
            visible: Net.btOn
            icon: "visibility"
            title: "Visible to other devices"
            sub: "Lets a phone or another computer find this one"
            Switch { checked: Net.bt?.discoverable ?? false; onToggled: Net.bt.discoverable = !Net.bt.discoverable }
        }
    }

    SGroup {
        title: "My devices"
        visible: Net.btOn && root.mine.length > 0
        Repeater {
            model: root.mine
            SRow {
                id: dr
                required property var modelData
                required property int index
                readonly property var d: modelData
                first: index === 0
                icon: root.icon(d)
                title: d.name
                sub: d.connected ? "Connected" + (d.batteryAvailable ? ` · battery ${Math.round(d.battery * 100)}%` : "")
                   : d.state === BluetoothDeviceState.Connecting ? "Connecting…" : "Not connected"
                Row {
                    spacing: 8
                    Btn {
                        text: dr.d.connected ? "Disconnect" : "Connect"
                        onClicked: dr.d.connected ? dr.d.disconnect() : dr.d.connect()
                    }
                    Btn {
                        text: "Rename"
                        onClicked: root.renaming = root.renaming === dr.d.address ? "" : dr.d.address
                    }
                    Btn {
                        text: root.forgetting === dr.d.address ? "Forget?" : "Forget"
                        kind: root.forgetting === dr.d.address ? "danger" : "tonal"
                        onClicked: {
                            if (root.forgetting !== dr.d.address) { root.forgetting = dr.d.address; return; }
                            root.forgetting = "";
                            dr.d.forget();
                        }
                    }
                }
                below: Rectangle {
                    visible: root.renaming === dr.d.address
                    width: parent.width; height: visible ? 34 : 0
                    radius: 8
                    color: Theme.m3 ? Theme.surface3 : Theme.fill
                    TextInput {
                        id: nameIn
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 13
                        selectByMouse: true
                        onVisibleChanged: if (visible) { text = dr.d.name; selectAll(); forceActiveFocus(); }
                        onAccepted: { if (text.trim()) dr.d.name = text.trim(); root.renaming = ""; }
                        Keys.onEscapePressed: root.renaming = ""
                    }
                }
            }
        }
    }

    SGroup {
        title: "Other devices"
        visible: Net.btOn
        note: "Put the device in pairing mode, then click it. Confirm the code on the device if it asks."
        SRow {
            visible: root.others.length === 0
            first: true
            icon: "bluetooth_searching"
            title: "Looking for devices…"
        }
        Repeater {
            model: root.others
            SRow {
                id: or
                required property var modelData
                required property int index
                first: index === 0
                property bool want: false
                icon: root.icon(modelData)
                title: modelData.name
                sub: modelData.pairing ? "Pairing…" : ""
                clickable: true
                onClicked: { want = true; modelData.trusted = true; modelData.pair(); }
                Connections {
                    target: or.modelData
                    function onPairedChanged() { if (or.modelData.paired && or.want) { or.want = false; or.modelData.connect(); } }
                }
                Btn { text: "Pair"; onClicked: or.clicked() }
            }
        }
    }
}
