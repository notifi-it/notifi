import SwiftUI

/// Shown when the inbox has never received anything.
struct EmptyStateView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Image("SadBell")
                .resizable()
                .scaledToFit()
                .frame(width: 118)
                .accessibilityHidden(true)
                .padding(.bottom, 16)

            Text("Nothing yet")
                .font(.inco(.title3, weight: .bold))
                .foregroundStyle(Theme.fg)

            Text("Send your first notification and it lands here.")
                .font(Theme.body)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            if model.notificationStatus != .authorized {
                OutlineButton(title: "Enable Notifications", fill: false) {
                    Task { await model.requestNotificationPermission() }
                }
                .padding(.top, 22)
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}
