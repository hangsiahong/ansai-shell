// Signed-in AI accounts for Ask Ansai: any pi-ai provider (ChatGPT/Codex, Claude, Copilot, Gemini, OpenRouter…),
// several accounts per provider. Stored in ~/.config/ansai-shell/ai-accounts.json (0600), never printed.
// pi-ai keys credentials by provider id (one each), so each request binds the store to one account and
// `failover` moves to the provider's next account when one is rate limited or signed out.
import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";
import { builtinModels } from "@earendil-works/pi-ai/providers/all";
import { registerLazyOAuthFlows } from "@earendil-works/pi-ai/lazy-oauth";
import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

registerLazyOAuthFlows();

export function accountsFile(cfg) { return join(cfg, "ai-accounts.json"); }

export async function load(file) {
    try { return JSON.parse(await readFile(file, "utf8")); } catch { return { accounts: [] }; }
}
// Re-read before writing so two agents running at once don't drop each other's refreshed tokens.
export async function update(file, fn) {
    const db = await load(file);
    fn(db);
    await mkdir(dirname(file), { recursive: true, mode: 0o700 });
    const tmp = file + "." + process.pid;
    await writeFile(tmp, JSON.stringify(db, null, 1), { mode: 0o600 });
    await rename(tmp, file);
    return db;
}

export const pub = a => ({ id: a.id, provider: a.provider, label: a.label, type: a.cred?.type, limitedUntil: a.limitedUntil || 0, error: a.error || "", lastUsed: a.lastUsed || 0 });

// Best-effort account name from the token's claims (ChatGPT, Claude and others put the email in the JWT).
function emailOf(cred) {
    for (const t of [cred.idToken, cred.id_token, cred.access]) {
        if (typeof t !== "string" || t.split(".").length !== 3) continue;
        try {
            const c = JSON.parse(Buffer.from(t.split(".")[1], "base64url").toString());
            const e = c.email || c["https://api.openai.com/profile"]?.email;
            if (e) return e;
        } catch { /* not a JWT */ }
    }
    return cred.email || "";
}

// Binds pi-ai's per-provider credential store to whichever account is current.
export function boundModels(file) {
    let cur = null;
    const store = {
        async read(pid) { return cur && cur.provider === pid ? cur.cred : undefined; },
        async list() { return cur ? [{ providerId: cur.provider, type: cur.cred.type }] : []; },
        async modify(pid, fn) {
            if (!cur || cur.provider !== pid) return fn(undefined);
            const next = await fn(cur.cred);
            if (next && next !== cur.cred) {
                cur.cred = next;
                const id = cur.id;
                await update(file, db => { const a = db.accounts.find(x => x.id === id); if (a) a.cred = next; });
            }
            return cur.cred;
        },
        async delete() {},
    };
    const models = builtinModels({ credentials: store });
    return { models, use(a) { cur = a; } };
}

const LIMIT = /\b429\b|rate.?limit|usage.?limit|quota|too many requests|limit (reached|exceeded)|insufficient_quota|exceeded your|try again (in|later)/i;
const AUTH = /\b401\b|\b403\b|unauthori[sz]ed|invalid.?(grant|token|api.?key)|expired|sign in again|forbidden/i;
export const failKind = msg => LIMIT.test(msg) ? "limit" : AUTH.test(msg) ? "auth" : "";

// "try again in 3h 20m" / "in 45 minutes" / "resets in 30s": how long to skip a limited account (default 30 min).
function coolDown(msg) {
    let s = 0;
    for (const [, n, u] of msg.matchAll(/(\d+(?:\.\d+)?)\s*(h|hr|hour|m|min|minute|s|sec|second)s?\b/gi))
        s += Number(n) * (/^h/i.test(u) ? 3600 : /^m/i.test(u) ? 60 : 1);
    return Math.min(s || 1800, 7 * 86400) * 1000;
}

// Accounts to try for a provider: the pinned one only, or (auto) everyone not resting, least recently used first.
export function order(db, provider, pinned) {
    const mine = db.accounts.filter(a => a.provider === provider);
    if (pinned && pinned !== "auto") {
        const p = mine.find(a => a.id === pinned);
        if (p) return [p];
    }
    const now = Date.now();
    const ok = mine.filter(a => !(a.limitedUntil > now)).sort((a, b) => (a.lastUsed || 0) - (b.lastUsed || 0));
    const resting = mine.filter(a => a.limitedUntil > now).sort((a, b) => a.limitedUntil - b.limitedUntil);
    return [...ok, ...resting];
}

