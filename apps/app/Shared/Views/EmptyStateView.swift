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
    var body: some View {
        Image("EmptyBell")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(Theme.muted)
            .grainGlyph()
    }
}
