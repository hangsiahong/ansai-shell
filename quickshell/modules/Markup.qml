import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs
import qs.components
import qs.services

// Screenshot markup (macOS Markup): pen, highlighter, arrow, box, oval, text, blur, crop; undo/redo.
// Marks live in image pixels, and the result is rendered back at full resolution (grabToImage).
// Done, Esc or a click outside saves over the file; Copy also puts it on the clipboard; Delete trashes it.
Sheet {
    id: root
    name: "markup"
    dim: true
    exclusiveKeys: true
    panelRadius: 22
    panelWidth: Math.max(holder.width, bar.implicitWidth) + 32
    panelHeight: holder.height + bar.height + 44
    panelY: Theme.barH + Math.max(12, (height - Theme.barH - panelHeight) / 2)

    readonly property string file: Shell.markupFile
    readonly property real natW: base.implicitWidth
    readonly property real natH: base.implicitHeight
    readonly property real u: Math.max(natW, natH) / 720    // one "logical" stroke unit in image pixels
    readonly property var crop: marks.filter(m => m.t === "crop").pop() ?? { x: 0, y: 0, w: natW, h: natH }
    readonly property real k: natW ? Math.min((width - 96) / crop.w, (height - Theme.barH - 150) / crop.h, 1 / dpr) : 1

    readonly property real dpr: screen?.devicePixelRatio ?? 1
    property var marks: []
    property var redo: []
    property var live: null
    property string tool: "pen"
    property color ink: "#ff3b30"
    property int size: 1
    property bool saving: false
    readonly property var tools: [["pen", "stylus", "Pen"], ["hl", "ink_highlighter", "Highlighter"], ["arrow", "north_east", "Arrow"],
        ["rect", "crop_square", "Box"], ["oval", "circle", "Oval"], ["text", "title", "Text"], ["blur", "blur_on", "Blur"], ["crop", "crop", "Crop"]]
    readonly property var inks: ["#ff3b30", "#ff9500", "#ffcc00", "#34c759", "#0a84ff", "#af52de", "#ffffff", "#000000"]

    onShownChanged: {
        if (shown) {
            marks = []; redo = []; live = null; textAt = null; saving = false;
            base.source = "";
            base.source = "file://" + file;
        } else if (marks.length && !saving) {
            save(false);
        }
    }

    function add(m: var): void {
        marks = marks.concat([m]);
        redo = [];
    }
    function undo(): void {
        if (!marks.length) return;
        redo = redo.concat([marks[marks.length - 1]]);
        marks = marks.slice(0, -1);
    }
    function redoOne(): void {
        if (!redo.length) return;
        marks = marks.concat([redo[redo.length - 1]]);
        redo = redo.slice(0, -1);
    }
    function save(copy: bool): void {
        commitText();
        saving = true;
        if (!marks.length) {
            if (copy) Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", file]);
            Shell.close();
            return;
        }
        const path = file;
        cropBox.grabToImage(r => {
            r.saveToFile(path);
            if (copy) Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", path]);
            marks = [];
            if (Shell.open === "markup") Shell.close();
        }, Qt.size(crop.w / dpr, crop.h / dpr));   // grabToImage multiplies by the screen scale
    }
    function trash(): void {
        saving = true;
        Quickshell.execDetached(["gio", "trash", file]);
        Shell.close();
    }

    // Text tool: a field at the click point; Enter or clicking elsewhere commits it.
    property var textAt: null
    function commitText(): void {
        if (textAt && field.text.trim()) add({ t: "text", x: textAt.x, y: textAt.y, text: field.text, c: ink.toString(), s: [0.7, 1, 1.5][size] });
        textAt = null;
        field.text = "";
    }

    panel.Keys.onPressed: e => {
        if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Z) { (e.modifiers & Qt.ShiftModifier) ? redoOne() : undo(); e.accepted = true; }
        else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_Y) { redoOne(); e.accepted = true; }
        else if ((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_C) { save(true); e.accepted = true; }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { save(false); e.accepted = true; }
    }

    Row {
        id: bar
        anchors { top: parent.top; topMargin: 14; horizontalCenter: parent.horizontalCenter }
        height: 36
        spacing: 4
        Repeater {
            model: root.tools
            IconButton {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                icon: modelData[1]
                iconSize: 18
                active: root.tool === modelData[0]
                activeColor: Theme.accentSoft
                iconColor: active ? Theme.accent : Theme.text
                onClicked: { root.commitText(); root.tool = modelData[0]; }
            }
        }
        Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.line }
        Repeater {
            model: root.inks
            Item {
                required property string modelData
                width: 22; height: 32
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.centerIn: parent
                    width: 20; height: 20; radius: 10
                    color: Theme.accent
                    visible: Qt.colorEqual(root.ink, parent.modelData)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 15; height: 15; radius: 7.5
                    color: parent.modelData
                    border.width: 1
                    border.color: Qt.rgba(0.5, 0.5, 0.5, 0.5)
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.ink = parent.modelData }
            }
        }
        Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.line }
        Repeater {
            model: 3
            Hover {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28; radius: 14
                active: root.size === index
                activeColor: Theme.accentSoft
                onClicked: root.size = index
                Rectangle { anchors.centerIn: parent; width: 4 + parent.index * 4; height: width; radius: width / 2; color: parent.active ? Theme.accent : Theme.text }
            }
        }
        Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.line }
        IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "undo"; iconSize: 18; opacity: root.marks.length ? 1 : 0.35; onClicked: root.undo() }
        IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "redo"; iconSize: 18; opacity: root.redo.length ? 1 : 0.35; onClicked: root.redoOne() }
        Rectangle { width: 1; height: 20; anchors.verticalCenter: parent.verticalCenter; color: Theme.line }
        IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "delete"; iconSize: 18; onClicked: root.trash() }
        IconButton { anchors.verticalCenter: parent.verticalCenter; icon: "content_copy"; iconSize: 18; onClicked: root.save(true) }
        Hover {
            anchors.verticalCenter: parent.verticalCenter
            width: doneT.implicitWidth + 28; height: 30; radius: 15
            base: Theme.accent
            onClicked: root.save(false)
            Txt { id: doneT; anchors.centerIn: parent; text: "Done"; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.accentInk }
        }
    }

    Item {
        id: holder
        anchors { top: bar.bottom; topMargin: 14; horizontalCenter: parent.horizontalCenter }
        width: root.crop.w * root.k
        height: root.crop.h * root.k

        Image {   // the screenshot at full size, only shown through the copies in cropBox
            id: base
            visible: false
            cache: false
            asynchronous: false
        }

        Item {
            id: cropBox   // what gets saved: the crop of doc, in image pixels
            width: root.crop.w
            height: root.crop.h
            scale: root.k
            transformOrigin: Item.TopLeft
            clip: true

            Item {
                id: doc
                x: -root.crop.x
                y: -root.crop.y
                width: root.natW
                height: root.natH

                Image { anchors.fill: parent; source: base.source; cache: false; smooth: true; mipmap: true }

                Repeater {
                    model: root.marks.concat(root.live ? [root.live] : [])
                    Loader {
                        required property var modelData
                        readonly property var m: modelData
                        sourceComponent: ({ pen: stroke, hl: stroke, arrow: arrow, rect: box, oval: oval, text: label, blur: blur, crop: null })[m.t] ?? null
                    }
                }

                Rectangle {   // crop selection in progress
                    visible: root.live?.t === "crop"
                    x: root.live?.x ?? 0; y: root.live?.y ?? 0
                    width: root.live?.w ?? 0; height: root.live?.h ?? 0
                    color: "transparent"
                    border.width: 2 * root.u
                    border.color: "#ffffff"
                    Rectangle { anchors.fill: parent; anchors.margins: -1 * root.u; color: "transparent"; border.width: root.u; border.color: Qt.rgba(0, 0, 0, 0.6) }
                }

                TextInput {
                    id: field
                    visible: root.textAt !== null
                    x: root.textAt?.x ?? 0
                    y: root.textAt?.y ?? 0
                    width: Math.max(contentWidth + 4, 40 * root.u)
                    color: root.ink
                    font.family: Theme.font
                    font.pixelSize: 16 * root.u * [0.7, 1, 1.5][root.size]
                    font.weight: Font.Bold
                    cursorVisible: visible
                    onAccepted: root.commitText()
                    Keys.onEscapePressed: { root.textAt = null; text = ""; root.panel.forceActiveFocus(); }
                    Rectangle { anchors.fill: parent; anchors.margins: -4 * root.u; z: -1; radius: 3 * root.u; color: "transparent"; border.width: root.u; border.color: Theme.accent }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                    property point o
                    onPressed: e => {
                        if (root.tool === "text") {
                            root.commitText();
                            root.textAt = Qt.point(e.x, e.y - 10 * root.u);
                            field.forceActiveFocus();
                            return;
                        }
                        root.commitText();
                        o = Qt.point(e.x, e.y);
                        const w = root.u * [1.5, 3, 6][root.size];
                        root.live = root.tool === "pen" || root.tool === "hl"
                            ? { t: root.tool, pts: [o], c: root.ink.toString(), w: root.tool === "hl" ? w * 5 : w }
                            : { t: root.tool, ox: o.x, oy: o.y, x: o.x, y: o.y, w: 0, h: 0, x2: o.x, y2: o.y, c: root.ink.toString(), lw: w };
                    }
                    onPositionChanged: e => {
                        const l = root.live;
                        if (!l) return;
                        const p = Qt.point(Math.max(0, Math.min(root.natW, e.x)), Math.max(0, Math.min(root.natH, e.y)));
                        if (l.pts) {
                            root.live = Object.assign({}, l, { pts: l.pts.concat([p]) });
                        } else {
                            root.live = Object.assign({}, l, { x: Math.min(o.x, p.x), y: Math.min(o.y, p.y), w: Math.abs(p.x - o.x), h: Math.abs(p.y - o.y), x2: p.x, y2: p.y });
                        }
                    }
                    onReleased: {
                        const l = root.live;
                        root.live = null;
                        if (!l) return;
                        const big = l.pts ? l.pts.length > 1 : (l.t === "arrow" ? Math.hypot(l.w, l.h) > 8 * root.u : l.w > 4 * root.u && l.h > 4 * root.u);
                        if (big) root.add(l);
                        root.panel.forceActiveFocus();
                    }
                }
            }
        }
        Rectangle {   // hairline frame around the picture
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Theme.line
        }
    }

    Component {
        id: stroke
        Shape {
            preferredRendererType: Shape.CurveRenderer
            opacity: m.t === "hl" ? 0.4 : 1
            ShapePath {
                strokeColor: m.c
                strokeWidth: m.w
                fillColor: "transparent"
                capStyle: m.t === "hl" ? ShapePath.SquareCap : ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: m.pts }
            }
        }
    }
    Component {
        id: arrow
        Shape {
            id: ar
            preferredRendererType: Shape.CurveRenderer
            readonly property real sx: m.ox
            readonly property real sy: m.oy
            readonly property real a: Math.atan2(m.y2 - sy, m.x2 - sx)
            readonly property real hl: Math.max(m.lw * 4, 14 * root.u)
            ShapePath {
                strokeColor: m.c
                strokeWidth: m.lw
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: ar.sx; startY: ar.sy
                PathLine { x: m.x2 - Math.cos(ar.a) * ar.hl * 0.8; y: m.y2 - Math.sin(ar.a) * ar.hl * 0.8 }
            }
            ShapePath {
                strokeColor: m.c
                strokeWidth: m.lw / 2
                fillColor: m.c
                joinStyle: ShapePath.RoundJoin
                startX: m.x2; startY: m.y2
                PathLine { x: m.x2 - Math.cos(ar.a - 0.45) * ar.hl; y: m.y2 - Math.sin(ar.a - 0.45) * ar.hl }
                PathLine { x: m.x2 - Math.cos(ar.a + 0.45) * ar.hl; y: m.y2 - Math.sin(ar.a + 0.45) * ar.hl }
                PathLine { x: m.x2; y: m.y2 }
            }
        }
    }
    Component {
        id: box
        Rectangle {
            x: m.x; y: m.y; width: m.w; height: m.h
            radius: 2 * root.u
            color: "transparent"
            border.width: m.lw
            border.color: m.c
        }
    }
    Component {
        id: oval
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: m.c
                strokeWidth: m.lw
                fillColor: "transparent"
                PathAngleArc { centerX: m.x + m.w / 2; centerY: m.y + m.h / 2; radiusX: m.w / 2; radiusY: m.h / 2; startAngle: 0; sweepAngle: 360 }
            }
        }
    }
    Component {
        id: label
        Text {
            x: m.x; y: m.y
            text: m.text
            color: m.c
            font.family: Theme.font
            font.pixelSize: 16 * root.u * m.s
            font.weight: Font.Bold
            style: Text.Outline
            styleColor: Qt.colorEqual(m.c, "#000000") ? Qt.rgba(1, 1, 1, 0.6) : Qt.rgba(0, 0, 0, 0.35)
        }
    }
    Component {
        id: blur
        Item {
            x: m.x; y: m.y; width: m.w; height: m.h
            clip: true
            Image {
                x: -m.x; y: -m.y
                width: root.natW; height: root.natH
                source: base.source
                cache: false
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 64; autoPaddingEnabled: false }
            }
        }
    }
}
