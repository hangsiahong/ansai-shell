pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Wallpaper path plus a Material 3 tonal scheme seeded from it (Android "dynamic color").
// Tones are CIELAB L*, which is what M3's HCT tone means; chroma is clipped to sRGB.
Singleton {
    id: root

    property string gnomeDark: ""
    property string gnomeLight: ""
    readonly property string wallpaper: Settings.wallpaper || (Settings.theme !== "light" ? gnomeDark : gnomeLight) || gnomeDark
    readonly property string wallpaperUrl: wallpaper ? (wallpaper.startsWith("/") ? "file://" + wallpaper : wallpaper) : ""

    // Hue of the most colourful wallpaper cluster; blue when the wallpaper is grey.
    readonly property real hue: {
        let best = null, score = 0;
        for (const c of q.colors) {
            const l = lab(c.r, c.g, c.b);
            const ch = Math.hypot(l[1], l[2]);
            const s = ch * (l[0] > 15 && l[0] < 92 ? 1 : 0.3);
            if (s > score) { score = s; best = l; }
        }
        return best && score > 12 ? (Math.atan2(best[2], best[1]) * 180 / Math.PI + 360) % 360 : 282;
    }

    function tone(h, c, t, a) {
        const hr = h * Math.PI / 180;
        for (let i = 0; i < 40; i++, c *= 0.9) {
            const rgb = fromLab(t, c * Math.cos(hr), c * Math.sin(hr));
            if (rgb.every(v => v >= -0.001 && v <= 1.001))
                return Qt.rgba(clamp(rgb[0]), clamp(rgb[1]), clamp(rgb[2]), a ?? 1);
        }
        const g = fromLab(t, 0, 0);
        return Qt.rgba(clamp(g[0]), clamp(g[1]), clamp(g[2]), a ?? 1);
    }
    function p(t: real): color { return tone(hue, 44, t); }
    function s(t: real): color { return tone(hue, 16, t); }
    function tr(t: real): color { return tone((hue + 60) % 360, 26, t); }
    function n(t: real): color { return tone(hue, 5, t); }
    function nv(t: real): color { return tone(hue, 10, t); }

    function clamp(v) { return Math.max(0, Math.min(1, v)); }
    function fromLab(L, A, B) {
        const fy = (L + 16) / 116, fx = fy + A / 500, fz = fy - B / 200;
        const inv = t => t > 6 / 29 ? t * t * t : 3 * (6 / 29) ** 2 * (t - 4 / 29);
        const X = 0.95047 * inv(fx), Y = inv(fy), Z = 1.08883 * inv(fz);
        const lin = [3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z,
                     -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z,
                     0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z];
        return lin.map(c => c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(Math.max(c, 0), 1 / 2.4) - 0.055);
    }
    function lab(r, g, b) {
        const [R, G, B] = [r, g, b].map(c => c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4);
        const X = (0.4124564 * R + 0.3575761 * G + 0.1804375 * B) / 0.95047;
        const Y = 0.2126729 * R + 0.7151522 * G + 0.0721750 * B;
        const Z = (0.0193339 * R + 0.1191920 * G + 0.9503041 * B) / 1.08883;
        const f = t => t > (6 / 29) ** 3 ? Math.cbrt(t) : t / (3 * (6 / 29) ** 2) + 4 / 29;
        return [116 * f(Y) - 16, 500 * (f(X) - f(Y)), 200 * (f(Y) - f(Z))];
    }


    ColorQuantizer {
        id: q
        source: root.wallpaperUrl
        depth: 3
        rescaleSize: 64
    }

    // No wallpaper chosen: reuse GNOME's (dark and light), so switching desktops keeps the look.
    Process {
        running: !Settings.wallpaper
        command: ["sh", "-c", "gsettings get org.gnome.desktop.background picture-uri-dark; gsettings get org.gnome.desktop.background picture-uri"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").map(s => s.replace(/^'|'$/g, ""));
                root.gnomeDark = l[0] ?? "";
                root.gnomeLight = l[1] ?? "";
            }
        }
    }
}
