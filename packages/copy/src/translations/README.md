# Translations

One file per language, named for its code in `src/languages.ts`, exporting a flat
map of dotted key to translated string:

```ts
import type { Translation } from '../types.js';

export const fr: Translation = {
  'common.cancel': 'Annuler',
  'inbox.count': { one: '1 notification', other: '{n} notifications' },
};
```

Rules the generator enforces, so none of them can be got wrong quietly:

- A language listed in `LANGUAGE_CODES` must have a file, and that file must
  cover every key in `src/strings.ts`. A missing key fails `make gen-copy`.
- A translated value must carry the same `{placeholders}` as the source. Dropping
  one silently loses whatever it was naming; adding one renders as itself.
- A key that is a `plural(...)` in the source must be a plural object here, and
  must fill in the plural categories its own language uses. English needs `one`
  and `other`; a language needing `few` or `many` supplies them.

There is no machine translation step. An untranslated language is a language that
is not listed.
