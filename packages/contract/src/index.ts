import { z } from 'zod';

export const ORIGIN = 'https://notifi.it';
export const EMAIL = 'hello@notifi.it';
export const GITHUB = 'https://github.com/notifi-it/notifi';
export const APP_STORE_ID = '1563961135';
export const APP_STORE = `https://apps.apple.com/app/id${APP_STORE_ID}`;

export const KEY_PREFIX = 'nk_';
export const KEY_PREFIX_BODY_CHARS = 4;
export const KEY_BYTES = 32;

export function keyPrefix(key: string): string {
  return key.slice(0, KEY_PREFIX.length + KEY_PREFIX_BODY_CHARS);
}

export const KEY_NAME_MAX = 64;
export const KEYS_PER_DEVICE = 5;
export const SENDS_PER_HOUR = 60;
export const SEND_WINDOW_S = 3600;
export const REQUESTS_PER_MINUTE = 100;
export const IP_WINDOW_S = 60;
export const HISTORY_LIMIT_DEFAULT = 50;
export const HISTORY_LIMIT_MAX = 200;

export const errorCode = z.enum([
  'bad_signature',
  'stale_timestamp',
  'unknown_device',
  'unknown_key',
  'rate_limited',
  'uncollected_limit',
  'invalid_request',
  'invalid_content',
  'not_found',
  'internal_error',
]);
export type ErrorCode = z.infer<typeof errorCode>;

export const publicErrorCode = errorCode.exclude([
  'bad_signature',
  'stale_timestamp',
  'unknown_device',
]);
export type PublicErrorCode = z.infer<typeof publicErrorCode>;

export const apiError = z.object({
  error: z.object({
    code: errorCode,
    message: z.string(),
  }),
});
export type ApiError = z.infer<typeof apiError>;

export const UNCOLLECTED_MAX = 500;

export const OCCURRED_AT_MIN_MS = 946_684_800_000;
export const OCCURRED_AT_MAX_SKEW_MS = 24 * 60 * 60 * 1000;

const sendFlag = z
  .union([z.boolean(), z.enum(['1', '0', 'true', 'false'])])
  .transform((v) => v === true || v === '1' || v === 'true');

export const TITLE_MAX = 200;
export const MESSAGE_MAX = 16000;
export const IMAGE_URL_MAX = 2048;
export const LINK_URL_MAX = 2048;

export const sendFields = z.object({
  key: z.string(),
  title: z.string().min(1).max(TITLE_MAX),
  message: z.string().max(MESSAGE_MAX).optional(),
  link: z.url().max(LINK_URL_MAX).optional(),
  image: z.string().max(IMAGE_URL_MAX).optional(),
  occurred_at: z
    .number()
    .int()
    .min(OCCURRED_AT_MIN_MS, { error: 'occurred_at must be after 2000-01-01' })
    .optional(),
  is_critical: z.boolean().optional(),
});

export const SEND_KEYS_MAX = 2;

const KEY_SEPARATOR = ',';

const sendKeyList = z
  .union([z.string(), z.array(z.string())])
  .transform((given) => {
    const pieces = (Array.isArray(given) ? given : [given]).flatMap((entry) =>
      entry.split(KEY_SEPARATOR),
    );
    const trimmed = pieces.map((piece) => piece.trim()).filter((piece) => piece !== '');
    return [...new Set(trimmed)];
  })
  .pipe(z.array(z.string()).min(1).max(SEND_KEYS_MAX));

export const CROP_TOLERANCE = { title: 5, message: 4, image: 2 };

export const sendParams = sendFields.extend({
  key: sendKeyList,
  title: z.string().min(1).max(TITLE_MAX * CROP_TOLERANCE.title),
  message: z.string().max(MESSAGE_MAX * CROP_TOLERANCE.message).optional(),
  image: z.string().max(IMAGE_URL_MAX * CROP_TOLERANCE.image).optional(),
  is_critical: sendFlag.optional(),
});
export type SendParams = z.infer<typeof sendParams>;

export const messageContent = sendParams
  .omit({ key: true, is_critical: true })
  .extend({
    key_id: z.number().int(),
    created_at: z.number().int(),
    is_critical: z.boolean(),
  });
export type MessageContent = z.infer<typeof messageContent>;

export const keyMeta = z.object({
  id: z.number().int(),
  name: z.string(),
  prefix: z.string(),
});
export type KeyMeta = z.infer<typeof keyMeta>;

export const registerDeviceBody = z.strictObject({
  public_key: z.string(),
  encryption_public_key: z.string(),
  apns_token: z.string().min(1).optional(),
  platform: z.string().min(1).max(16),
  app_version: z.string().min(1).max(16),
});
export type RegisterDeviceBody = z.infer<typeof registerDeviceBody>;

export const registerDeviceResponse = z.object({
  device_id: z.number().int(),
  strict_send: z.number().int(),
});
export type RegisterDeviceResponse = z.infer<typeof registerDeviceResponse>;

export const keySummary = z.object({
  id: z.number().int(),
  meta_sealed: z.string(),
  created_at: z.number().int(),
  last_used_at: z.number().int().nullable(),
  sent_count: z.number().int(),
  revoked_at: z.number().int().nullable(),
  is_critical: z.number().int(),
});
export type KeySummary = z.infer<typeof keySummary>;

export const listKeysResponse = z.object({
  keys: z.array(keySummary),
});
export type ListKeysResponse = z.infer<typeof listKeysResponse>;

export const createKeyBody = z.strictObject({
  name: z.string().min(1).max(KEY_NAME_MAX),
});
export type CreateKeyBody = z.infer<typeof createKeyBody>;

export const createKeyResponse = z.object({
  id: z.number().int(),
  name: z.string(),
  key: z.string(),
});
export type CreateKeyResponse = z.infer<typeof createKeyResponse>;

export const updateKeyBody = z.strictObject({
  is_critical: z.boolean(),
});
export type UpdateKeyBody = z.infer<typeof updateKeyBody>;

export const updateDeviceSettingsBody = z.strictObject({
  strict_send: z.boolean(),
});
export type UpdateDeviceSettingsBody = z.infer<typeof updateDeviceSettingsBody>;

export const historyQuery = z.object({
  ack: z.coerce.number().int().nonnegative().optional(),
  limit: z.coerce.number().int().min(1).max(HISTORY_LIMIT_MAX).optional(),
});
export type HistoryQuery = z.infer<typeof historyQuery>;

export const historyMessage = z.object({
  id: z.number().int(),
  content_sealed: z.string(),
  key_id: z.number().int().nullable(),
  created_at: z.number().int(),
  occurred_at: z.number().int().nullable().optional(),
});
export type HistoryMessage = z.infer<typeof historyMessage>;

export const historyResponse = z.object({
  messages: z.array(historyMessage),
  latest_id: z.number().int().nullable(),
});
export type HistoryResponse = z.infer<typeof historyResponse>;

export const socketFrame = z.object({
  type: z.literal('message'),
  latest_id: z.number().int(),
  pushed: z.boolean(),
});
export type SocketFrame = z.infer<typeof socketFrame>;

export const sendResponse = z.object({
  ok: z.literal(true),
  warnings: z.array(z.string()).optional(),
});
export type SendResponse = z.infer<typeof sendResponse>;
