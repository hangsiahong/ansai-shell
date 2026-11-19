#!/usr/bin/env python3
# MCP client (Streamable HTTP + OAuth 2.1 with PKCE and dynamic client registration) for Ask AI.
# CLI, used by services/AI.qml (one JSON line per event on stdout):
#   mcp.py login URL     opens the browser to sign in, waits for the redirect, saves the token
#   mcp.py logout URL    forgets the token
#   mcp.py status URL... {"url", "connected", "tools"} per server (tools from cache when fresh)
# Tokens live in ~/.config/ansai-shell/mcp-tokens.json (mode 600) and are never printed.
from http.server import BaseHTTPRequestHandler, HTTPServer
import base64, hashlib, json, os, secrets, subprocess, sys, time, urllib.error, urllib.parse, urllib.request

CFG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "ansai-shell")
TOKENS = os.path.join(CFG, "mcp-tokens.json")
CACHE = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "ansai-ai")
UA = {"User-Agent": "ansai-shell"}


def out(**kv):
    sys.stdout.write(json.dumps(kv, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def load_tokens():
    try:
        with open(TOKENS) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_tokens(t):
    os.makedirs(CFG, exist_ok=True)
    fd = os.open(TOKENS + ".tmp", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(t, f, indent=1)
    os.replace(TOKENS + ".tmp", TOKENS)


def fetch(url, data=None, headers=None, form=False, timeout=30):
    h = dict(UA, **(headers or {}))
    body = None
    if data is not None:
        if form:
            body = urllib.parse.urlencode(data).encode()
            h["Content-Type"] = "application/x-www-form-urlencoded"
        else:
            body = json.dumps(data).encode()
            h["Content-Type"] = "application/json"
    return urllib.request.urlopen(urllib.request.Request(url, body, h), timeout=timeout)


def get_json(url):
    with fetch(url) as r:
        return json.load(r)


def origin(url):
    u = urllib.parse.urlparse(url)
    return f"{u.scheme}://{u.netloc}"


def discover(url):
    """Protected-resource metadata → authorization server metadata."""
    try:
        pr = get_json(origin(url) + "/.well-known/oauth-protected-resource")
        issuer = pr["authorization_servers"][0]
        resource = pr.get("resource") or origin(url)
        scopes = pr.get("scopes_supported") or []
    except Exception:
        issuer, resource, scopes = origin(url), origin(url), []
    for path in ("/.well-known/oauth-authorization-server", "/.well-known/openid-configuration"):
        for base in (origin(issuer), origin(url)):
            try:
                meta = get_json(base + path)
                return meta, resource, scopes or meta.get("scopes_supported") or []
            except Exception:
                pass
    raise RuntimeError("This server doesn't offer OAuth sign-in")


def login(url):
    meta, resource, scopes = discover(url)
    code_box = {}

    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if "code" not in q and "error" not in q:
                self.send_response(404); self.end_headers(); return
            code_box.update({k: v[0] for k, v in q.items()})
            ok = "code" in q
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            msg = "Connected. You can close this tab and go back to ansai." if ok else "Sign-in was cancelled."
            self.wfile.write(f"<!doctype html><meta name=viewport content='width=device-width'><title>ansai</title>"
                             f"<body style='font:16px system-ui;display:grid;place-items:center;height:90vh'>{msg}</body>".encode())

        def log_message(self, *a):
            pass

    srv = HTTPServer(("127.0.0.1", 0), H)
    redirect = f"http://127.0.0.1:{srv.server_port}/callback"

    reg = meta.get("registration_endpoint")
    if not reg:
        raise RuntimeError("This server needs a pre-registered client; dynamic registration isn't offered")
    with fetch(reg, {"client_name": "ansai shell", "redirect_uris": [redirect], "grant_types": ["authorization_code", "refresh_token"],
                    "response_types": ["code"], "token_endpoint_auth_method": "none",
                    **({"scope": " ".join(scopes)} if scopes else {})}) as r:
        client = json.load(r)

    verifier = secrets.token_urlsafe(48)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    q = {"response_type": "code", "client_id": client["client_id"], "redirect_uri": redirect, "state": state,
         "code_challenge": challenge, "code_challenge_method": "S256", "resource": resource}
    if scopes:
        q["scope"] = " ".join(scopes)
    auth = meta["authorization_endpoint"] + "?" + urllib.parse.urlencode(q)
    subprocess.Popen(["xdg-open", auth], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    out(opened=True)

    srv.timeout = 1
    deadline = time.time() + 300
    while not code_box and time.time() < deadline:
        srv.handle_request()
    srv.server_close()
    if not code_box:
        raise RuntimeError("Timed out waiting for sign-in")
    if code_box.get("state") != state or "code" not in code_box:
        raise RuntimeError(code_box.get("error_description") or code_box.get("error") or "Sign-in failed")

    data = {"grant_type": "authorization_code", "code": code_box["code"], "redirect_uri": redirect,
            "client_id": client["client_id"], "code_verifier": verifier, "resource": resource}
    if client.get("client_secret"):
        data["client_secret"] = client["client_secret"]
    with fetch(meta["token_endpoint"], data, form=True) as r:
        tok = json.load(r)
    t = load_tokens()
    t[url] = {"client_id": client["client_id"], "client_secret": client.get("client_secret"),
              "token_endpoint": meta["token_endpoint"], "resource": resource,
              "access_token": tok["access_token"], "refresh_token": tok.get("refresh_token"),
              "expires_at": time.time() + float(tok.get("expires_in") or 3600)}
    save_tokens(t)


def access_token(url, force_refresh=False):
    t = load_tokens()
    e = t.get(url)
    if not e:
        return None
    if force_refresh or time.time() > e.get("expires_at", 0) - 60:
        if not e.get("refresh_token"):
            return None
        data = {"grant_type": "refresh_token", "refresh_token": e["refresh_token"], "client_id": e["client_id"],
                "resource": e.get("resource") or origin(url)}
        if e.get("client_secret"):
            data["client_secret"] = e["client_secret"]
        try:
            with fetch(e["token_endpoint"], data, form=True) as r:
                tok = json.load(r)
        except urllib.error.HTTPError:
            return None
        e.update(access_token=tok["access_token"], expires_at=time.time() + float(tok.get("expires_in") or 3600))
        if tok.get("refresh_token"):
            e["refresh_token"] = tok["refresh_token"]
        t[url] = e
        save_tokens(t)
    return e["access_token"]


class Session:
    """One MCP session over Streamable HTTP."""

    def __init__(self, url):
        self.url, self.sid, self.n = url, None, 0
        self.token = access_token(url)
        if not self.token:
            raise PermissionError("Not connected")
        self.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                "clientInfo": {"name": "ansai-shell", "version": "1"}})
        self.rpc("notifications/initialized", None, notify=True)

    def rpc(self, method, params, notify=False, retried=False):
        msg = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            msg["params"] = params
        if not notify:
            self.n += 1
            msg["id"] = self.n
        h = {"Authorization": "Bearer " + self.token, "Accept": "application/json, text/event-stream",
             "MCP-Protocol-Version": "2025-06-18"}
        if self.sid:
            h["Mcp-Session-Id"] = self.sid
        try:
            r = fetch(self.url, msg, h, timeout=120)
        except urllib.error.HTTPError as err:
            if err.code == 401 and not retried:
                self.token = access_token(self.url, force_refresh=True)
                if not self.token:
                    raise PermissionError("Sign-in expired")
                return self.rpc(method, params, notify, True)
            raise
        with r:
            self.sid = r.headers.get("Mcp-Session-Id") or self.sid
            if notify:
                return None
            ctype = r.headers.get("Content-Type", "")
            if "text/event-stream" in ctype:
                for raw in r:
                    line = raw.decode("utf-8", "replace").strip()
                    if line.startswith("data:"):
                        try:
                            m = json.loads(line[5:].strip())
                        except ValueError:
                            continue
                        if m.get("id") == msg["id"]:
                            return self._result(m)
                raise RuntimeError("No reply from the MCP server")
            return self._result(json.load(r))

    @staticmethod
    def _result(m):
        if "error" in m:
            raise RuntimeError(m["error"].get("message", "MCP error"))
        return m.get("result")

    def tools(self):
        out_, cursor = [], None
        while True:
            res = self.rpc("tools/list", {"cursor": cursor} if cursor else {})
            out_ += res.get("tools", [])
            cursor = res.get("nextCursor")
            if not cursor:
                return out_

    def call(self, name, args):
        res = self.rpc("tools/call", {"name": name, "arguments": args})
        parts = []
        for c in res.get("content", []):
            if c.get("type") == "text":
                parts.append(c["text"])
            elif c.get("type") == "resource":
                parts.append(c.get("resource", {}).get("text", ""))
            else:
                parts.append(f"[{c.get('type')} content]")
        if not parts and res.get("structuredContent") is not None:
            parts.append(json.dumps(res["structuredContent"], ensure_ascii=False))
        text = "\n".join(parts) or "(no output)"
        return ("Error: " + text) if res.get("isError") else text


def cache_file(url):
    return os.path.join(CACHE, "mcp-tools-" + hashlib.sha1(url.encode()).hexdigest()[:12] + ".json")


def tools_cached(url, max_age=600):
    f = cache_file(url)
    try:
        if time.time() - os.path.getmtime(f) < max_age:
            with open(f) as fh:
                return json.load(fh)
    except (OSError, ValueError):
        pass
    tools = Session(url).tools()
    os.makedirs(CACHE, exist_ok=True)
    with open(f, "w") as fh:
        json.dump(tools, fh)
    return tools


def main():
    cmd, urls = sys.argv[1], sys.argv[2:]
    if cmd == "login":
        try:
            login(urls[0])
            for f in [cache_file(urls[0])]:
                if os.path.exists(f):
                    os.remove(f)
            out(ok=True, tools=len(tools_cached(urls[0])))
        except urllib.error.HTTPError as err:
            try:
                body = json.loads(err.read())
                msg = body.get("error_description") or body.get("error") or body.get("message")
            except Exception:
                msg = None
            out(e=f"Sign-in failed ({err.code}{': ' + str(msg) if msg else ''})")
        except Exception as err:
            out(e=str(err))
    elif cmd == "logout":
        t = load_tokens()
        t.pop(urls[0], None)
        save_tokens(t)
        out(ok=True)
    elif cmd == "status":
        for u in urls:
            try:
                out(url=u, connected=True, tools=len(tools_cached(u)))
            except PermissionError:
                out(url=u, connected=False)
            except Exception as err:
                out(url=u, connected=bool(load_tokens().get(u)), e=str(err))


if __name__ == "__main__":
    main()
