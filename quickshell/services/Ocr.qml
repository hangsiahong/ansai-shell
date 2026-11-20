pragma Singleton

import QtQuick
import Quickshell

// Copy the text in an image (English and Khmer, scripts/ocr.sh) and say so in a notification.
Singleton {
    id: root
    readonly property string script: Quickshell.shellDir + "/scripts/ocr.sh"
    readonly property string copy: `e=$(mktemp); t=$("$0" "$1" 2>"$e"); r=$?
        if [ -n "$t" ]; then printf %s "$t" | wl-copy
            b=$(printf %s "$t" | head -n 5 | sed 's/&/\\&amp;/g; s/</\\&lt;/g; s/>/\\&gt;/g')
            notify-send -a "Copy Text" -i edit-copy "Copied text from the image" "$b"
        elif [ $r -ge 2 ]; then notify-send -a "Copy Text" -i dialog-error "Can't read text" "$(cat "$e")"
        else notify-send -a "Copy Text" -i edit-copy "No text found" "Try a sharper or larger area"; fi
        rm -f "$e"`

    function copyFrom(path: string): void {
        Quickshell.execDetached(["sh", "-c", copy, script, path]);
    }
    // Pick an area of the screen and copy its text.
    function screen(): void {
        Shell.close();
        Quickshell.execDetached(["sh", "-c", `f="\${XDG_RUNTIME_DIR:-/tmp}/ansai-ocr.png"
            g=$(slurp -d -b '#00000066' -c '#0a84ffff' -s '#0a84ff22' -w 2) && grim -g "$g" "$f" || exit 0
            sh -c "$1" "$0" "$f"; rm -f "$f"`, script, copy]);
    }
}
