"""From ansai (github.com/hangsiahong/ansai, MIT), used by Ask Ansai's desktop_* tools (agent/ansai-agent.mjs).

Drive this machine's Wayland desktop (GNOME or niri) for src/server/desktop.ts.

    python3 -I desktop.py <command> '<json args>'

prints one JSON object: {"ok": true, ...} or {"ok": false, "error": "..."}.
Stateless: each call opens what it needs and closes it again.

- see:   the xdg-desktop-portal screenshot (no prompt for host apps on GNOME), scaled
         to fit FIT so coordinates are image pixels the model saw unscaled.
- read:  the AT-SPI accessibility tree (what screen readers use). Element ids are
         child-index paths ("2.0.1.4") from the desktop root, resolved again on use.
- input: Mutter's RemoteDesktop D-Bus API (no root, no uinput), with a ScreenCast
         stream per monitor so pointer moves can be absolute.

On niri (no RemoteDesktop API): grim for see, `niri msg` for monitors, a wlr
virtual pointer spoken over the Wayland socket for the mouse, and wtype for keys.
ANSAI_DESKTOP_BACKEND=gnome|niri overrides the detection.
"""
import glob
import json
import os
import socket
import struct
import subprocess
import sys
import time

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi, Gio, GLib  # noqa: E402

# Claude scales images above ~1.15 MP or 1568 px down on its side; staying under
# keeps "the pixel you saw" equal to "the pixel you click".
FIT = (1280, 800)
NAME_MAX = 120
TEXT_MAX = 400

bus = Gio.bus_get_sync(Gio.BusType.SESSION)


class Fail(Exception):
    pass


def dbus(dest, path, iface, method, args=None, reply=None, timeout=10000):
    try:
        r = bus.call_sync(dest, path, iface, method, args, GLib.VariantType(reply) if reply else None,
                          Gio.DBusCallFlags.NONE, timeout, None)
        return r.unpack() if r is not None else None
    except GLib.Error as e:
        raise Fail(f"{iface}.{method}: {e.message}")


# ------------------------------------------------------------------- backend

def niri_socket():
    s = os.environ.get("NIRI_SOCKET")
    if s and os.path.exists(s):
        return s
    run = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    for s in sorted(glob.glob(f"{run}/niri.*.sock"), key=os.path.getmtime, reverse=True):
        pid = s.rsplit(".", 2)[-2]
        if pid.isdigit() and os.path.exists(f"/proc/{pid}"):
            return s
    return None


def detect_backend():
    forced = os.environ.get("ANSAI_DESKTOP_BACKEND")
    if forced in ("gnome", "niri"):
        return forced
    try:
        if dbus("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner",
                GLib.Variant("(s)", ("org.gnome.Mutter.RemoteDesktop",)), "(b)")[0]:
            return "gnome"
    except Fail:
        pass
    return "niri" if niri_socket() else "gnome"


BACKEND = detect_backend()


def niri_env():
    """The niri session's addresses: the helper may run from a service started outside it."""
    sock = niri_socket()
    if not sock:
        raise Fail("niri is not running (no niri socket in XDG_RUNTIME_DIR)")
    env = dict(os.environ, NIRI_SOCKET=sock)
    # niri.<wayland-display>.<pid>.sock
    env["WAYLAND_DISPLAY"] = os.path.basename(sock)[len("niri."):].rsplit(".", 2)[0]
    env.setdefault("XDG_RUNTIME_DIR", os.path.dirname(sock))
    return env


def run_tool(cmd, env=None, timeout=15):
    try:
        r = subprocess.run(cmd, env=env or niri_env(), capture_output=True, timeout=timeout)
    except FileNotFoundError:
        raise Fail(f"{cmd[0]} is not installed (sudo pacman -S {cmd[0]})")
    except subprocess.TimeoutExpired:
        raise Fail(f"{cmd[0]} took longer than {timeout}s")
    if r.returncode != 0:
        raise Fail(f"{cmd[0]} failed: {r.stderr.decode(errors='replace').strip()[-300:]}")
    return r.stdout


# ------------------------------------------------------------------ monitors

def niri_monitors():
    outs = json.loads(run_tool(["niri", "msg", "--json", "outputs"]))
    out = []
    for name, o in sorted(outs.items()):
        lg = o.get("logical")
        if not lg:
            continue  # disabled output
        out.append({"connector": name, "x": lg["x"], "y": lg["y"], "w": lg["width"], "h": lg["height"],
                    "scale": lg["scale"], "primary": False})
    if not out:
        raise Fail("no monitors found (is the screen on?)")
    out[0]["primary"] = True
    return out


