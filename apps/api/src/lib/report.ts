import * as Sentry from '@sentry/cloudflare';

const KEY = /^[a-z][a-z0-9]*(?:\.[a-z0-9_]+)+$/;

const GROUP_BY: Record<string, readonly string[]> = {
  'apns.non_200': ['status', 'reason'],
};

function isIdentifier(field: string): boolean {
  return field === 'id' || field.endsWith('_id');
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value) && !(value instanceof Error);
}

function tagValue(value: string | number | boolean): string {
  const s = String(value);
  return s.length > 200 ? `${s.slice(0, 197)}...` : s;
}

let reporting = false;

function report(args: readonly unknown[]): void {
  if (reporting) return;
  reporting = true;
  try {
    const first = args[0];
    const key = typeof first === 'string' && KEY.test(first) ? first : null;
    if (!key) return;

    const error = args.find((arg): arg is Error => arg instanceof Error);
    const detail: Record<string, unknown> = Object.assign({}, ...args.filter(isPlainObject));

    const tags: Record<string, string> = {};
    const context: Record<string, unknown> = {};
    for (const [field, value] of Object.entries(detail)) {
      const scalar = typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean';
      if (scalar && !isIdentifier(field)) tags[field] = tagValue(value);
      else context[field] = value;
    }
    tags.event = key;
    tags.domain = key.slice(0, key.indexOf('.'));

    Sentry.withScope((scope) => {
      scope.setTags(tags);
      if (Object.keys(context).length > 0) scope.setContext('detail', context);

      scope.setFingerprint(
        error
          ? ['{{ default }}', key]
          : [key, ...(GROUP_BY[key] ?? []).map((field) => String(detail[field] ?? 'none'))],
      );

      if (error) Sentry.captureException(error);
      else Sentry.captureMessage(key, 'error');
    });
  } catch {
  } finally {
    reporting = false;
  }
}

export function installConsoleCapture(): void {
  const original = console.error.bind(console);
  console.error = (...args: unknown[]): void => {
    original(...args);
    report(args);
  };
}
