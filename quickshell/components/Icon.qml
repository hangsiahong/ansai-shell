import QtQuick
import qs

// Material Symbols glyph in a square box the size of the icon, so centring it centres the glyph
// (the font's taller line box otherwise leaves glyphs sitting a little high or low).
Text {
    property string name
    property real size: 18
    property bool filled: false
    text: name
    color: Theme.text
    font.family: Theme.icons
    font.pixelSize: size
    width: size
    height: size
    lineHeightMode: Text.FixedHeight
    lineHeight: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 400, "opsz": 24 })
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
