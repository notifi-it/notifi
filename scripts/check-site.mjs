#!/usr/bin/env node
// Verifies the agent-facing contract of the website against a running origin:
// the Markdown variant of every page, the Vary and Link headers that make it
// cacheable and discoverable, the 406 for something we cannot produce, and the
// 404 that answers with a site map instead of an app shell.
//
//   node scripts/check-site.mjs                          # production
//   node scripts/check-site.mjs http://localhost:8787    # `make dev`
//
// A wrangler dev server started with --local-protocol https serves a
// self-signed certificate, so certificate verification is switched off for
// https loopback origins only.
const base = (process.argv[2] ?? "https://notifi.it").replace(/\/$/, "");
if (/^https:\/\/(127\.0\.0\.1|localhost)(:|\/|$)/.test(base)) {
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
}

const PAGES = ["/", "/about", "/contact", "/docs", "/faq", "/privacy", "/terms"];
const MARKDOWN = "text/markdown";

let failures = 0;
let checks = 0;

function ok(label, condition, detail) {
  checks++;
  if (condition) return;
  failures++;
  console.error(`FAIL ${label}${detail ? ` — ${detail}` : ""}`);
}

async function get(path, accept) {
  const headers = accept === null ? {} : { Accept: accept };
  const res = await fetch(base + path, { headers, redirect: "manual" });
  const body = await res.text();
  return { res, body };
}

function vary(res) {
  return (res.headers.get("vary") ?? "")
    .split(",")
    .map((s) => s.trim().toLowerCase());
}

function markdownPath(path) {
  return path === "/" ? "/index.md" : `${path}.md`;
}

for (const path of PAGES) {
  const html = await get(path, "text/html,application/xhtml+xml,*/*;q=0.8");
  ok(`GET ${path} (html) 200`, html.res.status === 200, String(html.res.status));
  ok(
    `GET ${path} (html) content-type`,
    (html.res.headers.get("content-type") ?? "").includes("text/html"),
    html.res.headers.get("content-type") ?? "",
  );
  ok(`GET ${path} (html) Vary: Accept`, vary(html.res).includes("accept"), html.res.headers.get("vary") ?? "none");
  ok(
    `GET ${path} (html) Link alternate`,
    (html.res.headers.get("link") ?? "").includes(`<${markdownPath(path)}>`),
    html.res.headers.get("link") ?? "none",
  );

  const md = await get(path, MARKDOWN);
  ok(`GET ${path} (markdown) 200`, md.res.status === 200, String(md.res.status));
  ok(
    `GET ${path} (markdown) content-type`,
    (md.res.headers.get("content-type") ?? "").startsWith("text/markdown"),
    md.res.headers.get("content-type") ?? "",
  );
  ok(`GET ${path} (markdown) Vary: Accept`, vary(md.res).includes("accept"), md.res.headers.get("vary") ?? "none");
  ok(`GET ${path} (markdown) body is Markdown`, md.body.trimStart().startsWith("#"), md.body.slice(0, 40));
  ok(`GET ${path} (markdown) is not HTML`, !md.body.includes("<!doctype html>"));

  const qvalues = await get(path, "text/markdown;q=0.4, text/html;q=0.9");
  ok(
    `GET ${path} honours q-values`,
    (qvalues.res.headers.get("content-type") ?? "").includes("text/html"),
    qvalues.res.headers.get("content-type") ?? "",
  );

  const rejected = await get(path, "application/pdf");
  ok(`GET ${path} rejects what it cannot produce`, rejected.res.status === 406, String(rejected.res.status));

  const direct = await get(markdownPath(path), null);
  ok(`GET ${markdownPath(path)} 200`, direct.res.status === 200, String(direct.res.status));
  ok(
    `GET ${markdownPath(path)} content-type`,
    (direct.res.headers.get("content-type") ?? "").startsWith("text/markdown"),
    direct.res.headers.get("content-type") ?? "",
  );
}

const llms = await get("/llms.txt", null);
ok("GET /llms.txt 200", llms.res.status === 200, String(llms.res.status));
ok("GET /llms.txt names when to use notifi", llms.body.includes("## When to use notifi"));
ok("GET /llms.txt lists the API documentation", llms.body.includes("https://notifi.it/docs"));
ok("GET /llms.txt lists the OpenAPI description", llms.body.includes("https://notifi.it/openapi.json"));

