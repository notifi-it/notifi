#!/usr/bin/env node
// The Markdown half of the website. Every doc-shaped page — the ones whose body
// is <main class="wrap doc"> — is converted to a .md sibling next to it, so the
// Worker can answer `Accept: text/markdown` on the same URL with authored
// Markdown rather than an edge conversion of the HTML.
//
// The HTML is the source. Never edit a generated .md by hand: `make gen-site-md`
// rewrites it and `make check-site-md` (CI) fails on drift.
//
// index.md is the one exception and is hand-written: the landing page is a
// marketing document with a canvas, a sprite sheet and thirteen code samples,
// and a mechanical conversion of it reads like nothing anyone would publish.
//
// The converter understands exactly the tags the doc pages use and throws on
// anything else, so a new construct fails the build here rather than silently
// dropping content from the agent-facing copy.
import { readFileSync, readdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const PUBLIC = join(dirname(fileURLToPath(import.meta.url)), "..", "apps", "api", "public");
const ORIGIN = "https://notifi.it";
const VOID = new Set(["br", "img", "hr", "input", "meta", "link", "source"]);

const ENTITIES = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: "\u00A0",
  mdash: "—",
  ndash: "–",
  hellip: "…",
  rsquo: "’",
  lsquo: "‘",
  rdquo: "”",
  ldquo: "“",
  rsaquo: "›",
  lsaquo: "‹",
  times: "×",
  rarr: "→",
  middot: "·",
};

function decode(text) {
  return text.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (whole, body) => {
    if (body[0] === "#") {
      const code = body[1] === "x" || body[1] === "X"
        ? parseInt(body.slice(2), 16)
        : parseInt(body.slice(1), 10);
      return Number.isNaN(code) ? whole : String.fromCodePoint(code);
    }
    const named = ENTITIES[body];
    if (named === undefined) throw new Error(`unknown entity &${body};`);
    return named;
  });
}

