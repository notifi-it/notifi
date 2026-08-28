import { z } from 'zod';

export const errorCode = z.enum([
  'bad_signature',
  'stale_timestamp',
  'unknown_device',
  'unknown_key',
  'rate_limited',
  'invalid_request',
  'invalid_content',
  'not_found',
  'internal_error',
]);
export type ErrorCode = z.infer<typeof errorCode>;

export const apiError = z.object({
  error: z.object({
    code: errorCode,
    message: z.string(),
  }),
});
export type ApiError = z.infer<typeof apiError>;

export const OCCURRED_AT_MIN_MS = 946_684_800_000;
export const OCCURRED_AT_MAX_SKEW_MS = 24 * 60 * 60 * 1000;

const sendFlag = z
  .union([z.boolean(), z.enum(['1', '0', 'true', 'false'])])
  .transform((v) => v === true || v === '1' || v === 'true');

export const TITLE_MAX = 200;
export const MESSAGE_MAX = 16000;
export const IMAGE_URL_MAX = 2048;

export const sendParams = z.object({
  key: z.string(),
  title: z.string().min(1).max(TITLE_MAX * 5),
  message: z.string().max(MESSAGE_MAX * 4).optional(),
  link: z.url().max(2048).optional(),
  image: z.string().max(IMAGE_URL_MAX * 2).optional(),
  occurred_at: z
    .number()
    .int()
    .min(OCCURRED_AT_MIN_MS, { error: 'occurred_at must be after 2000-01-01' })
    .optional(),
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
  name: z.string().min(1).max(64),
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
  since: z.coerce.number().int().nonnegative().optional(),
  limit: z.coerce.number().int().min(1).max(200).optional(),
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
