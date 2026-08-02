import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var testState: TestState = .idle
    @State private var testMessage: String?

    private enum TestState { case idle, sending }

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Notifications") {
                LabeledContent("Permission", value: permissionText)
                if model.notificationStatus != .authorized {
                    Button("Open System Settings") {
                        model.openSystemNotificationSettings()
                    }
                }
            }

            Section("Diagnostics") {
                Button {
                    Task { await sendTest() }
                } label: {
                    if testState == .sending {
                        ProgressView()
                    } else {
                        Text("Send Test Notification")
                    }
                }
                .disabled(testState == .sending)
                if let testMessage {
                    Text(testMessage)
                        .font(.inco(.footnote))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Display") {
                Toggle("Show unread badge", isOn: $model.badgeEnabled)
                    .onChange(of: model.badgeEnabled) { _, enabled in
                        if enabled {
                            model.sync?.updateBadge()
                        } else {
                            Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
                        }
                    }
            }

            Section("About") {
                LabeledContent("Version", value: AppModel.appVersion)
                Link("notifi.it", destination: URL(string: "https://notifi.it")!)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await model.refreshPermission() }
    }

    private var permissionText: String {
        switch model.notificationStatus {
        case .authorized: return "Enabled"
        case .denied: return "Off"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .notDetermined: return "Not set"
        @unknown default: return "Unknown"
        }
    }

    private func sendTest() async {
        testState = .sending
        testMessage = nil
        defer { testState = .idle }
        do {
            try await model.sendTestNotification()
            testMessage = "Sent. It should arrive momentarily."
        } catch {
            testMessage = (error as? APIError)?.userMessage ?? "Test failed."
        }
    }
}
