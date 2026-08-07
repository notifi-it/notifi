/// A value that varies by count. English needs only these two cases; a language
/// with more gets them in its own translation file, keyed by CLDR plural category.
export interface Plural {
  one: string;
  other: string;
  zero?: string;
  two?: string;
  few?: string;
  many?: string;
}

export type Leaf = string | Plural;
export type Tree = { [key: string]: Leaf | Tree };

export function isPlural(value: unknown): value is Plural {
  return typeof value === 'object' && value !== null && 'other' in value;
}

/// A translation file: every key of the source tree, flattened to dots, so a
/// translator sees `inbox.deleteMessage` and a sentence and nothing else.
export type Translation = Record<string, Leaf>;
