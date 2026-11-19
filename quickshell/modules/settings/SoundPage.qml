import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 22

    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    // GPU HDMI/DP "Pro" sinks are mostly unplugged ports; tuck them away unless chosen.
    property bool showAll: false
    function extra(n) { return /hdmi|displayport|controller pro( \d+)?$/i.test(label(n)); }
    readonly property var allSinks: devices.filter(n => n.isSink)
    readonly property var sinks: allSinks.filter(n => showAll || !extra(n) || n === Audio.sink)
    readonly property var sources: devices.filter(n => !n.isSink && !/monitor/i.test(n.name))
    PwObjectTracker { objects: root.devices }

    function label(n) { return n.description || n.nickname || n.name; }

    component Dev: SRow {
        id: d
        required property var modelData
        required property int index
        property bool isDefault
        signal pick
        first: index === 0
        clickable: true
        icon: isDefault ? "radio_button_checked" : "radio_button_unchecked"
        title: root.label(modelData)
        sub: modelData.properties?.["device.bus"] === "bluetooth" ? "Bluetooth" : modelData.properties?.["device.form-factor"] ?? ""
        onClicked: pick()
    }

    SGroup {
        title: "Output"
        SRow {
            first: true
            icon: Audio.icon()
            title: Audio.sink ? root.label(Audio.sink) : "No output"
            Txt { text: Math.round(Audio.volume * 100) + "%"; font.pixelSize: 13; color: Theme.muted; font.features: { "tnum": 1 } }
            IconButton { icon: Audio.muted ? "volume_off" : "volume_up"; iconSize: 18; onClicked: Audio.toggleMute() }
            below: Slider {
                width: parent.width
                icon: Audio.icon()
                value: Audio.volume
                onMoved: v => Audio.setVolume(v)
            }
        }
    }
    SGroup {
        title: "Output device"
        Repeater {
            model: root.sinks
            Dev {
                isDefault: Audio.sink === modelData
                onPick: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
        SRow {
            visible: root.allSinks.length > root.sinks.length || root.showAll
            clickable: true
            icon: root.showAll ? "expand_less" : "expand_more"
            title: root.showAll ? "Show fewer" : `Show HDMI and DisplayPort outputs (${root.allSinks.length - root.sinks.length})`
            onClicked: root.showAll = !root.showAll
        }
    }

    SGroup {
        title: "Input"
        visible: root.sources.length > 0
        SRow {
            first: true
            icon: Audio.micMuted ? "mic_off" : "mic"
            title: Audio.source ? root.label(Audio.source) : "No microphone"
            Txt { text: Math.round((Audio.source?.audio?.volume ?? 0) * 100) + "%"; font.pixelSize: 13; color: Theme.muted; font.features: { "tnum": 1 } }
            IconButton {
                icon: Audio.micMuted ? "mic_off" : "mic"; iconSize: 18
                onClicked: if (Audio.source?.audio) Audio.source.audio.muted = !Audio.source.audio.muted
            }
            below: Slider {
                width: parent.width
                icon: "mic"
                value: Audio.source?.audio?.volume ?? 0
                onMoved: v => { if (Audio.source?.audio) Audio.source.audio.volume = v; }
            }
        }
        Repeater {
            model: root.sources
            Dev {
                first: false
                isDefault: Audio.source === modelData
                onPick: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }
}
