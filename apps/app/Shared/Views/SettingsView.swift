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
                GeistHeader(title: "Settings")
                    .geistPageHeader()

                // MARK: Notifications
                SectionLabel(text: "Notifications")

                FieldRow(label: "Permission") {
                    Text(permissionText)
                        .font(.inco(.subheadline, weight: .medium))
                        .foregroundStyle(model.notificationStatus == .authorized
                                         ? Theme.fg : Theme.muted)
                }
                Hairline()

                if model.notificationStatus != .authorized {
                    OutlineButton(title: "Open System Settings") {
                        model.openSystemNotificationSettings()
                    }
                    .padding(.top, 14)
                }

                // MARK: Privacy
                SectionLabel(text: "Privacy")

                ToggleRow(
                    title: "Load images automatically",
                    detail: "A message can carry an image hosted anywhere. "
                        + "Fetching it tells whoever sent the message your IP "
                        + "address and when it arrived. Off means images load "
                        + "only when you tap them.",
                    isOn: $model.remoteImagesEnabled
                )
                Hairline()

                // MARK: Diagnostics
                SectionLabel(text: "Diagnostics")

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
                .buttonStyle(.plain)
                .disabled(testState == .sending)

                if let testMessage {
                    if testFailed {
                        InlineError(message: testMessage).padding(.bottom, 12)
                    } else {
                        Text(testMessage)
                            .font(Theme.metaSmall)
                            .foregroundStyle(Theme.dim)
                            .padding(.bottom, 12)
                    }
                }
                Hairline()

                Text("Sends through your default key.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .padding(.top, 10)

                // MARK: About
                SectionLabel(text: "About")

                FieldRow("Version", AppModel.appVersion)
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
                .buttonStyle(.plain)
                .disabled(!Updater.shared.canCheck)
                Hairline()
                #endif

                Link(destination: URL(string: "https://app.notifi.it/privacy")!) {
                    DisclosureRow {
                        Text("Privacy policy")
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                Hairline()

                Text("Keys live and die with this device. If you lose it, "
                     + "the keys stop working and cannot be recovered.")
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16)

                // The site sits at the foot rather than in a row of its own: it
                // leaves the app, which is not what the rows above it do.
                Link(destination: URL(string: "https://app.notifi.it")!) {
                    HStack(spacing: 5) {
                        Text("app.notifi.it")
                            .font(Theme.metaSmall)
                        Image("akar-link-chain")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 11, height: 11)
                    }
                    .foregroundStyle(Theme.muted)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
            .geistGutter()
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
            testMessage = "No default key on this device yet. Pull to refresh and try again."
        } catch {
            testFailed = true
            testMessage = (error as? APIError)?.userMessage ?? "Test failed."
        }
        testState = .idle
    }
}
