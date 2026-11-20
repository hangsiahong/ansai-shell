.pragma library

// Quick Note's reading view: a note's Markdown as Qt rich text. Line-based on purpose: every non-blank source line
// becomes exactly one text block, so `lines[block]` maps a click back to the source line (to edit or tick it).
// c: { text, muted, accent, code } colour strings.

function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

function inline(s, c) {
    const codes = [];
    s = s.replace(/`([^`]+)`/g, (m, x) => { codes.push(x); return "\u0001" + (codes.length - 1) + "\u0001"; });
    s = esc(s)
        .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (m, t, u) => `<a href="${u.replace(/"/g, "%22")}" style="color:${c.accent};text-decoration:none">${t}</a>`)
        .replace(/(^|[\s(])(https?:\/\/[^\s<)]+)/g, (m, p, u) => `${p}<a href="${u.replace(/"/g, "%22")}" style="color:${c.accent};text-decoration:none">${u}</a>`)
        .replace(/\*\*(.+?)\*\*|__(.+?)__/g, (m, a, b) => `<b>${a ?? b}</b>`)
        .replace(/(^|[^*\w])\*(?!\s)(.+?)\*(?!\w)/g, "$1<i>$2</i>")
        .replace(/(^|[^_\w])_(?!\s)(.+?)_(?!\w)/g, "$1<i>$2</i>")
        .replace(/~~(.+?)~~/g, "<s>$1</s>")
        .replace(/==(.+?)==/g, `<span style="background-color:${c.code}">$1</span>`);
    return s.replace(/\u0001(\d+)\u0001/g, (m, i) => `<span style="font-family:monospace;background-color:${c.code}">&nbsp;${esc(codes[+i])}&nbsp;</span>`);
}

function render(src, c) {
    const out = [], lines = [];
    let gap = false, fence = false;
    const block = (i, html) => { lines.push(i); out.push(html); gap = false; };
    const top = px => `margin-top:${gap ? px + 8 : px}px;`;
    src.split("\n").forEach((raw, i) => {
        if (/^\s*```/.test(raw)) { fence = !fence; gap = false; return; }
        if (fence) {
            block(i, `<p style="margin-top:0;font-family:monospace;font-size:13px;background-color:${c.code};white-space:pre">${esc(raw) || "&nbsp;"}</p>`);
            return;
        }
        const t = raw.replace(/\s+$/, "");
        if (!t.trim()) { gap = out.length > 0; return; }
        let m;
        const ind = (raw.match(/^\s*/)[0].replace(/\t/g, "    ").length >> 1) * 18;
        if ((m = t.match(/^(#{1,3})\s+(.*)$/))) {
            const size = [24, 19, 16][m[1].length - 1];
            block(i, `<p style="${top(out.length ? 14 : 0)}margin-bottom:2px;font-size:${size}px;font-weight:600">${inline(m[2], c)}</p>`);
        } else if ((m = t.match(/^\s*[-*+]\s+\[([ xX])\]\s?(.*)$/))) {
            const done = m[1] !== " ";
            const box = `<a href="tick:${i}" style="color:${done ? c.accent : c.muted};text-decoration:none;font-size:17px">${done ? "☑" : "☐"}</a>&nbsp;`;
            const body = done ? `<span style="color:${c.muted}"><s>${inline(m[2], c)}</s></span>` : inline(m[2], c);
            block(i, `<p style="${top(3)}margin-left:${ind + 24}px;text-indent:-24px">${box}${body}</p>`);
        } else if ((m = t.match(/^\s*[-*+]\s+(.*)$/))) {
            block(i, `<p style="${top(3)}margin-left:${ind + 18}px;text-indent:-14px"><span style="color:${c.accent}">•</span>&nbsp;&nbsp;${inline(m[1], c)}</p>`);
        } else if ((m = t.match(/^\s*(\d+[.)])\s+(.*)$/))) {
            block(i, `<p style="${top(3)}margin-left:${ind + 22}px;text-indent:-20px"><span style="color:${c.muted}">${m[1]}</span>&nbsp;${inline(m[2], c)}</p>`);
        } else if ((m = t.match(/^\s*>\s?(.*)$/))) {
            block(i, `<p style="${top(3)}margin-left:14px;color:${c.muted}"><i>${inline(m[1], c)}</i></p>`);
        } else if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(t)) {
            block(i, `<p style="${top(4)}color:${c.muted}">${"─".repeat(48)}</p>`);
        } else {
            block(i, `<p style="${top(3)}">${inline(t, c)}</p>`);
        }
    });
    return { html: out.join(""), lines: lines };
}

// Tick or untick the checklist item on source line i.
function tick(src, i) {
    const l = src.split("\n");
    l[i] = l[i].replace(/^(\s*[-*+]\s+\[)([ xX])\]/, (m, a, x) => a + (x === " " ? "x" : " ") + "]");
    return l.join("\n");
}

// A note's title for the list: its first line without Markdown marks.
function title(src) {
    const l = src.split("\n").find(x => x.trim() && !/^\s*```/.test(x)) ?? "";
    return l.replace(/^\s*(#{1,6}\s+|[-*+]\s+(\[[ xX]\]\s*)?|\d+[.)]\s+|>\s?)/, "").replace(/\*\*|__|~~|==|`/g, "").trim();
}
