export const ORIGIN = 'https://notifi.it';
export const EMAIL = 'hello@notifi.it';
export const AUTHOR = 'Maximilian Mitchell';
export const GITHUB = 'https://github.com/notifi-it/notifi';
export const GITHUB_ISSUES = `${GITHUB}/issues`;
export const APP_STORE = 'https://apps.apple.com/app/id1563961135';
export const MAC_DOWNLOAD = '/download/mac';
export const COUNTRY = 'GB';

export interface Social {
  name: string;
  url: string;
}

export const SOCIAL: Social[] = [
  { name: 'X', url: 'https://x.com/notifiit' },
  { name: 'Instagram', url: 'https://instagram.com/notifidotit' },
  { name: 'Facebook', url: 'https://facebook.com/notifidotit' },
];

export const THEME_COLOR = '#1C1C1E';
export const OG_IMAGE = `${ORIGIN}/og.png`;
export const OG_IMAGE_ALT =
  'The notifi bell, sketched in thin hatched strokes with a red dot.';

export const ORG_DESCRIPTION =
  "notifi delivers a push notification to an iPhone, iPad or Mac from one HTTP request. No account, no SDK, and notification content is encrypted with the device's public key.";
