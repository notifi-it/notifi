import { Hono } from 'hono';
import { errBody, t } from '../lib/respond.js';
import type { AppEnv } from '../types.js';

export const downloads = new Hono<AppEnv>();

/// Objects are stored under their real versioned name, e.g. notifi-1.2.0.dmg,
/// so a build is never overwritten and Sparkle can keep pointing at the exact
/// version it shipped an appcast entry for. `latest` is a pointer object whose
/// body is just the key of the current build, updated when a release is cut.
const LATEST_POINTER = 'mac/latest';

function assetHeaders(obj: R2ObjectBody, filename: string): Headers {
  const h = new Headers();
  obj.writeHttpMetadata(h);
  h.set('etag', obj.httpEtag);
  // Versioned filenames never change contents, so they can be cached hard.
  h.set('cache-control', 'public, max-age=31536000, immutable');
  h.set('content-disposition', `attachment; filename="${filename}"`);
  return h;
}

/// /download/mac resolves the pointer and redirects, so the URL on the website
/// never has to change when a version ships. 302 rather than 301: the target
/// moves every release, and a permanent redirect would be cached against us.
downloads.get('/download/mac', async (c) => {
  const pointer = await c.env.DOWNLOADS.get(LATEST_POINTER);
  if (!pointer) {
    return c.json(errBody('not_found', t(c).api.noMacBuild), 404);
  }
  const key = (await pointer.text()).trim();
  return c.redirect(`/download/${key.replace(/^mac\//, '')}`, 302);
});

/// Sparkle's feed. It sits next to the builds it describes rather than on the
/// GitHub release, because the repo is private and a release asset would need a
/// token the updater has no way to carry. Cached for minutes, not a year: this
/// object is overwritten on every release, unlike the versioned DMGs.
downloads.get('/download/appcast.xml', async (c) => {
  const obj = await c.env.DOWNLOADS.get('mac/appcast.xml');
  if (!obj) {
    return c.json(errBody('not_found', t(c).api.noMacBuild), 404);
  }
  return new Response(obj.body, {
    headers: {
      'content-type': 'application/xml; charset=utf-8',
      etag: obj.httpEtag,
      'cache-control': 'public, max-age=300',
    },
  });
});

downloads.get('/download/:file{[A-Za-z0-9._-]+\\.dmg}', async (c) => {
  const file = c.req.param('file');
  const obj = await c.env.DOWNLOADS.get(`mac/${file}`);
  if (!obj) {
    return c.json(errBody('not_found', t(c).api.noSuchBuild), 404);
  }
  return new Response(obj.body, { headers: assetHeaders(obj, file) });
});