def monitors():
    """Logical monitors: [{connector, x, y, w, h, scale}] in logical pixels."""
    if BACKEND == "niri":
        return niri_monitors()
    serial, mons, logical, props = dbus("org.gnome.Mutter.DisplayConfig", "/org/gnome/Mutter/DisplayConfig",
                                        "org.gnome.Mutter.DisplayConfig", "GetCurrentState")
    modes = {}
    for (connector, *_), mlist, _p in mons:
        for mode in mlist:
            mid, w, h, _rate, _pref, _scales, mprops = mode
            if mprops.get("is-current"):
                modes[connector] = (w, h)
    layout_logical = props.get("layout-mode", 1) == 1
    out = []
    for x, y, scale, transform, primary, connectors, _ in logical:
        connector = connectors[0][0]
        w, h = modes.get(connector, (0, 0))
        if transform in (1, 3, 5, 7):
            w, h = h, w
        if layout_logical:
            w, h = round(w / scale), round(h / scale)
        out.append({"connector": connector, "x": x, "y": y, "w": w, "h": h, "scale": scale, "primary": bool(primary)})
    if not out:
        raise Fail("no monitors found (is the screen on?)")
    return out


def desktop_box(mons):
    x0 = min(m["x"] for m in mons)
    y0 = min(m["y"] for m in mons)
    x1 = max(m["x"] + m["w"] for m in mons)
    y1 = max(m["y"] + m["h"] for m in mons)
    return x0, y0, x1 - x0, y1 - y0


def fit(w, h):
    k = min(FIT[0] / w, FIT[1] / h, 1.0)
    return max(1, round(w * k)), max(1, round(h * k))


def to_logical(ix, iy):
    """Image pixel (of a full `see`) → logical desktop point."""
    x0, y0, w, h = desktop_box(monitors())
    iw, ih = fit(w, h)
    if not (0 <= ix < iw and 0 <= iy < ih):
        raise Fail(f"({ix}, {iy}) is outside the screenshot ({iw}×{ih})")
    return x0 + (ix + 0.5) * w / iw, y0 + (iy + 0.5) * h / ih


# ---------------------------------------------------------------- screenshot

def portal_screenshot():
    loop = GLib.MainLoop()
    got = {}
    token = f"ansai{os.getpid()}{int(time.time() * 1000) % 100000}"
    sender = bus.get_unique_name()[1:].replace(".", "_")
    handle = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"

    def on_response(_c, _s, _p, _i, _sig, params):
        code, res = params.unpack()
        got["code"], got["uri"] = code, res.get("uri")
        loop.quit()

    sub = bus.signal_subscribe("org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response", handle,
                               None, Gio.DBusSignalFlags.NO_MATCH_RULE, on_response)
    dbus("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop", "org.freedesktop.portal.Screenshot",
         "Screenshot", GLib.Variant("(sa{sv})", ("", {"handle_token": GLib.Variant("s", token),
                                                      "interactive": GLib.Variant("b", False)})))

    def timeout():
        got.setdefault("code", "timeout")
        loop.quit()
        return False

    GLib.timeout_add_seconds(20, timeout)
    loop.run()
    bus.signal_unsubscribe(sub)
    if got.get("code") != 0 or not got.get("uri"):
        raise Fail(f"the screenshot portal said no (response {got.get('code')}); is the screen locked?")
    return GLib.filename_from_uri(got["uri"])[0]


def grim_screenshot(out):
    raw = os.path.splitext(out)[0] + ".raw.png"
    run_tool(["grim", "-t", "png", "-l", "0", raw])
    return raw


