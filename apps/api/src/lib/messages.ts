export interface NewMessage {
  deviceId: number;
  keyId: number;
  contentEncrypted: string;
  createdAt: number;
  expiresAt: number;
  occurredAt: number | null;
}

export interface SendLimits {
  hourStartS: number;
  sendsPerHour: number;
  uncollectedMax: number;
}

export interface SendLimitUsage {
  oldestSendInHour: number | null;
  uncollectedCount: number;
}

function countSendsInLastHour(): string {
  return 'SELECT COUNT(*) FROM messages WHERE device_id = ? AND created_at > ?';
}

function countUncollected(): string {
  return 'SELECT COUNT(*) FROM messages WHERE device_id = ? AND collected_at IS NULL';
}

function insertMessageIf(condition: string): string {
  return `INSERT INTO messages
            (device_id, key_id, content_sealed, created_at, expires_at, occurred_at)
          SELECT ?, ?, ?, ?, ?, ?
          WHERE ${condition}
          RETURNING id`;
}

export async function insertMessageWithinLimits(
  db: D1Database,
  message: NewMessage,
  limits: SendLimits,
): Promise<number | null> {
  const row = await db
    .prepare(insertMessageIf(`(${countSendsInLastHour()}) < ? AND (${countUncollected()}) < ?`))
    .bind(
      message.deviceId,
      message.keyId,
      message.contentEncrypted,
      message.createdAt,
      message.expiresAt,
      message.occurredAt,
      message.deviceId,
      limits.hourStartS,
      limits.sendsPerHour,
      message.deviceId,
      limits.uncollectedMax,
    )
    .first<{ id: number }>();
  return row?.id ?? null;
}

export async function readSendLimitUsage(
  db: D1Database,
  deviceId: number,
  hourStartS: number,
): Promise<SendLimitUsage | null> {
  const row = await db
    .prepare(
      `SELECT
         MIN(CASE WHEN created_at > ? THEN created_at END) AS oldest_send_in_hour,
         SUM(collected_at IS NULL) AS uncollected_count
       FROM messages WHERE device_id = ?`,
    )
    .bind(hourStartS, deviceId)
    .first<{ oldest_send_in_hour: number | null; uncollected_count: number }>();
  if (!row) return null;
  return { oldestSendInHour: row.oldest_send_in_hour, uncollectedCount: row.uncollected_count };
}

export async function recordKeyUse(db: D1Database, keyId: number, nowS: number): Promise<void> {
  await db
    .prepare('UPDATE keys SET sent_count = sent_count + 1, last_used_at = ? WHERE id = ?')
    .bind(nowS, keyId)
    .run();
}

export async function markCollectedUpTo(
  db: D1Database,
  deviceId: number,
  latestId: number,
  nowS: number,
): Promise<void> {
  await db
    .prepare(
      `UPDATE messages SET content_sealed = '', collected_at = ?
       WHERE device_id = ? AND id <= ? AND collected_at IS NULL`,
    )
    .bind(nowS, deviceId, latestId)
    .run();
}

export async function deleteExpiredAndSpentMessages(
  db: D1Database,
  nowS: number,
  hourS: number,
): Promise<void> {
  await db
    .prepare(
      `DELETE FROM messages
       WHERE expires_at <= ? OR (collected_at IS NOT NULL AND created_at <= ?)`,
    )
    .bind(nowS, nowS - hourS)
    .run();
}
