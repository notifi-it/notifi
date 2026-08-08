import { Hono } from 'hono';
import { errBody } from '../lib/respond.js';
import { getDevice, signatureAuth } from '../middleware.js';
import type { AppEnv } from '../types.js';

export const socket = new Hono<AppEnv>();

// The upgrade carries no body, so it signs exactly like the `/history` GET does
// — same canonical string, same empty-body hash — and the device reuses the
// signing it already has.
//
socket.use('/socket', signatureAuth);

socket.get('/socket', async (c) => {
  if (c.req.header('Upgrade') !== 'websocket') {
    return c.json(errBody('invalid_request', 'Expected a websocket upgrade.'), 426);
  }

  const device = await getDevice(c);
  if (!device) return c.json(errBody('unknown_device', 'Device is not registered.'), 401);

  // Keyed by the device row id, which is what the send path has in hand. Names
  // are derived, not stored, so there is no lookup table to keep in step.
  const id = c.env.DEVICE_SOCKET.idFromName(String(device.id));
  return c.env.DEVICE_SOCKET.get(id).fetch(c.req.raw);
});
