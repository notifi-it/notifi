import { publicErrorCode, sendFields, sendResponse } from '@notifi/contract';
import { z } from 'zod';
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

type JsonObject = Record<string, unknown>;

function contractProperties(schema: z.ZodType): Record<string, JsonObject> {
  const json = z.toJSONSchema(schema) as { properties?: Record<string, JsonObject> };
  if (!json.properties) throw new Error('contract schema has no properties');
  for (const property of Object.values(json.properties)) {
    if (property.maximum === Number.MAX_SAFE_INTEGER) delete property.maximum;
  }
  return json.properties;
}

const fieldSchemas = contractProperties(sendFields);

function fieldSchema(name: string): JsonObject {
  const base = fieldSchemas[name];
  const param = params.find((p) => p.name === name);
  if (!base || !param) throw new Error(`no contract field ${name}`);
  return { ...base, ...param.openapi };
}

function assertErrorTableMatchesContract(): void {
  const documented = errors.map((e) => e.code);
  const contract = publicErrorCode.options;
  const missing = contract.filter((c) => !documented.includes(c));
  const extra = documented.filter((c) => !contract.includes(c));
  if (missing.length || extra.length) {
    throw new Error(`error table out of sync with contract: missing ${missing}, extra ${extra}`);
  }
}

const OPERATION_ERRORS = [
  'invalid_request',
  'unknown_key',
  'key_paused',
  'invalid_content',
  'rate_limited',
];

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
    out[param.name] = {
      ...fieldSchema(param.name),
      description: description(param.name),
      ...(param.example === undefined ? {} : { examples: [param.example] }),
    };
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
      schema: fieldSchema(param.name),
      ...(param.example === undefined ? {} : { example: param.example }),
    };
  }
  return out;
}

function errorResponses(): Record<string, unknown> {
  const out: Record<string, unknown> = {
    Accepted: {
      description: 'The server accepted the notification; it is not a delivery receipt.',
      content: {
        'application/json': {
          schema: { $ref: '#/components/schemas/SendResponse' },
          examples: {
            delivered: { value: { ok: true } },
            deliveredWithWarnings: {
              value: {
                ok: true,
                warnings: [
                  'Sent as a normal notification, because critical alerts are switched off for this key.',
                ],
              },
            },
          },
        },
      },
    },
  };
  const other = errors.filter((error) => !OPERATION_ERRORS.includes(error.code));
  out.UnexpectedError = {
    description: `Any other failure, in the same error shape: ${other.map((e) => e.code).join(' or ')}.`,
    content: { 'application/json': { schema: { $ref: '#/components/schemas/Error' } } },
  };
  for (const error of errors) {
    if (!OPERATION_ERRORS.includes(error.code)) continue;
    const body: Record<string, unknown> = {
      description: error.detail ? `${error.summary} ${error.detail}` : error.summary,
      content: {
        'application/json': {
          schema: { $ref: '#/components/schemas/Error' },
          example: { error: { code: error.code, message: error.message } },
        },
      },
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
  out.default = { $ref: '#/components/responses/UnexpectedError' };
  return out;
}

const responseProperties = contractProperties(sendResponse);

export function openapi(): Record<string, unknown> {
  assertErrorTableMatchesContract();
  const security = [{ sendKey: [] }, { keyParameter: [] }];
  const bodySchema = { $ref: '#/components/schemas/SendParams' };
  const bodyExample = Object.fromEntries(
    params
      .filter((p) => ['title', 'message', 'link'].includes(p.name) && p.example !== undefined)
      .map((p) => [p.name, p.example]),
  );
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
      contact: { name: 'notifi', url: ORIGIN, email: 'hello@notifi.it' },
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
            'Delivers a notification to the device that created the send key. Answers 202 once the server has accepted it, which is not a delivery receipt. Query parameters win over body fields when both are present. The key body field also authenticates; the security schemes above cannot describe a credential in the body, so it is listed only as a field of SendParams.',
          security,
          requestBody: {
            required: true,
            content: {
              'application/json': { schema: bodySchema, example: bodyExample },
              'application/x-www-form-urlencoded': { schema: bodySchema, example: bodyExample },
              'multipart/form-data': { schema: bodySchema, example: bodyExample },
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
            ok: responseProperties.ok,
            warnings: {
              ...responseProperties.warnings,
              description:
                'Present only when the notification was delivered differently from what was asked: a cropped title or body, or a critical alert delivered as an ordinary notification.',
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
                  enum: publicErrorCode.options,
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
      perIpPerMinute: REQUESTS_PER_MINUTE,
    },
  };
}
