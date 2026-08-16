import * as Sentry from '@sentry/cloudflare';

/// `console.error` is the only way this server reports a problem, and it stays
/// that way. A handler never imports Sentry and never decides what an event is
/// worth: it says what happened, and everything Sentry needs -- the title, the
/// tags, and the issue the event lands in -- is derived here.
///
/// That is the whole point of doing it this way. A reporting call that has to
/// be added next to the log line is a call somebody forgets, and the sites that
/// need it most are the ones written while chasing something else. Four of the
/// five reports in this codebase predate Sentry by a year.
///
/// The one convention is the first argument: a dotted `domain.event` key.
///
///     console.error('apns.non_200', { status, reason });
///     console.error('http.unhandled', err, { route, method });
///
/// An `Error` anywhere in the arguments becomes the exception, so the stack
/// survives -- pass the error itself, never `String(err)`, which throws the
/// stack away. Plain objects are merged into the event's detail. Anything else
/// is left to `console.error` alone.

/// `domain.event`, lowercase. The domain is tagged separately, which is what
/// makes "everything APNs has said today" a search rather than a memory of what
/// the individual events were called.
const KEY = /^[a-z][a-z0-9]*(?:\.[a-z0-9_]+)+$/;

/// Which detail fields join the fingerprint, for the keys where one event name
/// covers several unrelated incidents.
///
/// The default is the key alone, deliberately. A fingerprint built from the
/// message text splits one problem into one issue per distinct number inside
/// it, which is the usual way a Sentry project stops being read at all.
///
/// This lives here rather than at the call site because whether two failures
/// are the same incident is a thing you decide while looking at Sentry, not
/// while writing the push path.
const GROUP_BY: Record<string, readonly string[]> = {
  // BadDeviceToken is a stale registration, TooManyRequests is a ceiling being
  // hit, ExpiredProviderToken is a signing bug on our side. One issue holding
  // all three would page on whichever arrived first.
  'apns.non_200': ['status', 'reason'],
};

/// Tag values are what Sentry can group and facet by, so a field with one value
/// per device makes the tag useless and the tag list long. Identifiers are
/// still worth having on the event, as context.
function isIdentifier(field: string): boolean {
  return field === 'id' || field.endsWith('_id');
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value) && !(value instanceof Error);
}

/// Sentry truncates at 200 and the truncation is silent; do it here so what
/// arrives is what we chose to send.
function tagValue(value: string | number | boolean): string {
  const s = String(value);
  return s.length > 200 ? `${s.slice(0, 197)}...` : s;
}

let reporting = false;

function report(args: readonly unknown[]): void {
  // Sentry's transport reports its own failures through `console.error`. Without
  // this, one unreachable ingest endpoint is an unbounded recursion rather than
  // a dropped event.
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

      // With an exception, `{{ default }}` keeps Sentry's stack-based grouping --
      // which is better than anything derivable from the key -- and the key
      // namespaces it, so an APNs fetch failure cannot merge with an unrelated
      // bug that happens to fail in the same frame.
      scope.setFingerprint(
        error
          ? ['{{ default }}', key]
          : [key, ...(GROUP_BY[key] ?? []).map((field) => String(detail[field] ?? 'none'))],
      );

      if (error) Sentry.captureException(error);
      else Sentry.captureMessage(key, 'error');
    });
  } catch {
    // A reporting path that can throw turns a logged failure into a request
    // that 500s. There is nowhere left to report this to.
  } finally {
    reporting = false;
  }
}

/// Wraps `console.error` once per isolate. Unkeyed calls -- anything from a
/// dependency or the runtime -- pass straight through to the original: they
/// have no domain, no fingerprint and no reason to become an issue, and the
/// Worker's logs still have them.
export function installConsoleCapture(): void {
  const original = console.error.bind(console);
  console.error = (...args: unknown[]): void => {
    original(...args);
    report(args);
  };
}
