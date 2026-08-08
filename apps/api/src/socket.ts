import { DurableObject } from 'cloudflare:workers';
import type { Env } from './types.js';

/// One instance per device, holding that device's open sockets.
///
/// The socket carries a wake signal and nothing else: the frame says "there is
/// something new", and the device fetches it over the ordinary signed
/// `/history` call. Sending message content down the socket would mean a second
/// delivery path to seal, size, and keep in step with the push payload, for no
/// gain — the device has to reconcile against `/history` on reconnect anyway.
///
/// APNs remains the primary transport. This only covers the window where the
/// app is running and awake, which is exactly the window APNs is worst at
/// (foreground pushes the user has silenced, a token registered against the
/// wrong environment, an APNs incident).
export class DeviceSocket extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);

    // The whole cost model rests on this. A hibernated object is not billed for
    // duration, but any frame that reaches a handler wakes it and bills a
    // request — so a client keepalive every 30s would cost exactly what polling
    // costs. Auto-response answers pings at the edge without waking anything.
    ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair('ping', 'pong'));
  }

  async fetch(request: Request): Promise<Response> {
    if (request.headers.get('Upgrade') !== 'websocket') {
      return new Response('Expected websocket', { status: 426 });
    }

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];

    // `acceptWebSocket`, not `server.accept()`. The latter pins this object in
    // memory for the life of the connection, which for an always-on menu bar app
    // means paying duration around the clock.
    this.ctx.acceptWebSocket(server);

    return new Response(null, { status: 101, webSocket: client });
  }

  /// Called by the send path once the message is durably in D1.
  async notify(seq: number): Promise<void> {
    const frame = JSON.stringify({ type: 'message', latest_id: seq });
    for (const socket of this.ctx.getWebSockets()) {
      try {
        socket.send(frame);
      } catch {
        // A socket the client has already dropped without a close frame. The
        // device will catch up over /history when it reconnects, so there is
        // nothing to recover here and nothing worth failing the send for.
      }
    }
  }

  /// Nothing the client says is acted on — the device drives everything through
  /// signed HTTP. Anything arriving here is either a keepalive that missed the
  /// auto-response pair or a client that should not be sending.
  webSocketMessage(): void {}

  webSocketClose(socket: WebSocket, code: number): void {
    // 1006 is never a valid close code to send back; the runtime rejects it and
    // the object is torn down with an error instead of closing cleanly.
    socket.close(code === 1006 ? 1000 : code);
  }
}
