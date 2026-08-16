import type { LanguageCode } from '../languages.js';
import type { Translation } from '../types.js';
import { es } from './es.js';
import { de } from './de.js';
import { fr } from './fr.js';
import { it } from './it.js';

export const translations: Partial<Record<LanguageCode, Translation>> = { es, de, fr, it };
