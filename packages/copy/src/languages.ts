// The set of languages the product ships in. Adding one is a two-step change:
// add the code here, then add `src/translations/<code>.ts`. The generator refuses
// to run if a declared language is missing keys, so a half-translated language
// cannot ship silently — it fails the build instead.

export const LANGUAGE_CODES = ['en'] as const;
export type LanguageCode = (typeof LANGUAGE_CODES)[number];

/// The language the copy is written in. Every other language is a translation of
/// it, and a missing key falls back to it rather than rendering the key.
export const SOURCE_LANGUAGE: LanguageCode = 'en';

function isLanguageCode(value: string): value is LanguageCode {
  return (LANGUAGE_CODES as readonly string[]).includes(value);
}

/// Pick a language from an `Accept-Language` header. Quality values are honoured,
/// and a regional tag matches its base language (`pt-BR` matches `pt`) because a
/// reader who asked for one is better served by the other than by English.
export function negotiate(acceptLanguage: string | null | undefined): LanguageCode {
  if (!acceptLanguage) return SOURCE_LANGUAGE;

  const ranked = acceptLanguage
    .split(',')
    .map((part) => {
      const [tag = '', ...params] = part.trim().split(';');
      const q = params
        .map((p) => p.trim())
        .find((p) => p.startsWith('q='))
        ?.slice(2);
      return { tag: tag.trim().toLowerCase(), q: q === undefined ? 1 : Number(q) };
    })
    .filter((entry) => entry.tag.length > 0 && !Number.isNaN(entry.q) && entry.q > 0)
    .sort((a, b) => b.q - a.q);

  for (const { tag } of ranked) {
    if (isLanguageCode(tag)) return tag;
    const base = tag.split('-')[0];
    if (base !== undefined && isLanguageCode(base)) return base;
  }
  return SOURCE_LANGUAGE;
}
