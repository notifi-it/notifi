import { Hono } from 'hono';
import type { AppEnv } from '../types.js';

export const downloads = new Hono<AppEnv>();

const LATEST = 'https://github.com/notifi-it/notifi/releases/latest/download';

downloads.get('/download/mac', (c) => c.redirect(`${LATEST}/notifi.dmg`, 302));

downloads.get('/download/appcast.xml', (c) => c.redirect(`${LATEST}/appcast.xml`, 302));
