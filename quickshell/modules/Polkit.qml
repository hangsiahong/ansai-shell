import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs
import qs.components
import qs.services

// Password prompt for pkexec / system settings, as an ansai sheet.
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow
    readonly property bool shown: flow !== null && !flow.isCompleted

    PanelWindow {
        visible: root.shown
        screen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: Theme.scrim
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ansai-polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        BackgroundEffect.blurRegion: Region { item: card; radius: card.radius }

        onVisibleChanged: if (visible) { pw.text = ""; pw.forceActiveFocus(); }

        Glass {
            id: card
            anchors.centerIn: parent
            width: 380
            height: col.implicitHeight + 40
            radius: 22

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 12

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 52; height: 52; radius: 14
                    color: Theme.accentSoft
                    Icon { anchors.centerIn: parent; name: "admin_panel_settings"; size: 28; filled: true; color: Theme.accent }
                }
                Txt {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Authentication required"
                    font.pixelSize: 17; font.weight: Font.Bold
                }
                Txt {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    color: Theme.muted
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.preferredHeight: 42
                    radius: 12
                    color: Theme.fill2
                    border.width: 1
                    border.color: root.flow?.supplementaryIsError ? Theme.danger : "transparent"
                    TextInput {
                        id: pw
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 15
                        focus: true
                        Keys.onReturnPressed: submitIt()
                        Keys.onEnterPressed: submitIt()
                        Keys.onEscapePressed: root.flow?.cancelAuthenticationRequest()
                        function submitIt() {
                            if (root.flow?.isResponseRequired) {
                                root.flow.submit(text);
                                text = "";
                            }
                        }
                        Txt {
                            anchors.fill: parent
                            visible: !pw.text
                            text: (root.flow?.inputPrompt || "Password").replace(/:\s*$/, "")
                            color: Theme.faint
                            font.pixelSize: 15
                        }
                    }
                }
                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.danger : Theme.muted
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 10
                    Hover {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 12
                        base: Theme.fill
                        onClicked: root.flow?.cancelAuthenticationRequest()
                        Txt { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 15; font.weight: Font.Medium }
                    }
                    Hover {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 12
                        base: Theme.accent
                        onClicked: pw.submitIt()
                        Txt { anchors.centerIn: parent; text: "Authenticate"; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.accentInk }
                    }
                }
            }
        }
    }
}
