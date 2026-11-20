import QtQuick
import qs
import qs.components

// A time of day in Settings[key] (minutes after midnight), stepped by 30 minutes.
Row {
    id: ts
    property string key
    spacing: 2
    IconButton { icon: "remove"; iconSize: 15; implicitWidth: 28; implicitHeight: 28; onClicked: Settings[ts.key] = (Settings[ts.key] + 1410) % 1440 }
    Txt {
        anchors.verticalCenter: parent.verticalCenter
        width: 70; horizontalAlignment: Text.AlignHCenter
        text: Qt.formatTime(new Date(2000, 0, 1, Math.floor(Settings[ts.key] / 60), Settings[ts.key] % 60), Settings.use24h ? "HH:mm" : "h:mm AP")
        font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
    }
    IconButton { icon: "add"; iconSize: 15; implicitWidth: 28; implicitHeight: 28; onClicked: Settings[ts.key] = (Settings[ts.key] + 30) % 1440 }
}
