import { IMAGE_URL_MAX } from '@notifi/contract';

const ALLOWED_TYPES = ['image/png', 'image/jpeg', 'image/gif'];
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

const PROBE_TIMEOUT_MS = 3000;

export type ImageRejection = 'rejected' | 'unreachable';

const IPV4 = /^\d{1,3}(\.\d{1,3}){3}$/;

function addressLooksSane(raw: string): boolean {
  if (raw.length > IMAGE_URL_MAX) return false;

  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }

  if (url.protocol !== 'https:') return false;
  if (url.username !== '' || url.password !== '') return false;

  const host = url.hostname.toLowerCase();
  if (host === 'localhost' || host.endsWith('.localhost')) return false;
  if (IPV4.test(host) || host.includes(':')) return false;

  return true;
}

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

  const length = Number(res.headers.get('content-length'));
  if (!Number.isFinite(length) || length <= 0 || length > MAX_IMAGE_BYTES) {
    return 'unreachable';
  }

  return null;
}
