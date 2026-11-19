import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.components
import qs.services

ColumnLayout {
    id: root
    spacing: 22

    property int limit: -1
    property string kbd: ""
    readonly property bool asus: limit >= 0

    function refresh() { info.running = true; }
    Process {
        id: info
        running: true
        command: ["sh", "-c", "command -v asusctl >/dev/null || exit 0; echo limit=$(asusctl battery info 2>/dev/null | grep -o '[0-9]*%' | tr -d %); echo kbd=$(asusctl leds get 2>/dev/null | sed -n 's/.*: *//p')"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    const [k, v] = [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1).trim()];
                    if (k === "limit" && v) root.limit = parseInt(v);
                    if (k === "kbd") root.kbd = v.toLowerCase();
                }
            }
        }
    }

    function dur(s) {
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return h ? `${h} h ${m} min` : `${m} min`;
    }

    SGroup {
        title: "Power mode"
        SRow {
            first: true
            icon: PowerProfiles.profile === PowerProfile.Performance ? "speed" : PowerProfiles.profile === PowerProfile.PowerSaver ? "energy_savings_leaf" : "balance"
            title: "Profile"
            sub: PowerProfiles.profile === PowerProfile.Performance ? "Fastest; fans and battery drain go up"
               : PowerProfiles.profile === PowerProfile.PowerSaver ? "Quieter and cooler, longer battery" : "Balances speed and battery life"
            Seg {
                model: [{ v: PowerProfile.PowerSaver, l: "Saver" }, { v: PowerProfile.Balanced, l: "Balanced" }]
                    .concat(PowerProfiles.hasPerformanceProfile ? [{ v: PowerProfile.Performance, l: "Performance" }] : [])
                value: PowerProfiles.profile
                onPicked: v => PowerProfiles.profile = v
            }
        }
        SRow {
            icon: "coffee"
            title: "Keep awake"
            sub: "Don't lock or turn off the screen when idle (useful while agents work)"
            Switch { checked: Settings.keepAwake; onToggled: Settings.keepAwake = !Settings.keepAwake }
        }
        SRow {
            visible: Brightness.available
            icon: "brightness_6"
            title: "Screen brightness"
            Txt { text: Math.round(Brightness.value * 100) + "%"; font.pixelSize: 13; color: Theme.muted; font.features: { "tnum": 1 } }
            below: Slider {
                width: parent.width
                icon: "brightness_6"
                value: Brightness.value
                onMoved: v => Brightness.set(Math.max(0.02, v))
            }
        }
    }

    SGroup {
        title: "Battery"
        visible: Battery.present
        SRow {
            first: true
            icon: Battery.icon()
            title: Math.round(Battery.pct * 100) + "%" + (Battery.charging ? " · charging" : " · on battery")
            sub: Battery.charging ? (root.dur(Battery.dev?.timeToFull) ? root.dur(Battery.dev.timeToFull) + " until full" : "Plugged in")
               : (root.dur(Battery.dev?.timeToEmpty) ? root.dur(Battery.dev.timeToEmpty) + " left" : "")
            Txt {
                visible: (Battery.dev?.changeRate ?? 0) > 0
                text: (Battery.dev?.changeRate ?? 0).toFixed(1) + " W"
                font.pixelSize: 13; color: Theme.muted
            }
        }
        SRow {
            visible: root.asus
            icon: "battery_profile"
            title: "Charge limit"
            sub: "Stops charging here to keep the battery healthy when you're mostly plugged in. 80% is a good default."
            Txt { text: chargeSlider.shown + "%"; font.pixelSize: 15; font.weight: Theme.strong; font.features: { "tnum": 1 } }
            below: Slider {
                id: chargeSlider
                width: parent.width
                icon: "battery_charging_full"
                property int shown: root.limit
                value: (shown - 20) / 80
                onMoved: v => { shown = Math.round((20 + v * 80) / 5) * 5; applyLimit.restart(); }
                Connections { target: root; function onLimitChanged() { chargeSlider.shown = root.limit; } }
                Timer {
                    id: applyLimit
                    interval: 700
                    onTriggered: {
                        root.limit = chargeSlider.shown;
                        Quickshell.execDetached(["asusctl", "battery", "limit", String(chargeSlider.shown)]);
                    }
                }
            }
        }
        SRow {
            visible: root.asus
            icon: "battery_full"
            title: "Charge to 100% once"
            sub: "For a trip: charges fully this time, then the limit applies again"
            Btn { text: "Charge fully"; onClicked: Quickshell.execDetached(["asusctl", "battery", "oneshot"]) }
        }
    }

    SGroup {
        title: "Keyboard"
        visible: root.kbd !== ""
        SRow {
            first: true
            icon: "keyboard"
            title: "Backlight"
            Seg {
                small: true
                model: [{ v: "off", l: "Off" }, { v: "low", l: "Low" }, { v: "med", l: "Medium" }, { v: "high", l: "High" }]
                value: root.kbd === "medium" ? "med" : root.kbd
                onPicked: v => { root.kbd = v; Quickshell.execDetached(["asusctl", "leds", "set", v]); }
            }
        }
    }
}
