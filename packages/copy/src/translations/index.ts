// Every language but the source one. See README.md for the file format.
//
// Empty today: the product ships in English, and a language nobody has
// translated is a language that is not listed in `LANGUAGE_CODES`.

import type { LanguageCode } from '../languages.js';
import type { Translation } from '../types.js';

export const translations: Partial<Record<LanguageCode, Translation>> = {};