def cmd_see(a):
    from PIL import Image

    out = a["out"]
    mons = monitors()
    x0, y0, w, h = desktop_box(mons)
    iw, ih = fit(w, h)
    raw = grim_screenshot(a["out"]) if BACKEND == "niri" else portal_screenshot()
    try:
        im = Image.open(raw).convert("RGB")
        region = a.get("region")
        if region:
            rx, ry, rw, rh = (int(region[k]) for k in ("x", "y", "w", "h"))
            if rw <= 0 or rh <= 0 or rx < 0 or ry < 0 or rx + rw > iw or ry + rh > ih:
                raise Fail(f"region must lie inside the {iw}×{ih} screenshot")
            sx, sy = im.width / iw, im.height / ih
            im = im.crop((round(rx * sx), round(ry * sy), round((rx + rw) * sx), round((ry + rh) * sy)))
            cw, ch = fit(im.width, im.height)
            im = im.resize((cw, ch), Image.LANCZOS) if (cw, ch) != im.size else im
        else:
            im = im.resize((iw, ih), Image.LANCZOS)
        im.save(out, "PNG", optimize=True)
        if os.path.getsize(out) > 900_000:
            out = os.path.splitext(out)[0] + ".jpg"
            im.save(out, "JPEG", quality=88)
    finally:
        os.remove(raw)
    return {"path": out, "width": im.width, "height": im.height, "screen": {"width": iw, "height": ih},
            "region": a.get("region"), "monitors": len(mons), "active": active_window()}


# ------------------------------------------------------------- accessibility

def node_states(n):
    s = n.get_state_set()
    return {k for k, st in (("showing", Atspi.StateType.SHOWING), ("visible", Atspi.StateType.VISIBLE),
                            ("focused", Atspi.StateType.FOCUSED), ("active", Atspi.StateType.ACTIVE),
                            ("checked", Atspi.StateType.CHECKED), ("selected", Atspi.StateType.SELECTED),
                            ("editable", Atspi.StateType.EDITABLE), ("enabled", Atspi.StateType.ENABLED),
                            ("expanded", Atspi.StateType.EXPANDED), ("focusable", Atspi.StateType.FOCUSABLE),
                            ("sensitive", Atspi.StateType.SENSITIVE))
            if s.contains(st)}


def short(t, n):
    t = " ".join((t or "").split())
    return t if len(t) <= n else t[: n - 1] + "…"


# Accessible.get_text() is the old name of get_text_iface(), so call the interfaces' own functions.
def text_of(n, limit=TEXT_MAX + 1):
    try:
        if n.get_text_iface():
            c = Atspi.Text.get_character_count(n)
            return Atspi.Text.get_text(n, 0, min(c, limit)) if c else ""
    except GLib.Error:
        pass
    return None


def apps():
    d = Atspi.get_desktop(0)
    out = []
    for i in range(d.get_child_count()):
        app = d.get_child_at_index(i)
        if not app:
            continue
        try:
            wins = []
            for j in range(app.get_child_count()):
                w = app.get_child_at_index(j)
                if not w:
                    continue
                st = node_states(w)
                if "showing" in st or "active" in st:
                    wins.append({"id": f"{i}.{j}", "title": short(w.get_name(), NAME_MAX), "active": "active" in st})
            if wins:
                out.append({"app": app.get_name() or "?", "id": str(i), "pid": app.get_process_id(), "windows": wins})
        except GLib.Error:
            continue
    return out


def active_window():
    for a in apps():
        for w in a["windows"]:
            if w["active"]:
                return {"app": a["app"], "window": w["title"], "id": w["id"]}
    return None


def resolve(path):
    n = Atspi.get_desktop(0)
    try:
        for part in str(path).split("."):
            n = n.get_child_at_index(int(part))
            if n is None:
                raise Fail(f"element {path} is gone (the window changed); read it again")
    except ValueError:
        raise Fail(f"bad element id {path!r}")
    return n


def actions(n):
    if not n.get_action_iface():
        return []
    try:
        return [Atspi.Action.get_action_name(n, i) for i in range(Atspi.Action.get_n_actions(n))]
    except GLib.Error:
        return []


# GTK 4 puts its context-menu actions on every label; they only mean something on editable text.
MENU_ACTIONS = ("clipboard.", "selection.", "link.", "menu.popup")
SKIP_ROLES = {"filler", "panel", "section", "grouping", "scroll pane", "viewport", "redundant object", "invalid"}


