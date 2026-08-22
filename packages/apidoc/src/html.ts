import {
  AUTH,
  ENDPOINT,
  IMAGE_MAX_MB,
  KEYS_PER_DEVICE,
  ORIGIN,
  REQUESTS_PER_MINUTE,
  SENDS_PER_HOUR,
  errors,
  limits,
  params,
  resources,
} from './spec.js';
import { samples } from './samples.js';
import { terminal } from './landing.js';

export function escape(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function pre(code: string, lang: string): string {
  return `<pre data-lang="${lang}">${escape(code)}</pre>`;
}

function required(param: { required: boolean; name: string }): string {
  if (param.name === 'key') return 'conditional';
  return param.required ? 'required' : 'optional';
}

const QUICKSTART = `curl -X POST ${ORIGIN}${ENDPOINT} \\
  -H "Authorization: Bearer $NOTIFI_KEY" \\
  -d "title=Backup complete" \\
  -d "message=4.2 GB in 3m 11s"`;

const RAW_REQUEST = `POST /send HTTP/1.1
Host: notifi.it
Authorization: Bearer nk_yourkey
Content-Type: application/json
Accept-Language: en-GB

{"title":"Backup complete","message":"4.2 GB in 3m 11s","link":"https://console.internal/backups"}`;

const RAW_RESPONSE = `HTTP/1.1 202 Accepted
Content-Type: application/json; charset=utf-8

{"ok":true}`;

const RAW_ERROR = `HTTP/1.1 401 Unauthorized
Content-Type: application/json; charset=utf-8

{"error":{"code":"unknown_key","message":"Unknown or revoked key."}}`;

const CLIENTS: Array<[string, string, string]> = [
  [
    'Postman',
    'Import → Link, and paste the collection URL. Postman keeps it in sync from there.',
    `${ORIGIN}/notifi.postman_collection.json`,
  ],
  [
    'Bruno',
    'Drop the .bru file into a collection folder, or use Import → Postman Collection with the URL above.',
    `curl -O ${ORIGIN}/notifi.bru`,
  ],
  [
    'Insomnia',
    'Import from URL accepts either the OpenAPI document or the Postman collection.',
    `${ORIGIN}/openapi.json`,
  ],
  [
    'HTTPie',
    'No import needed.',
    `http -f POST ${ORIGIN}${ENDPOINT} "Authorization:Bearer $NOTIFI_KEY" title="Backup complete"`,
  ],
  [
    'Generated clients',
    'Any generator that reads OpenAPI 3.1.',
    `openapi-generator-cli generate -i ${ORIGIN}/openapi.json -g typescript-fetch -o ./notifi`,
  ],
];

const SECTIONS: Array<[string, string]> = [
  ['quickstart', 'Quickstart'],
  ['auth', 'Authentication'],
  ['request', 'Request'],
  ['parameters', 'Parameters'],
  ['response', 'Response'],
  ['errors', 'Errors'],
  ['limits', 'Rate limits'],
  ['clients', 'Clients and import'],
  ['machine', 'Machine-readable'],
  ['recipes', 'Recipes'],
];

function parameterRows(): string {
  return params
    .map(
      (p) => `          <tr>
            <td><code>${p.name}</code></td>
            <td>${escape(p.type)}</td>
            <td>${required(p)}</td>
            <td>${p.limit ? `<code>${escape(p.limit)}</code>` : '—'}</td>
            <td>${escape(p.detail ? `${p.summary} ${p.detail}` : p.summary)}</td>
          </tr>`,
    )
    .join('\n');
}

function errorRows(): string {
  return errors
    .map(
      (e) => `          <tr>
            <td><code>${e.status}</code></td>
            <td><code>${e.code}</code></td>
            <td>${escape(e.detail ? `${e.summary} ${e.detail}` : e.summary)}</td>
          </tr>`,
    )
    .join('\n');
}

function contents(): string {
  return SECTIONS.map(([id, label]) => `<a href="#${id}">${label}</a>`).join(' · ');
}

export function docsBody(): string {
  return `<main class="wrap doc api">

  <p class="eyebrow">API reference</p>
  <h1>notifi API documentation</h1>
  <p class="lede">
    One endpoint, seven parameters, no SDK. Everything on this page is generated
    from the same file that generates <a href="/openapi.json"><code>/openapi.json</code></a>
    and the client collections, so the three cannot disagree.
  </p>

  <p class="meta">${contents()}</p>

  <section id="quickstart">
    <h2>Quickstart</h2>
    <p>
      Install notifi on <a href="https://apps.apple.com/app/id1563961135">iPhone or iPad</a>
      or <a href="/download/mac">on the Mac</a>, allow notifications, open the Keys tab and
      copy the <code>Default</code> key. It starts with <code>nk_</code> and delivers only to
      the device that made it.
    </p>
    ${pre(QUICKSTART, 'bash')}
    <p>
      There is no endpoint that creates a key: keys are minted on the device by a request
      signed with a private key that never leaves it. A coding agent has to ask you for one.
      Keep it in the environment, not in a file that gets committed.
    </p>
  </section>

  <section id="auth">
    <h2>Authentication</h2>
    <p>${escape(AUTH.summary)}</p>
    <div class="tablewrap" tabindex="0" role="group" aria-label="Authentication methods">
      <table>
        <thead><tr><th>Method</th><th>Sent as</th><th>Notes</th></tr></thead>
        <tbody>
          <tr>
            <td>Bearer token</td>
            <td><code>Authorization: Bearer nk_yourkey</code></td>
            <td>${escape(AUTH.bearerDescription)}</td>
          </tr>
          <tr>
            <td>Parameter</td>
            <td><code>key=nk_yourkey</code></td>
            <td>${escape(AUTH.parameterDescription)}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>

  <section id="request">
    <h2>Request</h2>
    <p>
      <code>POST ${ORIGIN}${ENDPOINT}</code>, JSON, form-encoded or multipart.
      <code>GET</code> takes the same parameters in the query string and is there for a quick
      test. Query parameters win over body fields when both are present.
    </p>
    ${pre(RAW_REQUEST, 'http')}
  </section>

  <section id="parameters">
    <h2>Parameters</h2>
    <p>
      <code>key</code> is required unless the request carries a bearer token.
      An image is fetched server-side and must be <code>https</code>, PNG, JPEG or GIF,
      ${IMAGE_MAX_MB}&nbsp;MB at most.
    </p>
    <div class="tablewrap" tabindex="0" role="group" aria-label="Send parameters, scrollable">
      <table>
        <thead>
          <tr><th>Name</th><th>Type</th><th>Required</th><th>Limit</th><th>Description</th></tr>
        </thead>
        <tbody>
${parameterRows()}
        </tbody>
      </table>
    </div>
  </section>

  <section id="response">
    <h2>Response</h2>
    <p>
      A send answers <code>202</code>. That means the server accepted it, not that it was
      delivered — delivery is best-effort, as the <a href="/terms">terms</a> describe.
    </p>
    ${pre(RAW_RESPONSE, 'http')}
    <p>
      A <code>warnings</code> array is present only when the notification was delivered
      differently from what was asked: a cropped title or body, a dropped image, or a critical
      alert downgraded to an ordinary one.
    </p>
  </section>

  <section id="errors">
    <h2>Errors</h2>
    <p>
      Every error nests the code one level down. Read <code>error.code</code>, not
      <code>code</code>. The <code>message</code> is in the language negotiated from
      <code>Accept-Language</code> and is meant for a human, so match on the code.
    </p>
    ${pre(RAW_ERROR, 'http')}
    <div class="tablewrap" tabindex="0" role="group" aria-label="Error codes">
      <table>
        <thead><tr><th>Status</th><th><code>error.code</code></th><th>Meaning</th></tr></thead>
        <tbody>
${errorRows()}
        </tbody>
      </table>
    </div>
  </section>

  <section id="limits">
    <h2>Rate limits</h2>
    <ul>
${limits.map((l) => `      <li>${escape(l)}</li>`).join('\n')}
    </ul>
    <p>
      A <code>429</code> carries <code>Retry-After</code> in seconds. The device limit is
      ${SENDS_PER_HOUR} an hour across all ${KEYS_PER_DEVICE} keys; the address limit is
      ${REQUESTS_PER_MINUTE} requests a minute and covers every endpoint.
    </p>
  </section>

  <section id="clients">
    <h2>Clients and import</h2>
    <p>
      The collection and the OpenAPI document are generated from the same source as this page.
      Set <code>NOTIFI_KEY</code> and send.
    </p>
${CLIENTS.map(
  ([name, note, line]) => `    <h3>${name}</h3>
    <p>${escape(note)}</p>
    ${pre(line, 'bash')}`,
).join('\n')}
  </section>

  <section id="machine">
    <h2>Machine-readable</h2>
    <ul>
${resources
  .map((r) => `      <li><a href="${r.path}"><code>${r.path}</code></a> — ${escape(r.summary)}</li>`)
  .join('\n')}
    </ul>
    <p>
      Every page on this site is also served as Markdown: send
      <code>Accept: text/markdown</code> on the same URL, or append <code>.md</code>.
      <a href="https://github.com/notifi-it/notifi">The source</a> covers the app, the API and
      the cryptography.
    </p>
  </section>

  <section id="recipes">
    <h2>Recipes</h2>
    <p>
      The same request from everywhere it tends to get sent from — ${samples.length} of
      them, the same block the home page carries. Each one wants
      <code>NOTIFI_KEY</code> in the environment.
    </p>
${terminal()}
  </section>

  <p id="copystatus" role="status" aria-live="polite"
     style="position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap"></p>

  <section id="questions">
    <h2>Questions</h2>
    <p>
      The <a href="/faq">FAQ</a> covers cost, limits, what the server can read and what happens
      when you delete the app. Anything else goes to <a href="/contact">contact</a>.
    </p>
  </section>

</main>`;
}

export function docsStyle(): string {
  return `
.doc.api p.meta a{color:var(--muted);text-decoration:none}
.doc.api p.meta a:hover{color:var(--fg)}
.doc.api h3 .meta{font-weight:400;color:var(--dim);margin-left:8px}
.doc.api section{scroll-margin-top:76px}
.doc.api pre{
  font-family:var(--mono);font-size:12.5px;line-height:1.55;
  color:var(--fg);background:var(--surface);
  border:1px solid var(--line);border-radius:8px;
  padding:14px 16px;margin-top:14px;overflow-x:auto;
  white-space:pre;-webkit-text-size-adjust:100%;
}
.doc.api .tablewrap{overflow-x:auto;margin-top:14px;border:1px solid var(--line);border-radius:8px}
.doc.api table{border-collapse:collapse;width:100%;min-width:640px;font-size:13px}
.doc.api th,.doc.api td{
  text-align:left;vertical-align:top;padding:9px 14px;
  border-bottom:1px solid var(--line);
}
.doc.api thead th{
  font-family:var(--mono);font-size:11px;font-weight:600;
  letter-spacing:.14em;text-transform:uppercase;color:var(--dim);
  background:var(--surface);
}
.doc.api tbody tr:last-child td{border-bottom:0}
.doc.api td{color:var(--muted)}
.doc.api td:first-child{color:var(--fg);white-space:nowrap}
.doc.api ul{margin-top:14px}
`;
}
