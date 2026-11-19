# ansai-shell

A light Wayland desktop styled like the ansai web app (iOS-style dark/light tokens, glass panels, Inter).

- **Compositor:** [niri](https://github.com/YaLTeR/niri) (Rust, scrollable tiling, blur) — `niri/config.kdl`
- **Shell:** [Quickshell](https://quickshell.org) (QML) — `quickshell/`, runs as `qs -c ansai`

## Install

```sh
sudo pacman -S --needed niri xwayland-satellite quickshell brightnessctl playerctl swayidle cliphist fuzzel wlsunset
./install.sh
```

Log out, choose **Niri** in the login screen's session menu. Your old desktop stays available there.

## Keys

| Key | Action |
| --- | --- |
| Super+Space | Search apps/windows (`>cmd` runs in terminal, `=1+2` calculates) |
| Super+A | Control center |
| Super+N | Calendar + notifications |
| Super+Esc | Power menu |
| Super+L | Lock |
| Super+Return | Terminal |
| Super+E / Super+B | Files / browser |
| Super+Shift+V | Clipboard history |
| Super+O | Overview |
| Super+Backspace | Close window (Caps Lock works as Super) |
| Super+Shift+/ | All shortcuts |

## Settings

`~/.config/ansai-shell/settings.json` (theme, wallpaper, terminal, use24h, …) — edits apply live.

```sh
qs -c ansai ipc call shell theme light
qs -c ansai ipc call shell wallpaper ~/Pictures/wall.jpg
```

## System theme

The shell themes apps to match (`quickshell/services/SystemTheme.qml`), live on every style/theme/wallpaper change:
GTK4/libadwaita and GTK3 (`~/.config/gtk-{3,4}.0/gtk.css`, adw-gtk3), dark/light, accent and UI font via gsettings
(browsers and Qt follow), and Ghostty (`theme = light:ansai-light,dark:ansai-dark`).
Already-open GTK apps pick up new colours when reopened. The first run backs up what it replaced to
`~/.config/ansai-shell/system-theme-backup/`; to undo, set `"systemTheme": false` in settings.json and run `restore.sh` there.