def cmd_read(a):
    root_id = str(a["id"])
    root = resolve(root_id)
    limit = max(10, min(int(a.get("limit", 300)), 1500))
    depth = max(1, min(int(a.get("depth", 40)), 60))
    find = (a.get("find") or "").lower()
    lines, seen, more = [], 0, 0
    # GTK 4 sets neither state on anything, so a missing one only means "disabled" where the window has it.
    tracks_enabled = bool({"enabled", "sensitive"} & node_states(root))

    def walk(n, path, d, indent):
        nonlocal seen, more
        try:
            st = node_states(n)
            if d > 0 and "showing" not in st:
                return
            role = n.get_role_name()
            name = short(n.get_name(), NAME_MAX)
            txt = text_of(n) if role in ("text", "entry", "paragraph", "document text", "terminal", "password text") or "editable" in st else None
            if role == "password text":
                txt = "•••" if txt else txt
            hollow = role in SKIP_ROLES and not name and not actions(n)
            shown = not hollow and (not find or find in name.lower() or find in (txt or "").lower())
            child_indent = indent
            if shown:
                if seen >= limit:
                    more += 1
                    return
                seen += 1
                flags = [f for f in ("focused", "checked", "selected", "expanded") if f in st]
                if tracks_enabled and not {"enabled", "sensitive"} & st and role not in ("label", "text", "paragraph", "static"):
                    flags.append("disabled")
                acts = [x for x in actions(n) if x and ("editable" in st or not x.startswith(MENU_ACTIONS))]
                bits = [f"[{path}]", role]
                if name:
                    bits.append(json.dumps(name, ensure_ascii=False))
                if txt and txt != name:
                    bits.append("text=" + json.dumps(short(txt, TEXT_MAX), ensure_ascii=False))
                if flags:
                    bits.append("(" + ", ".join(flags) + ")")
                if acts:
                    bits.append("{" + ", ".join(acts[:4]) + "}")
                lines.append("  " * (indent if not find else 0) + " ".join(bits))
                child_indent = indent + 1
            if d >= depth:
                return
            for i in range(n.get_child_count()):
                c = n.get_child_at_index(i)
                if c is not None:
                    walk(c, f"{path}.{i}", d + 1, child_indent)
        except GLib.Error:
            return

    walk(root, root_id, 0, 0)
    return {"lines": lines, "more": more, "active": active_window()}


def cmd_apps(a):
    return {"apps": apps(), **cmd_status(a)}


def cmd_act(a):
    n = resolve(a["id"])
    role = n.get_role_name()
    name = short(n.get_name(), NAME_MAX)
    want = a.get("name")
    if want and want.lower() not in (name or "").lower():
        if not name:
            raise Fail(f"[{a['id']}] {role} has no name, so it isn't {want!r}; leave name out for it, or read the window again")
        raise Fail(f"[{a['id']}] is now {role} {json.dumps(name, ensure_ascii=False)}, not {want!r}; read the window again")
    do = a.get("action", "click")
    what = f"[{a['id']}] {role}" + (f" {json.dumps(name, ensure_ascii=False)}" if name else "")
    if do == "focus":
        if not n.get_component_iface() or not Atspi.Component.grab_focus(n):
            raise Fail(f"{what} can't take focus")
        return {"did": f"focused {what}", "active": active_window()}
    if do in ("set_text", "append_text"):
        if not n.get_editable_text_iface():
            raise Fail(f"{what} isn't editable text; click into it and use desktop_input type")
        text = str(a.get("text", ""))
        ok = Atspi.EditableText.set_text_contents(n, text) if do == "set_text" else insert(n, text_len(n), text)
        if not ok:
            raise Fail(f"{what} refused the text")
        return {"did": f"{'set' if do == 'set_text' else 'appended'} the text of {what}", "text": short(text_of(n), TEXT_MAX), "active": active_window()}
    names = actions(n)
    pick = do if do in names else next((x for x in ("click", "press", "activate", "toggle", "jump", "open") if do == "click" and x in names), None)
    if not pick:
        raise Fail(f"{what} has no {do!r} action (it has: {', '.join(names) or 'none'})")
    if not Atspi.Action.do_action(n, names.index(pick)):
        raise Fail(f"{what} refused {pick!r}")
    time.sleep(0.15)
    return {"did": f"{pick} on {what}", "active": active_window()}


def text_len(n):
    return Atspi.Text.get_character_count(n) if n.get_text_iface() else 0


def insert(n, pos, text):
    return Atspi.EditableText.insert_text(n, pos, text, len(text))


def focused_editable():
    """The text field with keyboard focus in the active window, if any."""
    act = active_window()
    if not act:
        return None
    stack, n = [(resolve(act["id"]), True)], 0
    while stack and n < 4000:
        node, root = stack.pop()
        n += 1
        try:
            st = node_states(node)
            if "focused" in st and "editable" in st and node.get_editable_text_iface():
                return node
            if root or "showing" in st:
                stack.extend((c, False) for c in (node.get_child_at_index(i) for i in range(node.get_child_count())) if c)
        except GLib.Error:
            continue
    return None


