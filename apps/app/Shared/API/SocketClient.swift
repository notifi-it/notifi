import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class SocketClient {
    enum State {
        case idle
        case connecting
        case connected
        case failed
    }

    private(set) var state: State = .idle

    private let api: APIClient
    private let onWake: (Int?) async -> Void
    private let log = Logger(subsystem: "it.notifi.notifi", category: "socket")

    private var task: URLSessionWebSocketTask?
    private var runLoop: Task<Void, Never>?
    private var attempt = 0

    init(api: APIClient, onWake: @escaping (Int?) async -> Void) {
        self.api = api
        self.onWake = onWake
    }

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

    private static let pingInterval: Duration = .seconds(45)
    private static let silenceLimit: TimeInterval = 100

    private func connectAndListen() async {
        var sawFrame = false
        do {
            let request = try api.socketRequest()
            let socket = URLSession.shared.webSocketTask(with: request)
            task = socket
            socket.resume()

            await onWake(nil)
            try? await socket.send(.string("ping"))

            var lastInbound = Date()
            let heartbeat = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: Self.pingInterval)
                    if Task.isCancelled { return }
                    if Date().timeIntervalSince(lastInbound) > Self.silenceLimit {
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
                if !sawFrame {
                    sawFrame = true
                    attempt = 0
                    enter(.connected)
                }
                if case .string("pong") = frame { continue }
                var unpushed: Int?
                if case .string(let text) = frame,
                   let parsed = try? JSONDecoder().decode(SocketFrame.self, from: Data(text.utf8)),
                   !parsed.pushed {
                    unpushed = parsed.latestID
                }
                await onWake(unpushed)
            }
        } catch {
            log.debug("socket closed: \(String(describing: error), privacy: .public)")
        }
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        if !Task.isCancelled, !sawFrame { enter(.failed) }
    }

    private func backOff() async {
        attempt = min(attempt + 1, 6)
        let base = min(pow(2.0, Double(attempt)), 60)
        let delay = base / 2 + Double.random(in: 0...(base / 2))
        try? await Task.sleep(for: .seconds(delay))
    }
}
