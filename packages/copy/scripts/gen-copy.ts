// Writes the app's two generated copy files from packages/copy:
//
//   apps/app/Shared/Resources/Localizable.xcstrings  the string catalog
//   apps/app/Shared/Support/Copy.swift               typed accessors into it
//
// Swift cannot import the TypeScript, and hand-mirroring is what this package
// exists to stop: ContractModels.swift already proves that two files typecheck
// happily while saying different things. So both are generated, and `--check`
// regenerates them in memory and fails if what is on disk differs, which is what
// CI calls.
//
// The catalog is keyed by dotted path -- `inbox.deleteMessage`, not the English
// sentence. Keying by source text is Apple's default and means every wording fix
// invalidates every translation of it; keying by path means a wording fix is a
// wording fix. Entries are marked `extractionState: manual` because nothing in
// the Swift source is a literal for Xcode to find.
//
// Placeholders become positional format specifiers in first-appearance order, so
// a translator can reorder them. Plurals become a catalog variation, which is the
// only reason to have a catalog at all: the OS then applies the reader's own
// plural categories rather than English's two.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LANGUAGE_CODES, SOURCE_LANGUAGE, type LanguageCode } from '../src/languages.js';
import { copy } from '../src/strings.js';
import { translations } from '../src/translations/index.js';
import { isPlural, type Leaf, type Plural, type Tree } from '../src/types.js';

const here = dirname(fileURLToPath(import.meta.url));
const appRoot = join(here, '..', '..', '..', 'apps', 'app');
const catalogPath = join(appRoot, 'Shared', 'Resources', 'Localizable.xcstrings');
const swiftPath = join(appRoot, 'Shared', 'Support', 'Copy.swift');

const PLURAL_CATEGORIES = ['zero', 'one', 'two', 'few', 'many', 'other'] as const;

/// Namespaces the app has no use for, left out of its catalog and its Swift.
/// `api` is the server's own responses: the app shows the `message` the server
/// sent rather than a local copy of it, and the server picks that message's
/// language from the request's `Accept-Language`. Shipping a second translation
/// of those sentences inside the app would give the reader two, differing by
/// which one happened to answer.
const SERVER_ONLY = new Set(['api']);

interface Entry {
  path: string;
  /// Dotted path split for nesting: ['inbox', 'deleteMessage'].
  segments: string[];
  source: Leaf;
  /// Placeholder names in first-appearance order. A plural's own `{n}` is not
  /// among them -- it is the count argument, and always comes first.
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
      // A plural leaf holds nothing but its own count. Anything mixing a count
      // with other text composes an already-rendered count instead, so the
      // catalog never has to pluralise on one argument while formatting another.
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

/// Every declared language must translate every key, with the same placeholders.
/// A gap here is a sentence that would silently render in English, or a format
/// string that would drop an argument at runtime.
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

// --- string catalog -------------------------------------------------------

/// `{name}` becomes `%1$@`, in the order the source declares. A plural's count is
/// always `%lld` and always first, because a plural leaf has no other argument.
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
  entries = entries.filter((e) => !SERVER_ONLY.has(e.segments[0]!));
  // Sorted, so the file's order is a property of the key names and not of the
  // order somebody happened to add things to strings.ts.
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

// --- Swift ----------------------------------------------------------------

function upperFirst(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function swiftKey(path: string): string {
  return `"${path}"`;
}

/// Every accessor resolves through the catalog at the point of use rather than at
/// load, so a language change while the app is running is picked up. Extensions
/// get `Bundle.main` too -- their own bundle -- which is why the catalog is listed
/// in their target sources.
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
  const header = [
    '// Generated by packages/copy/scripts/gen-copy.ts. Do not edit.',
    '//',
    '// Every string here is written in packages/copy/src/strings.ts. Edit that file',
    '// and run `make gen-copy`, which rewrites this and Localizable.xcstrings together.',
    '// A hand edit here survives until the next run, and CI fails before then.',
    '//',
    '// The values are catalog lookups, so the OS resolves the reader\'s language and',
    '// its own plural rules. A counted string takes an Int and pluralises itself --',
    '// do not interpolate the number into a format yourself.',
    '',
    'import Foundation',
    '',
  ];
  const body: string[] = [];
  for (const [key, value] of Object.entries(copy as unknown as Tree)) {
    if (SERVER_ONLY.has(key)) continue;
    if (typeof value === 'object' && !isPlural(value)) {
      body.push(...emit(key, value as Tree, [key], '    '));
    }
  }
  return [...header, 'enum Copy {', ...body, '}', ''].join('\n');
}

// --- run ------------------------------------------------------------------

const entries: Entry[] = [];
collect(copy as unknown as Tree, [], entries);
checkTranslations(entries);

const outputs: Array<{ path: string; contents: string; label: string }> = [
  { path: catalogPath, contents: renderCatalog(entries), label: 'Localizable.xcstrings' },
  { path: swiftPath, contents: renderSwift(), label: 'Copy.swift' },
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
  console.log(`Generated copy is up to date (${entries.length} keys, ${LANGUAGE_CODES.length} language${LANGUAGE_CODES.length === 1 ? '' : 's'}).`);
} else {
  for (const { path, contents, label } of outputs) {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, contents);
    console.log(`Wrote ${label}`);
  }
}
