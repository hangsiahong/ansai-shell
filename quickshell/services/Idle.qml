pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// Idle timers (Settings > Power): dim the backlight, lock, then turn the screens off. 0 = never.
// Keep awake's IdleInhibitor (modules/Bar.qml) holds them all off. swayidle only locks before sleep.
Singleton {
    id: root
    property real dimmedFrom: -1

    IdleMonitor {
        enabled: Settings.idleDim > 0 && Brightness.available
        timeout: Settings.idleDim
        onIsIdleChanged: {
            if (isIdle) {
                root.dimmedFrom = Brightness.value;
                Brightness.set(Math.max(0.02, Brightness.value * 0.3));
            } else if (root.dimmedFrom >= 0) {
                Brightness.set(root.dimmedFrom);
                root.dimmedFrom = -1;
            }
        }
    }
    IdleMonitor {
        enabled: Settings.idleLock > 0
        timeout: Settings.idleLock
        onIsIdleChanged: if (isIdle && !Lock.locked) Lock.lock()
    }
    IdleMonitor {
        enabled: Settings.idleOff > 0
        timeout: Settings.idleOff
        onIsIdleChanged: Quickshell.execDetached(["niri", "msg", "action", isIdle ? "power-off-monitors" : "power-on-monitors"])
    }
}
