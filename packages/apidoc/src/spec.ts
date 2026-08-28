export interface Param {
  name: string;
  type: string;
  required: boolean;
  limit?: string;
  summary: string;
  detail: string;
  openapi: Record<string, unknown>;
  example?: string;
}

export interface ErrorRow {
  code: string;
  status: number;
  reason: string;
  message: string;
  summary: string;
  detail: string;
}

export interface Sample {
  id: string;
  label: string;
  file: string;
  code: string;
  keywords?: string[];
  icon?: string;
  group?: string;
}

export interface Resource {
  path: string;
  summary: string;
}

export const ORIGIN = 'https://notifi.it';
export const ENDPOINT = '/send';
export const KEY_PREFIX = 'nk_';
export const TITLE_MAX = 200;
export const MESSAGE_MAX = 16000;
export const URL_MAX = 2048;
export const IMAGE_MAX_MB = 5;
export const SENDS_PER_HOUR = 60;
export const KEYS_PER_DEVICE = 5;
export const REQUESTS_PER_MINUTE = 100;

export const SUMMARY =
  'Push notifications to an iPhone, iPad or Mac from one HTTP request.';

export const DESCRIPTION = [
  'notifi delivers a push notification to the device that created the send key you authenticate with. There is no account: install the app, copy the send key it makes on first launch, and post a title and a body to notifi.it. Notification content is encrypted with the device’s public key before it is stored, so neither notifi nor Apple can read your notifications.',
  'Send keys are minted on the device by a request signed with a private key that never leaves it. There is no endpoint that creates one, so an agent has to ask a human to copy the key out of the app’s Keys tab.',
  'When to use it: a build, backup or training run that finished or failed; a CI job or deploy that broke; a coding agent that is done or is blocked on a decision; a cron job or home server that noticed something. It is not a way to reach anyone who has not given you one of their own keys, and delivery is best-effort, so it should not be the only path for anything where a missed notification causes harm.',
].join('\n\n');

export const AUTH = {
  header: 'Authorization: Bearer nk_yourkey',
  summary:
    'Authenticate with a bearer token. A key parameter also works, but it is written to edge logs, shell history and any proxy in between: use it only for a quick test, and rotate the key afterwards.',
  bearerDescription:
    'The send key from the app’s Keys tab, as Authorization: Bearer nk_yourkey. Preferred: a header is not written to edge logs or shell history.',
  parameterDescription:
    'The send key as a parameter. It appears in edge logs, in shell history and in any proxy in between, which makes it the weaker option: use it only for a quick test, and rotate the key afterwards.',
};

export const params: Param[] = [
  {
    name: 'key',
    type: 'string',
    required: true,
    limit: 'nk_…',
    summary: 'The send key, if it is not sent as a bearer token.',
    detail:
      'Required unless sent as a bearer token. The key picks the device the notification lands on, so which key a script holds decides where its notifications go.',
    openapi: { type: 'string', pattern: '^nk_' },
    example: 'nk_yourkey',
  },
  {
    name: 'title',
    type: 'string',
    required: true,
    limit: '1–200 chars',
    summary: 'The notification title.',
    detail: 'A longer title is delivered cropped, with a warning in the response.',
    openapi: { type: 'string', minLength: 1, maxLength: TITLE_MAX },
    example: 'Hello from notifi',
  },
  {
    name: 'message',
    type: 'string',
    required: false,
    limit: '≤ 16,000 chars',
    summary: 'The notification body, in Markdown.',
    detail: 'A longer body is delivered cropped, with a warning.',
    openapi: { type: 'string', maxLength: MESSAGE_MAX },
    example: 'Your first notification.',
  },
  {
    name: 'link',
    type: 'string (uri)',
    required: false,
    limit: '≤ 2,048 chars',
    summary: 'A link to a website or internal app.',
    detail: '',
    openapi: { type: 'string', format: 'uri', maxLength: URL_MAX },
    example: 'https://notifi.it/docs',
  },
  {
    name: 'image',
    type: 'string (uri)',
    required: false,
    limit: '≤ 2,048 chars',
    summary: 'https URL of a PNG, JPEG or GIF up to 5 MB.',
    detail:
      'One that cannot be fetched is dropped, with a warning, and the notification still arrives.',
    openapi: { type: 'string', format: 'uri', maxLength: URL_MAX },
    example: 'https://notifi.it/anaglyph-bell.png',
  },
  {
    name: 'occurred_at',
    type: 'integer',
    required: false,
    limit: 'unix ms',
    summary: 'When the event actually happened, as unix milliseconds.',
    detail:
      'For a queued or retried send. Only changes the timestamp shown in the app; defaults to the time the server accepted the request.',
    openapi: { type: 'integer', format: 'int64' },
  },
  {
    name: 'is_critical',
    type: 'boolean',
    required: false,
    summary: 'Breaks through Focus.',
    detail:
      'The key must also have critical alerts switched on in the app, or an ordinary notification is delivered and the response carries a warnings array.',
    openapi: { type: 'boolean' },
  },
];

