pragma Singleton

import QtQuick
import qs
import Quickshell

Singleton {
    readonly property date now: clock.date
    readonly property string time: Qt.formatTime(now, Settings.use24h ? "HH:mm" : "h:mm AP")
    readonly property string shortTime: Qt.formatTime(now, Settings.use24h ? "HH:mm" : "h:mm")
    readonly property string date: Qt.formatDate(now, "ddd d MMM")
    readonly property string longDate: Qt.formatDate(now, "dddd, d MMMM")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
