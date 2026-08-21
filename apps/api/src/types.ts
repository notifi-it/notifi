import type { ErrorCode } from '@notifi/contract';
import type { LanguageCode } from '@notifi/copy';

export interface RateLimitBinding {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

import type { ApnsToken } from './apnstoken.js';
import type { DeviceSocket } from './socket.js';

export interface Env {
  ASSETS: Fetcher;
  DB: D1Database;
  DEVICE_SOCKET: DurableObjectNamespace<DeviceSocket>;
  APNS_TOKEN: DurableObjectNamespace<ApnsToken>;
  SEND_IP_LIMIT: RateLimitBinding;
  APNS_HOST: string;
  APNS_TOPIC: string;
  APNS_TEAM_ID: string;
  APNS_KEY_ID: string;
  APNS_PRIVATE_KEY: string;
  ENCRYPTION_KEY: string;
  PER_DEVICE_LIMIT?: string;
  SENTRY_DSN?: string;
  SENTRY_ENVIRONMENT: string;
  SENTRY_RELEASE?: string;
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
  seq_counter: number;
}

export interface Variables {
  rawBody: ArrayBuffer;
  publicKey: string;
  signatureChecked: boolean;
  language: LanguageCode;
}

export interface AppEnv {
  Bindings: Env;
  Variables: Variables;
}

export type { ErrorCode };
