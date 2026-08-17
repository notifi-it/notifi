import type { ApiError, ErrorCode } from '@notifi/contract';
import { copyFor, type Strings } from '@notifi/copy';
import type { Context } from 'hono';
import type { AppEnv } from '../types.js';

export function errBody(code: ErrorCode, message: string): ApiError {
  return { error: { code, message } };
}

export function t(c: Context<AppEnv>): Strings {
  return copyFor(c.get('language'));
}
