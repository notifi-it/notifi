import { IMAGE_URL_MAX } from '@notifi/contract';

/// What the notification service extension will accept when it fetches the
/// image on the device (NotificationService.swift). Checking the same things
/// here does not make the device's checks redundant — it cannot, since the
/// server never handles the bytes and the host is free to answer differently
/// later. It exists so the sender finds out at send time instead of the
/// recipient finding out as a missing picture.
const ALLOWED_TYPES = ['image/png', 'image/jpeg', 'image/gif'];
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

/// Long enough for a slow CDN, short enough that a dead host does not hold the
/// send open. A probe that times out drops the image, same as a refusal.
const PROBE_TIMEOUT_MS = 3000;

export type ImageRejection = 'rejected' | 'unreachable';

const IPV4 = /^\d{1,3}(\.\d{1,3}){3}$/;

/// Address hygiene, before anything is fetched. This is the half that protects
/// the relay rather than the sender: without it the probe below is a request
/// generator pointed wherever the caller likes.
function addressLooksSane(raw: string): boolean {
  if (raw.length > IMAGE_URL_MAX) return false;

  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }

  if (url.protocol !== 'https:') return false;
  // Credentials in the URL mean the address is not one a recipient's device can
  // be handed safely — it would be storing someone's password in the message.
  if (url.username !== '' || url.password !== '') return false;

  const host = url.hostname.toLowerCase();
  if (host === 'localhost' || host.endsWith('.localhost')) return false;
  // Literal addresses, v4 or bracketed v6. Not a complete private-range defence
  // — a hostname can still resolve inside a network — but it removes the direct
  // way of asking the relay to fetch from somewhere only it can reach.
  if (IPV4.test(host) || host.includes(':')) return false;

  return true;
}

/// `null` when the image is fine to pass on, otherwise which way it failed.
export async function checkImage(raw: string): Promise<ImageRejection | null> {
  if (!addressLooksSane(raw)) return 'rejected';

  let res: Response;
  try {
    res = await fetch(raw, {
      method: 'HEAD',
      redirect: 'follow',
      signal: AbortSignal.timeout(PROBE_TIMEOUT_MS),
    });
  } catch {
    return 'unreachable';
  }

  if (!res.ok) return 'unreachable';

  const type = (res.headers.get('content-type') ?? '').split(';')[0]!.trim().toLowerCase();
  if (!ALLOWED_TYPES.includes(type)) return 'unreachable';

  // Required, not merely respected when offered. A host that will not say how
  // big the file is has not told us it is under the device's ceiling, and
  // guessing on the sender's behalf is the silent failure this whole path
  // exists to remove.
  const length = Number(res.headers.get('content-length'));
  if (!Number.isFinite(length) || length <= 0 || length > MAX_IMAGE_BYTES) {
    return 'unreachable';
  }

  return null;
}
