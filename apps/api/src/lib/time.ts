export function now(): number {
  return Math.floor(Date.now() / 1000);
}

export function windowStart(nowS: number): number {
  return Math.floor(nowS / 3600) * 3600;
}

export const MESSAGE_BACKSTOP_S = 7776000;
export const ABANDONED_DEVICE_S = 2592000;
export const PER_KEY_WINDOW_S = 3600;
export const PER_KEY_LIMIT = 120;
export const LAST_SEEN_STALE_S = 3600;
