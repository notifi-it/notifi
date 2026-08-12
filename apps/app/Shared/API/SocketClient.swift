import Foundation
import Observation
import OSLog

/// Holds the wake socket open and calls back whenever the server says there is
/// something new.
///
/// The socket carries no content. Every frame means the same thing — "fetch" —
/// and the fetch is the ordinary signed `/history` call, so there is one code
/// path that turns server state into stored messages regardless of what woke it.
/// That also makes a dropped frame harmless: the next connect re-syncs anyway.
///
/// Observable so that a view reading `state` through `AppModel.isOffline` is
/// redrawn when it changes. The Mac learns the same thing from
/// `notifiConnectivityChanged`, because its status item is AppKit and observes
/// nothing; iOS had no equivalent, so the offline banner appeared and vanished
/// on whatever unrelated redraw happened next rather than when connectivity
/// actually moved.
@MainActor
@Observable
final class SocketClient {
    /// Where the connection stands. This is the app's only live connectivity
    /// signal: the menu bar reads it to decide whether to strike the bell
    /// through, and the Inbox to decide whether to say it cannot reach notifi.
    ///
    /// Four states rather than a Bool because "not connected" covers two
    /// situations a reader would describe differently. A socket that has been
    /// asked for and has not answered yet is not an outage — and on iOS that
    /// gap is every single foreground, since the connection is torn down on
    /// background and the first attempt runs a full `/history` sync before it
    /// counts as open. Reporting that as offline showed the banner, and with it
    /// an error haptic, on essentially every launch.
    enum State {
        /// Nobody has asked for a connection, or it has been stopped.
        case idle
        /// The first attempt is in flight and has not failed yet.
        case connecting
        case connected
        /// An attempt has been made and did not hold. Retries stay in this
        /// state: once connectivity is known to be broken, the reader should
        /// not watch the banner blink off for each attempt.
        case failed
    }

    private(set) var state: State = .idle

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

    /// The only writer of `state`: the notification has to fire on every real
    /// move and on no repeat, and `didSet` cannot carry that under `@Observable`.
    private func enter(_ next: State) {
        guard state != next else { return }
        state = next
        NotificationCenter.default.post(name: .notifiConnectivityChanged, object: nil)
    }

    func start() {
        guard runLoop == nil else { return }
        enter(.connecting)
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
        enter(.idle)
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
            enter(.connected)

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
        // A cancelled run loop is `stop()` unwinding — the app backgrounding, or
        // the Mac quitting — which `stop()` has already recorded as `.idle`. Only
        // a socket that ended on its own is a failure.
        if !Task.isCancelled { enter(.failed) }
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
