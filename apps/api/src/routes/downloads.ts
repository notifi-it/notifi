import { Hono } from 'hono';
import { errBody, t } from '../lib/respond.js';
import type { AppEnv } from '../types.js';

export const downloads = new Hono<AppEnv>();

const LATEST_POINTER = 'mac/latest';

function assetHeaders(obj: R2ObjectBody, filename: string): Headers {
  const h = new Headers();
  obj.writeHttpMetadata(h);
  h.set('etag', obj.httpEtag);
  h.set('cache-control', 'public, max-age=31536000, immutable');
  h.set('content-disposition', `attachment; filename="${filename}"`);
  return h;
}

downloads.get('/download/mac', async (c) => {
  const pointer = await c.env.DOWNLOADS.get(LATEST_POINTER);
  if (!pointer) {
    return c.json(errBody('not_found', t(c).api.noMacBuild), 404);
  }
  const key = (await pointer.text()).trim();
  return c.redirect(`/download/${key.replace(/^mac\//, '')}`, 302);
});

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
