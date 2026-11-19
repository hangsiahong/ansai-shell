pragma Singleton

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Io
import qs
import qs.components

Singleton {
    id: root

    property bool locked: false
    property string buffer: ""
    property string status: ""   // "", "checking", "fail"
    readonly property string user: Quickshell.env("USER")

    function lock(): void {
        buffer = "";
        status = "";
        locked = true;
    }

    function submit(): void {
        if (pam.active || buffer === "") return;
        status = "checking";
        pam.start();
    }

    PamContext {
        id: pam
        config: "swaylock"
        user: root.user
        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(root.buffer);
        }
        onCompleted: res => {
            if (res === PamResult.Success) {
                root.status = "";
                root.buffer = "";
                root.locked = false;
            } else {
                root.status = "fail";
                root.buffer = "";
                shake.restart();
            }
        }
    }

    property real shakeX: 0
    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeX"; to: -14; duration: 50 }
        NumberAnimation { target: root; property: "shakeX"; to: 12; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: -8; duration: 70 }
        NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 60 }
    }

    WlSessionLock {
        locked: root.locked

        WlSessionLockSurface {
            id: surf
            color: "#000000"

            Wallpaper {
                id: wp
                anchors.fill: parent
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wp
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                brightness: -0.12
                saturation: 0.1
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.14
                spacing: 0
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.longDate
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.85)
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.shortTime
                    font.pixelSize: 112
                    font.weight: Font.Bold
                    font.features: { "tnum": 1 }
                    color: "#ffffff"
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.14
                spacing: 14

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64; height: 64; radius: 32
                    color: Qt.rgba(1, 1, 1, 0.18)
                    Txt {
                        anchors.centerIn: parent
                        text: root.user.charAt(0).toUpperCase()
                        font.pixelSize: 28; font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                }
                Txt {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.user
                    font.pixelSize: 16; font.weight: Font.DemiBold
                    color: "#ffffff"
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.shakeX
                    width: 280; height: 44; radius: 22
                    color: Qt.rgba(1, 1, 1, 0.16)
                    border.width: 1
                    border.color: root.status === "fail" ? Qt.rgba(1, 0.27, 0.23, 0.8) : Qt.rgba(1, 1, 1, 0.14)

                    TextInput {
                        id: pw
                        anchors { left: parent.left; right: go.left; leftMargin: 18; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.letterSpacing: 2
                        focus: true
                        text: root.buffer
                        onTextChanged: { root.buffer = text; if (text) root.status = ""; }
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: root.buffer = ""
                        Component.onCompleted: forceActiveFocus()

                        Txt {
                            anchors.fill: parent
                            visible: !pw.text
                            text: root.status === "fail" ? "Wrong password" : "Enter password"
                            color: root.status === "fail" ? "#ff6961" : Qt.rgba(1, 1, 1, 0.55)
                            font.pixelSize: 15
                        }
                    }
                    Rectangle {
                        id: go
                        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        width: 32; height: 32; radius: 16
                        color: root.buffer ? "#ffffff" : Qt.rgba(1, 1, 1, 0.2)
                        Icon {
                            anchors.centerIn: parent
                            name: root.status === "checking" ? "progress_activity" : "arrow_forward"
                            size: 18
                            color: root.buffer ? "#000000" : "#ffffff"
                            RotationAnimation on rotation { running: root.status === "checking"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.submit() }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function isLocked(): bool { return root.locked; }
    }
}