def unmappable(text):
    """Characters the current keyboard layout has no key for (Mutter can only press keys that exist)."""
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gdk, Gtk

    Gtk.init()
    disp = Gdk.Display.get_default()
    if disp is None:
        return []
    missing = []
    for ch in dict.fromkeys(text):
        if ch in "\n\t" or ch in missing:
            continue
        if not disp.map_keyval(keysym_for_char(ch))[0]:
            missing.append(ch)
    return missing


# --------------------------------------------------------------------- input

RD, SC = "org.gnome.Mutter.RemoteDesktop", "org.gnome.Mutter.ScreenCast"
BUTTONS = {"left": 0x110, "right": 0x111, "middle": 0x112}  # evdev BTN_*
MODS = {"ctrl": "Control_L", "control": "Control_L", "shift": "Shift_L", "alt": "Alt_L", "super": "Super_L", "meta": "Super_L", "win": "Super_L"}
KEYSYMS = {"enter": 0xFF0D, "return": 0xFF0D, "tab": 0xFF09, "escape": 0xFF1B, "esc": 0xFF1B, "backspace": 0xFF08,
           "delete": 0xFFFF, "home": 0xFF50, "end": 0xFF57, "pageup": 0xFF55, "pagedown": 0xFF56, "left": 0xFF51,
           "up": 0xFF52, "right": 0xFF53, "down": 0xFF54, "space": 0x20, "insert": 0xFF63,
           "Control_L": 0xFFE3, "Shift_L": 0xFFE1, "Alt_L": 0xFFE9, "Super_L": 0xFFEB,
           **{f"f{i}": 0xFFBE + i - 1 for i in range(1, 13)}}


class Remote:
    """One RemoteDesktop session (with a ScreenCast stream per monitor while pointing)."""

    def __init__(self, point=False):
        self.path = dbus(RD, "/org/gnome/Mutter/RemoteDesktop", RD, "CreateSession", reply="(o)")[0]
        self.streams = []
        if point:
            sid = self.prop(RD, self.path, RD + ".Session", "SessionId")
            sc = dbus(SC, "/org/gnome/Mutter/ScreenCast", SC, "CreateSession",
                      GLib.Variant("(a{sv})", ({"remote-desktop-session-id": GLib.Variant("s", sid)},)), "(o)")[0]
            for m in monitors():
                sp = dbus(SC, sc, SC + ".Session", "RecordMonitor",
                          GLib.Variant("(sa{sv})", (m["connector"], {"cursor-mode": GLib.Variant("u", 1)})), "(o)")[0]
                self.streams.append((m, sp))
        self.call("Start")

    def prop(self, dest, path, iface, name):
        return dbus(dest, path, "org.freedesktop.DBus.Properties", "Get", GLib.Variant("(ss)", (iface, name)), "(v)")[0]

    def call(self, method, sig=None, *vals):
        dbus(RD, self.path, RD + ".Session", method, GLib.Variant(sig, vals) if sig else None)

    def stop(self):
        try:
            self.call("Stop")
        except Fail:
            pass

    def move(self, x, y):
        for m, sp in self.streams:
            if m["x"] <= x < m["x"] + m["w"] and m["y"] <= y < m["y"] + m["h"]:
                # Mutter divides stream positions by the monitor's scale: they are physical pixels.
                k = m["scale"]
                self.call("NotifyPointerMotionAbsolute", "(sdd)", sp, (x - m["x"]) * k, (y - m["y"]) * k)
                return
        raise Fail(f"({x:.0f}, {y:.0f}) isn't on any monitor")

    def button(self, b, down):
        self.call("NotifyPointerButton", "(ib)", BUTTONS[b], down)

    def keysym(self, k, down):
        self.call("NotifyKeyboardKeysym", "(ub)", k, down)

    def scroll(self, axis, step):
        self.call("NotifyPointerAxisDiscrete", "(ui)", axis, step)


