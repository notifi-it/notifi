import SwiftUI

struct EmptyStateView: View {
    @Environment(AppModel.self) private var model
    #if os(iOS)
    @State private var showingCreate = false
    #else
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        ContentUnavailableView {
            Label("No notifications yet", systemImage: "bell.badge")
        } description: {
            Text("Create a key and point your scripts, alerts, or webhooks at it.")
        } actions: {
            Button("Create First Key") { createKey() }
                .buttonStyle(.borderedProminent)
            if model.notificationStatus != .authorized {
                Button("Enable Notifications") {
                    Task { await model.requestNotificationPermission() }
                }
            }
        }
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
        openWindow(id: "create-key")
        #endif
    }
}
