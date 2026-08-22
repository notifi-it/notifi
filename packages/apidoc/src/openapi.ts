import {
  AUTH,
  DESCRIPTION,
  ENDPOINT,
  ORIGIN,
  REQUESTS_PER_MINUTE,
  SENDS_PER_HOUR,
  SUMMARY,
  errors,
  params,
} from './spec.js';

const OPERATION_ERRORS = ['invalid_request', 'unknown_key', 'invalid_content', 'rate_limited'];

function responseName(code: string): string {
  return code
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join('');
}

function description(name: string): string {
  const param = params.find((p) => p.name === name);
  if (!param) throw new Error(`no parameter ${name}`);
  return param.detail ? `${param.summary} ${param.detail}` : param.summary;
}

function properties(): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const param of params) {
    out[param.name] = { ...param.openapi, description: description(param.name) };
  }
  return out;
}

function queryParameters(): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const param of params) {
    out[param.name] = {
      name: param.name,
      in: 'query',
      required: param.name === 'title',
      description: param.summary,
      schema: param.openapi,
    };
  }
  return out;
}

function errorResponses(): Record<string, unknown> {
  const out: Record<string, unknown> = {
    Accepted: {
      description: 'The server accepted the notification. Not a delivery receipt.',
      content: { 'application/json': { schema: { $ref: '#/components/schemas/SendResponse' } } },
    },
  };
  for (const error of errors) {
    if (!OPERATION_ERRORS.includes(error.code)) continue;
    const body: Record<string, unknown> = {
      description: error.detail ? `${error.summary} ${error.detail}` : error.summary,
      content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
    };
    if (error.code === 'rate_limited') {
      body.headers = {
        'Retry-After': {
          description: 'Seconds until the window resets.',
          schema: { type: 'integer' },
        },
      };
    }
    out[responseName(error.code)] = body;
  }
  return out;
}

function operationResponses(): Record<string, unknown> {
  const out: Record<string, unknown> = { '202': { $ref: '#/components/responses/Accepted' } };
  for (const error of errors) {
    if (!OPERATION_ERRORS.includes(error.code)) continue;
    out[String(error.status)] = { $ref: `#/components/responses/${responseName(error.code)}` };
  }
  return out;
}

export function openapi(): Record<string, unknown> {
  const security = [{ sendKey: [] }, { keyParameter: [] }];
  const bodySchema = { $ref: '#/components/schemas/SendParams' };
  return {
    openapi: '3.1.0',
    info: {
      title: 'notifi',
      summary: SUMMARY,
      description: DESCRIPTION,
      version: '1.0.0',
      termsOfService: `${ORIGIN}/terms`,
      license: {
        name: 'MIT',
        url: 'https://github.com/notifi-it/notifi/blob/main/LICENSE',
      },
      contact: { name: 'notifi', url: `${ORIGIN}/contact`, email: 'hello@notifi.it' },
    },
    externalDocs: { description: 'notifi API documentation', url: `${ORIGIN}/docs` },
    servers: [{ url: ORIGIN, description: 'Production' }],
    tags: [{ name: 'send', description: 'Delivering a notification.' }],
    paths: {
      [ENDPOINT]: {
        get: {
          tags: ['send'],
          operationId: 'sendNotificationViaQuery',
          summary: 'Send a notification with query parameters',
          description:
            'The same operation as POST /send, for a quick test from a browser or a shell. A key in a query string ends up in edge logs and shell history, so prefer POST with an Authorization header, and rotate any key you have sent this way.',
          security,
          parameters: params.map((p) => ({ $ref: `#/components/parameters/${p.name}` })),
          responses: operationResponses(),
        },
        post: {
          tags: ['send'],
          operationId: 'sendNotification',
          summary: 'Send a notification',
          description:
            'Delivers a notification to the device that created the send key. Answers 202 once the server has accepted it, which is not a delivery receipt. Query parameters win over body fields when both are present.',
          security,
          requestBody: {
            required: true,
            content: {
              'application/json': { schema: bodySchema },
              'application/x-www-form-urlencoded': { schema: bodySchema },
              'multipart/form-data': { schema: bodySchema },
            },
          },
          responses: operationResponses(),
        },
      },
    },
    components: {
      securitySchemes: {
        sendKey: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'nk_',
          description: AUTH.bearerDescription,
        },
        keyParameter: {
          type: 'apiKey',
          in: 'query',
          name: 'key',
          description: AUTH.parameterDescription,
        },
      },
      parameters: queryParameters(),
      schemas: {
        SendParams: {
          type: 'object',
          required: ['title'],
          properties: properties(),
          additionalProperties: false,
        },
        SendResponse: {
          type: 'object',
          required: ['ok'],
          properties: {
            ok: { const: true },
            warnings: {
              type: 'array',
              items: { type: 'string' },
              description:
                'Present only when the notification was delivered differently from what was asked: a cropped title or body, a dropped image, or a critical alert downgraded to an ordinary one.',
            },
          },
        },
        Error: {
          type: 'object',
          required: ['error'],
          properties: {
            error: {
              type: 'object',
              required: ['code', 'message'],
              properties: {
                code: {
                  type: 'string',
                  enum: errors.map((e) => e.code),
                  description: 'Read error.code, not code: the code is nested one level down.',
                },
                message: {
                  type: 'string',
                  description:
                    'A readable explanation, in the language negotiated from Accept-Language.',
                },
              },
            },
          },
        },
      },
      responses: errorResponses(),
    },
    'x-rate-limits': {
      perDevicePerHour: SENDS_PER_HOUR,
      perAddressPerMinute: REQUESTS_PER_MINUTE,
    },
  };
}