class WlPointer:
    """A wlr virtual pointer, spoken straight over the compositor's Wayland socket (niri has no RemoteDesktop)."""

    def __init__(self):
        env = niri_env()
        path = os.path.join(env["XDG_RUNTIME_DIR"], env["WAYLAND_DISPLAY"])
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(5)
        try:
            self.sock.connect(path)
        except OSError as e:
            raise Fail(f"can't reach the compositor at {path}: {e}")
        self.next_id, self.buf = 2, b""
        self.registry = self.new_id()
        self.send(1, 1, struct.pack("<I", self.registry))  # wl_display.get_registry
        globs = {}
        self.roundtrip(lambda oid, op, body: oid == self.registry and op == 0 and self.on_global(body, globs))
        if "zwlr_virtual_pointer_manager_v1" not in globs:
            raise Fail("the compositor has no virtual pointer (zwlr_virtual_pointer_manager_v1)")
        name, _ver = globs["zwlr_virtual_pointer_manager_v1"]
        mgr = self.bind(name, "zwlr_virtual_pointer_manager_v1", 1)
        self.ptr = self.new_id()
        self.send(mgr, 0, struct.pack("<II", 0, self.ptr))  # create_virtual_pointer(seat=null)
        self.box = desktop_box(monitors())
        self.roundtrip()

    def new_id(self):
        self.next_id += 1
        return self.next_id - 1

    def send(self, oid, op, body=b""):
        self.sock.sendall(struct.pack("<II", oid, ((8 + len(body)) << 16) | op) + body)

    @staticmethod
    def string(s):
        b = s.encode() + b"\0"
        return struct.pack("<I", len(b)) + b + b"\0" * (-len(b) % 4)

    def bind(self, name, iface, ver):
        oid = self.new_id()
        self.send(self.registry, 0, struct.pack("<I", name) + self.string(iface) + struct.pack("<II", ver, oid))
        return oid

    def on_global(self, body, globs):
        name, n = struct.unpack_from("<II", body)
        iface = body[8:8 + n - 1].decode()
        globs[iface] = (name, struct.unpack_from("<I", body, 8 + n + (-n % 4))[0])

    def roundtrip(self, on_event=None):
        cb = self.new_id()
        self.send(1, 0, struct.pack("<I", cb))  # wl_display.sync
        while True:
            while len(self.buf) < 8 or len(self.buf) < (struct.unpack_from("<I", self.buf, 4)[0] >> 16):
                chunk = self.sock.recv(65536)
                if not chunk:
                    raise Fail("the compositor closed the connection")
                self.buf += chunk
            oid, so = struct.unpack_from("<II", self.buf)
            size, op = so >> 16, so & 0xFFFF
            body, self.buf = self.buf[8:size], self.buf[size:]
            if oid == 1 and op == 0:  # wl_display.error
                _obj, code, n = struct.unpack_from("<III", body)
                raise Fail(f"compositor error {code}: {body[12:12 + n - 1].decode(errors='replace')}")
            if oid == cb:
                return
            if on_event:
                on_event(oid, op, body)

    @staticmethod
    def now():
        return int(time.monotonic() * 1000) & 0xFFFFFFFF

    def move(self, x, y):
        x0, y0, w, h = self.box
        if not (x0 <= x < x0 + w and y0 <= y < y0 + h):
            raise Fail(f"({x:.0f}, {y:.0f}) isn't on any monitor")
        k = 16  # sub-pixel precision
        self.send(self.ptr, 1, struct.pack("<IIIII", self.now(), round((x - x0) * k), round((y - y0) * k), w * k, h * k))
        self.send(self.ptr, 4)  # frame
        self.roundtrip()

    def button(self, b, down):
        self.send(self.ptr, 2, struct.pack("<III", self.now(), BUTTONS[b], 1 if down else 0))
        self.send(self.ptr, 4)
        self.roundtrip()

    def scroll(self, axis, step):
        self.send(self.ptr, 5, struct.pack("<I", 0))  # axis_source wheel
        self.send(self.ptr, 7, struct.pack("<IIii", self.now(), axis, 15 * 256 * step, step))  # axis_discrete
        self.send(self.ptr, 4)
        self.roundtrip()

    def stop(self):
        try:
            self.send(self.ptr, 8)  # destroy
            self.roundtrip()
        except (Fail, OSError):
            pass
        self.sock.close()


WTYPE_KEYS = {"enter": "Return", "return": "Return", "tab": "Tab", "escape": "Escape", "esc": "Escape",
              "backspace": "BackSpace", "delete": "Delete", "home": "Home", "end": "End", "pageup": "Prior",
              "pagedown": "Next", "left": "Left", "up": "Up", "right": "Right", "down": "Down", "space": "space",
              "insert": "Insert", **{f"f{i}": f"F{i}" for i in range(1, 13)}}
WTYPE_MODS = {"ctrl": "ctrl", "control": "ctrl", "shift": "shift", "alt": "alt", "super": "logo", "meta": "logo", "win": "logo"}


