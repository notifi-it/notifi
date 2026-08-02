import { z } from 'zod';

export const errorCode = z.enum([
  'bad_signature',
  'stale_timestamp',
  'unknown_device',
  'unknown_key',
  'rate_limited',
  'invalid_request',
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

/// 2000-01-01T00:00:00Z. Anything older is a unit mistake — seconds passed as ms.
export const OCCURRED_AT_MIN_MS = 946_684_800_000;
/// How far ahead of the server clock a client timestamp may sit.
export const OCCURRED_AT_MAX_SKEW_MS = 24 * 60 * 60 * 1000;

export const sendParams = z.object({
  key: z.string(),
  title: z.string().min(1).max(200),
  message: z.string().max(2000).optional(),
  link: z.string().url().max(2048).optional(),
  image: z
    .string()
    .url()
    .max(2048)
    .refine((u) => u.toLowerCase().startsWith('https:'), {
      message: 'image must be an https URL',
    })
    .optional(),
  // When the event actually happened, in unix MILLISECONDS. Optional — most
  // senders will not set it and the server receipt time is used instead.
  //
  // Display only. It never affects ordering, the `since` bookmark or expiry,
  // because the sender controls this value and could otherwise pin a message to
  // the top or bottom of the feed. Bounded to keep obvious nonsense out.
  occurred_at: z
    .number()
    .int()
    .min(OCCURRED_AT_MIN_MS, { message: 'occurred_at must be after 2000-01-01' })
    .optional(),
});
export type SendParams = z.infer<typeof sendParams>;

export const messageContent = sendParams.omit({ key: true }).extend({
  key_id: z.number().int(),
  created_at: z.number().int(),
});
export type MessageContent = z.infer<typeof messageContent>;

export const keyMeta = z.object({
  id: z.number().int(),
  name: z.string(),
  prefix: z.string(),
});
export type KeyMeta = z.infer<typeof keyMeta>;

export const registerDeviceBody = z
  .object({
    public_key: z.string(),
    encryption_public_key: z.string(),
    apns_token: z.string().min(1),
    platform: z.string().min(1).max(16),
    app_version: z.string().min(1).max(16),
  })
  .strict();
export type RegisterDeviceBody = z.infer<typeof registerDeviceBody>;

export const registerDeviceResponse = z.object({
  device_id: z.number().int(),
});
export type RegisterDeviceResponse = z.infer<typeof registerDeviceResponse>;

export const keySummary = z.object({
  id: z.number().int(),
  meta_sealed: z.string(),
  created_at: z.number().int(),
  last_used_at: z.number().int().nullable(),
  sent_count: z.number().int(),
  revoked_at: z.number().int().nullable(),
});
export type KeySummary = z.infer<typeof keySummary>;

export const listKeysResponse = z.object({
  keys: z.array(keySummary),
});
export type ListKeysResponse = z.infer<typeof listKeysResponse>;

export const createKeyBody = z
  .object({
    name: z.string().min(1).max(64),
  })
  .strict();
export type CreateKeyBody = z.infer<typeof createKeyBody>;

export const createKeyResponse = z.object({
  id: z.number().int(),
  name: z.string(),
  key: z.string(),
});
export type CreateKeyResponse = z.infer<typeof createKeyResponse>;

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
  /// Client-supplied event time in unix ms, or null. Display only.
  occurred_at: z.number().int().nullable().optional(),
});
export type HistoryMessage = z.infer<typeof historyMessage>;

export const historyResponse = z.object({
  messages: z.array(historyMessage),
  latest_id: z.number().int().nullable(),
});
export type HistoryResponse = z.infer<typeof historyResponse>;

export const sendResponse = z.object({
  id: z.number().int(),
});
export type SendResponse = z.infer<typeof sendResponse>;
