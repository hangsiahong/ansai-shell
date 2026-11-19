pragma Singleton

import QtQuick
import qs
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev?.isLaptopBattery ?? false
    readonly property real pct: dev?.percentage ?? 0
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging || dev?.state === UPowerDeviceState.FullyCharged || dev?.state === UPowerDeviceState.PendingCharge
    readonly property bool low: !charging && pct < 0.2
    readonly property string profile: PowerProfile.toString(PowerProfiles.profile)

    function icon(): string {
        if (charging)
            return "battery_charging_full";
        const step = Math.min(6, Math.floor(pct * 7));
        return pct > 0.95 ? "battery_full" : "battery_" + step + "_bar";
    }

    function cycleProfile(): void {
        const order = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance];
        const i = order.indexOf(PowerProfiles.profile);
        let next = order[(i + 1) % order.length];
        if (next === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
            next = order[0];
        PowerProfiles.profile = next;
    }
}
