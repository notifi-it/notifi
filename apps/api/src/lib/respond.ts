import type { ApiError, ErrorCode } from '@notifi/contract';
import { copyFor, type Strings } from '@notifi/copy';
import type { Context } from 'hono';
import type { AppEnv } from '../types.js';

export function errBody(code: ErrorCode, message: string): ApiError {
  return { error: { code, message } };
}

/// The copy tree in the language this request asked for. Every user-facing
/// message goes through here rather than importing `copy` directly, so a
/// response never answers in a language the caller did not ask for.
export function t(c: Context<AppEnv>): Strings {
  return copyFor(c.get('language'));
}
