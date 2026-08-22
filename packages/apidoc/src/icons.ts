export type IconName = 'terminal' | 'braces' | 'file' | 'link';

const PATHS: Record<IconName, string> = {
  terminal: '<path d="M3.2 4.4 6.6 8l-3.4 3.6"/><path d="M8.4 11.9h4.4"/>',
  braces:
    '<path d="M6.4 2.8c-1.5 0-1.8 1-1.8 2.3v1.2c0 .9-.5 1.6-1.3 1.7.8.1 1.3.8 1.3 1.7v1.2c0 1.3.3 2.3 1.8 2.3"/>' +
    '<path d="M9.6 2.8c1.5 0 1.8 1 1.8 2.3v1.2c0 .9.5 1.6 1.3 1.7-.8.1-1.3.8-1.3 1.7v1.2c0 1.3-.3 2.3-1.8 2.3"/>',
  file: '<path d="M9.1 2.4H4.9a1.5 1.5 0 0 0-1.5 1.5v8.2a1.5 1.5 0 0 0 1.5 1.5h6.2a1.5 1.5 0 0 0 1.5-1.5V5.7z"/><path d="M9.1 2.4v2.8a.5.5 0 0 0 .5.5h3"/>',
  link: '<path d="M6.7 9.3a2.7 2.7 0 0 0 4 .3l1.4-1.4a2.7 2.7 0 0 0-3.8-3.8l-.8.8"/><path d="M9.3 6.7a2.7 2.7 0 0 0-4-.3L3.9 7.8a2.7 2.7 0 0 0 3.8 3.8l.8-.8"/>',
};

export function icon(name: IconName): string {
  return (
    `<svg class="tab-i" viewBox="0 0 16 16" width="13" height="13" aria-hidden="true" ` +
    `fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" ` +
    `stroke-linejoin="round">${PATHS[name]}</svg>`
  );
}
