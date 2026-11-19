#!/usr/bin/env python3
# KOOMPI AI Gateway client for services/AI.qml. Reads {"model", "messages"} JSON on stdin, where a
# message may carry "image": "/path.png" (sent as a data URL). Streams one JSON line per event to
# stdout: {"d": text} for each piece of the reply, {"e": message} on failure. The key is read from
# ~/.config/ansai-shell/ai-key (or $ANSAI_AI_KEY) and never printed.
import base64, json, mimetypes, os, sys, urllib.error, urllib.request

BASE = os.environ.get("ANSAI_AI_BASE", "https://ai.koompi.cloud/v1")
cfg = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
KEY_FILE = os.path.join(cfg, "ansai-shell", "ai-key")


def out(**kv):
    sys.stdout.write(json.dumps(kv, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def content(m):
    img = m.get("image")
    if not img:
        return m.get("content", "")
    mime = mimetypes.guess_type(img)[0] or "image/png"
    with open(img, "rb") as f:
        url = f"data:{mime};base64,{base64.b64encode(f.read()).decode()}"
    return [{"type": "text", "text": m.get("content") or "Describe this image."},
            {"type": "image_url", "image_url": {"url": url}}]


def main():
    key = os.environ.get("ANSAI_AI_KEY", "").strip()
    if not key:
        try:
            key = open(KEY_FILE).read().strip()
        except OSError:
            return out(e=f"No AI key. Paste one in Settings → AI (saved to {KEY_FILE}).")
    req = json.load(sys.stdin)
    try:
        msgs = [{"role": m["role"], "content": content(m)} for m in req["messages"]]
    except OSError as err:
        return out(e=f"Couldn't read the image: {err.strerror}")
    body = json.dumps({"model": req.get("model") or "koompi-luna", "messages": msgs, "stream": True}).encode()
    r = urllib.request.Request(BASE + "/chat/completions", body, {
        "Authorization": "Bearer " + key, "Content-Type": "application/json", "Accept": "text/event-stream"})
    try:
        with urllib.request.urlopen(r, timeout=120) as resp:
            for raw in resp:
                line = raw.decode("utf-8", "replace").strip()
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    break
                try:
                    ev = json.loads(data)
                except ValueError:
                    continue
                if ev.get("error"):
                    return out(e=str(ev["error"].get("message", ev["error"])))
                for ch in ev.get("choices") or []:
                    piece = (ch.get("delta") or {}).get("content")
                    if piece:
                        out(d=piece)
    except urllib.error.HTTPError as err:
        try:
            msg = json.loads(err.read()).get("error", {}).get("message")
        except Exception:
            msg = None
        out(e=f"{err.code}: {msg or err.reason}" + (" — check the key in Settings → AI" if err.code == 401 else ""))
    except (urllib.error.URLError, TimeoutError) as err:
        out(e=f"Can't reach the AI gateway ({getattr(err, 'reason', err)})")


main()
