pragma Singleton

import QtQuick
import Quickshell

// Pick a colour anywhere on screen (niri's picker), copy it as #rrggbb and show it in a notification.
Singleton {
    function pick(): void {
        Quickshell.execDetached(["sh", "-c", `c=$(niri msg --json pick-color) || exit 0
            h=$(printf %s "$c" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("#%02x%02x%02x" % tuple(round(v*255) for v in d["rgb"]))') || exit 0
            printf %s "$h" | wl-copy
            notify-send -a "Colour Picker" -i color-select "$h" "Copied to the clipboard"`]);
    }
}
