import Foundation
import OSLog

/// Holds the wake socket open and calls back whenever the server says there is
/// something new.
///
/// The socket carries no content. Every frame means the same thing — "fetch" —
/// and the fetch is the ordinary signed `/history` call, so there is one code
/// path that turns server state into stored messages regardless of what woke it.
/// That also makes a dropped frame harmless: the next connect re-syncs anyway.
@MainActor
final class SocketClient {
    private let api: APIClient
    private let onWake: () async -> Void
    private let log = Logger(subsystem: "it.notifi.notifi", category: "socket")

    private var task: URLSessionWebSocketTask?
    private var runLoop: Task<Void, Never>?
    private var attempt = 0

    init(api: APIClient, onWake: @escaping () async -> Void) {
        self.api = api
        self.onWake = onWake
    }

    func start() {
        guard runLoop == nil else { return }
        runLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.connectAndListen()
                guard let self, !Task.isCancelled else { return }
                await self.backOff()
            }
        }
    }

    func stop() {
        runLoop?.cancel()
        runLoop = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        attempt = 0
    }

    /// A socket that TCP has dropped without telling either end — a NAT table
    /// that expired, a Wi-Fi handoff, a proxy that closed an idle connection —
    /// looks exactly like a quiet one. Nothing arrives and no error is raised,
    /// so without a heartbeat the app would sit on a dead socket believing it
    /// was live, and nothing short of a relaunch would find anything.
    ///
    /// 45s because the idle timeouts that cause this are commonly 60. The frame
    /// is a text "ping" rather than a protocol ping so that it matches the
    /// object's auto-response pair, which answers at the edge without waking the
    /// Durable Object and so without billing a request.
    private static let pingInterval: Duration = .seconds(45)
    /// Two intervals plus slack: one missed pong is a slow network, two is a
    /// socket that is not coming back.
    private static let silenceLimit: TimeInterval = 100

    private func connectAndListen() async {
        do {
            let request = try api.socketRequest()
            let socket = URLSession.shared.webSocketTask(with: request)
            task = socket
            socket.resume()

            // Before the first frame, not after. Whatever arrived while the
            // socket was down was never announced, and on a laptop that gap is
            // every lid close.
            await onWake()
            attempt = 0

            var lastInbound = Date()
            let heartbeat = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: Self.pingInterval)
                    if Task.isCancelled { return }
                    if Date().timeIntervalSince(lastInbound) > Self.silenceLimit {
                        // Cancelling makes the receive below throw, which is what
                        // takes the connection down and starts the reconnect.
                        socket.cancel(with: .goingAway, reason: nil)
                        return
                    }
                    try? await socket.send(.string("ping"))
                }
            }
            defer { heartbeat.cancel() }

            while !Task.isCancelled {
                let frame = try await socket.receive()
                lastInbound = Date()
                // The pong is liveness and nothing else. Syncing on it would put
                // a fetch on a 45s timer and rebuild the polling this design
                // deliberately does not have.
                if case .string("pong") = frame { continue }
                await onWake()
            }
        } catch {
            // Includes the ordinary case of the server or the network closing
            // the socket, which is not worth an error line every lid close.
            log.debug("socket closed: \(String(describing: error), privacy: .public)")
        }
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    /// Exponential with a ceiling and jitter. Without the jitter an APNs-scale
    /// outage would reconnect every device on the same second, which is the
    /// moment the server can least afford it.
    private func backOff() async {
        attempt = min(attempt + 1, 6)
        let base = min(pow(2.0, Double(attempt)), 60)
        let delay = base / 2 + Double.random(in: 0...(base / 2))
        try? await Task.sleep(for: .seconds(delay))
    }
}
