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
