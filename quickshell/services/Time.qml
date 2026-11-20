pragma Singleton

import QtQuick
import qs
import Quickshell

Singleton {
    readonly property date now: clock.date
    readonly property string time: Qt.formatTime(now, Settings.use24h ? "HH:mm" : "h:mm AP")
    // Qt's "h" is 12-hour only alongside "AP", so drop the AM/PM after formatting.
    readonly property string shortTime: time.replace(/\s*[AaPp]\.?[Mm]\.?$/, "")
    readonly property string date: Qt.formatDate(now, "ddd d MMM")
    readonly property string longDate: Qt.formatDate(now, "dddd, d MMMM")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
