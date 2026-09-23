import { DAILY_SEND_MAX } from '@notifi/contract';

export function now(): number {
  return Math.floor(Date.now() / 1000);
}

export function windowStart(nowS: number): number {
  return Math.floor(nowS / PER_DEVICE_WINDOW_S) * PER_DEVICE_WINDOW_S;
}

export const MESSAGE_BACKSTOP_S = 7776000;
export const PER_DEVICE_WINDOW_S = 86400;

export function perDeviceLimit(env: { PER_DEVICE_LIMIT?: string }): number {
  const raw = Number(env.PER_DEVICE_LIMIT);
  return Number.isInteger(raw) && raw > 0 ? raw : DAILY_SEND_MAX;
}
export const LAST_SEEN_STALE_S = 3600;
export const REPLAY_WINDOW_S = 60;
