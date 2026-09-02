import {
  ENDPOINT,
  MESSAGE_MAX,
  ORIGIN,
  TITLE_MAX,
  URL_MAX,
  params,
} from './spec.js';
import { samples } from './samples.js';
import { escape } from './html.js';
import { brand } from './icons.js';
import { shikify, type Lang } from './shikify.js';

const KEY = /\$?NOTIFI_KEY/g;

function markKeys(text: string): string {
  return text.replace(KEY, (hit) => `<span class="k">${hit}</span>`);
}

export function highlight(code: string, lang: Lang): string {
  return markKeys(shikify(code, lang));
}

const NOTES: Record<string, string> = {
  key: 'The key from the app. It picks which device gets the push. Send it as a header, <code>Authorization: Bearer nk_yourkey</code>, which keeps it out of logs; or pass it as this parameter.',
  title: `The notification title. Up to ${TITLE_MAX} characters.`,
  message: `The notification body. Markdown, up to ${MESSAGE_MAX.toLocaleString('en-GB')} characters.`,
  link: `A link to a website or internal app. Up to ${URL_MAX.toLocaleString('en-GB')} characters.`,
  image: `Image displayed with the notification. URL up to ${URL_MAX.toLocaleString('en-GB')} characters.`,
  occurred_at:
    '<a href="https://currentmillis.com" class="src">Unix milliseconds</a>. Changes the timestamp shown in the app; defaults to when we receive the request.',
  is_critical:
    'Ask for a critical alert: it breaks through Focus and stays on the lock screen. The key must also have <em>Critical alerts</em> <a href="/docs#critical-alerts" class="src">switched on in the app</a>.',
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
  return tabRow('', samples);
}

export function landingPanels(): string {
  return samples
    .map((s, i) => {
      const hidden = i === 0 ? '' : ' hidden';
      return `      <div class="panel" id="p-${s.id}" role="tabpanel" tabindex="0" aria-labelledby="t-${s.id}" data-name="${escape(s.file)}" data-label="${escape(s.label)}"${hidden}>
<pre>${highlight(s.code, s.lang)}</pre>
      </div>`;
    })
    .join('\n');
}

export function landingEndpoint(): string {
  return `    <p class="lede no-reveal" style="margin-top:14px;margin-bottom:8px">
      <code>GET</code> or <code>POST</code> <code>${ORIGIN}${ENDPOINT}</code>
    </p>
    <p class="meta" style="margin-bottom:26px">
      JSON or form-encoded. Authenticate with <code>Authorization: Bearer &lt;key&gt;</code>,
      or pass <code>key</code> as a parameter.
      The full reference is at <a href="/docs" class="src">notifi.it/docs</a>.
    </p>`;
}

export interface Group {
  id: string;
  label: string;
  file: string;
  code: string;
  lang: Lang;
  icon?: string;
  group?: string;
}

function tabButton(prefix: string, item: Group, isSelected: boolean): string {
  const label = item.label.replace(/ /g, '&nbsp;');
  const glyph = item.icon ? brand(item.icon) : '';
  return `<button class="tab" role="tab" aria-selected="${isSelected}" aria-controls="${prefix}p-${item.id}" id="${prefix}t-${item.id}">${glyph}<span>${label}</span></button>`;
}

function tabRow(prefix: string, items: Group[]): string {
  const labels = [...new Set(items.map((i) => i.group).filter(Boolean))] as string[];
  if (labels.length === 0) {
    return items
      .map((item, i) => `      ${tabButton(prefix, item, i === 0)}`)
      .join('\n');
  }
  let seen = 0;
  return labels
    .map((label) => {
      const rows = items
        .filter((i) => i.group === label)
        .map((item) => `          ${tabButton(prefix, item, seen++ === 0)}`)
        .join('\n');
      return `      <div class="tabgroup" role="presentation">
        <span class="tabgroup-label" aria-hidden="true">${escape(label)}</span>
        <div class="tabgroup-items" role="presentation">
${rows}
        </div>
      </div>`;
    })
    .join('\n');
}

export function terminalGroup(prefix: string, aria: string, items: Group[]): string {
  const first = items[0];
  if (!first) throw new Error(`no items for ${prefix}`);
  const panels = items
    .map((item, i) => {
      const hidden = i === 0 ? '' : ' hidden';
      return `      <div class="panel" id="${prefix}p-${item.id}" role="tabpanel" tabindex="0" aria-labelledby="${prefix}t-${item.id}" data-name="${escape(item.file)}" data-label="${escape(item.label)}"${hidden}>
<pre>${highlight(item.code, item.lang)}</pre>
      </div>`;
    })
    .join('\n');
  return `    <div class="tabs" role="tablist" aria-label="${aria}">
${tabRow(prefix, items)}
    </div>

    <div class="term">
      <div class="term-bar">
        <span class="dot3"><i></i><i></i><i></i></span>
        <span class="term-title">${escape(first.file)}</span>
        <button class="copy" data-copy-panel aria-label="Copy the ${aria.toLowerCase()} shown">Copy</button>
      </div>
${panels}
    </div>`;
}

export function terminal(): string {
  return terminalGroup('', 'Examples', samples);
}
