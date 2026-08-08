export function now(): number {
  return Math.floor(Date.now() / 1000);
}

export function windowStart(nowS: number): number {
  return Math.floor(nowS / 3600) * 3600;
}

/// No longer a deletion deadline — the sweep that enforced it was removed.
/// Still written to expires_at and sent as the APNs expiry, so Apple stops
/// retrying a push after this long.
export const MESSAGE_BACKSTOP_S = 7776000;
export const PER_DEVICE_WINDOW_S = 3600;
export const PER_DEVICE_LIMIT = 60;
export const LAST_SEEN_STALE_S = 3600;
/// How far a request timestamp may sit from the server clock and still verify.
/// This window is the whole replay defence now — the seen-signatures guard that
/// shared the constant was removed.
export const REPLAY_WINDOW_S = 60;
