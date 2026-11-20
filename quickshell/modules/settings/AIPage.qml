import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

ColumnLayout {
    id: page
    spacing: 22
    property string test: ""      // result of the Test button
    property bool testing: false
    Component.onCompleted: { AI.checkKey(); AI.refreshMcp(); }

    SGroup {
        title: "KOOMPI AI Gateway"
        note: "The key is stored only on this computer, readable by you alone (" + AI.keyFile.replace(Quickshell.env("HOME"), "~") + "). Create one in KConsole → AI Gateway."
        SRow {
            first: true
            icon: AI.hasKey ? "key" : "key_off"
            title: AI.hasKey ? "Key saved" : "No key yet"
            sub: page.testing ? "Testing…" : page.test || (AI.hasKey ? "Paste a new key below to replace it" : "Paste your kpi_… key below")
            Btn {
                visible: AI.hasKey
                text: "Test"
                onClicked: {
                    page.testing = true;
                    page.test = "";
                    AI.task("Reply with exactly: OK", "ping", (full, err) => {
                        page.testing = false;
                        page.test = err ? "✕ " + err : "✓ Connected · " + Settings.aiModel + " answered";
                    });
                }
            }
        }
        SRow {
            icon: "password"
            title: ""
            Rectangle {
                width: 330
                height: Theme.m3 ? 40 : 30
                radius: Theme.m3 ? 20 : 8
                color: Theme.m3 ? Theme.surface3 : Theme.fill2
                TextInput {
                    id: keyIn
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    clip: true
                    onAccepted: save.clicked(null)
                    Txt { visible: !keyIn.text; anchors.verticalCenter: parent.verticalCenter; text: "kpi_…"; color: Theme.faint; font.pixelSize: 13 }
                }
            }
            Btn {
                id: save
                text: "Save"
                kind: "filled"
                opacity: keyIn.text.trim() ? 1 : 0.4
                onClicked: {
                    if (!keyIn.text.trim()) return;
                    AI.setKey(keyIn.text);
                    keyIn.text = "";
                    page.test = "";
                }
            }
        }
    }

    SGroup {
        title: "Connectors (MCP)"
        note: "Ask Ansai can already work on this computer (files, commands, apps, windows). Connected services add their own tools. Anything that changes something asks you first. Sign-in happens in your browser; tokens stay on this computer."
        SRow {
            first: true
            icon: Settings.aiAllowAll ? "lock_open" : "verified_user"
            title: "Ask before actions"
            sub: Settings.aiAllowAll ? "Off: Ask Ansai runs commands, edits files and does connector actions (deploy, delete) without asking"
                                     : "Commands, file changes and connector actions wait for Allow; looking things up never asks"
            Switch { checked: !Settings.aiAllowAll; onToggled: Settings.aiAllowAll = !Settings.aiAllowAll }
        }
        Repeater {
            model: AI.mcpServers
            SRow {
                id: cr
                required property var modelData
                required property int index
                readonly property var st: AI.mcp[modelData.url] ?? {}
                icon: modelData.url.includes("koompi") ? "cloud" : "hub"
                title: modelData.name
                sub: st.waiting ? "Finish signing in in your browser…" : st.busy ? "Working…"
                   : st.e ? st.e : st.connected ? "Connected · " + (st.tools ?? 0) + " tools · " + modelData.url.replace("https://", "")
                   : modelData.url.replace("https://", "")
                Switch {
                    visible: !!cr.st.connected
                    anchors.verticalCenter: parent.verticalCenter
                    checked: cr.modelData.on
                    onToggled: page.setServer(cr.index, { on: !cr.modelData.on })
                }
                Btn {
                    text: cr.st.connected ? "Disconnect" : cr.st.waiting ? "Waiting…" : "Connect"
                    kind: cr.st.connected ? "tonal" : "filled"
                    opacity: cr.st.busy && !cr.st.waiting ? 0.5 : 1
                    onClicked: if (!cr.st.busy) cr.st.connected ? AI.disconnect(cr.modelData.url) : AI.connect(cr.modelData.url)
                }
                IconButton {
                    visible: !cr.st.connected && cr.index > 0
                    icon: "close"; iconSize: 18; iconColor: Theme.danger
                    onClicked: Settings.mcpServers = AI.mcpServers.filter((_, i) => i !== cr.index)
                }
            }
        }
        SRow {
            icon: "add_link"
            title: ""
            Rectangle {
                width: 330
                height: Theme.m3 ? 40 : 30
                radius: Theme.m3 ? 20 : 8
                color: Theme.m3 ? Theme.surface3 : Theme.fill2
                TextInput {
                    id: urlIn
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                    clip: true
                    onAccepted: addBtn.clicked(null)
                    Txt { visible: !urlIn.text; anchors.verticalCenter: parent.verticalCenter; text: "https://… MCP server URL"; color: Theme.faint; font.pixelSize: 13 }
                }
            }
            Btn {
                id: addBtn
                text: "Add"
                opacity: /^https?:\/\/\S+$/.test(urlIn.text.trim()) ? 1 : 0.4
                onClicked: {
                    const u = urlIn.text.trim().replace(/\/+$/, "");
                    if (!/^https?:\/\/\S+$/.test(u) || AI.mcpServers.some(s => s.url === u)) return;
                    Settings.mcpServers = [...AI.mcpServers, { name: u.replace(/^https?:\/\//, "").split("/")[0], url: u, on: true }];
                    urlIn.text = "";
                    AI.refreshMcp();
                }
            }
        }
    }

    SGroup {
        title: "Learning"
        note: "After a task that took many steps or hit a snag, Ask Ansai writes down one short lesson and follows it next time. Lessons stay on this computer (" + AI.dataDir.replace(Quickshell.env("HOME"), "~") + "/ai-lessons.md); delete any that are wrong."
        SRow {
            first: true
            icon: "school"
            title: "Learn from mistakes"
            sub: Settings.aiLearn ? AI.lessons.length + (AI.lessons.length === 1 ? " lesson" : " lessons") + " so far" : "Off: no new lessons, and saved ones aren't used"
            Switch { checked: Settings.aiLearn; onToggled: Settings.aiLearn = !Settings.aiLearn }
        }
        Repeater {
            model: AI.lessons
            SRow {
                id: lr
                required property string modelData
                required property int index
                icon: "lightbulb"
                title: ""
                sub: modelData
                IconButton {
                    icon: "delete"; iconSize: 18; iconColor: Theme.danger
                    onClicked: AI.setLessons(AI.lessons.filter((_, i) => i !== lr.index))
                }
            }
        }
    }

    function setServer(i, v) {
        const l = AI.mcpServers.map(s => Object.assign({}, s));
        Object.assign(l[i], v);
        Settings.mcpServers = l;
    }

    SGroup {
        title: "Model"
        note: "koompi-luna (Mekong) understands Khmer and reads screenshots. Any other gateway model works too: set \"aiModel\" in ~/.config/ansai-shell/settings.json."
        SRow {
            first: true
            icon: "neurology"
            title: "Model"
            sub: Settings.aiModel
            below: Chips {
                model: AI.models.map(m => ({ v: m, l: m.replace("koompi-", "") }))
                value: Settings.aiModel
                onPicked: v => { Settings.aiModel = v; page.test = ""; }
            }
        }
        SRow {
            icon: "translate"
            title: "Translate between English and"
            sub: "Used by Translate in the clipboard panel"
            below: Chips {
                model: ["Khmer", "Thai", "Vietnamese", "Lao", "Chinese", "Japanese", "Korean", "French"].map(l => ({ v: l, l: l }))
                value: Settings.aiLang
                onPicked: v => Settings.aiLang = v
            }
        }
    }

    SGroup {
        title: "Where to find it"
        SRow { first: true; icon: "auto_awesome"; title: "Ask Ansai sidebar"; sub: "Super+I or Alt+A, or the ✦ button in Control Center" }
        SRow { icon: "screenshot_region"; title: "Ask about part of the screen"; sub: "Super+Shift+S or Alt+Shift+S: pick an area, then ask about it" }
        SRow { icon: "content_paste"; title: "Clipboard"; sub: "Super+Shift+C, then Ctrl+T translate · Ctrl+S summarize · Ctrl+E fix writing · Ctrl+J ask · Tab: describe what you copied and let AI find it" }
    }
}
