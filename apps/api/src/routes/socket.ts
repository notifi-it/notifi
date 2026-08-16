import { Hono } from 'hono';
import { errBody } from '../lib/respond.js';
import { getDevice, signatureAuth } from '../middleware.js';
import type { AppEnv } from '../types.js';

export const socket = new Hono<AppEnv>();

socket.use('/socket', signatureAuth);

socket.get('/socket', async (c) => {
  if (c.req.header('Upgrade') !== 'websocket') {
    return c.json(errBody('invalid_request', 'Expected a websocket upgrade.'), 426);
  }

  const device = await getDevice(c);
  if (!device) return c.json(errBody('unknown_device', 'Device is not registered.'), 401);

  const id = c.env.DEVICE_SOCKET.idFromName(String(device.id));
  try {
    return await c.env.DEVICE_SOCKET.get(id).fetch(c.req.raw);
  } catch (err) {
    if ((err as { retryable?: boolean }).retryable === true) {
      return c.body(null, 503, { 'Retry-After': '1' });
    }
    throw err;
  }
});
