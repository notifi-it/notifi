import {
  AUTHOR,
  COUNTRY,
  EMAIL,
  GITHUB,
  GITHUB_ISSUES,
  ORG_DESCRIPTION,
  ORIGIN,
  SOCIAL,
} from './constants.js';

export const ORG_ID = `${ORIGIN}/#org`;

export function organization(): Record<string, unknown> {
  return {
    '@type': 'Organization',
    '@id': ORG_ID,
    name: 'notifi',
    alternateName: 'notifi.it',
    url: `${ORIGIN}/`,
    description: ORG_DESCRIPTION,
    logo: `${ORIGIN}/apple-touch-icon.png`,
    email: EMAIL,
    contactPoint: [
      {
        '@type': 'ContactPoint',
        contactType: 'customer support',
        email: EMAIL,
        url: `${ORIGIN}/contact`,
        availableLanguage: ['en'],
      },
      {
        '@type': 'ContactPoint',
        contactType: 'technical support',
        email: EMAIL,
        url: GITHUB_ISSUES,
        availableLanguage: ['en'],
      },
    ],
    address: { '@type': 'PostalAddress', addressCountry: COUNTRY },
    founder: { '@type': 'Person', name: AUTHOR },
    sameAs: [GITHUB, ...SOCIAL.map((s) => s.url)],
  };
}

export function graph(nodes: Array<Record<string, unknown>>): string {
  const body = JSON.stringify(
    { '@context': 'https://schema.org', '@graph': [organization(), ...nodes] },
    null,
    2,
  );
  return `<script type="application/ld+json">\n${body}\n</script>`;
}

export function pageNode(
  type: string,
  path: string,
  name: string,
  description: string,
  extra: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    '@type': type,
    '@id': `${ORIGIN}${path}#page`,
    url: `${ORIGIN}${path}`,
    name,
    description,
    about: { '@id': ORG_ID },
    publisher: { '@id': ORG_ID },
    inLanguage: 'en',
    ...extra,
  };
}
