import type { ApiError, ErrorCode } from '@notifi/contract';

export function errBody(code: ErrorCode, message: string): ApiError {
  return { error: { code, message } };
}
