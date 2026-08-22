import * as simple from 'simple-icons';

export type IconName = 'file' | 'copy';

const PATHS: Record<IconName, string> = {
  file: '<path d="M9.1 2.4H4.9a1.5 1.5 0 0 0-1.5 1.5v8.2a1.5 1.5 0 0 0 1.5 1.5h6.2a1.5 1.5 0 0 0 1.5-1.5V5.7z"/><path d="M9.1 2.4v2.8a.5.5 0 0 0 .5.5h3"/>',
  copy: '<rect x="5.9" y="5.9" width="7.2" height="7.2" rx="1.3"/><path d="M10.6 3.6a1.3 1.3 0 0 0-1.3-1.3H4.2a1.3 1.3 0 0 0-1.3 1.3v5.1a1.3 1.3 0 0 0 1.3 1.3"/>',
};

export function icon(name: IconName): string {
  return (
    `<svg class="tab-i" viewBox="0 0 16 16" width="13" height="13" aria-hidden="true" ` +
    `fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" ` +
    `stroke-linejoin="round">${PATHS[name]}</svg>`
  );
}

const icons = simple as unknown as Record<string, { title: string; path: string } | undefined>;

export function brand(slug: string): string {
  const mark = icons[slug];
  if (!mark) throw new Error(`simple-icons has no ${slug}`);
  return (
    `<svg class="tab-i" viewBox="0 0 24 24" width="13" height="13" aria-hidden="true" ` +
    `fill="currentColor"><path d="${mark.path}"/></svg>`
  );
}
