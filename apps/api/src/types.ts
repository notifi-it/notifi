import type { ErrorCode } from '@notifi/contract';

export interface RateLimitBinding {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export interface Env {
  DB: D1Database;
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
  acked_id: number;
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