def wtype(args):
    if locked():
        raise Fail(LOCKED_MSG)
    run_tool(["wtype", *args], timeout=60)
    time.sleep(0.2)


def keysym_for_char(ch):
    if ch == "\n":
        return KEYSYMS["return"]
    if ch == "\t":
        return KEYSYMS["tab"]
    cp = ord(ch)
    if 0x20 <= cp <= 0x7E or 0xA0 <= cp <= 0xFF:
        return cp
    return 0x01000000 | cp


def keysym_for_name(name):
    k = KEYSYMS.get(name) or KEYSYMS.get(name.lower())
    if k:
        return k
    if len(name) == 1:
        return keysym_for_char(name.lower())
    raise Fail(f"unknown key {name!r} (use names like enter, tab, escape, f5, left, or a single character)")


def locked():
    """Whether seat0 shows the lock screen (logind's LockedHint, which GNOME keeps up to date)."""
    if BACKEND == "niri":
        # niri doesn't set LockedHint; ansai-shell's lock screen keeps this file while it is up.
        run = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
        return os.path.exists(f"{run}/ansai-shell/locked")
    try:
        sysbus = Gio.bus_get_sync(Gio.BusType.SYSTEM)

        def prop(path, iface, name):
            return sysbus.call_sync("org.freedesktop.login1", path, "org.freedesktop.DBus.Properties", "Get",
                                    GLib.Variant("(ss)", (iface, name)), GLib.VariantType("(v)"),
                                    Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]
        _sid, session = prop("/org/freedesktop/login1/seat/seat0", "org.freedesktop.login1.Seat", "ActiveSession")
        return session not in ("", "/") and bool(prop(session, "org.freedesktop.login1.Session", "LockedHint"))
    except GLib.Error:
        return False  # no logind to ask (not systemd): nothing to go on, so don't block


LOCKED_MSG = ("the screen is locked, so clicks and keys would land in the unlock prompt. "
              "Ask the user to unlock it; desktop_read, desktop_act and desktop_see still work")


def run_input(a, point, body):
    if locked():
        raise Fail(LOCKED_MSG)
    r = WlPointer() if BACKEND == "niri" else Remote(point=point)
    try:
        time.sleep(0.05)
        did = body(r)
    finally:
        time.sleep(0.05)
        r.stop()
    time.sleep(0.2)
    return {"did": did, "active": active_window()}


def cmd_click(a):
    x, y = to_logical(float(a["x"]), float(a["y"]))
    b = a.get("button", "left")
    if b not in BUTTONS:
        raise Fail("button is left, right or middle")
    clicks = int(a.get("clicks", 1))

    def body(r):
        r.move(x, y)
        time.sleep(0.08)
        for i in range(clicks):
            r.button(b, True)
            time.sleep(0.03)
            r.button(b, False)
            time.sleep(0.06)
        return f"{'moved to' if clicks == 0 else ('double-' if clicks == 2 else '') + b + ' click at'} ({a['x']}, {a['y']})"

    return run_input(a, True, body)


def cmd_drag(a):
    x0, y0 = to_logical(float(a["x"]), float(a["y"]))
    x1, y1 = to_logical(float(a["to_x"]), float(a["to_y"]))

    def body(r):
        r.move(x0, y0)
        time.sleep(0.08)
        r.button("left", True)
        for i in range(1, 11):
            r.move(x0 + (x1 - x0) * i / 10, y0 + (y1 - y0) * i / 10)
            time.sleep(0.02)
        r.button("left", False)
        return f"dragged ({a['x']}, {a['y']}) → ({a['to_x']}, {a['to_y']})"

    return run_input(a, True, body)


def cmd_scroll(a):
    x, y = to_logical(float(a["x"]), float(a["y"]))
    dy, dx = int(a.get("down", 0)), int(a.get("right", 0))

    def body(r):
        r.move(x, y)
        time.sleep(0.05)
        for axis, n in ((0, dy), (1, dx)):
            for _ in range(abs(n)):
                r.scroll(axis, 1 if n > 0 else -1)
                time.sleep(0.02)
        return f"scrolled {dy} down, {dx} right at ({a['x']}, {a['y']})"

    return run_input(a, True, body)


