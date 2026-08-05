import SwiftUI

/// Shown when the inbox has never received anything.
struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false
    @State private var sending = false
    @State private var sent = false
    @State private var sendError: String?

    private static let sampleTitle = "It lives"
    private static let sampleMessage = "notifi is working."

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
                sendError = error.localizedDescription
            }
            sending = false
        }
    }

    /// The snippet is built from the device's own default key so the first send
    /// works on paste. Without a key there is nothing to paste, so it shows the
    /// placeholder rather than a command that would 401.
    ///
    /// `--get -d` rather than a hand-built query string: curl does the escaping,
    /// which keeps each parameter on its own readable line instead of a wall of
    /// percent codes.
    private var command: String {
        let key = model.defaultKeyValue ?? "nk_your_key"
        return """
        curl --get "\(model.baseURL.absoluteString)/send" \\
          -d key=\(key) \\
          -d title="\(Self.sampleTitle)" \\
          -d message="\(Self.sampleMessage)"
        """
    }

    private var notificationsAllowed: Bool { model.notificationStatus == .authorized }

    var body: some View {
        VStack(spacing: 0) {
            // The mark as a dashed outline, as if it were pencilled in and not
            // yet filled: nothing has arrived to draw it properly. The bell that
            // used to sit here was a face drawn on older, thinner artwork.
            Image("EmptyBell")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Theme.muted)
                .frame(width: 96)
                .accessibilityHidden(true)
                .padding(.bottom, 14)

            Text("Nothing yet")
                .font(.inco(.title3, weight: .bold))
                .foregroundStyle(Theme.fg)

            Text("Send your first notification and it lands here.")
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
                    title: "Allow notifications",
                    done: notificationsAllowed
                ) {
                    if !notificationsAllowed {
                        OutlineButton(title: "Enable Notifications", fill: true) {
                            Task { await model.requestNotificationPermission() }
                        }
                    }
                }

                OnboardingStep(number: 2, title: "Send one") {
                    Text(command)
                        .font(Theme.metaSmall)
                        .foregroundStyle(Theme.fg)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.surface))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radius)
                                .stroke(Theme.line, lineWidth: 1)
                        )

                    HStack(spacing: 10) {
                        OutlineButton(title: copied ? "Copied" : "Copy", fill: true) {
                            Clipboard.copy(command)
                            copied = true
                        }

                        OutlineButton(title: sending ? "Sending…" : "Try It", fill: true) {
                            send()
                        }
                        .disabled(sending)
                    }

                    if let sendError {
                        InlineError(message: sendError)
                    } else {
                        Text(sent
                             ? "Sent. It arrives here and on your lock screen in a moment."
                             : "It arrives here and on your lock screen. Make more keys under Keys to keep sources apart.")
                            .font(Theme.metaSmall)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

/// One numbered step of the first-run walkthrough. A finished step keeps its
/// place in the list rather than disappearing, so the numbering the user was
/// just reading does not shift under them.
private struct OnboardingStep<Content: View>: View {
    var number: Int
    var title: String
    var done: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Group {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.bg)
                    } else {
                        Text("\(number)")
                            .font(.inco(.footnote, weight: .bold))
                            .foregroundStyle(Theme.fg)
                    }
                }
                .frame(width: 20, height: 20)
                .background(Circle().fill(done ? Theme.fg : Theme.chip))

                Text(title)
                    .font(.inco(.footnote, weight: .semibold))
                    .foregroundStyle(done ? Theme.dim : Theme.fg)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Step \(number). \(title).\(done ? " Done." : "")")

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
