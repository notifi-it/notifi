import SwiftUI

/// Shown when the inbox has never received anything.
struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false
    @State private var sending = false
    @State private var sent = false
    @State private var sendError: String?
    @State private var key: String?
    @State private var keyFailed = false
    /// Which step is open. One at a time: the two steps are ordered, and showing
    /// both at once is what pushed the send command below the fold on a phone.
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
                // Every other call site maps through `userMessage`; this one was
                // handing the reader whatever `localizedDescription` happened to
                // produce, which for a decoding failure is Swift's own diagnostic.
                sendError = (error as? APIError)?.userMessage
                    ?? Copy.Empty.sendFailed
            }
            sending = false
        }
    }

    /// The snippet is built from the device's own default key so the first send
    /// works on paste.
    ///
    /// `-d` rather than a hand-built query string: curl does the escaping,
    /// which keeps each parameter on its own readable line instead of a wall of
    /// percent codes. A POST rather than `--get`, so the key rides in the body
    /// instead of a URL that lands in edge logs and shell history.
    private func command(key: String) -> String {
        """
        curl "\(model.baseURL.absoluteString)/send" \\
          -d key=\(key) \\
          -d title="\(Self.sampleTitle)" \\
          -d message="\(Self.sampleMessage)"
        """
    }

    private var notificationsAllowed: Bool { model.notificationStatus == .authorized }

    /// The key is minted by a boot task that this screen regularly beats onto the
    /// display. Rather than print a `nk_your_key` placeholder — a command that
    /// looks copyable and answers 401 — step 2 waits, and asks for the key itself
    /// in case the boot attempt failed while offline.
    private func loadKey() async {
        if let existing = model.defaultKeyValue {
            key = existing
            return
        }
        keyFailed = false
        await model.ensureDefaultKey()
        key = model.defaultKeyValue
        // `ensureDefaultKey` swallows its own failures into the log, so a key
        // that is still missing afterwards is the only signal the screen gets.
        keyFailed = key == nil
    }

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
        // Granting permission finishes step 1, so step 2 is what the user came for
        // next. Moving there beats leaving a finished step open above a closed one.
        .onChange(of: notificationsAllowed) { _, allowed in
            if allowed, openStep == 1 { openStep = 2 }
        }
    }
}

/// One numbered step of the first-run walkthrough, collapsible. A finished step
/// keeps its place in the list rather than disappearing, so the numbering the
/// user was just reading does not shift under them.
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
                            // The one deliberately expressive moment in the app.
                            // It is affordable here and nowhere else: this screen
                            // is only ever seen before the first notification
                            // lands, so nobody sees this twice.
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

            // Opening and closing is not animated. The height change here is a
            // large one — a code block and two buttons — and no curve made it
            // read as anything but the rest of the screen being shoved. The
            // chevron carries the state change instead.
            VStack(alignment: .leading, spacing: 10) {
                if open {
                    content
                }
            }
            .padding(.top, open ? 10 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Granting notifications changed the number to a tick, filled the disc,
        // greyed the title and removed the Enable button beneath it, all on one
        // frame — the step went from "do this" to "done" with nothing marking
        // that it had been the user who did it. Scoped to `done` so typing or
        // sending elsewhere in the step does not animate.
        .animation(Theme.state, value: done)
    }
}
