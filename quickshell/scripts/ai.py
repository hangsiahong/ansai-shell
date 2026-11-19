#!/usr/bin/env python3
# KOOMPI AI Gateway client for services/AI.qml. Reads one JSON line on stdin: {"model", "messages",
# "mcp": [server urls]}; a message may carry "image": "/path.png" (sent as a data URL). Streams one
# JSON line per event to stdout:
#   {"d": text}                                   a piece of the reply
#   {"tool": {id, name, server, args, ask}}       a tool call starting (ask: waiting for approval)
#   {"tool_done": {id, ok, preview}}              its result
#   {"e": message}                                failure
# Tools that may change something (no readOnlyHint) wait for a stdin line: "y" runs it, anything else
# declines. The key is read from ~/.config/ansai-shell/ai-key (or $ANSAI_AI_KEY) and never printed.
import base64, json, mimetypes, os, re, sys, urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mcp  # noqa: E402

BASE = os.environ.get("ANSAI_AI_BASE", "https://ai.koompi.cloud/v1")
KEY_FILE = os.path.join(mcp.CFG, "ai-key")
MAX_ROUNDS = 12


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


def load_tools(urls):
    """OpenAI tool specs plus name → (url, mcp tool) for every connected server."""
    specs, table = [], {}
    for i, url in enumerate(urls):
        try:
            tools = mcp.tools_cached(url)
        except PermissionError:
            continue
        except Exception as err:
            out(e=f"{mcp.origin(url)}: {err}")
            continue
        for t in tools:
            name = re.sub(r"[^a-zA-Z0-9_-]", "_", t["name"] if len(urls) == 1 else f"s{i}_{t['name']}")[:64]
            table[name] = (url, t)
            specs.append({"type": "function", "function": {
                "name": name, "description": (t.get("description") or "")[:1024],
                "parameters": t.get("inputSchema") or {"type": "object", "properties": {}}}})
    return specs, table


def stream(key, model, msgs, tools):
    """One completion; yields the reply text as it comes and returns (text, tool_calls)."""
    body = {"model": model, "messages": msgs, "stream": True}
    if tools:
        body["tools"] = tools
    r = urllib.request.Request(BASE + "/chat/completions", json.dumps(body).encode(), {
        "Authorization": "Bearer " + key, "Content-Type": "application/json", "Accept": "text/event-stream"})
    text, calls = "", {}
    with urllib.request.urlopen(r, timeout=180) as resp:
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
                raise RuntimeError(str(ev["error"].get("message", ev["error"])))
            for ch in ev.get("choices") or []:
                delta = ch.get("delta") or {}
                if delta.get("content"):
                    text += delta["content"]
                    out(d=delta["content"])
                for tc in delta.get("tool_calls") or []:
                    c = calls.setdefault(tc.get("index", 0), {"id": "", "name": "", "args": ""})
                    c["id"] = tc.get("id") or c["id"]
                    fn = tc.get("function") or {}
                    c["name"] += fn.get("name") or ""
                    c["args"] += fn.get("arguments") or ""
    return text, [calls[i] for i in sorted(calls)]


def main():
    key = os.environ.get("ANSAI_AI_KEY", "").strip()
    if not key:
        try:
            key = open(KEY_FILE).read().strip()
        except OSError:
            return out(e=f"No AI key. Paste one in Settings → AI (saved to {KEY_FILE}).")
    req = json.loads(sys.stdin.readline())
    try:
        msgs = [{"role": m["role"], "content": content(m)} for m in req["messages"]]
    except OSError as err:
        return out(e=f"Couldn't read the image: {err.strerror}")
    tools, table = load_tools(req.get("mcp") or [])
    sessions = {}
    try:
        for _ in range(MAX_ROUNDS):
            text, calls = stream(key, req.get("model") or "koompi-luna", msgs, tools)
            if not calls:
                return
            msgs.append({"role": "assistant", "content": text or None, "tool_calls": [
                {"id": c["id"], "type": "function", "function": {"name": c["name"], "arguments": c["args"] or "{}"}} for c in calls]})
            for c in calls:
                msgs.append({"role": "tool", "tool_call_id": c["id"], "content": run_tool(c, table, sessions)})
            if text:
                out(d="\n\n")
        out(e="Stopped after too many tool steps")
    except urllib.error.HTTPError as err:
        try:
            msg = json.loads(err.read()).get("error", {}).get("message")
        except Exception:
            msg = None
        out(e=f"{err.code}: {msg or err.reason}" + (" — check the key in Settings → AI" if err.code == 401 else ""))
    except (urllib.error.URLError, TimeoutError) as err:
        out(e=f"Can't reach the AI gateway ({getattr(err, 'reason', err)})")
    except RuntimeError as err:
        out(e=str(err))


def run_tool(c, table, sessions):
    try:
        args = json.loads(c["args"] or "{}")
    except ValueError:
        args = {}
    entry = table.get(c["name"])
    if not entry:
        return f"Unknown tool {c['name']}"
    url, tool = entry
    ask = not (tool.get("annotations") or {}).get("readOnlyHint", False)
    out(tool={"id": c["id"], "name": tool["name"], "title": (tool.get("annotations") or {}).get("title") or tool.get("title") or "",
              "server": mcp.origin(url).split("//")[1], "args": args, "ask": ask})
    if ask and sys.stdin.readline().strip() != "y":
        out(tool_done={"id": c["id"], "ok": False, "preview": "Declined"})
        return "The user declined this action. Don't retry it; ask them what to do instead."
    try:
        if url not in sessions:
            sessions[url] = mcp.Session(url)
        result = sessions[url].call(tool["name"], args)
        ok = not result.startswith("Error: ")
    except Exception as err:
        result, ok = f"Error: {err}", False
    out(tool_done={"id": c["id"], "ok": ok, "preview": result[:300]})
    return result[:24000]


main()
