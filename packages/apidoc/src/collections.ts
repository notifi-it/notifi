import { ENDPOINT, ORIGIN, SUMMARY, params } from './spec.js';

const KEY_VARIABLE = '{{NOTIFI_KEY}}';

function bodyFields() {
  return params
    .filter((p) => p.name !== 'key' && p.example !== undefined)
    .map((p) => ({ key: p.name, value: p.example as string }));
}

export function postman(): Record<string, unknown> {
  const fields = bodyFields();
  return {
    info: {
      _postman_id: '6e6f7469-6669-4974-8000-6e6f74696669',
      name: 'notifi',
      description: `${SUMMARY}\n\nSet NOTIFI_KEY to the send key from the app’s Keys tab. Docs: ${ORIGIN}/docs`,
      schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
    },
    variable: [
      { key: 'baseUrl', value: ORIGIN, type: 'string' },
      { key: 'NOTIFI_KEY', value: '', type: 'string' },
    ],
    auth: { type: 'bearer', bearer: [{ key: 'token', value: KEY_VARIABLE, type: 'string' }] },
    item: [
      {
        name: 'Send a notification',
        request: {
          method: 'POST',
          header: [{ key: 'Content-Type', value: 'application/json' }],
          url: {
            raw: `{{baseUrl}}${ENDPOINT}`,
            host: ['{{baseUrl}}'],
            path: [ENDPOINT.replace(/^\//, '')],
          },
          body: {
            mode: 'raw',
            raw: JSON.stringify(
              Object.fromEntries(fields.map((f) => [f.key, f.value])),
              null,
              2,
            ),
            options: { raw: { language: 'json' } },
          },
          description: `Answers 202 with {"ok":true} once the server has accepted the notification. See ${ORIGIN}/docs.`,
        },
        response: [],
      },
      {
        name: 'Send a notification (form-encoded)',
        request: {
          method: 'POST',
          header: [],
          url: {
            raw: `{{baseUrl}}${ENDPOINT}`,
            host: ['{{baseUrl}}'],
            path: [ENDPOINT.replace(/^\//, '')],
          },
          body: { mode: 'urlencoded', urlencoded: fields.map((f) => ({ ...f, type: 'text' })) },
        },
        response: [],
      },
    ],
  };
}

export function bruno(): string {
  const fields = bodyFields();
  const body = JSON.stringify(
    Object.fromEntries(fields.map((f) => [f.key, f.value])),
    null,
    2,
  )
    .split('\n')
    .map((line) => `    ${line}`)
    .join('\n');
  return `meta {
  name: Send a notification
  type: http
  seq: 1
}

post {
  url: ${ORIGIN}${ENDPOINT}
  body: json
  auth: bearer
}

auth:bearer {
  token: {{NOTIFI_KEY}}
}

headers {
  Content-Type: application/json
}

body:json {
${body}
}

docs {
  ${SUMMARY}

  Set NOTIFI_KEY to the send key from the app's Keys tab, then send. A 202 with
  {"ok":true} means the server accepted it, not that it was delivered.

  Reference: ${ORIGIN}/docs
}
`;
}
