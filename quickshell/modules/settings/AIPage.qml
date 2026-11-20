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
    property bool adding: false   // provider list open
    property string prov: AI.provider    // provider whose models the Model group lists ("" = KOOMPI)
    property string filter: ""
    property bool allLessons: false
    Component.onCompleted: { AI.checkKey(); AI.refreshMcp(); AI.refreshAccounts(); }
    Component.onDestruction: if (AI.signin && AI.signin.step !== "busy" && AI.signin.step !== "url" && AI.signin.step !== "code") AI.cancelSignIn()

    function when(ms) { return Qt.formatTime(new Date(ms), Settings.use24h ? "HH:mm" : "h:mm AP") + (new Date(ms).toDateString() === new Date().toDateString() ? "" : " " + Qt.formatDate(new Date(ms), "ddd")); }
    function acctStatus(a) {
        if (a.error) return a.error;
        if (a.limitedUntil > Time.now) return "Hit its limit · resting until " + when(a.limitedUntil);
        return (a.type === "oauth" ? "Subscription sign-in" : "API key") + (a.lastUsed ? " · last used " + when(a.lastUsed) : "");
    }
    // Providers to offer: subscriptions first, then API-key services, by name.
    readonly property var offer: AI.providers.slice().sort((a, b) => ((b.id === "openai-codex") - (a.id === "openai-codex")) || (!!b.oauth?.sub - !!a.oauth?.sub) || a.name.localeCompare(b.name))

    SGroup {
        title: "Accounts"
        note: "Sign in with a subscription (ChatGPT, Claude, Copilot…) or an API key. Add several accounts of the same service: when one hits its limit, Ask Ansai moves on to the next. Tokens stay on this computer (" + Settings.dir.replace(Quickshell.env("HOME"), "~") + "/ai-accounts.json), readable by you alone."
        Repeater {
            model: AI.accounts
            SRow {
                id: ar
                required property var modelData
                required property int index
                first: index === 0
                icon: modelData.error ? "warning" : modelData.limitedUntil > Time.now ? "hourglass_empty" : modelData.type === "oauth" ? "account_circle" : "key"
                title: modelData.label
                sub: AI.providerName(modelData.provider) + " · " + page.acctStatus(modelData)
                Btn {
                    visible: !!ar.modelData.error
                    text: "Sign in again"
                    onClicked: { AI.signOut(ar.modelData.id); AI.signIn(ar.modelData.provider, ar.modelData.type === "oauth" ? "oauth" : "api_key"); }
                }
                IconButton {
                    icon: "logout"; iconSize: 18; iconColor: Theme.danger
                    onClicked: {
                        if (Settings.aiAccount === ar.modelData.id) Settings.aiAccount = "auto";
                        AI.signOut(ar.modelData.id);
                    }
                }
            }
        }
        // Sign-in in progress
        SRow {
            visible: !!AI.signin
            first: !AI.accounts.length
            icon: AI.signin?.step === "done" ? "check_circle" : AI.signin?.step === "error" ? "error" : "login"
            title: AI.providerName(AI.signin?.provider ?? "")
            sub: AI.signin?.step === "url" ? "Finish signing in in the browser page that opened"
               : AI.signin?.step === "code" ? "Enter the code below on the page that opened"
               : AI.signin?.prompt && AI.signin?.step === "prompt" ? AI.signin.prompt.message
               : (AI.signin?.msg ?? "")
            Btn {
                visible: !!AI.signin?.url && (AI.signin?.step === "url" || AI.signin?.step === "code")
                text: "Open page"
                onClicked: Qt.openUrlExternally(AI.signin.url)
            }
            Btn {
                text: AI.signin?.step === "done" || AI.signin?.step === "error" ? "Done" : "Cancel"
                onClicked: AI.cancelSignIn()
            }
            below: Column {
                width: parent.width
                spacing: 8
                Txt {
                    visible: AI.signin?.step === "code"
                    text: AI.signin?.code ?? ""
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    font.letterSpacing: 3
                    font.features: { "tnum": 1 }
                }
                Chips {
                    visible: AI.signin?.step === "prompt" && AI.signin?.prompt?.type === "select"
                    model: (AI.signin?.prompt?.options ?? []).map(o => ({ v: o.id, l: o.label }))
                    onPicked: v => AI.answerSignIn(v)
                }
                Row {
                    // Free-text answers: an API key, or (browser flows) the redirect URL pasted when the page can't reach this computer.
                    visible: !!AI.signin?.prompt && AI.signin.prompt.type !== "select" && (AI.signin.step === "prompt" || AI.signin.step === "url")
                    spacing: 8
                    Field {
                        id: answer
                        width: 330
                        secret: AI.signin?.prompt?.type === "secret"
                        placeholder: AI.signin?.step === "url" ? "Or paste the address the browser ended on" : (AI.signin?.prompt?.placeholder || "")
                        onAccepted: sendAnswer.clicked(null)
                    }
                    Btn {
                        id: sendAnswer
                        text: "Continue"
                        kind: "filled"
                        opacity: answer.text.trim() ? 1 : 0.4
                        onClicked: { if (!answer.text.trim()) return; AI.answerSignIn(answer.text.trim()); answer.text = ""; }
                    }
                }
            }
        }
        SRow {
            first: !AI.accounts.length && !AI.signin
            icon: "add"
            title: "Add account"
            sub: page.adding ? "Pick a service" : "ChatGPT, Claude, GitHub Copilot, Gemini, Grok, OpenRouter, DeepSeek…"
            clickable: true
            onClicked: page.adding = !page.adding
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "expand_more"; size: 16; color: Theme.muted
                rotation: page.adding ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.med } }
            }
            below: Column {
                visible: page.adding
                width: parent.width
                spacing: 2
                Repeater {
                    model: page.adding ? page.offer : []
                    Item {
                        id: pv
                        required property var modelData
                        width: parent.width
                        height: 40
                        Column {
                            anchors { left: parent.left; leftMargin: 8; right: btns.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            Txt { width: parent.width; text: pv.modelData.name; font.pixelSize: 13 }
                            Txt {
                                width: parent.width
                                text: pv.modelData.oauth ? (pv.modelData.oauth.label || pv.modelData.oauth.name) : pv.modelData.key
                                font.pixelSize: 11; color: Theme.muted
                            }
                        }
                        Row {
                            id: btns
                            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                            spacing: 6
                            Btn {
                                visible: !!pv.modelData.oauth
                                text: "Sign in"
                                kind: "filled"
                                onClicked: { page.adding = false; AI.signIn(pv.modelData.id, "oauth"); }
                            }
                            Btn {
                                visible: !!pv.modelData.key
                                text: "API key"
                                onClicked: { page.adding = false; AI.signIn(pv.modelData.id, "api_key"); }
                            }
                        }
                    }
                }
            }
        }
    }

    SGroup {
        title: "KOOMPI AI Gateway"
        note: "The key is stored only on this computer, readable by you alone (" + AI.keyFile.replace(Quickshell.env("HOME"), "~") + "). Create one in KConsole → AI Gateway."
        SRow {
            first: true
            icon: AI.hasKey ? "key" : "key_off"
            title: AI.hasKey ? "Key saved" : "No key yet"
            sub: (AI.hasKey ? "Paste a new key below to replace it" : "Paste your kpi_… key below")
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
        Repeater {   // newest first; only the latest 3 until "Show all"
            model: AI.lessons.map((l, i) => ({ l: l, i: i })).reverse().slice(0, page.allLessons ? undefined : 3)
            SRow {
                id: lr
                required property var modelData
                icon: "lightbulb"
                title: ""
                sub: modelData.l
                IconButton {
                    icon: "delete"; iconSize: 18; iconColor: Theme.danger
                    onClicked: AI.setLessons(AI.lessons.filter((_, i) => i !== lr.modelData.i))
                }
            }
        }
        SRow {
            visible: AI.lessons.length > 3
            clickable: true
            icon: page.allLessons ? "expand_less" : "expand_more"
            title: page.allLessons ? "Show fewer" : `Show all ${AI.lessons.length} lessons`
            onClicked: page.allLessons = !page.allLessons
        }
    }

    function setServer(i, v) {
        const l = AI.mcpServers.map(s => Object.assign({}, s));
        Object.assign(l[i], v);
        Settings.mcpServers = l;
    }

    SGroup {
        title: "Model"
        note: page.prov ? "Signed-in accounts of " + AI.providerName(page.prov) + " answer in turn." : "koompi-luna (Mekong) understands Khmer and reads screenshots. Any other gateway model works too: set \"aiModel\" in ~/.config/ansai-shell/settings.json."
        SRow {
            first: true
            icon: "neurology"
            title: "Model"
            sub: AI.modelLabel + " · " + AI.providerName(AI.provider)
            below: Column {
                width: parent.width
                spacing: 10
                Chips {
                    visible: model.length > 1
                    model: [{ v: "", l: "KOOMPI" }].concat([...new Set(AI.accounts.map(a => a.provider))].map(p => ({ v: p, l: AI.providerName(p) })))
                    value: page.prov
                    onPicked: v => { page.prov = v; page.filter = ""; }
                }
                Field {
                    id: mf
                    visible: (AI.catalogModels[page.prov] ?? []).length > 16
                    width: 260
                    placeholder: "Search " + (AI.catalogModels[page.prov] ?? []).length + " models"
                    onTextChanged: page.filter = text.trim().toLowerCase()
                }
                Chips {
                    readonly property var all: page.prov ? (AI.catalogModels[page.prov] ?? []).map(m => ({ v: page.prov + "/" + m.id, l: m.id })) : AI.models.map(m => ({ v: m, l: m.replace("koompi-", "") }))
                    model: all.filter(m => !page.filter || m.l.toLowerCase().includes(page.filter)).slice(0, 40)
                    value: Settings.aiModel
                    onPicked: v => { Settings.aiModel = v; page.test = ""; }
                }
            }
        }
        SRow {
            id: acr
            readonly property var mine: AI.accounts.filter(a => a.provider === AI.provider)
            visible: mine.length > 1
            icon: "sync"
            title: "Account"
            sub: Settings.aiAccount === "auto" || !mine.some(a => a.id === Settings.aiAccount) ? "Automatic: the next account takes over when one hits its limit" : "Always this account"
            below: Chips {
                model: [{ v: "auto", l: "Automatic" }].concat(acr.mine.map(a => ({ v: a.id, l: a.label })))
                value: acr.mine.some(a => a.id === Settings.aiAccount) ? Settings.aiAccount : "auto"
                onPicked: v => Settings.aiAccount = v
            }
        }
        SRow {
            visible: AI.ready
            icon: "check_circle"
            title: "Test"
            sub: page.testing ? "Testing…" : page.test || "Send a short message to the chosen model"
            Btn {
                text: "Test"
                onClicked: {
                    page.testing = true;
                    page.test = "";
                    AI.task("Reply with exactly: OK", "ping", (full, err) => {
                        page.testing = false;
                        page.test = err ? "✕ " + err : "✓ " + AI.modelLabel + " answered" + (AI.provider && AI.via ? " · " + AI.via.label : "");
                    });
                }
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
