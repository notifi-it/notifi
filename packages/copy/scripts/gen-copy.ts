import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LANGUAGE_CODES, SOURCE_LANGUAGE, type LanguageCode } from '../src/languages.js';
import { copyFor } from '../src/index.js';
import { copy } from '../src/strings.js';
import { translations } from '../src/translations/index.js';
import { isPlural, type Leaf, type Plural, type Tree } from '../src/types.js';

const here = dirname(fileURLToPath(import.meta.url));
const appRoot = join(here, '..', '..', '..', 'apps', 'app');
const catalogPath = join(appRoot, 'Shared', 'Resources', 'Localizable.xcstrings');
const swiftPath = join(appRoot, 'Shared', 'Support', 'Copy.swift');
const captionsPath = join(appRoot, 'fastlane', 'screenshot-copy.json');

const PLURAL_CATEGORIES = ['zero', 'one', 'two', 'few', 'many', 'other'] as const;

const NOT_IN_APP = new Set(['api', 'store']);

interface Entry {
  path: string;
  segments: string[];
  source: Leaf;
  params: string[];
  isPlural: boolean;
}

function placeholders(value: string): string[] {
  const seen: string[] = [];
  for (const m of value.matchAll(/\{(\w+)\}/g)) {
    const name = m[1]!;
    if (!seen.includes(name)) seen.push(name);
  }
  return seen;
}

function fail(message: string): never {
  console.error(message);
  process.exit(1);
}

function collect(tree: Tree, prefix: string[], out: Entry[]): void {
  for (const [key, value] of Object.entries(tree)) {
    const segments = [...prefix, key];
    if (typeof value === 'object' && !isPlural(value)) {
      collect(value as Tree, segments, out);
      continue;
    }
    const path = segments.join('.');
    if (isPlural(value)) {
      for (const category of PLURAL_CATEGORIES) {
        const text = value[category];
        if (text === undefined) continue;
        const extra = placeholders(text).filter((p) => p !== 'n');
        if (extra.length > 0) {
          fail(`${path}: a plural may only use {n}, but ${category} uses {${extra[0]}}.`);
        }
      }
      if (!placeholders(value.other).includes('n')) {
        fail(`${path}: the "other" case of a plural must use {n}.`);
      }
      out.push({ path, segments, source: value, params: [], isPlural: true });
    } else {
      out.push({ path, segments, source: value, params: placeholders(value), isPlural: false });
    }
  }
}

function checkTranslations(entries: Entry[]): void {
  for (const code of LANGUAGE_CODES) {
    if (code === SOURCE_LANGUAGE) continue;
    const flat = translations[code];
    if (!flat) fail(`${code} is declared in LANGUAGE_CODES but has no translation file.`);

    for (const entry of entries) {
      const value = flat[entry.path];
      if (value === undefined) fail(`${code} is missing ${entry.path}.`);
      if (entry.isPlural !== isPlural(value)) {
        fail(`${code}: ${entry.path} must be ${entry.isPlural ? 'a plural' : 'a string'}.`);
      }
      const texts: string[] = isPlural(value)
        ? PLURAL_CATEGORIES.flatMap((c) => {
            const text: string | undefined = value[c];
            return text === undefined ? [] : [text];
          })
        : [value];
      for (const text of texts) {
        const expected = entry.isPlural ? ['n'] : entry.params;
        for (const name of expected) {
          if (entry.isPlural && !placeholders(text).includes('n') && text === (value as Plural).one)
            continue;
          if (!placeholders(text).includes(name)) {
            fail(`${code}: ${entry.path} is missing the {${name}} placeholder.`);
          }
        }
        for (const name of placeholders(text)) {
          if (!expected.includes(name)) {
            fail(`${code}: ${entry.path} has a {${name}} placeholder the source does not.`);
          }
        }
      }
    }
  }
}

function toFormat(text: string, params: string[], isPluralLeaf: boolean): string {
  let out = text;
  if (isPluralLeaf) return out.split('{n}').join('%lld');
  params.forEach((name, index) => {
    out = out.split(`{${name}}`).join(`%${index + 1}$@`);
  });
  return out;
}

interface CatalogUnit {
  state: string;
  value: string;
}

function localization(entry: Entry, value: Leaf): unknown {
  if (isPlural(value)) {
    const variations: Record<string, { stringUnit: CatalogUnit }> = {};
    for (const category of PLURAL_CATEGORIES) {
      const text = value[category];
      if (text === undefined) continue;
      variations[category] = {
        stringUnit: { state: 'translated', value: toFormat(text, [], true) },
      };
    }
    return { variations: { plural: variations } };
  }
  return {
    stringUnit: { state: 'translated', value: toFormat(value, entry.params, false) },
  };
}

function renderCatalog(entries: Entry[]): string {
  const strings: Record<string, unknown> = {};
  entries = entries.filter((e) => !NOT_IN_APP.has(e.segments[0]!));
  for (const entry of [...entries].sort((a, b) => a.path.localeCompare(b.path))) {
    const localizations: Record<string, unknown> = {
      [SOURCE_LANGUAGE]: localization(entry, entry.source),
    };
    for (const code of LANGUAGE_CODES) {
      if (code === SOURCE_LANGUAGE) continue;
      const value = translations[code]?.[entry.path];
      if (value !== undefined) localizations[code] = localization(entry, value);
    }
    strings[entry.path] = { extractionState: 'manual', localizations };
  }
  return `${JSON.stringify({ sourceLanguage: SOURCE_LANGUAGE, strings, version: '1.0' }, null, 2)}\n`;
}

