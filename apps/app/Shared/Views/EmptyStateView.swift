import SwiftUI
import UserNotifications

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false
    @State private var sending = false
    @State private var sent = false
    @State private var sendError: String?
    @State private var key: String?
    @State private var keyFailed = false

    private static let sampleTitle = Copy.Empty.sampleTitle
    private static let sampleMessage = Copy.Empty.sampleMessage

    private func send() {
        sending = true
        sent = false
        sendError = nil
        Task {
            do {
                try await model.sendTestNotification(
                    title: Self.sampleTitle,
                    message: Self.sampleMessage
                )
                sent = true
            } catch {
                sendError = (error as? APIError)?.userMessage
                    ?? Copy.Empty.sendFailed
            }
            sending = false
        }
    }

    private static func displayKey(_ key: String) -> String {
        guard key.count > 16 else { return key }
        return "\(key.prefix(9))…\(key.suffix(4))"
    }

    private func command(key: String) -> String {
        """
        curl "\(model.baseURL.absoluteString)/send" \\
          -d key=\(key) \\
          -d title="\(Self.sampleTitle)" \\
          -d message="\(Self.sampleMessage)" \\
          -d link="\(AppModel.sampleLink)" \\
          -d image="\(AppModel.sampleImage)"
        """
    }

    private var notificationsAllowed: Bool { model.notificationStatus == .authorized }

    private func loadKey() async {
        if let existing = model.defaultKeyValue {
            key = existing
            return
        }
        keyFailed = false
        await model.ensureDefaultKey()
        key = model.defaultKeyValue
        keyFailed = key == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            GrainyBell()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
                .padding(.bottom, 14)

            Text(Copy.Empty.title)
                .font(.inco(.title3, weight: .bold))
                .foregroundStyle(Theme.fg)

            Text(Copy.Empty.detail)
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 6)

            Hairline()
                .padding(.top, 26)
                .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 10) {
                if !notificationsAllowed {
                    OutlineButton(title: Copy.Empty.enableNotifications, fill: true) {
                        if model.notificationStatus == .denied {
                            model.openSystemNotificationSettings()
                        } else {
                            Task {
                                await model.requestNotificationPermission()
                            }
                        }
                    }

                    Hairline()
                        .padding(.vertical, 12)
                }

                if let key {
                    let command = command(key: key)

                    Text(self.command(key: Self.displayKey(key)))
                        .font(Theme.metaSmall)
                        .foregroundStyle(Theme.fg)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .stroke(Theme.line, lineWidth: 1)
                        )

                    HStack(spacing: 10) {
                        OutlineButton(title: copied ? Copy.Common.copied : Copy.Common.copy, fill: true) {
                            Clipboard.copySensitive(command)
                            copied = true
                        }

                        OutlineButton(title: sending ? Copy.Empty.sending : Copy.Empty.sendTest, fill: true) {
                            send()
                        }
                        .disabled(sending)
                    }

                    if let sendError {
                        InlineError(message: sendError)
                    } else if sent {
                        AnnouncedText(
                            message: Copy.Empty.sent,
                            color: Theme.muted
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else if keyFailed {
                    InlineError(message: Copy.Empty.makeKeyFailed)

                    OutlineButton(title: Copy.Common.tryAgain, fill: true) {
                        Task { await loadKey() }
                    }
                } else {
                    Text(Copy.Empty.makingKey)
                        .font(Theme.metaSmall)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .animation(Theme.reveal, value: notificationsAllowed)
        }
        .frame(maxWidth: 360)
        .geistGutter()
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .task { await loadKey() }
    }
}

private struct GrainyBell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            frame(shift: 0, glow: 1, grainAt: nil)
        } else {
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                frame(
                    shift: Self.chromaShift(at: time),
                    glow: Self.glow(at: time),
                    grainAt: time
                )
            }
        }
    }

    private var mark: some View {
        Image("EmptyBell")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
    }

    private func frame(shift: CGFloat, glow: Double, grainAt time: TimeInterval?) -> some View {
        ZStack {
            if shift > 0 {
                mark
                    .foregroundStyle(Theme.chromaWarm)
                    .offset(x: -shift)
                mark
                    .foregroundStyle(Theme.chromaCool)
                    .offset(x: shift)
            }

            mark
                .foregroundStyle(Theme.muted)
                .overlay { grain(at: time) }
                .mask(mark)
        }
        .opacity(glow)
    }

    @ViewBuilder
    private func grain(at time: TimeInterval?) -> some View {
        if let time {
            Canvas { canvasContext, size in
                var generator = SeededGenerator(seed: time)
                let cell: CGFloat = 3
                let columns = Int(size.width / cell) + 1
                let rows = Int(size.height / cell) + 1
                for row in 0..<rows {
                    for column in 0..<columns {
                        guard Double.random(in: 0...1, using: &generator) < 0.5 else { continue }
                        let rect = CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)
                        let brightness = Double.random(in: 0...1, using: &generator)
                        canvasContext.fill(Path(rect), with: .color(.white.opacity(brightness * 0.35)))
                    }
                }
            }
            .blendMode(.overlay)
        } else {
            Color.clear
        }
    }

    private static func chromaShift(at time: TimeInterval) -> CGFloat {
        var generator = SeededGenerator(seed: (time * 11).rounded(.down))
        guard Double.random(in: 0...1, using: &generator) < 0.22 else { return 0 }
        return CGFloat(Double.random(in: 0.8...3.2, using: &generator))
    }

    private static func glow(at time: TimeInterval) -> Double {
        var episode = SeededGenerator(seed: (time * 1.7).rounded(.down))
        guard Double.random(in: 0...1, using: &episode) < 0.13 else { return 1 }
        var pulse = SeededGenerator(seed: (time * 18).rounded(.down))
        guard Double.random(in: 0...1, using: &pulse) < 0.4 else { return 1 }
        return Double.random(in: 0.35...0.62, using: &pulse)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: TimeInterval) {
        state = UInt64(bitPattern: Int64(seed * 1000)) &* 2862933555777941757 &+ 1
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
