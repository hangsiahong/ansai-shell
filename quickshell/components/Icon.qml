import QtQuick
import qs
import "phosphor.js" as Ph

// One icon glyph in a square box the size of the icon, so centring it centres the glyph.
// Names are Material Symbols names; the ansai look draws the Phosphor equivalent (components/phosphor.js) when there is one.
Text {
    property string name
    property real size: 18
    property bool filled: false
    readonly property var ph: Theme.phosphor && Theme.ph ? Ph.map[name] : undefined
    text: ph ? String.fromCodePoint(ph[filled ? 1 : 0]) : name
    color: Theme.text
    font.family: ph ? (filled ? Theme.phFill : Theme.ph) : Theme.icons
    font.pixelSize: ph ? size * 1.05 : size
    width: size
    height: size
    lineHeightMode: Text.FixedHeight
    lineHeight: size
    font.variableAxes: ph ? ({}) : ({ "FILL": filled ? 1 : 0, "wght": 400, "opsz": 24 })
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