function upperFirst(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function swiftKey(path: string): string {
  return `"${path}"`;
}

function accessor(entry: Entry): string {
  const key = swiftKey(entry.path);
  const lookup = `NSLocalizedString(${key}, comment: "")`;

  if (entry.isPlural) {
    return `static func ${last(entry)}(_ n: Int) -> String { String.localizedStringWithFormat(${lookup}, n) }`;
  }
  if (entry.params.length === 0) {
    return `static var ${last(entry)}: String { ${lookup} }`;
  }
  const signature = entry.params.map((p) => `_ ${p}: String`).join(', ');
  const args = entry.params.join(', ');
  return `static func ${last(entry)}(${signature}) -> String { String.localizedStringWithFormat(${lookup}, ${args}) }`;
}

function last(entry: Entry): string {
  return entry.segments[entry.segments.length - 1]!;
}

function emit(name: string, tree: Tree, prefix: string[], indent: string): string[] {
  const lines = [`${indent}enum ${upperFirst(name)} {`];
  const inner = `${indent}    `;
  for (const [key, value] of Object.entries(tree)) {
    const segments = [...prefix, key];
    if (typeof value === 'object' && !isPlural(value)) {
      lines.push(...emit(key, value as Tree, segments, inner));
      continue;
    }
    const entry: Entry = {
      path: segments.join('.'),
      segments,
      source: value,
      params: isPlural(value) ? [] : placeholders(value),
      isPlural: isPlural(value),
    };
    lines.push(inner + accessor(entry));
  }
  lines.push(`${indent}}`);
  return lines;
}

function renderSwift(): string {
  const header = ['import Foundation', ''];
  const body: string[] = [];
  for (const [key, value] of Object.entries(copy as unknown as Tree)) {
    if (NOT_IN_APP.has(key)) continue;
    if (typeof value === 'object' && !isPlural(value)) {
      body.push(...emit(key, value as Tree, [key], '    '));
    }
  }
  return [...header, 'enum Copy {', ...body, '}', ''].join('\n');
}

const STORE_LOCALES: Record<LanguageCode, string> = {
  en: 'en-GB',
  es: 'es-ES',
  de: 'de-DE',
  fr: 'fr-FR',
  it: 'it',
};

const STORE_SHARED: Record<string, string> = {
  'name.txt': 'notifi',
  'marketing_url.txt': 'https://notifi.it',
  'privacy_url.txt': 'https://notifi.it/privacy',
  'support_url.txt': 'https://notifi.it',
};

const STORE_LIMITS: Record<string, number> = {
  'subtitle.txt': 30,
  'promotional_text.txt': 170,
  'keywords.txt': 100,
  'description.txt': 4000,
  'release_notes.txt': 4000,
};

function storeOutputs(): Array<{ path: string; contents: string; label: string }> {
  const out: Array<{ path: string; contents: string; label: string }> = [];
  const captions: Record<string, Record<string, string>> = {};

  for (const code of LANGUAGE_CODES) {
    const locale = STORE_LOCALES[code];
    const s = copyFor(code).store;
    const dir = join(appRoot, 'fastlane', 'metadata', locale);

    const files: Record<string, string> = {
      ...STORE_SHARED,
      'subtitle.txt': s.subtitle,
      'promotional_text.txt': s.promotionalText,
      'keywords.txt': s.keywords,
      'description.txt': s.description,
      'release_notes.txt': s.releaseNotes,
    };

    for (const [file, value] of Object.entries(files)) {
      const limit = STORE_LIMITS[file];
      if (limit !== undefined && value.trimEnd().length > limit) {
        fail(`${code}: store ${file} is ${value.trimEnd().length} characters, over the App Store limit of ${limit}.`);
      }
      out.push({
        path: join(dir, file),
        contents: value.endsWith('\n') ? value : `${value}\n`,
        label: `fastlane/metadata/${locale}/${file}`,
      });
    }

    captions[locale] = {
      inboxTitle: s.shotInboxTitle,
      inboxBody: s.shotInboxBody,
      messageTitle: s.shotMessageTitle,
      messageBody: s.shotMessageBody,
      keysTitle: s.shotKeysTitle,
      keysBody: s.shotKeysBody,
    };
  }

  out.push({
    path: captionsPath,
    contents: `${JSON.stringify(captions, null, 2)}\n`,
    label: 'fastlane/screenshot-copy.json',
  });
  return out;
}

const entries: Entry[] = [];
collect(copy as unknown as Tree, [], entries);
checkTranslations(entries);

const outputs: Array<{ path: string; contents: string; label: string }> = [
  { path: catalogPath, contents: renderCatalog(entries), label: 'Localizable.xcstrings' },
  { path: swiftPath, contents: renderSwift(), label: 'Copy.swift' },
  ...storeOutputs(),
];

if (process.argv.includes('--check')) {
  for (const { path, contents, label } of outputs) {
    let onDisk: string;
    try {
      onDisk = readFileSync(path, 'utf8');
    } catch {
      fail(`${label} is missing. Run \`make gen-copy\`.`);
    }
    if (onDisk !== contents) fail(`${label} is out of date with packages/copy. Run \`make gen-copy\`.`);
  }
  const languageCount: number = LANGUAGE_CODES.length;
  console.log(`Generated copy is up to date (${entries.length} keys, ${languageCount} language${languageCount === 1 ? '' : 's'}).`);
} else {
  for (const { path, contents, label } of outputs) {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, contents);
    console.log(`Wrote ${label}`);
  }
}
