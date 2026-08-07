// Copy, in one place, for the API, the app and anything else that speaks to a
// person.
//
// - `copy` is the source language. The Swift app never reads this: it reads the
//   string catalog and Swift file that `scripts/gen-copy.ts` writes, so the OS
//   resolves the reader's language and its own plural rules.
// - `copyFor(...)` is for the server, which has no reader locale of its own and
//   must be told one — from `Accept-Language`, per request.
//
// With one language shipping, `copyFor` returns the source tree unchanged. It
// exists anyway because the alternative is discovering every call site that
// assumed English on the day a second language lands.

import { LANGUAGE_CODES, negotiate, SOURCE_LANGUAGE, type LanguageCode } from './languages.js';
import { copy, type Strings } from './strings.js';
import { translations } from './translations/index.js';
import { isPlural, type Leaf, type Tree } from './types.js';

export { copy, LANGUAGE_CODES, negotiate, SOURCE_LANGUAGE };
export type { LanguageCode, Strings };
export type { Leaf, Plural, Translation, Tree } from './types.js';

/** Substitute `{name}` placeholders. Missing keys are left in place rather than
 *  rendered as "undefined", so a mistake shows up as the placeholder itself. */
export function fmt(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (whole, name: string) =>
    name in vars ? String(vars[name]) : whole,
  );
}

/** Pick the case of a plural for a count, in the source language's rules. Other
 *  languages resolve on the client, where the OS knows their categories; this is
 *  only for the server, which formats English. */
export function plural(leaf: Leaf, n: number): string {
  if (!isPlural(leaf)) return leaf;
  return fmt(n === 1 ? leaf.one : leaf.other, { n });
}

function overlay(tree: Tree, prefix: string, flat: Record<string, Leaf>): Tree {
  const out: Tree = {};
  for (const [key, value] of Object.entries(tree)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (typeof value === 'object' && !isPlural(value)) {
      out[key] = overlay(value as Tree, path, flat);
    } else {
      out[key] = flat[path] ?? value;
    }
  }
  return out;
}

const built = new Map<LanguageCode, Strings>();

/** The copy tree in one language. Accepts a language code or a raw
 *  `Accept-Language` header; anything unrecognised falls back to the source
 *  language rather than throwing, because a request with an odd header still
 *  deserves an answer. */
export function copyFor(language: LanguageCode | string | null | undefined): Strings {
  const code = negotiate(typeof language === 'string' ? language : undefined);
  if (code === SOURCE_LANGUAGE) return copy;

  const cached = built.get(code);
  if (cached) return cached;

  const flat = translations[code] ?? {};
  const merged = overlay(copy as unknown as Tree, '', flat) as unknown as Strings;
  built.set(code, merged);
  return merged;
}
