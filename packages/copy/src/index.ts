import { LANGUAGE_CODES, negotiate, SOURCE_LANGUAGE, type LanguageCode } from './languages.js';
import { copy, type Strings } from './strings.js';
import { translations } from './translations/index.js';
import { isPlural, type Leaf, type Tree } from './types.js';

export { copy, LANGUAGE_CODES, negotiate, SOURCE_LANGUAGE };
export type { LanguageCode, Strings };
export type { Leaf, Plural, Translation, Tree } from './types.js';

export function fmt(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (whole, name: string) =>
    name in vars ? String(vars[name]) : whole,
  );
}

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