def cmd_type(a):
    text = str(a["text"])
    if len(text) > 2000:
        raise Fail("type at most 2000 characters at a time")
    if BACKEND == "niri":
        # wtype uploads a keymap holding whatever characters it needs, so any script types as keys.
        wtype(["-d", "8", "--", text])
        return {"did": f"typed {len(text)} characters", "active": active_window()}
    missing = unmappable(text)
    if missing:
        # No key makes these (e.g. Khmer on a US layout): put the text in at the focused field's caret instead.
        n = focused_editable()
        shown = "".join(missing[:12])
        if n is None:
            raise Fail(f"the keyboard layout has no keys for {shown!r} and no text field has focus; "
                       "click into the field first, or use desktop_act with set_text")
        if not insert(n, Atspi.Text.get_caret_offset(n), text):
            raise Fail(f"the focused field refused the text (no keys for {shown!r} on this layout)")
        name = short(n.get_name(), NAME_MAX)
        return {"did": f"inserted {len(text)} characters at the caret of {n.get_role_name()} {json.dumps(name, ensure_ascii=False)} "
                       f"(not as key presses: the layout has no keys for {shown!r}, so Enter in the text adds a line instead of sending)",
                "active": active_window()}

    def body(r):
        for ch in text:
            k = keysym_for_char(ch)
            r.keysym(k, True)
            r.keysym(k, False)
            time.sleep(0.008)
        return f"typed {len(text)} characters"

    return run_input(a, False, body)


def cmd_key(a):
    combo = [p.strip() for p in str(a["keys"]).replace(" ", "").split("+") if p.strip()]
    if not combo:
        raise Fail("keys looks like ctrl+l, enter, alt+tab or shift+f10")
    mods = [keysym_for_name(MODS[p.lower()]) for p in combo[:-1] if p.lower() in MODS]
    if len(mods) != len(combo) - 1:
        raise Fail(f"only the last of {a['keys']!r} can be a non-modifier key (modifiers: ctrl, shift, alt, super)")
    key = keysym_for_name(MODS.get(combo[-1].lower(), combo[-1]))
    times = max(1, min(int(a.get("times", 1)), 50))
    if BACKEND == "niri":
        mods_w = [WTYPE_MODS[p.lower()] for p in combo[:-1]]
        last = combo[-1].lower()
        if last in WTYPE_MODS:
            press = ["-M", WTYPE_MODS[last], "-m", WTYPE_MODS[last]]
        elif last in WTYPE_KEYS:
            press = ["-k", WTYPE_KEYS[last]]
        elif len(combo[-1]) == 1:
            press = ["-k", "minus"] if combo[-1] == "-" else [combo[-1].lower()]
        else:
            raise Fail(f"unknown key {combo[-1]!r} (use names like enter, tab, escape, f5, left, or a single character)")
        args = [x for m in mods_w for x in ("-M", m)] + press * times + [x for m in reversed(mods_w) for x in ("-m", m)]
        wtype(args)
        return {"did": f"pressed {a['keys']}" + (f" ×{times}" if times > 1 else ""), "active": active_window()}

    def body(r):
        for m in mods:
            r.keysym(m, True)
        for _ in range(times):
            r.keysym(key, True)
            time.sleep(0.02)
            r.keysym(key, False)
            time.sleep(0.03)
        for m in reversed(mods):
            r.keysym(m, False)
        return f"pressed {a['keys']}" + (f" ×{times}" if times > 1 else "")

    return run_input(a, False, body)


def cmd_status(_a):
    mons = monitors()
    x0, y0, w, h = desktop_box(mons)
    return {"monitors": mons, "screen": dict(zip(("width", "height"), fit(w, h))), "active": active_window(),
            "backend": BACKEND}


COMMANDS = {"see": cmd_see, "apps": cmd_apps, "read": cmd_read, "act": cmd_act, "click": cmd_click, "drag": cmd_drag,
            "scroll": cmd_scroll, "type": cmd_type, "key": cmd_key, "status": cmd_status}


def main():
    try:
        cmd = COMMANDS.get(sys.argv[1] if len(sys.argv) > 1 else "")
        if not cmd:
            raise Fail(f"unknown command; one of {', '.join(COMMANDS)}")
        out = {"ok": True, **cmd(json.loads(sys.argv[2]) if len(sys.argv) > 2 else {})}
    except Fail as e:
        out = {"ok": False, "error": str(e)}
    except (KeyError, TypeError, ValueError) as e:
        out = {"ok": False, "error": f"bad arguments: {e}"}
    except GLib.Error as e:
        out = {"ok": False, "error": e.message}
    sys.stdout.write(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
