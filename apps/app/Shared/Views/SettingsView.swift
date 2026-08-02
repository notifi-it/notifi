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
                    .padding(.top, 4)
                    .padding(.bottom, 8)

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

                // MARK: Display
                SectionLabel(text: "Display")

                Toggle(isOn: $model.badgeEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Unread badge")
                            .font(Theme.body)
                            .foregroundStyle(Theme.fg)
                        Text("Show the count on the app icon.")
                            .font(Theme.metaSmall)
                            .foregroundStyle(Theme.dim)
                    }
                }
                .tint(Theme.brand)
                .padding(.vertical, 12)
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
                    .padding(.vertical, 12)
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

                Link(destination: URL(string: "https://notifi.it")!) {
                    DisclosureRow {
                        Text("notifi.it")
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
