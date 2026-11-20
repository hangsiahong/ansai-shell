#!/usr/bin/env python3
# Installed app icon themes for Settings -> Appearance, one JSON line: [{name, title, icons: [paths]}].
import json, os, glob, configparser
SAMPLES = ["org.gnome.Nautilus", "firefox", "utilities-terminal", "preferences-system", "org.gnome.Calculator"]
roots = [os.path.expanduser("~/.local/share/icons"), os.path.expanduser("~/.icons"), "/usr/share/icons"]
seen, out = set(), []
for r in roots:
    for d in sorted(glob.glob(r + "/*/index.theme")):
        base = os.path.dirname(d); name = os.path.basename(base)
        if name in seen or name in ("hicolor", "default", "locolor") or "cursor" in name.lower(): continue
        cp = configparser.ConfigParser(interpolation=None, strict=False)
        try: cp.read(d, encoding="utf-8")
        except Exception: continue
        if not cp.has_section("Icon Theme") or cp.get("Icon Theme", "Hidden", fallback="false").lower() == "true": continue
        icons = []
        for s in SAMPLES:
            hits = [p for sub in ("scalable/apps", "128x128/apps", "apps/scalable", "apps/128", "64x64/apps", "apps/64", "48x48/apps", "apps/48")
                    for p in glob.glob(f"{base}/{sub}/{s}.*")]
            if hits: icons.append(hits[0])
        if len(icons) < 2: continue
        seen.add(name)
        out.append({"name": name, "title": cp.get("Icon Theme", "Name", fallback=name), "icons": icons[:4]})
print(json.dumps(out))