const llmsMd = await get("/llms.txt", MARKDOWN);
ok(
  "GET /llms.txt (markdown) content-type",
  (llmsMd.res.headers.get("content-type") ?? "").startsWith("text/markdown"),
  llmsMd.res.headers.get("content-type") ?? "",
);
ok("GET /llms.txt Vary: Accept", vary(llmsMd.res).includes("accept"), llmsMd.res.headers.get("vary") ?? "none");

const openapi = await get("/openapi.json", null);
ok("GET /openapi.json 200", openapi.res.status === 200, String(openapi.res.status));
let spec = null;
try {
  spec = JSON.parse(openapi.body);
} catch (err) {
  ok("GET /openapi.json parses", false, err.message);
}
if (spec) {
  ok("openapi.json describes /send", Boolean(spec.paths?.["/send"]?.post));
  ok("openapi.json carries a contact", Boolean(spec.info?.contact?.url));
}

const collection = await get("/notifi.postman_collection.json", null);
ok("GET the Postman collection 200", collection.res.status === 200, String(collection.res.status));
let postman = null;
try {
  postman = JSON.parse(collection.body);
} catch (err) {
  ok("the Postman collection parses", false, err.message);
}
if (postman) {
  ok("the collection names a schema", String(postman.info?.schema ?? "").includes("v2.1.0"));
  ok("the collection has a send request", (postman.item ?? []).length > 0);
}

const bru = await get("/notifi.bru", null);
ok("GET the Bruno request 200", bru.res.status === 200, String(bru.res.status));
ok("the Bruno request posts to /send", bru.body.includes("url: https://notifi.it/send"));

const robots = await get("/robots.txt", null);
ok("GET /robots.txt 200", robots.res.status === 200, String(robots.res.status));
ok("robots.txt points at the sitemap", robots.body.includes("Sitemap: https://notifi.it/sitemap.xml"));

const sitemap = await get("/sitemap.xml", null);
ok("GET /sitemap.xml 200", sitemap.res.status === 200, String(sitemap.res.status));
for (const loc of [...sitemap.body.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1])) {
  const path = new URL(loc).pathname;
  const { res } = await get(path, "text/html,*/*;q=0.8");
  ok(`sitemap ${path} 200`, res.status === 200, String(res.status));
}

const missing = await get("/a-path-that-does-not-exist", "*/*");
ok("GET missing path 404", missing.res.status === 404, String(missing.res.status));
ok(
  "GET missing path answers Markdown",
  (missing.res.headers.get("content-type") ?? "").startsWith("text/markdown"),
  missing.res.headers.get("content-type") ?? "",
);
ok("404 body links the sitemap", missing.body.includes("/sitemap.xml"));
ok("404 body links llms.txt", missing.body.includes("/llms.txt"));
ok("404 body links the documentation", missing.body.includes("/docs"));
ok("404 Vary: Accept", vary(missing.res).includes("accept"), missing.res.headers.get("vary") ?? "none");

const missingHtml = await get("/a-path-that-does-not-exist", "text/html,*/*;q=0.8");
ok("GET missing path (browser) 404", missingHtml.res.status === 404, String(missingHtml.res.status));
ok(
  "GET missing path (browser) is HTML",
  (missingHtml.res.headers.get("content-type") ?? "").includes("text/html"),
  missingHtml.res.headers.get("content-type") ?? "",
);

const missingApi = await get("/send/typo", "*/*");
ok("GET a missing API path 404", missingApi.res.status === 404, String(missingApi.res.status));
ok("a missing API path still answers JSON", missingApi.body.startsWith('{"error"'), missingApi.body.slice(0, 40));

const missingJson = await get("/a-path-that-does-not-exist", "application/json");
ok("a JSON client still gets JSON on 404", missingJson.body.startsWith('{"error"'), missingJson.body.slice(0, 40));

console.log(`${checks - failures}/${checks} checks passed against ${base}`);
if (failures > 0) process.exit(1);
