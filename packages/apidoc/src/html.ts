import { APP_STORE, EMAIL } from '@notifi/contract';
import {
  AUTH,
  INTEGRATION_SURFACE,
  OPERATION_ERRORS,
  ENDPOINT,
  EXAMPLE_IMAGE,
  EXAMPLE_KEY,
  EXAMPLE_LINK,
  KEY_PREFIX,
  KEYS_PER_DEVICE,
  MESSAGE_MAX,
  ORIGIN,
  REQUESTS_PER_MINUTE,
  SENDS_PER_HOUR,
  TITLE_MAX,
  errors,
  limits,
  params,
  resources,
} from './spec.js';
import { samples } from './samples.js';
import { terminalGroup } from './landing.js';
import { readFileSync } from 'node:fs';
import { icon } from './icons.js';
import type { Group } from './landing.js';

export function escape(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const PNG_IHDR_WIDTH_OFFSET = 16;
const PNG_DIMENSION_BYTES = 4;

export function pngSize(file: URL): { width: number; height: number } {
  const header = readFileSync(file).subarray(
    PNG_IHDR_WIDTH_OFFSET,
    PNG_IHDR_WIDTH_OFFSET + PNG_DIMENSION_BYTES * 2,
  );
  return { width: header.readUInt32BE(0), height: header.readUInt32BE(PNG_DIMENSION_BYTES) };
}

function figure(src: string, alt: string, caption: string): string {
  const { width, height } = pngSize(new URL(`../../../apps/api/public${src}`, import.meta.url));
  return `    <figure>
      <img src="${src}" width="${width}" height="${height}" alt="${escape(alt)}">
      <figcaption>${escape(caption)}</figcaption>
    </figure>`;
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
  -d "message=Your first notification." \\
  -d "link=${EXAMPLE_LINK}" \\
  -d "image=${EXAMPLE_IMAGE}"`;

const WARNINGS_RESPONSE = `HTTP/1.1 202 Accepted
Content-Type: application/json; charset=utf-8

{"ok":true,"warnings":["Title shortened to ${TITLE_MAX} characters."]}`;

const RAW_REQUEST = `POST /send HTTP/1.1
Host: notifi.it
Authorization: Bearer ${EXAMPLE_KEY}
Content-Type: application/json
Accept-Language: en-GB

{"title":"Hello from notifi","message":"Your first notification.","link":"${EXAMPLE_LINK}","image":"${EXAMPLE_IMAGE}"}`;

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
    lang: 'http',
    code: responseBody(202, 'Accepted', '{"ok":true}'),
  },
  ...errors
    .filter((e) => OPERATION_ERRORS.includes(e.code))
    .map((e): Group => ({
      id: String(e.status),
      label: String(e.status),
      file: e.code,
      lang: 'http',
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
    lang: 'bash',
    icon: 'siPostman',
    label: 'Postman',
    file: 'postman',
    code: `# Import → Link, then paste this. Postman keeps it in sync from there.
${ORIGIN}/notifi.postman_collection.json`,
  },
  {
    id: 'bruno',
    lang: 'bash',
    icon: 'siBruno',
    label: 'Bruno',
    file: 'bruno',
    code: `# Drop the .bru straight into a collection folder,
# or use Import → Postman Collection with the URL above.
curl -O ${ORIGIN}/notifi.bru`,
  },
  {
    id: 'insomnia',
    lang: 'bash',
    icon: 'siInsomnia',
    label: 'Insomnia',
    file: 'insomnia',
    code: `# Import From → URL takes either the OpenAPI document
# or the Postman collection.
${ORIGIN}/openapi.json`,
  },
  {
    id: 'httpie',
    lang: 'bash',
    icon: 'siHttpie',
    label: 'HTTPie',
    file: 'httpie',
    code: `# No import needed.
http -f POST ${ORIGIN}${ENDPOINT} \\
  "Authorization:Bearer $NOTIFI_KEY" \\
  title="Hello from notifi" \\
  message="Your first notification." \\
  link="${EXAMPLE_LINK}" \\
  image="${EXAMPLE_IMAGE}"`,
  },
  {
    id: 'generate',
    lang: 'bash',
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
  ['machine', 'For the bots'],
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
  return `<main id="main" class="wrap doc api">

  <p class="eyebrow">API reference</p>
  <h1>notifi API documentation</h1>
  <p class="lede">
    One endpoint, seven parameters. This page, <a href="/openapi.json"><code>/openapi.json</code></a>
    and the client collections are generated from one source, so they cannot disagree.
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
      Install notifi on <a href="${APP_STORE}">iPhone or iPad</a>
      or <a href="/download/mac">Mac</a>, allow notifications, open Keys and copy the
      <code>Device</code> key. It starts with <code>${KEY_PREFIX}</code>.
    </p>
    ${pre(QUICKSTART, 'bash')}
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
            <td><code>Authorization: Bearer ${EXAMPLE_KEY}</code></td>
            <td>${escape(AUTH.bearerDescription)}</td>
          </tr>
          <tr>
            <td>Parameter</td>
            <td><code>key=${EXAMPLE_KEY}</code></td>
            <td>${escape(AUTH.parameterDescription)}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>

  <section id="request">
    <h2>Request</h2>
    <p>
      <code>POST ${ORIGIN}${ENDPOINT}</code> as JSON, form-encoded or multipart.
      <code>GET</code> takes the same parameters in the query string, for quick tests only:
      rotate the key afterwards. Query parameters win over body fields.
    </p>
    ${pre(RAW_REQUEST, 'http')}
  </section>

  <section id="parameters">
    <h2>Parameters</h2>
    <p>
      <code>key</code> is required unless the request carries a bearer token.
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
      <code>202</code> means accepted. Delivery is best-effort, per the
      <a href="/terms">terms</a>. Every status the endpoint can answer:
    </p>
${terminalGroup('r-', 'Responses', RESPONSES)}
    <p>
      A <code>warnings</code> array is present only when the notification was delivered
      differently from what was asked: a cropped title or body. The status is still
      <code>202</code>; the notification was sent, in the altered form each warning describes.
    </p>
${pre(WARNINGS_RESPONSE, 'http')}

    <h3>Over-length text is cropped</h3>
    <p>
      A title over ${TITLE_MAX} characters or a body over ${MESSAGE_MAX} is cropped, with a
      warning. <strong>Reject invalid sends</strong>, in the app's Settings, answers
      <code>422 invalid_content</code> instead and stores nothing. It is off by default.
    </p>
${figure(
  '/shots/settings-reject-invalid-sends.png',
  'The Settings screen, showing the Reject invalid sends switch turned off.',
  'Settings → Permissions → Reject invalid sends. Off by default.',
)}

    <h3 id="urgent-alerts">Urgent alerts are granted per key</h3>
    <p>
      <code>is_critical=1</code> asks for a Time Sensitive notification, which breaks through
      Focus. It works only if the key has <strong>Urgent alerts</strong> on, in the app.
      Otherwise the notification is delivered normally.
    </p>
${figure(
  '/shots/key-urgent-alerts.png',
  "A key's screen in the app, showing the Urgent alerts switch turned on.",
  'Keys → a key → Urgent alerts. Per key.',
)}

    <h3 id="links">A link does not have to be https</h3>
    <p>
      <code>link</code> accepts any URL scheme, so it can deep-link into another app. The app
      opens only <code>https</code> until <strong>Open any link</strong> is switched on for the
      key. Only the person holding the device can switch it on.
    </p>
${figure(
  '/shots/key-open-any-link.png',
  "A key's screen in the app, showing the Open any link switch.",
  'Keys → a key → Open any link. Off, only https opens.',
)}
  </section>

  <section id="errors">
    <h2>Errors</h2>
    <p>
      Every error nests the code one level down: read <code>error.code</code>. The
      <code>message</code> is translated and meant for a human, so match on the code.
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
      A <code>429</code> carries <code>Retry-After</code> in seconds.
    </p>
  </section>

  <section id="clients">
    <h2>Clients and import</h2>
    <p>
      Generated from the same source as this page. Set <code>NOTIFI_KEY</code> and send.
    </p>
${terminalGroup('c-', 'Clients', CLIENTS)}
  </section>

  <section id="machine">
    <h2>For the bots</h2>
    <ul>
${resources
  .map((r) => `      <li><a href="${r.path}"><code>${r.path}</code></a> — ${escape(r.summary)}</li>`)
  .join('\n')}
    </ul>
    <p>
      Every page is also served as Markdown: send <code>Accept: text/markdown</code>, or
      append <code>.md</code>.
    </p>
    <p>${escape(INTEGRATION_SURFACE)}</p>
  </section>

  <section id="recipes">
    <h2>Recipes</h2>
    <p>
      The same request in ${samples.length} languages and tools. Each expects
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
      when you delete the app. If yours isn't there, write to <a href="mailto:${EMAIL}">${EMAIL}</a>.
    </p>
  </section>

</main>`;
}
