import {
  ENDPOINT,
  IMAGE_MAX_MB,
  MESSAGE_MAX,
  ORIGIN,
  SENDS_PER_HOUR,
  TITLE_MAX,
  URL_MAX,
  errors,
  params,
} from './spec.js';
import { samples } from './samples.js';
import { escape } from './html.js';

const KEY = /\$?NOTIFI_KEY/g;

function markKeys(text: string): string {
  return text.replace(KEY, (hit) => `<span class="k">${hit}</span>`);
}

function markKeywords(text: string, keywords: string[]): string {
  let out = text;
  for (const word of keywords) {
    const found = new RegExp(`\\b${word}\\b`).exec(out);
    if (!found) continue;
    const at = found.index;
    out = `${out.slice(0, at)}<span class="f">${word}</span>${out.slice(at + word.length)}`;
  }
  return out;
}

export function highlight(code: string, keywords: string[] = []): string {
  const pieces = escape(code).split(/(&quot;[^\n]*?&quot;|`[^\n`]*?`)/g);
  const remaining = [...keywords];
  return pieces
    .map((piece, i) => {
      if (i % 2 === 1) return `<span class="s">${markKeys(piece)}</span>`;
      let out = markKeywords(piece, remaining);
      for (const word of remaining.slice()) {
        if (out.includes(`<span class="f">${word}</span>`)) {
          remaining.splice(remaining.indexOf(word), 1);
        }
      }
      return markKeys(out);
    })
    .join('');
}

const NOTES: Record<string, string> = {
  key: 'The key from the app. It picks which device gets the push. Send it as a header, <code>Authorization: Bearer nk_yourkey</code>, which keeps it out of logs; or pass it as this parameter.',
  title: `The notification title. Up to ${TITLE_MAX} characters.`,
  message: `The notification body. Markdown, up to ${MESSAGE_MAX.toLocaleString('en-GB')} characters. The push shows a short preview; the app renders the full text.`,
  link: `URL opened when the notification is tapped. Up to ${URL_MAX.toLocaleString('en-GB')} characters.`,
  image: `Image displayed with the notification. Must be <code>https</code>. PNG, JPEG or GIF, ${IMAGE_MAX_MB}&nbsp;MB max, URL up to ${URL_MAX.toLocaleString('en-GB')} characters.`,
  occurred_at:
    'When the event actually happened, as unix <em>milliseconds</em>, useful when a send is queued or retried. Only changes the timestamp shown in the app; defaults to when we receive the request.',
  is_critical:
    'Ask for a critical alert: it breaks through Focus and stays on the lock screen, but does not sound through silent mode. The key must also have <em>Critical alerts</em> switched on in the app; a send that asks without that arrives as an ordinary notification rather than failing, and the reply carries a <code>warning</code> saying so.',
};

function shortType(type: string): string {
  if (type.startsWith('string (uri)')) return 'URL';
  return type;
}

export function landingRows(): string {
  return params
    .map((p) => {
      const note = NOTES[p.name];
      if (note === undefined) throw new Error(`no landing note for ${p.name}`);
      const flag = p.required ? ' <span class="req">required</span>' : '';
      return `          <tr>
            <td>${p.name}${flag}</td>
            <td>${shortType(p.type)}</td>
            <td>${note}</td>
          </tr>`;
    })
    .join('\n');
}

export function landingTabs(): string {
  return samples
    .map((s, i) => {
      const selected = i === 0 ? 'true' : 'false';
      const label = s.label.replace(/ /g, '&nbsp;');
      return `      <button class="tab" role="tab" aria-selected="${selected}" aria-controls="p-${s.id}" id="t-${s.id}">${label}</button>`;
    })
    .join('\n');
}

export function landingPanels(): string {
  return samples
    .map((s, i) => {
      const hidden = i === 0 ? '' : ' hidden';
      return `      <div class="panel" id="p-${s.id}" role="tabpanel" tabindex="0" aria-labelledby="t-${s.id}" data-name="${escape(s.file)}"${hidden}>
<pre>${highlight(s.code, s.keywords ?? [])}</pre>
      </div>`;
    })
    .join('\n');
}

const NOTE_ERRORS = ['invalid_request', 'unknown_key', 'rate_limited'];

const NOTE_LABELS: Record<string, string> = {
  invalid_request: 'invalid parameters',
  unknown_key: 'unknown or revoked key',
  rate_limited: 'rate limited',
};

export function landingEndpoint(): string {
  return `    <p class="lede" style="margin-top:14px;margin-bottom:8px">
      <code>GET</code> or <code>POST</code> <code>${ORIGIN}${ENDPOINT}</code>
    </p>
    <p class="meta" style="margin-bottom:26px">
      JSON or form-encoded. Authenticate with <code>Authorization: Bearer &lt;key&gt;</code>,
      or pass <code>key</code> as a parameter. The header keeps it out of logs.
      Query parameters win over the body.
    </p>`;
}

export function landingNote(): string {
  const codes = NOTE_ERRORS.map((code) => {
    const row = errors.find((e) => e.code === code);
    if (!row) throw new Error(`no error ${code}`);
    return `<code>${row.status}</code> ${NOTE_LABELS[code]}`;
  }).join(' · ');
  return `    <p class="meta" style="margin-top:22px">
      ${SENDS_PER_HOUR} sends an hour, shared by every key on your device. Errors return JSON with a <code>code</code> and a readable
      <code>message</code>: ${codes}. <code>GET</code> works for a quick
      test; <code>POST</code> is recommended.
    </p>`;
}
