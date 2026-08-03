import type { ErrorCode } from '@notifi/contract';

export interface RateLimitBinding {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export interface Env {
  DB: D1Database;
  /// Signed macOS builds. The repo is private, so a GitHub release asset would
  /// need auth and 404 for the public; this is the download the site links to.
  DOWNLOADS: R2Bucket;
  SEND_IP_LIMIT: RateLimitBinding;
  APNS_HOST: string;
  APNS_TOPIC: string;
  APNS_TEAM_ID: string;
  APNS_KEY_ID: string;
  APNS_PRIVATE_KEY: string;
  ENCRYPTION_KEY: string;
}

export interface DeviceRow {
  id: number;
  public_key: string;
  encryption_public_key: string;
  apns_token: string;
  apns_token_hmac: string;
  platform: string;
  app_version: string;
  created_at: number;
  last_seen_at: number;
  /// Highest device_seq the device has confirmed collecting.
  acked_id: number;
  /// Last device_seq handed out. Never decreases, so a number is not reused
  /// after the message holding it has been deleted.
  seq_counter: number;
}

export interface Variables {
  rawBody: ArrayBuffer;
  publicKey: string;
}

export interface AppEnv {
  Bindings: Env;
  Variables: Variables;
}

export type { ErrorCode };
