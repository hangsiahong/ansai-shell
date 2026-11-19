pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Two styles share one token set:
//  "ansai"    mirrors ansai/src/web/styles.css (:root and [data-theme="light"]).
//  "material" is Android 16 Material 3 Expressive: wallpaper-seeded tonal colours, Roboto, big shapes.
Singleton {
    readonly property bool dark: Settings.theme !== "light"
    readonly property bool m3: Settings.style === "material"
    readonly property var pal: Scheme

    readonly property color bg: m3 ? pal.n(dark ? 6 : 98) : dark ? "#000000" : "#f2f2f7"
    readonly property color surface: m3 ? pal.n(dark ? 12 : 94) : dark ? "#1c1c1e" : "#ffffff"
    readonly property color surface2: m3 ? pal.n(dark ? 17 : 92) : dark ? "#2c2c2e" : "#f2f2f7"
    readonly property color surface3: m3 ? pal.n(dark ? 22 : 90) : dark ? "#3a3a3c" : "#e5e5ea"
    readonly property color fill: m3 ? pal.nv(dark ? 26 : 87) : dark ? Qt.rgba(118/255, 118/255, 128/255, 0.24) : Qt.rgba(118/255, 118/255, 128/255, 0.12)
    readonly property color fill2: m3 ? pal.n(dark ? 18 : 92) : dark ? Qt.rgba(118/255, 118/255, 128/255, 0.16) : Qt.rgba(118/255, 118/255, 128/255, 0.08)
    readonly property color hover: Qt.rgba(text.r, text.g, text.b, m3 ? 0.08 : dark ? 0.06 : 0.04)
    readonly property color press: Qt.rgba(text.r, text.g, text.b, m3 ? 0.12 : dark ? 0.10 : 0.08)
    readonly property color line: m3 ? pal.nv(dark ? 30 : 80) : dark ? Qt.rgba(84/255, 84/255, 88/255, 0.55) : Qt.rgba(60/255, 60/255, 67/255, 0.2)
    readonly property color text: m3 ? pal.n(dark ? 90 : 10) : dark ? "#ffffff" : "#000000"
    readonly property color text2: m3 ? pal.nv(dark ? 80 : 30) : dark ? Qt.rgba(235/255, 235/255, 245/255, 0.86) : Qt.rgba(60/255, 60/255, 67/255, 0.92)
    readonly property color muted: m3 ? pal.nv(dark ? 72 : 38) : dark ? Qt.rgba(235/255, 235/255, 245/255, 0.6) : Qt.rgba(60/255, 60/255, 67/255, 0.6)
    readonly property color faint: m3 ? pal.nv(dark ? 58 : 55) : dark ? Qt.rgba(235/255, 235/255, 245/255, 0.32) : Qt.rgba(60/255, 60/255, 67/255, 0.3)
    readonly property color accent: m3 ? pal.p(dark ? 80 : 40) : dark ? "#0a84ff" : "#007aff"
    readonly property color accentInk: m3 ? pal.p(dark ? 20 : 100) : "#ffffff"
    readonly property color accentSoft: m3 ? pal.p(dark ? 30 : 90) : dark ? Qt.rgba(10/255, 132/255, 1, 0.18) : Qt.rgba(0, 122/255, 1, 0.12)
    readonly property color accentSoftInk: m3 ? pal.p(dark ? 90 : 10) : accent
    // M3 secondary container: tonal fill for selected-but-quiet things (sliders' rest track, chips).
    readonly property color tonal: m3 ? pal.s(dark ? 30 : 90) : fill
    readonly property color tonalInk: m3 ? pal.s(dark ? 90 : 10) : text
    readonly property color green: dark ? "#30d158" : "#34c759"
    readonly property color warn: dark ? "#ff9f0a" : "#ff9500"
    readonly property color danger: m3 ? (dark ? "#ffb4ab" : "#ba1a1a") : dark ? "#ff453a" : "#ff3b30"
    readonly property color indigo: m3 ? pal.tr(dark ? 80 : 40) : dark ? "#5e5ce6" : "#5856d6"
    readonly property color seg: dark ? "#636366" : "#ffffff"
    // Panels sit on compositor blur, so glass is a little denser than the web's 0.72.
    // ansai is macOS 27 Liquid Glass: a thin tint over heavy blur, a bright specular rim, a darker edge.
    readonly property color glass: m3 ? pal.tone(pal.hue, 5, dark ? 12 : 95, 0.9) : dark ? Qt.rgba(28/255, 28/255, 32/255, 0.56) : Qt.rgba(1, 1, 1, 0.58)
    readonly property color glassLine: m3 ? "transparent" : dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.7)
    readonly property color glassEdge: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
    // Module/tile fill inside glass panels (Control Center modules, menu hover).
    readonly property color glassTile: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color scrim: dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.3)
    // Colour to put on a toggle that is on; M3 uses primary for every toggle.
    function on(c: color): color { return m3 ? accent : c; }
    function onInk(c: color): color { return m3 ? accentInk : "#ffffff"; }

    readonly property int rSm: m3 ? 12 : 8
    readonly property int r: m3 ? 22 : 16
    readonly property int rLg: m3 ? 28 : 24
    readonly property int rMenu: m3 ? 20 : 12
    readonly property int rGroup: m3 ? 28 : 16
    readonly property int barH: m3 ? 40 : 30

    readonly property var fonts: ["Noto Sans", "Roboto", "Inter", "Cantarell"]
    readonly property string fontName: Settings.font || (m3 ? "Roboto" : "Noto Sans")
    readonly property string font: fontName === "Inter" ? (inter.status === FontLoader.Ready ? inter.name : "sans-serif") : fontName
    readonly property string mono: "monospace"
    readonly property string icons: "Material Symbols Rounded"
    // Text weights: M3 type scale is lighter than the web's semibold labels.
    readonly property int strong: m3 ? Font.Medium : Font.DemiBold

    readonly property int fast: m3 ? 180 : 140
    readonly property int med: m3 ? 320 : 220
    readonly property int easing: m3 ? Easing.OutQuint : Easing.OutCubic
    // M3 Expressive "spatial spring": a small overshoot for shape and size changes.
    readonly property int spring: m3 ? Easing.OutBack : Easing.OutCubic


    property FontLoader inter: FontLoader {
        source: Qt.resolvedUrl("assets/fonts/inter-latin.ttf")
    }
}
