interface AcceptEntry {
  type: string;
  q: number;
  specificity: number;
}

function parseAccept(header: string): AcceptEntry[] {
  const entries: AcceptEntry[] = [];
  for (const raw of header.split(',')) {
    const parts = raw.trim().split(';').map((s) => s.trim());
    const type = (parts[0] ?? '').toLowerCase();
    if (!type) continue;
    let q = 1;
    for (const param of parts.slice(1)) {
      const [name, value] = param.split('=').map((s) => s.trim());
      if (name === 'q') {
        const parsed = Number(value);
        if (!Number.isNaN(parsed)) q = Math.max(0, Math.min(1, parsed));
      }
    }
    const specificity = type === '*/*' ? 0 : type.endsWith('/*') ? 1 : 2;
    entries.push({ type, q, specificity });
  }
  return entries;
}

function matches(entry: AcceptEntry, candidate: string): boolean {
  if (entry.type === '*/*') return true;
  if (entry.type.endsWith('/*')) return candidate.startsWith(entry.type.slice(0, -1));
  return entry.type === candidate;
}

export function preferredType(header: string | null | undefined, produces: string[]): string | null {
  if (!header) return produces[0] ?? null;
  const entries = parseAccept(header);
  if (entries.length === 0) return produces[0] ?? null;

  let bestType: string | null = null;
  let bestQ = -1;
  let bestPosition = Number.POSITIVE_INFINITY;

  for (const candidate of produces) {
    let matched: AcceptEntry | null = null;
    let matchedPosition = Number.POSITIVE_INFINITY;
    let i = -1;
    for (const entry of entries) {
      i++;
      if (!matches(entry, candidate)) continue;
      if (
        matched === null ||
        entry.specificity > matched.specificity ||
        (entry.specificity === matched.specificity && i < matchedPosition)
      ) {
        matched = entry;
        matchedPosition = i;
      }
    }
    if (matched === null || matched.q <= 0) continue;
    if (matched.q > bestQ || (matched.q === bestQ && matchedPosition < bestPosition)) {
      bestQ = matched.q;
      bestPosition = matchedPosition;
      bestType = candidate;
    }
  }

  return bestType;
}

export function appendVaryAccept(headers: Headers): void {
  const existing = headers.get('Vary');
  if (!existing) {
    headers.set('Vary', 'Accept');
    return;
  }
  const tokens = existing.split(',').map((s) => s.trim().toLowerCase());
  if (tokens.includes('*') || tokens.includes('accept')) return;
  headers.set('Vary', `${existing}, Accept`);
}
