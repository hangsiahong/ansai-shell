//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules
import qs.services

ShellRoot {
    Variants {
        model: Quickshell.screens
        Background {}
    }
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        Dock {}
    }

    Launcher {}
    DockMenu {}
    ControlCenter {}
    Calendar {}
    PowerMenu {}
    AppMenu {}
    Toasts {}
    Osd {}

    LazyLoader {
        active: !Shell.nested
        Polkit {}
    }

    Component.onCompleted: {
        Lock.locked; // instantiate the lock singleton so its IPC handler registers
        NiriStyle.text; // writes ~/.config/niri/ansai-style.kdl for window borders
        Quickshell.execDetached(["mkdir", "-p", Settings.dir]);
        Quickshell.execDetached(["rm", "-f", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ansai-shell/locked"]);
    }

    IpcHandler {
        target: "shell"
        function toggle(name: string): void { Shell.toggle(name); }
        function close(): void { Shell.close(); }
        function theme(mode: string): void { Settings.theme = mode; }
        function wallpaper(path: string): void { Settings.wallpaper = path; }
        function testNotify(): void {
            const n = { appName: "ansai", summary: "Agent finished: Rate-limit the /invoices endpoint", body: "billing-api · ready for review. 3 files changed, tests pass.", actions: [{ identifier: "review", text: "Review", invoke() {} }, { identifier: "later", text: "Later", invoke() {} }] };
            Notifs.list = [{ n: n, time: new Date(), popup: true }, ...Notifs.list];
        }
    }
    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.set(Brightness.value + 0.05); }
        function down(): void { Brightness.set(Brightness.value - 0.05); }
    }
    IpcHandler {
        target: "volume"
        function up(): void { Audio.setVolume(Audio.volume + 0.05); }
        function down(): void { Audio.setVolume(Audio.volume - 0.05); }
        function mute(): void { Audio.toggleMute(); }
    }
}
