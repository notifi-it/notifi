import SwiftUI

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false
    @State private var sending = false
    @State private var sent = false
    @State private var sendError: String?
    @State private var key: String?
    @State private var keyFailed = false
    @State private var openStep = 1

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
          -d message="\(Self.sampleMessage)"
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

            VStack(alignment: .leading, spacing: 22) {
                OnboardingStep(
                    number: 1,
                    title: Copy.Empty.stepAllow,
                    done: notificationsAllowed,
                    open: openStep == 1,
                    toggle: { openStep = openStep == 1 ? 0 : 1 }
                ) {
                    if notificationsAllowed {
                        Text(Copy.Empty.notificationsOn)
                            .font(Theme.metaSmall)
                            .foregroundStyle(Theme.muted)
                    } else {
                        OutlineButton(title: Copy.Empty.enableNotifications, fill: true) {
                            Task {
                                await model.requestNotificationPermission()
                            }
                        }
                    }
                }

                OnboardingStep(
                    number: 2,
                    title: Copy.Empty.stepSend,
                    open: openStep == 2,
                    toggle: { openStep = openStep == 2 ? 0 : 2 }
                ) {
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
                        } else {
                            Text(Copy.Empty.sentDetail)
                                .font(Theme.metaSmall)
                                .foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
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
            }
        }
        .frame(maxWidth: 360)
        .geistGutter()
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .task { await loadKey() }
        .onAppear {
            openStep = notificationsAllowed ? 2 : 1
        }
        .onChange(of: notificationsAllowed) { _, allowed in
            if allowed, openStep == 1 { openStep = 2 }
        }
    }
}

private struct GrainyBell: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let bell = Image("EmptyBell")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()

        let body = bell
            .foregroundStyle(Theme.muted)
            .overlay {
                if reduceMotion {
                    Color.clear
                } else {
                    TimelineView(.animation) { context in
                        Canvas { canvasContext, size in
                            var generator = SeededGenerator(seed: context.date.timeIntervalSinceReferenceDate)
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
                    }
                    .blendMode(.overlay)
                }
            }
            .mask(bell)

        if reduceMotion {
            body
        } else {
            TimelineView(.animation) { context in
                body.offset(x: Self.jitter(at: context.date.timeIntervalSinceReferenceDate))
            }
        }
    }

    private static func jitter(at time: TimeInterval) -> CGFloat {
        var generator = SeededGenerator(seed: (time * 14).rounded(.down))
        guard Double.random(in: 0...1, using: &generator) < 0.25 else { return 0 }
        return CGFloat(Double.random(in: -3...3, using: &generator))
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

private struct OnboardingStep<Content: View>: View {
    var number: Int
    var title: String
    var done: Bool = false
    var open: Bool
    var toggle: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
            HStack(spacing: 8) {
                Group {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .symbolEffect(.bounce, value: done)
                            .transition(.opacity)
                    } else {
                        Text("\(number)")
                            .font(.inco(.footnote, weight: .bold))
                            .foregroundStyle(Theme.fg)
                            .transition(.opacity)
                    }
                }
                .frame(width: 20, height: 20)
                .background(Circle().fill(done ? Theme.fg : Theme.chip))

                Text(title)
                    .font(.inco(.footnote, weight: .semibold))
                    .foregroundStyle(done ? Theme.dim : Theme.fg)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .rotationEffect(.degrees(open ? 0 : -90))
            }
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Copy.Empty.stepLabel("\(number)", title) + (done ? Copy.Empty.stepDone : ""))
            .accessibilityHint(open ? Copy.Common.collapse : Copy.Common.expand)

            VStack(alignment: .leading, spacing: 10) {
                if open {
                    content
                }
            }
            .padding(.top, open ? 10 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(Theme.state, value: done)
    }
}