// streamFn for the agent: tries each account until one starts answering. A failure after text has
// streamed is passed through (the agent loop reports it); failures before that move to the next account.
export function failover(file, bound, accounts, onSwitch) {
    let i = 0;
    return async (model, context, options) => {
        for (;;) {
            const acct = accounts[i];
            bound.use(acct);
            const src = bound.models.streamSimple(model, context, options);
            const held = [];
            let failed = null;
            for await (const ev of src) {
                if (ev.type === "error") { failed = ev; break; }
                held.push(ev);
                if (ev.type !== "start") break;
            }
            if (failed) {
                const msg = failed.error?.errorMessage || "";
                const kind = failKind(msg);
                if (kind) {
                    await update(file, db => {
                        const a = db.accounts.find(x => x.id === acct.id);
                        if (!a) return;
                        if (kind === "limit") a.limitedUntil = Date.now() + coolDown(msg);
                        else a.error = "Sign in again";
                    }).catch(() => {});
                }
                if (kind && i + 1 < accounts.length) { i++; onSwitch?.(accounts[i], kind); continue; }
                const s = createAssistantMessageEventStream();
                queueMicrotask(() => { s.push(failed); s.end(failed.error); });
                return s;
            }
            await update(file, db => {
                const a = db.accounts.find(x => x.id === acct.id);
                if (a) { a.lastUsed = Date.now(); a.limitedUntil = 0; a.error = ""; }
            }).catch(() => {});
            const s = createAssistantMessageEventStream();
            (async () => {
                for (const ev of held) s.push(ev);
                for await (const ev of src) s.push(ev);
                s.end();
            })().catch(err => s.end());
            return s;
        }
    };
}

// Interactive sign-in over JSON lines: {auth_url|device_code|info|progress|prompt} out, answers in.
export async function login(file, providerId, type, out, nextLine) {
    const { models } = boundModels(file);   // nothing bound: login starts from a blank credential
    const p = models.getProvider(providerId);
    if (!p) throw new Error(`Unknown provider ${providerId}`);
    type ||= p.auth.oauth ? "oauth" : "api_key";
    const ctl = new AbortController();
    const interaction = {
        signal: ctl.signal,
        notify(ev) { out({ ev }); },
        async prompt(pr) {
            out({ prompt: { type: pr.type, message: pr.message, placeholder: pr.placeholder || "", options: pr.options || [] } });
            const ans = await Promise.race([nextLine(), new Promise(r => pr.signal?.addEventListener("abort", () => r("\u0000")))]);
            if (ans === "\u0000") throw new Error("aborted");
            if (ans == null || ans === "") { ctl.abort(); throw new Error("Cancelled"); }
            return ans;
        },
    };
    let deviceId = "";
    const cred = await models.login(providerId, type, interaction, {
        agentName: "Ansai",
        getDeviceId: () => (deviceId ||= randomUUID()),
    });
    const id = randomUUID().slice(0, 8);
    let label = emailOf(cred);
    await update(file, db => {
        const n = db.accounts.filter(a => a.provider === providerId).length;
        label ||= `${p.name} ${n + 1}`;
        db.accounts.push({ id, provider: providerId, label, cred, added: Date.now() });
    });
    return { id, label, provider: providerId };
}

// Clearer names where pi-ai's are ambiguous: [name, sign-in line]. openai-codex is the ChatGPT plan most people have.
const NAMES = {
    "openai-codex": ["ChatGPT (Codex)", "Sign in with ChatGPT Plus, Pro or Team"],
    "openai": ["OpenAI API", "ChatGPT sign-in for the OpenAI API"],
    "anthropic": ["Claude", "Sign in with Claude Pro or Max"],
    "github-copilot": ["GitHub Copilot", "Sign in with GitHub"],
};

// Providers you can sign in to, and the chat models of providers you have accounts for.
export async function catalog(file) {
    const db = await load(file);
    const { models } = boundModels(file);
    const have = new Set(db.accounts.map(a => a.provider));
    return {
        providers: models.getProviders().filter(p => p.auth.oauth || p.auth.apiKey?.login).map(p => ({
            id: p.id, name: NAMES[p.id]?.[0] || p.name,
            oauth: p.auth.oauth ? { name: p.auth.oauth.name, label: NAMES[p.id]?.[1] || p.auth.oauth.loginLabel || "", sub: !!p.auth.oauth.isSubscription } : null,
            key: p.auth.apiKey?.login ? p.auth.apiKey.name : "",
        })),
        models: Object.fromEntries([...have].map(pid => [pid, (models.getModels(pid) || []).map(m => ({ id: m.id, name: m.name || m.id, image: !!m.input?.includes("image") }))])),
        accounts: db.accounts.map(pub),
    };
}