function attributes(raw) {
  const out = {};
  const re = /([a-zA-Z-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
  let m;
  while ((m = re.exec(raw)) !== null) out[m[1].toLowerCase()] = decode(m[2] ?? m[3] ?? m[4] ?? "");
  return out;
}

function parse(html) {
  const root = { tag: "#root", attrs: {}, children: [] };
  const stack = [root];
  const re = /<(\/?)([a-zA-Z][a-zA-Z0-9]*)((?:[^>"']|"[^"]*"|'[^']*')*)>/g;
  let last = 0;
  let m;
  const text = (raw) => {
    if (raw) stack[stack.length - 1].children.push({ tag: "#text", value: decode(raw) });
  };
  while ((m = re.exec(html)) !== null) {
    text(html.slice(last, m.index));
    last = re.lastIndex;
    const [, closing, name, rawAttrs] = m;
    const tag = name.toLowerCase();
    if (closing) {
      const open = stack.pop();
      if (!open || open.tag !== tag) throw new Error(`</${tag}> closes <${open?.tag}>`);
      continue;
    }
    const node = { tag, attrs: attributes(rawAttrs), children: [] };
    stack[stack.length - 1].children.push(node);
    if (!VOID.has(tag) && !rawAttrs.trimEnd().endsWith("/")) stack.push(node);
  }
  text(html.slice(last));
  if (stack.length !== 1) throw new Error(`unclosed <${stack[stack.length - 1].tag}>`);
  return root;
}

let pageUrl = ORIGIN;

function absolute(href) {
  if (href.startsWith("/")) return ORIGIN + href;
  if (href.startsWith("#")) return pageUrl + href;
  return href;
}

function spaces(text) {
  return text.replace(/\u00A0/g, " ");
}

function inline(node) {
  if (node.tag === "#text") return node.value.replace(/[^\S\u00A0]+/g, " ");
  const kids = () => node.children.map(inline).join("");
  switch (node.tag) {
    case "code":
      return `\`${kids().trim()}\``;
    case "strong":
    case "b":
      return `**${kids().trim()}**`;
    case "em":
    case "i":
      return `_${kids().trim()}_`;
    case "a":
      return `[${kids().trim()}](${absolute(node.attrs.href ?? "")})`;
    case "span":
      return kids();
    case "br":
      return " ";
    case "abbr":
      return kids();
    default:
      throw new Error(`inline tag <${node.tag}> has no Markdown form`);
  }
}

function inlineOf(node) {
  return spaces(node.children.map(inline).join("").replace(/[^\S\u00A0]+/g, " ")).trim();
}

function codeText(node) {
  if (node.tag === "#text") return node.value.replace(/\n[ \t]*/g, "");
  if (node.tag === "br") return "\n";
  return node.children.map(codeText).join("");
}

// <pre> is verbatim, so unlike codeText this keeps every newline and every
// space that follows one.
function rawText(node) {
  if (node.tag === "#text") return node.value;
  if (node.tag === "br") return "\n";
  return node.children.map(rawText).join("");
}

function rows(node, out) {
  for (const child of node.children) {
    if (child.tag === "tr") out.push(child);
    else if (child.tag === "thead" || child.tag === "tbody" || child.tag === "tfoot") {
      rows(child, out);
    }
  }
  return out;
}

// GitHub-flavoured, because that is what reads as a table wherever the .md
// lands. A cell cannot hold a newline, so a pipe is escaped rather than the
// row being broken up.
function table(node) {
  const all = rows(node, []);
  if (!all.length) throw new Error("empty <table>");
  const cells = (tr) =>
    tr.children
      .filter((c) => c.tag === "th" || c.tag === "td")
      .map((c) => inlineOf(c).replace(/\|/g, "\\|"));
  const head = cells(all[0]);
  const body = all.slice(1).map(cells);
  return [
    `| ${head.join(" | ")} |`,
    `| ${head.map(() => "---").join(" | ")} |`,
    ...body.map((r) => `| ${r.join(" | ")} |`),
  ].join("\n");
}

function isCodeCard(node) {
  const kids = node.children.filter((c) => c.tag !== "#text" || c.value.trim() !== "");
  if (kids.length !== 1 || kids[0].tag !== "p") return false;
  const inner = kids[0].children.filter((c) => c.tag !== "#text" || c.value.trim() !== "");
  return inner.length === 1 && inner[0].tag === "code";
}

function blocks(node, depth) {
  const out = [];
  for (const child of node.children) {
    if (child.tag === "#text") {
      if (child.value.trim() !== "") throw new Error(`stray text: ${child.value.trim()}`);
      continue;
    }
    const heading = /^h([1-6])$/.exec(child.tag);
    if (heading) {
      out.push(`${"#".repeat(Number(heading[1]))} ${inlineOf(child)}`);
      continue;
    }
    const cls = child.attrs.class ?? "";
    switch (child.tag) {
      case "section":
      case "article":
        out.push(...blocks(child, depth));
        break;
      case "p":
        if (cls.includes("eyebrow")) break;
        if (cls.includes("lede")) out.push(`> ${inlineOf(child)}`);
        else if (cls.includes("meta")) out.push(`_${inlineOf(child)}_`);
        else out.push(inlineOf(child));
        break;
      case "ul":
      case "ol": {
        const items = child.children.filter((c) => c.tag === "li");
        out.push(
          items
            .map((li, i) => `${child.tag === "ol" ? `${i + 1}.` : "-"} ${inlineOf(li)}`)
            .join("\n"),
        );
        break;
      }
      case "pre": {
        const lang = child.attrs["data-lang"] ?? "";
        out.push("```" + lang + "\n" + rawText(child).replace(/\n+$/, "") + "\n```");
        break;
      }
      case "table":
        out.push(table(child));
        break;
      case "div":
        if (cls.includes("tablewrap")) {
          out.push(...blocks(child, depth));
        } else if (isCodeCard(child)) {
          const body = spaces(codeText(child))
            .split("\n")
            .map((line) => line.trimEnd())
            .join("\n")
            .trim();
          out.push("```\n" + body + "\n```");
        } else {
          out.push(
            blocks(child, depth + 1)
              .join("\n\n")
              .split("\n")
              .map((line) => (line === "" ? ">" : `> ${line}`))
              .join("\n"),
          );
        }
        break;
      default:
        throw new Error(`block tag <${child.tag}> has no Markdown form`);
    }
  }
  return out;
}

function slice(html, open, close) {
  const start = html.indexOf(open);
  if (start === -1) return null;
  const end = html.indexOf(close, start);
  if (end === -1) throw new Error(`missing ${close}`);
  return html.slice(start, end + close.length);
}

function footerLinks(html) {
  const foot = slice(html, '<div class="wrap foot">', "</div>");
  if (!foot) throw new Error("no footer");
  const links = [...foot.matchAll(/<a\s+href="([^"]+)"[^>]*>([^<]+)<\/a>/g)];
  return links.map(([, href, label]) => `- [${spaces(decode(label))}](${absolute(href)})`).join("\n");
}

// The opening tag is matched on its prefix, not in full: a page that adds a
// modifier class to it — docs.html carries `api` — is still a doc page, and
// matching the whole tag silently dropped it from the agent-facing copy
// instead of failing.
function sliceMain(html) {
  const open = /<main class="wrap doc[^"]*">/.exec(html);
  if (!open) return null;
  const end = html.indexOf("</main>", open.index);
  if (end === -1) throw new Error("missing </main>");
  return html.slice(open.index, end + "</main>".length);
}

function render(html, canonical) {
  pageUrl = canonical;
  const stripped = html.replace(/<!--[\s\S]*?-->/g, "");
  const main = sliceMain(stripped);
  if (!main) return null;
  const tree = parse(main).children.find((c) => c.tag === "main");
  const body = blocks(tree, 0).join("\n\n");
  return `${body}\n\n---\n\nThis page as HTML: ${canonical}\n\n## More from notifi\n\n${footerLinks(stripped)}\n`;
}

function canonicalOf(html, file) {
  const m = /<link rel="canonical" href="([^"]+)">/.exec(html);
  if (!m) throw new Error(`${file} has no canonical URL`);
  return m[1];
}

const check = process.argv.includes("--check");
let drift = 0;
let written = 0;

for (const file of readdirSync(PUBLIC).filter((f) => f.endsWith(".html")).sort()) {
  const html = readFileSync(join(PUBLIC, file), "utf8");
  let md;
  try {
    md = render(html, canonicalOf(html, file));
  } catch (err) {
    console.error(`${file}: ${err.message}`);
    process.exit(1);
  }
  if (md === null) continue;
  const target = join(PUBLIC, file.replace(/\.html$/, ".md"));
  let current = null;
  try {
    current = readFileSync(target, "utf8");
  } catch {
    current = null;
  }
  if (current === md) continue;
  if (check) {
    console.error(`${file.replace(/\.html$/, ".md")} is out of date`);
    drift++;
  } else {
    writeFileSync(target, md);
    written++;
    console.log(`wrote ${file.replace(/\.html$/, ".md")}`);
  }
}

if (check && drift > 0) {
  console.error(`\n${drift} Markdown page(s) out of date. Run \`make gen-site-md\` and commit.`);
  process.exit(1);
}
if (check) console.log("site Markdown is up to date");
else if (written === 0) console.log("site Markdown already up to date");
