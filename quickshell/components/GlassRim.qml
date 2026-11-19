import QtQuick
import qs

// Liquid Glass edge light for an ansai glass surface; fill the surface with it (see shaders/glassrim.frag).
ShaderEffect {
    property real radius: 0
    readonly property size size: Qt.size(width, height)
    property real rimWidth: 2.3
    property real rimIntensity: Theme.dark ? 0.42 : 0.75
    property real rimPower: 1.9
    property real aoIntensity: Theme.dark ? 0.55 : 0.18
    property real aoRadius: 1.0
    property real lightAngle: Math.PI / 2
    visible: !Theme.m3
    fragmentShader: Qt.resolvedUrl("../shaders/glassrim.frag.qsb")
}
