export const LANGUAGE_CODES = ['en'] as const;
export type LanguageCode = (typeof LANGUAGE_CODES)[number];

export const SOURCE_LANGUAGE: LanguageCode = 'en';

function isLanguageCode(value: string): value is LanguageCode {
  return (LANGUAGE_CODES as readonly string[]).includes(value);
}

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
