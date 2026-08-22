import { Hono } from 'hono';
import type { AppEnv } from '../types.js';

export const downloads = new Hono<AppEnv>();

const RELEASES = 'https://github.com/notifi-it/notifi/releases';

async function latestTag(): Promise<string | null> {
  try {
    const res = await fetch(`${RELEASES}/latest`, {
      redirect: 'manual',
      signal: AbortSignal.timeout(3000),
      cf: { cacheEverything: true, cacheTtl: 300 },
    });
    return res.headers.get('location')?.match(/\/releases\/tag\/(v[^/?#]+)$/)?.[1] ?? null;
  } catch {
    return null;
  }
}

downloads.get('/download/mac', async (c) => {
  const tag = await latestTag();
  if (!tag) return c.redirect(`${RELEASES}/latest`, 302);
  return c.redirect(`${RELEASES}/download/${tag}/notifi-${tag.slice(1)}.dmg`, 302);
});

downloads.get('/download/appcast.xml', (c) =>
  c.redirect(`${RELEASES}/latest/download/appcast.xml`, 302),
);
