import { createHighlighterCoreSync } from 'shiki/core';
import { createJavaScriptRegexEngine } from 'shiki/engine/javascript';
import bash from 'shiki/langs/bash.mjs';
import go from 'shiki/langs/go.mjs';
import http from 'shiki/langs/http.mjs';
import ini from 'shiki/langs/ini.mjs';
import java from 'shiki/langs/java.mjs';
import javascript from 'shiki/langs/javascript.mjs';
import jsonc from 'shiki/langs/jsonc.mjs';
import php from 'shiki/langs/php.mjs';
import python from 'shiki/langs/python.mjs';
import ruby from 'shiki/langs/ruby.mjs';
import rust from 'shiki/langs/rust.mjs';
import swift from 'shiki/langs/swift.mjs';
import yaml from 'shiki/langs/yaml.mjs';

export type Lang =
  | 'bash'
  | 'go'
  | 'http'
  | 'ini'
  | 'java'
  | 'javascript'
  | 'jsonc'
  | 'php'
  | 'python'
  | 'ruby'
  | 'rust'
  | 'swift'
  | 'yaml';

const PLAIN = '#000000';
const COMMENT = '#000001';
const STRING = '#000002';
const KEYWORD = '#000003';
const FUNC = '#000004';
const NUMBER = '#000005';

const CLASSES: Record<string, string> = {
  [COMMENT]: 'c',
  [STRING]: 's',
  [KEYWORD]: 'f',
  [FUNC]: 'fn',
  [NUMBER]: 'n',
};

const marker = {
  name: 'marker',
  settings: [
    { settings: { foreground: PLAIN } },
    {
      scope: ['comment', 'punctuation.definition.comment'],
      settings: { foreground: COMMENT },
    },
    {
      scope: ['string', 'punctuation.definition.string'],
      settings: { foreground: STRING },
    },
    {
      scope: ['string.unquoted'],
      settings: { foreground: PLAIN },
    },
    {
      scope: [
        'keyword.control',
        'keyword.other',
        'keyword.function',
        'keyword.declaration',
        'storage.type',
        'storage.modifier',
      ],
      settings: { foreground: KEYWORD },
    },
    {
      scope: [
        'entity.name.function',
        'support.function',
        'meta.function-call.generic',
      ],
      settings: { foreground: FUNC },
    },
    {
      scope: ['constant.numeric', 'constant.language'],
      settings: { foreground: NUMBER },
    },
  ],
};

const highlighter = createHighlighterCoreSync({
  themes: [marker],
  langs: [
    bash,
    go,
    http,
    ini,
    java,
    javascript,
    jsonc,
    php,
    python,
    ruby,
    rust,
    swift,
    yaml,
  ],
  engine: createJavaScriptRegexEngine({ forgiving: true }),
});

function esc(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export function shikify(code: string, lang: Lang): string {
  const lines = highlighter.codeToTokensBase(code, { lang, theme: 'marker' });
  return lines
    .map((line) => {
      let out = '';
      let cls = '';
      let run = '';
      const flush = () => {
        if (!run) return;
        out += cls ? `<span class="${cls}">${esc(run)}</span>` : esc(run);
        run = '';
      };
      for (const token of line) {
        const next = CLASSES[token.color ?? PLAIN] ?? '';
        if (next !== cls) {
          flush();
          cls = next;
        }
        run += token.content;
      }
      flush();
      return out;
    })
    .join('\n');
}
