import { DurableObject } from 'cloudflare:workers';
import type { Env } from './types.js';

export class DeviceSocket extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);

    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  async fetch(request: Request): Promise<Response> {
    if (request.headers.get('Upgrade') !== 'websocket') {
      return new Response('Expected websocket', { status: 426 });
    }

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];

    this.ctx.acceptWebSocket(server);

    return new Response(null, { status: 101, webSocket: client });
  }

  async notify(latestId: number, wasPushed: boolean): Promise<void> {
    const frame = JSON.stringify({ type: 'message', latest_id: latestId, pushed: wasPushed });
    for (const socket of this.ctx.getWebSockets()) {
      try {
        socket.send(frame);
      } catch {
      }
    }
  }

  webSocketMessage(): void {}

  webSocketClose(socket: WebSocket, code: number): void {
    socket.close(code === 1006 ? 1000 : code);
  }
}
