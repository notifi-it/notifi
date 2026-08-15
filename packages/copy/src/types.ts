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

export type Translation = Record<string, Leaf>;
