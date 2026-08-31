const FENCE = '```';

export interface Front {
  [key: string]: string;
}

export function front(source: string): { front: Front; body: string } {
  if (!source.startsWith('---\n')) throw new Error('page has no front matter');
  const end = source.indexOf('\n---\n', 3);
  if (end === -1) throw new Error('page front matter is not closed');
  const out: Front = {};
  for (const line of source.slice(4, end).split('\n')) {
    if (!line.trim()) continue;
    const at = line.indexOf(':');
    if (at === -1) throw new Error(`front matter line has no key: ${line}`);
    out[line.slice(0, at).trim()] = line.slice(at + 1).trim();
  }
  return { front: out, body: source.slice(end + 5).trim() };
}

function escape(text: string): string {
  return text.replace(/&(?!(?:[a-zA-Z]+|#\d+);)/g, '&amp;').replace(/</g, '&lt;');
}

function inline(text: string): string {
  const codes: string[] = [];
  let out = text.replace(/`([^`]+)`/g, (_, code: string) => {
    codes.push(`<code>${escape(code)}</code>`);
    return `%%CODE${codes.length - 1}%%`;
  });
  const literals: string[] = [];
  out = out.replace(/\\([\\`*_[\]()<>&#.!-])/g, (_, ch: string) => {
    literals.push(ch);
    return `%%LIT${literals.length - 1}%%`;
  });
  out = escape(out);
  out = out.replace(
    /\[([^\]]+)\]\(((?:[^\s()]|\([^\s()]*\))+)\)/g,
    (_, label: string, href: string) => `<a href="${href}">${label}</a>`,
  );
  out = out.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  out = out.replace(/(^|[\s(])_([^_]+)_(?=[\s.,;:)]|$)/g, '$1<em>$2</em>');
  out = out.replace(/&lt;br&gt;/g, '<br>');
  out = out.replace(/%%LIT(\d+)%%/g, (_, i: string) => escape(literals[Number(i)] as string));
  return out.replace(/%%CODE(\d+)%%/g, (_, i: string) => codes[Number(i)] as string);
}

function card(lines: string[]): string {
  const body = lines
    .map((line) => {
      const spaces = line.length - line.trimStart().length;
      return '&nbsp;'.repeat(spaces) + escape(line.trimStart());
    })
    .join('<br>\n      ');
  return `    <div class="card">\n      <p><code>${body}</code></p>\n    </div>`;
}

export function render(body: string): string {
  const lines = body.split('\n');
  const out: string[] = [];
  let open = false;
  let lede = false;
  let i = 0;

  const indent = () => (open ? '    ' : '  ');
  const close = () => {
    if (open) out.push('  </section>');
    open = false;
  };

  while (i < lines.length) {
    const line = lines[i] as string;
    if (!line.trim()) {
      i++;
      continue;
    }

    if (line.startsWith(FENCE)) {
      const block: string[] = [];
      i++;
      while (i < lines.length && !(lines[i] as string).startsWith(FENCE)) {
        block.push(lines[i] as string);
        i++;
      }
      i++;
      out.push(card(block));
      continue;
    }

    const heading = /^(#{1,3}) (.+)$/.exec(line);
    if (heading) {
      const level = (heading[1] as string).length;
      const text = inline(heading[2] as string);
      if (level === 1) {
        out.push(`  <h1>${text}</h1>`);
      } else if (level === 2) {
        close();
        out.push('', '  <section>', `    <h2>${text}</h2>`);
        open = true;
      } else {
        out.push(`    <h3>${text}</h3>`);
      }
      i++;
      continue;
    }

    if (line.startsWith('>')) {
      const quoted: string[] = [];
      while (i < lines.length && (lines[i] as string).startsWith('>')) {
        quoted.push((lines[i] as string).replace(/^>\s?/, ''));
        i++;
      }
      if (!lede) {
        lede = true;
        out.push(`${indent()}<p class="lede">${inline(quoted.join(' ').trim())}</p>`);
        continue;
      }
      const pad = indent();
      const paragraphs = quoted
        .join('\n')
        .split(/\n\s*\n/)
        .map((text) => text.replace(/\s+/g, ' ').trim())
        .filter(Boolean);
      out.push(
        `${pad}<div class="card">`,
        ...paragraphs.map((text) => `${pad}  <p>${inline(text)}</p>`),
        `${pad}</div>`,
      );
      continue;
    }

    if (line.startsWith('- ')) {
      const items: string[] = [];
      while (i < lines.length && (lines[i] as string).startsWith('- ')) {
        items.push((lines[i] as string).slice(2));
        i++;
      }
      const pad = indent();
      out.push(
        `${pad}<ul>`,
        ...items.map((item) => `${pad}  <li>${inline(item)}</li>`),
        `${pad}</ul>`,
      );
      continue;
    }

    const meta = /^_(.+)_$/.exec(line);
    out.push(
      meta
        ? `${indent()}<p class="meta">${inline(meta[1] as string)}</p>`
        : `${indent()}<p>${inline(line)}</p>`,
    );
    i++;
  }

  close();
  return out.join('\n');
}

export function main(eyebrow: string, body: string): string {
  const top = eyebrow ? `  <p class="eyebrow">${eyebrow}</p>\n` : '';
  return `<main id="main" class="wrap doc">\n\n${top}${render(body)}\n\n</main>`;
}