export const errors: ErrorRow[] = [
  {
    code: 'invalid_request',
    status: 400,
    reason: 'Bad Request',
    message: 'title is required.',
    summary: 'A parameter is missing or malformed.',
    detail: '',
  },
  {
    code: 'unknown_key',
    status: 401,
    reason: 'Unauthorized',
    message: 'Unknown or revoked key.',
    summary: 'The key is unknown or has been revoked.',
    detail: '',
  },
  {
    code: 'invalid_content',
    status: 422,
    reason: 'Unprocessable Content',
    message: 'Not sent. This device is set to refuse a notification it cannot deliver as written.',
    summary: 'The device is set to refuse a notification it cannot deliver as written.',
    detail: '',
  },
  {
    code: 'rate_limited',
    status: 429,
    reason: 'Too Many Requests',
    message: 'Too many notifications. Try again shortly.',
    summary: 'Over the hourly device limit or the per-minute IP limit.',
    detail: 'Carries a Retry-After header with the seconds until the window resets.',
  },
  { code: 'not_found', status: 404, reason: 'Not Found', message: 'No such path.', summary: 'No such path.', detail: '' },
  {
    code: 'internal_error',
    status: 500,
    reason: 'Internal Server Error',
    message: 'Something went wrong.',
    summary: 'Something broke on our side.',
    detail: '',
  },
];

export const limits: string[] = [
  `${SENDS_PER_HOUR} notifications an hour per device, shared across every key on it.`,
  `${KEYS_PER_DEVICE} active send keys per device, one of which is the app’s own default.`,
  `${REQUESTS_PER_MINUTE} requests a minute per IP address, across every endpoint.`,
  'Revoking a key in the app takes effect on the next send. Reinstalling the app, or moving to a new device, makes a new identity and every old key stops working; there is no migration.',
];

export const OPERATION_ERRORS = ['invalid_request', 'unknown_key', 'invalid_content', 'rate_limited'];

export const INTEGRATION_SURFACE =
  'There is no MCP server, no webhook API and no OAuth. One endpoint and a bearer token is the whole integration surface, and anything claiming otherwise is not us.';

export const resources: Resource[] = [
  { path: '/llms.txt', summary: 'The full reference as plain text, written for coding agents.' },
  { path: '/openapi.json', summary: 'OpenAPI 3.1 for /send.' },
  { path: '/notifi.postman_collection.json', summary: 'Postman v2.1 collection. Bruno, Insomnia, Hoppscotch and Paw import it too.' },
  { path: '/notifi.bru', summary: 'A Bruno request file, for dropping straight into a collection folder.' },
  { path: '/sitemap.xml', summary: 'Every page worth reading.' },
  { path: '/docs.md', summary: 'This page as Markdown.' },
];
