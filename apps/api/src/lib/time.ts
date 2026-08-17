export function now(): number {
  return Math.floor(Date.now() / 1000);
}

export function windowStart(nowS: number): number {
  return Math.floor(nowS / 3600) * 3600;
}

export const MESSAGE_BACKSTOP_S = 7776000;
export const PER_DEVICE_WINDOW_S = 3600;
export const PER_DEVICE_LIMIT = 60;

export function perDeviceLimit(env: { PER_DEVICE_LIMIT?: string }): number {
  const raw = Number(env.PER_DEVICE_LIMIT);
  return Number.isInteger(raw) && raw > 0 ? raw : PER_DEVICE_LIMIT;
}
export const LAST_SEEN_STALE_S = 3600;
export const REPLAY_WINDOW_S = 60;
