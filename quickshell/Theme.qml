pragma Singleton

import QtQuick
import Quickshell

// Tokens mirror ansai/src/web/styles.css (:root and [data-theme="light"]).
Singleton {
    readonly property bool dark: Settings.theme !== "light"

    readonly property color bg: dark ? "#000000" : "#f2f2f7"
    readonly property color surface: dark ? "#1c1c1e" : "#ffffff"
    readonly property color surface2: dark ? "#2c2c2e" : "#f2f2f7"
    readonly property color surface3: dark ? "#3a3a3c" : "#e5e5ea"
    readonly property color fill: dark ? Qt.rgba(118/255, 118/255, 128/255, 0.24) : Qt.rgba(118/255, 118/255, 128/255, 0.12)
    readonly property color fill2: dark ? Qt.rgba(118/255, 118/255, 128/255, 0.16) : Qt.rgba(118/255, 118/255, 128/255, 0.08)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color press: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color line: dark ? Qt.rgba(84/255, 84/255, 88/255, 0.55) : Qt.rgba(60/255, 60/255, 67/255, 0.2)
    readonly property color text: dark ? "#ffffff" : "#000000"
    readonly property color text2: dark ? Qt.rgba(235/255, 235/255, 245/255, 0.86) : Qt.rgba(60/255, 60/255, 67/255, 0.92)
    readonly property color muted: dark ? Qt.rgba(235/255, 235/255, 245/255, 0.6) : Qt.rgba(60/255, 60/255, 67/255, 0.6)
    readonly property color faint: dark ? Qt.rgba(235/255, 235/255, 245/255, 0.32) : Qt.rgba(60/255, 60/255, 67/255, 0.3)
    readonly property color accent: dark ? "#0a84ff" : "#007aff"
    readonly property color accentInk: "#ffffff"
    readonly property color accentSoft: dark ? Qt.rgba(10/255, 132/255, 1, 0.18) : Qt.rgba(0, 122/255, 1, 0.12)
    readonly property color green: dark ? "#30d158" : "#34c759"
    readonly property color warn: dark ? "#ff9f0a" : "#ff9500"
    readonly property color danger: dark ? "#ff453a" : "#ff3b30"
    readonly property color indigo: dark ? "#5e5ce6" : "#5856d6"
    readonly property color seg: dark ? "#636366" : "#ffffff"
    // Panels sit on compositor blur, so glass is a little denser than the web's 0.72.
    readonly property color glass: dark ? Qt.rgba(30/255, 30/255, 32/255, 0.78) : Qt.rgba(1, 1, 1, 0.78)
    readonly property color glassLine: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color scrim: dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.3)

    readonly property int rSm: 8
    readonly property int r: 14
    readonly property int rLg: 18
    readonly property int rGroup: 16

    readonly property string font: inter.status === FontLoader.Ready ? inter.name : "sans-serif"
    readonly property string mono: "monospace"
    readonly property string icons: "Material Symbols Rounded"

    readonly property int fast: 140
    readonly property int med: 220
    readonly property int easing: Easing.OutCubic

    property FontLoader inter: FontLoader {
        source: Qt.resolvedUrl("assets/fonts/inter-latin.ttf")
    }
}
