import SwiftUI
import UserNotifications

/// Settings.
///
/// Geist replaces `Form` with hairline-ruled sections — `Form` brings grouped
/// backgrounds and system insets that fight a pure-black ground.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var testState: TestState = .idle
    @State private var testMessage: String?
    @State private var testFailed = false

    private enum TestState { case idle, sending }

    var body: some View {
        @Bindable var model = model

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // The gutter sits on each block rather than on the stack, so
                // the rules between rows run the full width of the screen while
                // the content they separate stays inside the margin.
                GeistHeader(title: "Settings")
                    .geistPageHeader()
                    .geistGutter()

                // MARK: Notifications
                SectionLabel(text: "Notifications")
                    .geistGutter()

                FieldRow(label: "Permission") {
                    Text(permissionText)
                        .font(.inco(.subheadline, weight: .medium))
                        .foregroundStyle(model.notificationStatus == .authorized
                                         ? Theme.fg : Theme.muted)
                }
                .geistGutter()
                Hairline()

                if model.notificationStatus != .authorized {
                    OutlineButton(title: "Open system settings") {
                        model.openSystemNotificationSettings()
                    }
                    .padding(.top, 14)
                    .geistGutter()
                }

                // MARK: Privacy
                SectionLabel(text: "Privacy")
                    .geistGutter()

                ToggleRow(
                    title: "Load images automatically",
                    detail: "Fetching an image tells the sender your IP address "
                        + "and when it arrived. Off, images load only when tapped.",
                    isOn: $model.remoteImagesEnabled
                )
                .geistGutter()
                Hairline()

                // MARK: Diagnostics
                SectionLabel(text: "Diagnostics")
                    .geistGutter()

                Button {
                    Task { await sendTest() }
                } label: {
                    HStack(spacing: 10) {
                        Text("Send test notification")
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                        Spacer(minLength: 8)
                        if testState == .sending {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.muted)
                        } else {
                            Image(systemName: "paperplane")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.dim)
                        }
                    }
                    .padding(.vertical, Theme.rowPadV)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.geistRow)
                .disabled(testState == .sending)
                .geistGutter()

                if let testMessage {
                    Group {
                        if testFailed {
                            InlineError(message: testMessage).padding(.bottom, 12)
                        } else {
                            AnnouncedText(message: testMessage)
                                .padding(.bottom, 12)
                        }
                    }
                    .geistGutter()
                }
                Hairline()

                Text("Sends through your default key.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 10)
                    .geistGutter()

                // MARK: About
                SectionLabel(text: "About")
                    .geistGutter()

                FieldRow("Version", AppModel.appVersion)
                    .geistGutter()
                Hairline()

                // Sparkle only exists in the macOS build; iOS updates through the
                // App Store and does not link it.
                #if os(macOS)
                ToggleRow(
                    title: "Automatic updates",
                    detail: "Check for new versions in the background.",
                    isOn: Binding(
                        get: { Updater.shared.automaticallyChecks },
                        set: { Updater.shared.automaticallyChecks = $0 }
                    )
                )
                .geistGutter()
                Hairline()

                Button {
                    Updater.shared.checkForUpdates()
                } label: {
                    DisclosureRow {
                        Text("Check for updates")
                            .font(Theme.body)
                            .foregroundStyle(Updater.shared.canCheck ? Theme.fg : Theme.dim)
                    }
                    .padding(.vertical, Theme.rowPadV)
                }
                .buttonStyle(.geistRow)
                .disabled(!Updater.shared.canCheck)
                .geistGutter()
                Hairline()
                #endif

                Link(destination: URL(string: "https://notifi.it/privacy")!) {
                    DisclosureRow {
                        Text("Privacy policy")
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.geistRow)
                .geistGutter()
                Hairline()

                Text("Keys live and die with this device. If you lose it, "
                     + "the keys stop working and cannot be recovered.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)
                    .geistGutter()

                // The site sits at the foot rather than in a row of its own: it
                // leaves the app, which is not what the rows above it do.
                Link(destination: URL(string: "https://notifi.it")!) {
                    HStack(spacing: 5) {
                        Text("notifi.it")
                            .font(Theme.metaSmall)
                        Image("akar-link-chain")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 11, height: 11)
                    }
                    .foregroundStyle(Theme.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.geist)
                // 11pt text and an 11pt glyph, so the drawn target is about a
                // third of the minimum.
                .geistHitArea(expandedBy: 15)
                .padding(.top, 14)
                .padding(.bottom, 40)
                .geistGutter()
            }
            .geistMeasure()
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task { await model.refreshPermission() }
    }

    private var permissionText: String {
        switch model.notificationStatus {
        case .authorized: "Enabled"
        case .denied: "Off"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        case .notDetermined: "Not set"
        @unknown default: "Unknown"
        }
    }

    private func sendTest() async {
        testState = .sending
        testMessage = nil
        testFailed = false
        do {
            try await model.sendTestNotification()
            testMessage = "Sent. It should arrive momentarily."
        } catch NotifiError.identityMissing {
            testFailed = true
            testMessage = "No default key on this device yet. Refresh and try again."
        } catch {
            testFailed = true
            testMessage = (error as? APIError)?.userMessage ?? "Couldn't send the test. Check your connection and try again."
        }
        testState = .idle
    }
}
