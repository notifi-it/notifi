import SwiftUI

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    #if os(iOS)
    @State private var showingCreate = false
    #endif

    private let brand = Color(red: 0.737, green: 0.129, blue: 0.133)

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            Image("SadBell")
                .resizable()
                .scaledToFit()
                .frame(width: 130)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                (Text("To receive notifications, send an ")
                    + Text("HTTP request").foregroundColor(brand)
                    + Text(" with your key…"))
                    .font(.inco(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let key = model.defaultKeyValue {
                    Button { Clipboard.copy(key) } label: {
                        Text(key)
                            .font(.inco(.headline, weight: .bold))
                            .foregroundColor(brand)
                            .multilineTextAlignment(.center)
                    }
                    .buttonStyle(.plain)
                    Text("tap to copy")
                        .font(.inco(.caption2))
                        .textCase(.uppercase)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 24)

            VStack(spacing: 8) {
                Button { createKey() } label: {
                    Text("Create Key")
                        .fontWeight(.semibold)
                        .frame(maxWidth: 260)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonBorderShape(.capsule)

                if model.notificationStatus != .authorized {
                    Button("Enable Notifications") {
                        Task { await model.requestNotificationPermission() }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(brand)
                    .font(.inco(.callout, weight: .medium))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(iOS)
        .sheet(isPresented: $showingCreate) {
            NavigationStack { CreateKeyView() }
                .environment(model)
        }
        #endif
    }

    private func createKey() {
        #if os(iOS)
        showingCreate = true
        #else
        model.presentingCreateKey = true
        #endif
    }
}
