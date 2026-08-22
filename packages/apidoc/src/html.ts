import {
  AUTH,
  INTEGRATION_SURFACE,
  OPERATION_ERRORS,
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
import { terminalGroup } from './landing.js';
import { icon } from './icons.js';
import type { Group } from './landing.js';

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
  -d "title=Hello from notifi" \\
  -d "message=Your first notification."`;

const RAW_REQUEST = `POST /send HTTP/1.1
Host: notifi.it
Authorization: Bearer nk_yourkey
Content-Type: application/json
Accept-Language: en-GB

{"title":"Hello from notifi","message":"Your first notification.","link":"https://notifi.it/docs"}`;

function responseBody(status: number, reason: string, body: string, retry = false): string {
  const head = [
    `HTTP/1.1 ${status} ${reason}`,
    'Content-Type: application/json; charset=utf-8',
    ...(retry ? ['Retry-After: 42'] : []),
  ].join('\n');
  return `${head}\n\n${body}`;
}

const RESPONSES: Group[] = [
  {
    id: '202',
    label: '202',
    file: 'accepted',
    code: responseBody(202, 'Accepted', '{"ok":true}'),
  },
  ...errors
    .filter((e) => OPERATION_ERRORS.includes(e.code))
    .map((e): Group => ({
      id: String(e.status),
      label: String(e.status),
      file: e.code,
      code: responseBody(
        e.status,
        e.reason,
        `{"error":{"code":"${e.code}","message":"${e.message}"}}`,
        e.code === 'rate_limited',
      ),
    })),
];

const CLIENTS: Group[] = [
  {
    id: 'postman',
    icon: 'siPostman',
    label: 'Postman',
    file: 'postman',
    code: `# Import → Link, then paste this. Postman keeps it in sync from there.
${ORIGIN}/notifi.postman_collection.json`,
  },
  {
    id: 'bruno',
    icon: 'siBruno',
    label: 'Bruno',
    file: 'bruno',
    code: `# Drop the .bru straight into a collection folder,
# or use Import → Postman Collection with the URL above.
curl -O ${ORIGIN}/notifi.bru`,
  },
  {
    id: 'insomnia',
    icon: 'siInsomnia',
    label: 'Insomnia',
    file: 'insomnia',
    code: `# Import From → URL takes either the OpenAPI document
# or the Postman collection.
${ORIGIN}/openapi.json`,
  },
  {
    id: 'httpie',
    icon: 'siHttpie',
    label: 'HTTPie',
    file: 'httpie',
    code: `# No import needed.
http -f POST ${ORIGIN}${ENDPOINT} \\
  "Authorization:Bearer $NOTIFI_KEY" \\
  title="Hello from notifi" \\
  message="Your first notification."`,
  },
  {
    id: 'generate',
    icon: 'siOpenapiinitiative',
    label: 'Client generator',
    file: 'openapi-generator',
    code: `# Any generator that reads OpenAPI 3.1.
openapi-generator-cli generate \\
  -i ${ORIGIN}/openapi.json \\
  -g typescript-fetch \\
  -o ./notifi`,
  },
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
  return SECTIONS.map(([id, label]) => `<a href="#${id}">${label}</a>`).join('\n    ');
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

  <p class="meta actions screen-only">
    <a href="/docs.md">${icon('file')}<span>View as Markdown</span></a>
    <button class="linkish" id="copymd" data-src="/docs.md">${icon('copy')}<span>Copy page as Markdown</span></button>
  </p>

  <div class="toc">
    <p class="meta">${contents()}</p>
  </div>

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
      delivered — delivery is best-effort, as the <a href="/terms">terms</a> describe. Every
      status the endpoint can answer with is here:
    </p>
${terminalGroup('r-', 'Responses', RESPONSES)}
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
      The collection and the OpenAPI document are generated from the same source
      as this page. Set <code>NOTIFI_KEY</code> and send.
    </p>
${terminalGroup('c-', 'Clients', CLIENTS)}
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
    <p>${escape(INTEGRATION_SURFACE)}</p>
  </section>

  <section id="recipes">
    <h2>Recipes</h2>
    <p>
      The same request from everywhere it tends to get sent from — ${samples.length} of
      them, the same block the home page carries. Each one wants
      <code>NOTIFI_KEY</code> in the environment.
    </p>
${terminalGroup('', 'Examples', samples)}
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
